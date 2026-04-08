# frozen_string_literal: true

RSpec.describe DiscourseKanban::TopicSync do
  fab!(:admin)
  fab!(:category) { Fabricate(:category, name: "Todo") }
  fab!(:tag_a) { Fabricate(:tag, name: "sync-alpha") }
  fab!(:tag_b) { Fabricate(:tag, name: "sync-beta") }
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  it "creates an auto topic card when board category matches and column is catch-all" do
    board =
      DiscourseKanban::Board.create!(
        name: "Todo Board",
        slug: "todo-board",
        category_ids: [category.id],
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Backlog", position: 0)

    expect { described_class.sync_topic(topic) }.to change { DiscourseKanban::Card.count }.by(1)

    card = DiscourseKanban::Card.last
    expect(card.topic_id).to eq(topic.id)
    expect(card.column_id).to eq(column.id)
  end

  it "creates an auto card when board tag matches and column tag matches" do
    tagged_topic = Fabricate(:topic, tags: [tag_a])
    board =
      DiscourseKanban::Board.create!(
        name: "Tag Board",
        slug: "tag-board",
        tag_ids: [tag_a.id],
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)

    expect { described_class.sync_topic(tagged_topic) }.to change {
      DiscourseKanban::Card.count
    }.by(1)

    card = DiscourseKanban::Card.last
    expect(card.column_id).to eq(column.id)
  end

  it "does not match topics when board has no constraints" do
    board =
      DiscourseKanban::Board.create!(
        name: "No Filter Board",
        slug: "no-filter-board",
        created_by_id: admin.id,
      )
    board.columns.create!(title: "Backlog", position: 0)

    expect { described_class.sync_topic(topic) }.not_to change { DiscourseKanban::Card.count }
  end

  it "does not delete existing cards on unconstrained boards" do
    board =
      DiscourseKanban::Board.create!(
        name: "Manual Board",
        slug: "manual-board",
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Backlog", position: 0)

    board.cards.create!(
      topic_id: topic.id,
      card_type: :topic,
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )

    expect { described_class.sync_topic(topic) }.not_to change { DiscourseKanban::Card.count }
  end

  it "does not match topics in wrong category" do
    other_category = Fabricate(:category)
    board =
      DiscourseKanban::Board.create!(
        name: "Wrong Cat Board",
        slug: "wrong-cat-board",
        category_ids: [other_category.id],
        created_by_id: admin.id,
      )
    board.columns.create!(title: "Backlog", position: 0)

    expect { described_class.sync_topic(topic) }.not_to change { DiscourseKanban::Card.count }
  end

  it "places a topic in multiple columns when it matches multiple column tags" do
    multi_topic = Fabricate(:topic, category: category, tags: [tag_a, tag_b])

    board =
      DiscourseKanban::Board.create!(
        name: "Multi Column Board",
        slug: "multi-column-board",
        category_ids: [category.id],
        created_by_id: admin.id,
      )
    col_a = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)
    col_b = board.columns.create!(title: "Beta", position: 1, tag_id: tag_b.id)

    expect { described_class.sync_topic(multi_topic) }.to change { DiscourseKanban::Card.count }.by(
      2,
    )

    expect(board.cards.where(topic_id: multi_topic.id).pluck(:column_id)).to contain_exactly(
      col_a.id,
      col_b.id,
    )
  end

  it "removes an auto card when the board category no longer matches" do
    board =
      DiscourseKanban::Board.create!(
        name: "Remove Auto Board",
        slug: "remove-auto-board",
        category_ids: [category.id],
        created_by_id: admin.id,
      )
    board.columns.create!(title: "Backlog", position: 0)
    described_class.sync_topic(topic)
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)

    other_category = Fabricate(:category)
    board.update!(category_ids: [other_category.id])

    expect { described_class.sync_topic(topic) }.to change {
      board.cards.where(topic_id: topic.id).count
    }.from(1).to(0)
  end

  it "removes cards when board constraints no longer match" do
    board =
      DiscourseKanban::Board.create!(
        name: "Constraint Board",
        slug: "constraint-board",
        category_ids: [category.id],
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Backlog", position: 0)

    board.cards.create!(
      topic_id: topic.id,
      card_type: :topic,
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )

    other_category = Fabricate(:category)
    board.update!(category_ids: [other_category.id])
    described_class.sync_topic(topic)

    expect(board.cards.where(topic_id: topic.id).count).to eq(0)
  end

  it "removes an auto card when column tag no longer matches topic" do
    tagged_topic = Fabricate(:topic, category: category, tags: [tag_a])

    board =
      DiscourseKanban::Board.create!(
        name: "Tag Miss Board",
        slug: "tag-miss-board",
        category_ids: [category.id],
        created_by_id: admin.id,
      )
    col = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)

    described_class.sync_topic(tagged_topic)
    expect(board.cards.where(topic_id: tagged_topic.id, column_id: col.id).count).to eq(1)

    col.update!(tag_id: tag_b.id)

    expect { described_class.sync_topic(tagged_topic) }.to change {
      board.cards.where(topic_id: tagged_topic.id).count
    }.from(1).to(0)
  end

  it "rolls back sync changes when apply fails part way through" do
    board =
      DiscourseKanban::Board.create!(
        name: "Atomic Board",
        slug: "atomic-board",
        category_ids: [category.id],
        created_by_id: admin.id,
      )
    board.columns.create!(title: "Backlog", position: 0)

    described_class.sync_topic(topic)
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)

    other_category = Fabricate(:category)
    board.update!(category_ids: [other_category.id])

    described_class.stubs(:execute_sync_changes).raises(StandardError.new("create boom"))

    expect { described_class.sync_topic(topic) }.to raise_error(StandardError, "create boom")
    expect(board.cards.where(topic_id: topic.id).count).to eq(1)
  end

  it "retries once when a unique topic-card violation happens" do
    attempts = 0

    described_class.send(:with_topic_sync_retry) do
      attempts += 1
      if attempts == 1
        raise ActiveRecord::RecordNotUnique.new("idx_kanban_cards_unique_topic_per_column")
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
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )

    expect { described_class.remove_topic(topic.id) }.to change { DiscourseKanban::Card.count }.by(
      -1,
    )
  end

  describe "multi-column card semantics" do
    it "creates auto cards in other columns when a card exists in one column" do
      multi_topic = Fabricate(:topic, category: category, tags: [tag_a, tag_b])

      board =
        DiscourseKanban::Board.create!(
          name: "Manual In Multi Board",
          slug: "manual-in-multi-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col_a = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)
      col_b = board.columns.create!(title: "Beta", position: 1, tag_id: tag_b.id)

      board.cards.create!(
        topic_id: multi_topic.id,
        card_type: :topic,
        column_id: col_a.id,
        position: 0,
        created_by_id: admin.id,
      )

      expect { described_class.sync_topic(multi_topic) }.to change {
        DiscourseKanban::Card.count
      }.by(1)

      expect(board.cards.where(topic_id: multi_topic.id).pluck(:column_id)).to contain_exactly(
        col_a.id,
        col_b.id,
      )
    end

    it "cleans up auto cards while preserving manually created cards after tag change" do
      tagged_topic = Fabricate(:topic, category: category, tags: [tag_a, tag_b])

      board =
        DiscourseKanban::Board.create!(
          name: "Preserve Manual Board",
          slug: "preserve-manual-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col_a = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)
      col_b = board.columns.create!(title: "Beta", position: 1, tag_id: tag_b.id)

      board.cards.create!(
        topic_id: tagged_topic.id,
        card_type: :topic,
        column_id: col_a.id,
        position: 0,
        created_by_id: admin.id,
      )

      described_class.sync_topic(tagged_topic)
      expect(board.cards.where(topic_id: tagged_topic.id).count).to eq(2)

      other_tag = Fabricate(:tag, name: "sync-other")
      col_b.update!(tag_id: other_tag.id)
      described_class.sync_topic(tagged_topic)

      expect(board.cards.where(topic_id: tagged_topic.id).count).to eq(1)
      remaining = board.cards.find_by(topic_id: tagged_topic.id)
      expect(remaining.column_id).to eq(col_a.id)
    end
  end

  describe "sticky catch-all columns" do
    it "does not relocate a card between catch-all columns on re-sync" do
      board =
        DiscourseKanban::Board.create!(
          name: "Sticky Board",
          slug: "sticky-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )

      col_a = board.columns.create!(title: "Column A", position: 0)
      col_b = board.columns.create!(title: "Column B", position: 1)

      # Manually place in column B (not the lowest-ID catch-all)
      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        column_id: col_b.id,
        position: 0,
        created_by_id: admin.id,
      )

      described_class.sync_topic(topic)

      card = board.cards.find_by(topic_id: topic.id)
      expect(card.column_id).to eq(col_b.id)
    end

    it "places a new topic in the first catch-all when no tagged column matches" do
      board =
        DiscourseKanban::Board.create!(
          name: "First Catchall Board",
          slug: "first-catchall-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )

      col_a = board.columns.create!(title: "Column A", position: 0)
      board.columns.create!(title: "Column B", position: 1)

      described_class.sync_topic(topic)

      card = board.cards.find_by(topic_id: topic.id)
      expect(card.column_id).to eq(col_a.id)
    end

    it "does not place a tagged topic in a catch-all column" do
      tagged_topic = Fabricate(:topic, category: category, tags: [tag_a])

      board =
        DiscourseKanban::Board.create!(
          name: "No Catchall Board",
          slug: "no-catchall-for-tagged",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col_tagged = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)
      board.columns.create!(title: "Backlog", position: 1)

      described_class.sync_topic(tagged_topic)

      cards = board.cards.where(topic_id: tagged_topic.id)
      expect(cards.count).to eq(1)
      expect(cards.first.column_id).to eq(col_tagged.id)
    end

    it "falls to a catch-all when a topic loses its column tag" do
      tagged_topic = Fabricate(:topic, category: category, tags: [tag_a])

      board =
        DiscourseKanban::Board.create!(
          name: "Fallback Board",
          slug: "fallback-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col_tagged = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)
      col_catchall = board.columns.create!(title: "Backlog", position: 1)

      described_class.sync_topic(tagged_topic)
      cards = board.cards.where(topic_id: tagged_topic.id)
      expect(cards.count).to eq(1)
      expect(cards.first.column_id).to eq(col_tagged.id)

      # Remove the tag — topic no longer matches the tagged column
      tagged_topic.tags = []
      tagged_topic.save!

      described_class.sync_topic(tagged_topic)

      cards = board.cards.where(topic_id: tagged_topic.id)
      expect(cards.count).to eq(1)
      expect(cards.first.column_id).to eq(col_catchall.id)
    end
  end

  describe ".backfill_board" do
    it "creates cards for matching topics that have no card record" do
      topic_2 = Fabricate(:topic, category: category)

      board =
        DiscourseKanban::Board.create!(
          name: "Backfill Board",
          slug: "backfill-board",
          category_ids: [category.id],
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
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      column = board.columns.create!(title: "Backlog", position: 0)

      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )

      expect { described_class.backfill_board(board) }.not_to change {
        board.cards.where(topic_id: topic.id).count
      }
    end

    it "excludes category definition topics" do
      board =
        DiscourseKanban::Board.create!(
          name: "No Defs Board",
          slug: "no-defs-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      described_class.backfill_board(board)

      carded_topic_ids = board.cards.pluck(:topic_id)
      expect(carded_topic_ids).to include(topic.id)
      expect(carded_topic_ids).not_to include(category.topic_id)
    end

    it "discovers topics by column tag" do
      tagged_topic = Fabricate(:topic, tags: [tag_a])

      board =
        DiscourseKanban::Board.create!(
          name: "Tag Backfill Board",
          slug: "tag-backfill-board",
          tag_ids: [tag_a.id],
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)

      described_class.backfill_board(board)

      card = board.cards.find_by(topic_id: tagged_topic.id)
      expect(card).to be_present
      expect(card.column_id).to eq(col.id)
    end

    it "limits the number of topics per column to MAX_CARDS_PER_COLUMN" do
      # Create topics before the board so sync_topic doesn't fire
      4.times { Fabricate(:topic, category: category) }

      board =
        DiscourseKanban::Board.create!(
          name: "Limit Board",
          slug: "limit-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      stub_const(DiscourseKanban::TopicSync, :MAX_CARDS_PER_COLUMN, 3) do
        described_class.backfill_board(board)
      end

      expect(board.cards.count).to be <= 3
    end

    it "evicts oldest topic cards when a column exceeds MAX_CARDS_PER_COLUMN via sync" do
      board =
        DiscourseKanban::Board.create!(
          name: "Eviction Board",
          slug: "eviction-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Backlog", position: 0)

      stub_const(DiscourseKanban::TopicSync, :MAX_CARDS_PER_COLUMN, 3) do
        topics = 4.times.map { Fabricate(:topic, category: category) }
        topics.each { |t| described_class.sync_topic(t) }

        cards = board.cards.where(column_id: col.id).order(:position)
        expect(cards.count).to eq(3)
        expect(cards.pluck(:topic_id)).to eq(topics.last(3).map(&:id))
      end
    end

    it "assigns to the lowest-ID catch-all column regardless of position order" do
      board =
        DiscourseKanban::Board.create!(
          name: "Backfill Stable Board",
          slug: "backfill-stable-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )

      col_a = board.columns.create!(title: "Column A", position: 0)
      col_b = board.columns.create!(title: "Column B", position: 1)

      col_b.update_column(:position, 0)
      col_a.update_column(:position, 1)

      described_class.backfill_board(board)

      card = board.cards.find_by(topic_id: topic.id)
      expect(card.column_id).to eq(col_a.id)
    end

    it "does not discover topics when board has no constraints" do
      board =
        DiscourseKanban::Board.create!(
          name: "No Filter Backfill Board",
          slug: "no-filter-backfill-board",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      expect { described_class.backfill_board(board) }.not_to change { DiscourseKanban::Card.count }
    end

    it "does not delete existing cards on unconstrained boards" do
      board =
        DiscourseKanban::Board.create!(
          name: "No Filter Preserve Board",
          slug: "no-filter-preserve-board",
          created_by_id: admin.id,
        )
      column = board.columns.create!(title: "Backlog", position: 0)

      board.cards.create!(
        topic_id: topic.id,
        card_type: :topic,
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )

      expect { described_class.backfill_board(board) }.not_to change { DiscourseKanban::Card.count }
    end

    it "places a topic in multiple columns when it matches multiple column tags" do
      multi_topic = Fabricate(:topic, category: category, tags: [tag_a, tag_b])

      board =
        DiscourseKanban::Board.create!(
          name: "Backfill Multi Board",
          slug: "backfill-multi-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col_a = board.columns.create!(title: "Alpha", position: 0, tag_id: tag_a.id)
      col_b = board.columns.create!(title: "Beta", position: 1, tag_id: tag_b.id)

      described_class.backfill_board(board)

      cards = board.cards.where(topic_id: multi_topic.id)
      expect(cards.count).to eq(2)
      expect(cards.pluck(:column_id)).to contain_exactly(col_a.id, col_b.id)
    end
  end

  describe "PostCreator integration" do
    it "does not interfere with topic creation" do
      DiscourseKanban::Board
        .create!(
          name: "Board",
          slug: "post-creator-board",
          category_ids: [category.id],
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
