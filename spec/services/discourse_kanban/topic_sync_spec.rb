# frozen_string_literal: true

RSpec.describe DiscourseKanban::TopicSync do
  fab!(:admin)
  fab!(:category) { Fabricate(:category, name: "Todo") }
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  it "creates an auto topic card when board and column filters match" do
    board =
      DiscourseKanban::Board.create!(
        name: "Todo Board",
        slug: "todo-board",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )

    column = board.columns.create!(title: "Backlog", position: 0)

    expect { described_class.sync_topic(topic) }.to change { DiscourseKanban::Card.count }.by(1)

    card = DiscourseKanban::Card.last
    expect(card.topic_id).to eq(topic.id)
    expect(card.column_id).to eq(column.id)
    expect(card.membership_mode).to eq("auto")
  end

  it "does not override manually removed topic cards" do
    board =
      DiscourseKanban::Board.create!(
        name: "Todo Board",
        slug: "todo-board-2",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )

    board.columns.create!(title: "Backlog", position: 0)

    card =
      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        membership_mode: :manual_out,
        position: 0,
        created_by_id: admin.id,
      )

    described_class.sync_topic(topic)

    expect(card.reload.membership_mode).to eq("manual_out")
    expect(card.column_id).to be_nil
  end

  it "treats board base_filter_query as a hard constraint before column filters" do
    board =
      DiscourseKanban::Board.create!(
        name: "Hard Constraint Board",
        slug: "hard-constraint-board",
        base_filter_query: "category:another-category",
        created_by_id: admin.id,
      )

    board.columns.create!(title: "Backlog", position: 0, filter_query: "category:#{category.slug}")

    expect { described_class.sync_topic(topic) }.not_to change { DiscourseKanban::Card.count }
  end

  it "auto-adds topics when base_filter_query is blank and a column filter matches" do
    board =
      DiscourseKanban::Board.create!(
        name: "Blank Base Board",
        slug: "blank-base-board",
        created_by_id: admin.id,
      )

    board.columns.create!(title: "Backlog", position: 0, filter_query: "category:#{category.slug}")

    expect { described_class.sync_topic(topic) }.to change { DiscourseKanban::Card.count }.by(1)
  end

  it "does not auto-add topics when base_filter_query is blank and columns are unfiltered" do
    board =
      DiscourseKanban::Board.create!(
        name: "No Filter Board",
        slug: "no-filter-board",
        created_by_id: admin.id,
      )
    board.columns.create!(title: "Backlog", position: 0)

    expect { described_class.sync_topic(topic) }.not_to change { DiscourseKanban::Card.count }
  end

  it "removes an auto card when the board base_filter_query no longer matches" do
    board =
      DiscourseKanban::Board.create!(
        name: "Remove Auto Board",
        slug: "remove-auto-board",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )

    board.columns.create!(title: "Backlog", position: 0)
    described_class.sync_topic(topic)
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)

    board.update!(base_filter_query: "category:another-category")

    expect { described_class.sync_topic(topic) }.to change {
      board.cards.where(topic_id: topic.id).count
    }.from(1).to(0)
  end

  it "does not remove manual_in cards when filters no longer match" do
    board =
      DiscourseKanban::Board.create!(
        name: "Manual In Board",
        slug: "manual-in-board",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Backlog", position: 0)

    card =
      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        membership_mode: :manual_in,
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )

    board.update!(base_filter_query: "category:another-category")
    described_class.sync_topic(topic)

    expect(card.reload.membership_mode).to eq("manual_in")
    expect(card.column_id).to eq(column.id)
  end

  it "removes an auto card when no column matches after board match" do
    board =
      DiscourseKanban::Board.create!(
        name: "Remove On Column Miss Board",
        slug: "remove-on-column-miss-board",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )

    column = board.columns.create!(title: "Backlog", position: 0)
    described_class.sync_topic(topic)
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)

    column.update!(filter_query: "status:closed")

    expect { described_class.sync_topic(topic) }.to change {
      board.cards.where(topic_id: topic.id).count
    }.from(1).to(0)
  end

  it "moves an auto card when the first matching column changes" do
    board =
      DiscourseKanban::Board.create!(
        name: "Move Auto Board",
        slug: "move-auto-board",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )

    first_column = board.columns.create!(title: "Ready", position: 0, filter_query: "status:closed")
    second_column = board.columns.create!(title: "Backlog", position: 1)

    described_class.sync_topic(topic)
    expect(board.cards.find_by(topic_id: topic.id)&.column_id).to eq(second_column.id)

    first_column.update!(filter_query: "")
    described_class.sync_topic(topic)

    expect(board.cards.find_by(topic_id: topic.id)&.column_id).to eq(first_column.id)
  end

  it "rolls back sync changes when apply fails part way through" do
    board =
      DiscourseKanban::Board.create!(
        name: "Atomic Board",
        slug: "atomic-board",
        base_filter_query: "category:#{category.slug}",
        created_by_id: admin.id,
      )
    board.columns.create!(title: "Backlog", position: 0)

    described_class.sync_topic(topic)
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)

    board.update!(base_filter_query: "category:another-category")

    described_class.stubs(:create_auto_cards).raises(StandardError.new("create boom"))

    expect { described_class.sync_topic(topic) }.to raise_error(StandardError, "create boom")
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)
  end

  it "retries once when a unique topic-card violation happens" do
    attempts = 0

    described_class.send(:with_topic_sync_retry) do
      attempts += 1
      if attempts == 1
        raise ActiveRecord::RecordNotUnique.new("idx_kanban_cards_unique_topic_per_board")
      end
    end

    expect(attempts).to eq(2)
  end

  it "removes cards when topic is removed" do
    board =
      DiscourseKanban::Board.create!(
        name: "Todo Board",
        slug: "todo-board-3",
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Backlog", position: 0)

    board.cards.create!(
      topic_id: topic.id,
      card_type: :topic,
      membership_mode: :manual_in,
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )

    expect { described_class.remove_topic(topic.id) }.to change { DiscourseKanban::Card.count }.by(
      -1,
    )
  end

  describe ".backfill_board" do
    it "creates cards for matching topics that have no card record" do
      topic_2 = Fabricate(:topic, category: category)

      board =
        DiscourseKanban::Board.create!(
          name: "Backfill Board",
          slug: "backfill-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      column = board.columns.create!(title: "Backlog", position: 0)

      expect { described_class.backfill_board(board) }.to change { DiscourseKanban::Card.count }.by(
        2,
      )

      expect(board.cards.where(topic_id: topic.id).first.column_id).to eq(column.id)
      expect(board.cards.where(topic_id: topic_2.id).first.column_id).to eq(column.id)
    end

    it "does not duplicate cards for topics that already have one" do
      board =
        DiscourseKanban::Board.create!(
          name: "No Dup Board",
          slug: "no-dup-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      column = board.columns.create!(title: "Backlog", position: 0)

      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        membership_mode: :manual_in,
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )

      expect { described_class.backfill_board(board) }.not_to change {
        board.cards.where(topic_id: topic.id).count
      }
    end

    it "respects manual_out cards and does not re-add them" do
      board =
        DiscourseKanban::Board.create!(
          name: "Manual Out Board",
          slug: "manual-out-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        membership_mode: :manual_out,
        position: 0,
        created_by_id: admin.id,
      )

      described_class.backfill_board(board)

      card = board.cards.find_by(topic_id: topic.id)
      expect(card.membership_mode).to eq("manual_out")
      expect(card.column_id).to be_nil
    end

    it "excludes category definition topics" do
      board =
        DiscourseKanban::Board.create!(
          name: "No Defs Board",
          slug: "no-defs-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      described_class.backfill_board(board)

      carded_topic_ids = board.cards.pluck(:topic_id)
      expect(carded_topic_ids).to include(topic.id)
      expect(carded_topic_ids).not_to include(category.topic_id)
    end

    it "discovers topics using column filter_query when base_filter_query is blank" do
      board =
        DiscourseKanban::Board.create!(
          name: "Column Filter Board",
          slug: "column-filter-board",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Design", position: 0, filter_query: "category:#{category.slug}")

      expect { described_class.backfill_board(board) }.to change { DiscourseKanban::Card.count }.by(
        1,
      )
    end

    it "does not discover topics when base_filter_query is blank and columns are unfiltered" do
      board =
        DiscourseKanban::Board.create!(
          name: "No Filter Backfill Board",
          slug: "no-filter-backfill-board",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Design", position: 0)

      expect { described_class.backfill_board(board) }.not_to change { DiscourseKanban::Card.count }
    end
  end

  describe "PostCreator integration" do
    it "does not interfere with topic creation" do
      DiscourseKanban::Board
        .create!(
          name: "Board",
          slug: "post-creator-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
        .columns
        .create!(title: "Backlog", position: 0)

      post =
        PostCreator.create!(
          admin,
          title: "A topic created while kanban is active",
          raw: "This should succeed without any errors from the plugin.",
          category: category.id,
          archetype: Archetype.default,
        )

      expect(post).to be_persisted
      expect(post.topic).to be_persisted
    end

    it "does not break topic creation when sync raises an error" do
      DiscourseKanban::TopicSync.stubs(:sync_topic).raises(StandardError.new("sync boom"))

      post =
        PostCreator.create!(
          admin,
          title: "A topic created while sync is broken",
          raw: "This should still succeed despite sync errors.",
          category: category.id,
          archetype: Archetype.default,
        )

      expect(post).to be_persisted
      expect(post.topic).to be_persisted
    end
  end
end
