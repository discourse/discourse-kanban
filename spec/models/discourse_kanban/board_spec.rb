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
      described_class.create!(
        name: "Engineering",
        slug: "engineering",
        allow_write_group_ids: [],
      )

    expect(board.can_write?(Guardian.new(admin))).to eq(true)
  end

  it "allows creator to write" do
    board =
      described_class.create!(
        name: "Support",
        slug: "support",
        created_by_id: creator.id,
      )

    expect(board.can_write?(Guardian.new(creator))).to eq(true)
  end
end
