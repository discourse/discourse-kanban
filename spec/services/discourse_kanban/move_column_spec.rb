# frozen_string_literal: true

RSpec.describe DiscourseKanban::MoveColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:column_id) }
    it { is_expected.to validate_presence_of(:direction) }
    it { is_expected.to validate_inclusion_of(:direction).in_array([-1, 1]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Sales",
        slug: "sales-mc",
        base_filter_query: "tags:sales",
        created_by_id: admin.id,
      )
    end
    fab!(:col_star) { board.columns.create!(title: "Star", position: 0, filter_query: "tags:star") }
    fab!(:col_progress) { board.columns.create!(title: "In Progress", position: 1) }
    fab!(:col_done) { board.columns.create!(title: "Done", position: 2) }

    let(:params) { { board_id: board.id, column_id: col_progress.id, direction: 1 } }
    let(:dependencies) { { guardian: Guardian.new(admin) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
    end

    context "when moving a column right" do
      it { is_expected.to run_successfully }

      it "swaps positions with the right neighbor" do
        result
        expect(col_progress.reload.position).to eq(2)
        expect(col_done.reload.position).to eq(1)
      end

      it "does not change the unaffected column" do
        result
        expect(col_star.reload.position).to eq(0)
      end

      it "returns the new column order" do
        expect(result[:column_order]).to eq([col_star.id, col_done.id, col_progress.id])
      end
    end

    context "when moving a column left" do
      let(:params) { { board_id: board.id, column_id: col_progress.id, direction: -1 } }

      it { is_expected.to run_successfully }

      it "swaps positions with the left neighbor" do
        result
        expect(col_progress.reload.position).to eq(0)
        expect(col_star.reload.position).to eq(1)
      end

      it "returns the new column order" do
        expect(result[:column_order]).to eq([col_progress.id, col_star.id, col_done.id])
      end
    end

    context "when moving leftmost column left" do
      let(:params) { { board_id: board.id, column_id: col_star.id, direction: -1 } }

      it { is_expected.to fail_a_step(:swap_positions) }
    end

    context "when moving rightmost column right" do
      let(:params) { { board_id: board.id, column_id: col_done.id, direction: 1 } }

      it { is_expected.to fail_a_step(:swap_positions) }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, column_id: col_progress.id, direction: 1 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, column_id: 0, direction: 1 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: Guardian.new(user) } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when direction is invalid" do
      let(:params) { { board_id: board.id, column_id: col_progress.id, direction: 2 } }

      it { is_expected.to fail_a_contract }
    end

    it "does not reassign topic cards" do
      topic = Fabricate(:topic)
      card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: col_progress.id,
          position: 0,
          created_by_id: admin.id,
        )

      result
      expect(card.reload.column_id).to eq(col_progress.id)
    end

    it "publishes a columns_reordered event" do
      messages = MessageBus.track_publish("/kanban/boards/#{board.id}") { result }

      reorder_msg = messages.find { |m| m.data[:type] == "columns_reordered" }
      expect(reorder_msg).to be_present
      expect(reorder_msg.data[:column_order]).to eq([col_star.id, col_done.id, col_progress.id])
    end
  end
end
