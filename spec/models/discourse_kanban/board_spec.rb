# frozen_string_literal: true

RSpec.describe DiscourseKanban::Board do
  before { enable_current_plugin }

  describe "#topic_matches?" do
    fab!(:category)
    fab!(:tag)

    it "matches topic by category_ids" do
      board = described_class.create!(name: "B", slug: "b", category_ids: [category.id])
      topic = Fabricate(:topic, category: category)

      expect(board.topic_matches?(topic)).to eq(true)
    end

    it "does not match topic in different category" do
      board = described_class.create!(name: "B", slug: "b", category_ids: [category.id])
      topic = Fabricate(:topic, category: Fabricate(:category))

      expect(board.topic_matches?(topic)).to eq(false)
    end

    it "matches topic by tag_ids" do
      board = described_class.create!(name: "B", slug: "b", tag_ids: [tag.id])
      topic = Fabricate(:topic, tags: [tag])

      expect(board.topic_matches?(topic)).to eq(true)
    end

    it "does not match topic without required tags" do
      board = described_class.create!(name: "B", slug: "b", tag_ids: [tag.id])
      topic = Fabricate(:topic)

      expect(board.topic_matches?(topic)).to eq(false)
    end

    it "requires both category and tag match when both are set" do
      board =
        described_class.create!(
          name: "B",
          slug: "b",
          category_ids: [category.id],
          tag_ids: [tag.id],
        )
      topic_with_both = Fabricate(:topic, category: category, tags: [tag])
      topic_category_only = Fabricate(:topic, category: category)
      topic_tag_only = Fabricate(:topic, tags: [tag])

      expect(board.topic_matches?(topic_with_both)).to eq(true)
      expect(board.topic_matches?(topic_category_only)).to eq(false)
      expect(board.topic_matches?(topic_tag_only)).to eq(false)
    end

    it "returns false when both category_ids and tag_ids are empty" do
      board = described_class.create!(name: "B", slug: "b")
      topic = Fabricate(:topic)

      expect(board.topic_matches?(topic)).to eq(false)
    end
  end

  describe "#tags and #categories" do
    fab!(:category_a) { Fabricate(:category, name: "alpha-cat") }
    fab!(:category_b) { Fabricate(:category, name: "beta-cat") }
    fab!(:tag_a) { Fabricate(:tag, name: "alpha") }
    fab!(:tag_b) { Fabricate(:tag, name: "beta") }

    it "returns tags ordered by name" do
      board = described_class.create!(name: "B", slug: "b", tag_ids: [tag_b.id, tag_a.id])

      expect(board.tags).to eq([tag_a, tag_b])
    end

    it "returns categories ordered by name" do
      board =
        described_class.create!(name: "B", slug: "b", category_ids: [category_b.id, category_a.id])

      expect(board.categories).to eq([category_a, category_b])
    end

    it "returns empty arrays when nothing is set" do
      board = described_class.create!(name: "B", slug: "b")

      expect(board.tags).to eq([])
      expect(board.categories).to eq([])
    end

    it "memoizes the result so repeated access does not requery" do
      board = described_class.create!(name: "B", slug: "b", tag_ids: [tag_a.id])
      board.tags

      queries = track_sql_queries { 5.times { board.tags } }
      expect(queries).to be_empty
    end

    it "resets memoization on reload" do
      board = described_class.create!(name: "B", slug: "b", tag_ids: [tag_a.id])
      expect(board.tags).to eq([tag_a])

      board.update!(tag_ids: [tag_b.id])
      board.reload

      expect(board.tags).to eq([tag_b])
    end
  end

  describe ".preload_tags and .preload_categories" do
    fab!(:tag_a) { Fabricate(:tag, name: "alpha") }
    fab!(:tag_b) { Fabricate(:tag, name: "beta") }
    fab!(:category_a) { Fabricate(:category, name: "alpha-cat") }
    fab!(:category_b) { Fabricate(:category, name: "beta-cat") }

    it "preloads tags for many boards in a single query" do
      board_a = described_class.create!(name: "A", slug: "a", tag_ids: [tag_a.id])
      board_b = described_class.create!(name: "B", slug: "b", tag_ids: [tag_a.id, tag_b.id])

      boards = [board_a, board_b]
      described_class.preload_tags(boards)

      queries = track_sql_queries { boards.each(&:tags) }
      expect(queries).to be_empty
      expect(board_a.tags).to eq([tag_a])
      expect(board_b.tags).to eq([tag_a, tag_b])
    end

    it "preloads categories for many boards in a single query" do
      board_a = described_class.create!(name: "A", slug: "a", category_ids: [category_a.id])
      board_b =
        described_class.create!(name: "B", slug: "b", category_ids: [category_a.id, category_b.id])

      boards = [board_a, board_b]
      described_class.preload_categories(boards)

      queries = track_sql_queries { boards.each(&:categories) }
      expect(queries).to be_empty
      expect(board_a.categories).to eq([category_a])
      expect(board_b.categories).to eq([category_a, category_b])
    end

    it "handles empty input and boards without ids" do
      expect(described_class.preload_tags([])).to eq([])

      board = described_class.create!(name: "B", slug: "b")
      described_class.preload_tags([board])
      described_class.preload_categories([board])

      expect(board.tags).to eq([])
      expect(board.categories).to eq([])
    end
  end

  describe "#all_matching_columns" do
    fab!(:category)
    fab!(:tag_a) { Fabricate(:tag, name: "alpha") }
    fab!(:tag_b) { Fabricate(:tag, name: "beta") }

    it "matches columns by tag_id" do
      board = described_class.create!(name: "B", slug: "b", category_ids: [category.id])
      col_a = board.columns.create!(title: "A", position: 0, tag_id: tag_a.id)
      col_b = board.columns.create!(title: "B", position: 1, tag_id: tag_b.id)

      topic = Fabricate(:topic, category: category, tags: [tag_a])
      expect(board.all_matching_columns(topic)).to eq([col_a])

      topic2 = Fabricate(:topic, category: category, tags: [tag_a, tag_b])
      expect(board.all_matching_columns(topic2)).to contain_exactly(col_a, col_b)
    end

    it "does not include unconstrained columns in matching results" do
      board = described_class.create!(name: "B", slug: "b", category_ids: [category.id])
      board.columns.create!(title: "Catch", position: 0, tag_id: nil)
      col_a = board.columns.create!(title: "A", position: 1, tag_id: tag_a.id)

      topic = Fabricate(:topic, category: category, tags: [tag_a])
      expect(board.all_matching_columns(topic)).to eq([col_a])

      topic2 = Fabricate(:topic, category: category)
      expect(board.all_matching_columns(topic2)).to eq([])
    end
  end
end
