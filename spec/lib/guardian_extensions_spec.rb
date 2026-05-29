# frozen_string_literal: true

RSpec.describe DiscourseKanban::GuardianExtensions do
  fab!(:admin)
  fab!(:creator, :user)
  fab!(:reader, :user)
  fab!(:writer, :user)
  fab!(:outsider, :user)
  fab!(:read_group, :group)
  fab!(:write_group, :group)
  let(:anonymous_guardian) { Guardian.new }

  before do
    enable_current_plugin

    read_group.add(reader)
    write_group.add(writer)
  end

  describe "#can_read_board?" do
    it "allows all anonymous and logged in users to read when no read_group_ids are set" do
      board = DiscourseKanban::Board.create!(name: "Roadmap", slug: "roadmap")
      expect(reader.guardian.can_read_board?(board)).to eq(true)
      expect(outsider.guardian.can_read_board?(board)).to eq(true)
      expect(anonymous_guardian.can_read_board?(board)).to eq(true)
    end

    it "does not allow anonymous users to read when read_group_ids are set" do
      board =
        DiscourseKanban::Board.create!(
          name: "Roadmap",
          slug: "roadmap",
          allow_read_group_ids: [read_group.id],
        )
      expect(anonymous_guardian.can_read_board?(board)).to eq(false)
    end

    it "grants read through read groups" do
      board =
        DiscourseKanban::Board.create!(
          name: "Roadmap",
          slug: "roadmap",
          allow_read_group_ids: [read_group.id],
        )

      expect(reader.guardian.can_read_board?(board)).to eq(true)
      expect(outsider.guardian.can_read_board?(board)).to eq(false)
    end

    it "returns true when the user can write" do
      board =
        DiscourseKanban::Board.create!(
          name: "Operations",
          slug: "operations",
          allow_write_group_ids: [write_group.id],
        )

      expect(writer.guardian.can_read_board?(board)).to eq(true)
    end
  end

  describe "#can_write_board?" do
    it "grants write through write groups" do
      board =
        DiscourseKanban::Board.create!(
          name: "Operations",
          slug: "operations",
          allow_write_group_ids: [write_group.id],
        )

      expect(writer.guardian.can_write_board?(board)).to eq(true)
      expect(outsider.guardian.can_write_board?(board)).to eq(false)
    end

    it "always allows admins to write" do
      board =
        DiscourseKanban::Board.create!(
          name: "Engineering",
          slug: "engineering",
          allow_write_group_ids: [],
        )

      expect(admin.guardian.can_write_board?(board)).to eq(true)
    end

    it "does not allow creator special priveleges to write if they are not in a write group" do
      board =
        DiscourseKanban::Board.create!(
          name: "Support",
          slug: "support",
          created_by_id: creator.id,
          allow_write_group_ids: [write_group.id],
        )

      expect(creator.guardian.can_write_board?(board)).to eq(false)

      write_group.add(creator)
      creator.reload

      expect(creator.guardian.can_write_board?(board)).to eq(true)
    end
  end
end
