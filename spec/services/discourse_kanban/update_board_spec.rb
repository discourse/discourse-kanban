# frozen_string_literal: true

RSpec.describe DiscourseKanban::UpdateBoard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, raw_board_params: raw, **dependencies) }

    fab!(:admin)
    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      DiscourseKanban::Board.create!(name: "Old", slug: "old", created_by_id: admin.id)
    end
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }

    let(:raw) { { "name" => "Updated" } }
    let(:params) { raw.merge("id" => board.id) }
    let(:dependencies) { { guardian: Guardian.new(manager) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      SiteSetting.discourse_kanban_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:params) { { id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { "id" => 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: Guardian.new(outsider) } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "updates the board" do
        result
        board.reload
        expect(board.name).to eq("Updated")
        expect(board.updated_by_id).to eq(manager.id)
      end

      it "does not delete topic cards on unconstrained boards" do
        let_raw = { "name" => "Updated", "columns" => [{ "id" => column.id, "title" => "Col" }] }
        let_params = let_raw.merge("id" => board.id)

        board.cards.create!(
          topic_id: Fabricate(:topic).id,
          card_type: :topic,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )

        expect {
          described_class.call(
            params: let_params,
            raw_board_params: let_raw,
            guardian: Guardian.new(manager),
          )
        }.not_to change { board.cards.where(card_type: :topic).count }
      end

      context "with column changes" do
        let(:raw) do
          {
            "name" => "Updated",
            "columns" => [{ "id" => column.id, "title" => "Renamed" }, { "title" => "New Col" }],
          }
        end

        it "replaces columns" do
          result
          board.reload
          expect(board.columns.count).to eq(2)
          expect(column.reload.title).to eq("Renamed")
        end
      end
    end
  end
end
