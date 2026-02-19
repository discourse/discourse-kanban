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
  end
end
