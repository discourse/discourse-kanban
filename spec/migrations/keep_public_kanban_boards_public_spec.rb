# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-kanban/db/migrate/20260528205423_keep_public_kanban_boards_public.rb",
        )

RSpec.describe KeepPublicKanbanBoardsPublic do
  fab!(:read_group, :group)

  before do
    enable_current_plugin
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "grants public read to boards with no read groups and leaves restricted boards untouched" do
    public_board = DiscourseKanban::Board.create!(name: "Public", slug: "public")
    restricted_board =
      DiscourseKanban::Board.create!(
        name: "Restricted",
        slug: "restricted",
        allow_read_group_ids: [read_group.id],
      )

    described_class.new.up

    expect(public_board.reload.allow_read_group_ids).to contain_exactly(
      Group::AUTO_GROUPS[:anonymous],
      Group::AUTO_GROUPS[:trust_level_0],
    )
    expect(restricted_board.reload.allow_read_group_ids).to contain_exactly(read_group.id)
  end
end
