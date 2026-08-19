# frozen_string_literal: true

RSpec.describe DiscourseKanban::CheckCardConstraintMismatches do
  subject(:result) { described_class.call(params:, guardian: admin.guardian) }

  fab!(:admin)
  fab!(:board_tag, :tag) { Fabricate(:tag, name: "board-filter") }
  fab!(:sibling_tag, :tag) { Fabricate(:tag, name: "sibling-column") }
  fab!(:target_tag, :tag) { Fabricate(:tag, name: "target-column") }
  fab!(:board) { Fabricate(:kanban_board, created_by: admin, tag_ids: [board_tag.id]) }
  fab!(:sibling_column) { Fabricate(:kanban_column, board:, tag: sibling_tag) }
  fab!(:target_column) { Fabricate(:kanban_column, board:, tag: target_tag) }

  let(:params) { { topic_id: topic.id, target_column_id: target_column.id } }

  before { enable_current_plugin }

  context "when only a sibling column's tag matches the board filter" do
    let!(:topic) { Fabricate(:topic, tags: [sibling_tag]) }

    it { is_expected.to run_successfully }

    it "returns the board tags needed to fix the mismatch" do
      expect(result[:tags_needed]).to eq([board_tag.name])
    end
  end

  context "when an unrelated topic tag matches the board filter" do
    let!(:topic) { Fabricate(:topic, tags: [sibling_tag, board_tag]) }

    it "does not report a tag mismatch" do
      expect(result[:tags_needed]).to be_nil
    end
  end
end
