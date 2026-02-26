# frozen_string_literal: true

RSpec.describe DiscourseKanban::Column do
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test-col", created_by_id: admin.id)
  end

  describe "wip_limit validation" do
    it "allows nil wip_limit" do
      column = board.columns.build(title: "Col", position: 0, wip_limit: nil)
      expect(column).to be_valid
    end

    it "allows positive integer wip_limit" do
      column = board.columns.build(title: "Col", position: 0, wip_limit: 5)
      expect(column).to be_valid
    end

    it "rejects zero" do
      column = board.columns.build(title: "Col", position: 0, wip_limit: 0)
      expect(column).not_to be_valid
      expect(column.errors[:wip_limit]).to be_present
    end

    it "rejects negative values" do
      column = board.columns.build(title: "Col", position: 0, wip_limit: -1)
      expect(column).not_to be_valid
      expect(column.errors[:wip_limit]).to be_present
    end

    it "rejects non-integer values" do
      column = board.columns.build(title: "Col", position: 0, wip_limit: 3.5)
      expect(column).not_to be_valid
      expect(column.errors[:wip_limit]).to be_present
    end
  end
end
