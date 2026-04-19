# frozen_string_literal: true

RSpec.describe DiscourseKanban::Board do
  fab!(:admin)
  fab!(:creator, :user)
  fab!(:reader, :user)
  fab!(:writer, :user)
  fab!(:outsider, :user)
  fab!(:read_group, :group)
  fab!(:write_group, :group)

  before do
    enable_current_plugin

    read_group.add(reader)
    write_group.add(writer)
  end

  it "grants read through read groups" do
    board =
      described_class.create!(
        name: "Roadmap",
        slug: "roadmap",
        allow_read_group_ids: [read_group.id],
      )

    expect(board.can_read?(reader.guardian)).to eq(true)
    expect(board.can_read?(outsider.guardian)).to eq(false)
  end

  it "grants write through write groups and implies read" do
    board =
      described_class.create!(
        name: "Operations",
        slug: "operations",
        allow_write_group_ids: [write_group.id],
      )

    expect(board.can_write?(writer.guardian)).to eq(true)
    expect(board.can_read?(writer.guardian)).to eq(true)
    expect(board.can_write?(outsider.guardian)).to eq(false)
  end

  it "always allows admins to write" do
    board =
      described_class.create!(name: "Engineering", slug: "engineering", allow_write_group_ids: [])

    expect(board.can_write?(admin.guardian)).to eq(true)
  end

  it "allows creator to write" do
    board = described_class.create!(name: "Support", slug: "support", created_by_id: creator.id)

    expect(board.can_write?(creator.guardian)).to eq(true)
  end

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
