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
    SiteSetting.discourse_kanban_enabled = true

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

    expect(board.can_read?(Guardian.new(reader))).to eq(true)
    expect(board.can_read?(Guardian.new(outsider))).to eq(false)
  end

  it "grants write through write groups and implies read" do
    board =
      described_class.create!(
        name: "Operations",
        slug: "operations",
        allow_write_group_ids: [write_group.id],
      )

    expect(board.can_write?(Guardian.new(writer))).to eq(true)
    expect(board.can_read?(Guardian.new(writer))).to eq(true)
    expect(board.can_write?(Guardian.new(outsider))).to eq(false)
  end

  it "always allows admins to write" do
    board =
      described_class.create!(name: "Engineering", slug: "engineering", allow_write_group_ids: [])

    expect(board.can_write?(Guardian.new(admin))).to eq(true)
  end

  it "allows creator to write" do
    board = described_class.create!(name: "Support", slug: "support", created_by_id: creator.id)

    expect(board.can_write?(Guardian.new(creator))).to eq(true)
  end

  it "caches query matches per topic id and query" do
    category_1 = Fabricate(:category, name: "Cache One")
    category_2 = Fabricate(:category, name: "Cache Two")
    topic_1 = Fabricate(:topic, category: category_1)
    topic_2 = Fabricate(:topic, category: category_2)
    query = "category:#{category_1.slug}"

    matcher_context = {
      scope:
        TopicQuery.new(Discourse.system_user, limit: false, no_definitions: true).latest_results,
      guardian: Guardian.new(Discourse.system_user),
      cache: {
      },
    }

    expect(described_class.topic_matches_query?(topic_1, query, matcher_context:)).to eq(true)
    expect(described_class.topic_matches_query?(topic_2, query, matcher_context:)).to eq(false)
  end

  it "hits TopicsFilter only once for repeated checks of the same topic and query" do
    category = Fabricate(:category, name: "Cache Calls")
    topic = Fabricate(:topic, category: category)
    query = "category:#{category.slug}"

    matcher_context = {
      scope:
        TopicQuery.new(Discourse.system_user, limit: false, no_definitions: true).latest_results,
      guardian: Guardian.new(Discourse.system_user),
      cache: {
      },
    }

    filter = mock
    TopicsFilter.expects(:new).once.returns(filter)
    filter.expects(:filter_from_query_string).once.with(query).returns(Topic.where(id: topic.id))

    expect(described_class.topic_matches_query?(topic, query, matcher_context:)).to eq(true)
    expect(described_class.topic_matches_query?(topic, query, matcher_context:)).to eq(true)
  end

  it "does not match when query is blank" do
    topic = Fabricate(:topic)
    expect(described_class.topic_matches_query?(topic, "")).to eq(false)
  end
end
