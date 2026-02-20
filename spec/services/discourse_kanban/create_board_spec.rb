# frozen_string_literal: true

RSpec.describe DiscourseKanban::CreateBoard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, raw_board_params: raw, **dependencies) }

    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)

    let(:raw) { { "name" => "New Board", "slug" => "new-board" } }
    let(:params) { raw }
    let(:dependencies) { { guardian: Guardian.new(manager) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      SiteSetting.discourse_kanban_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:raw) { { "slug" => "no-name" } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: Guardian.new(outsider) } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates the board" do
        expect { result }.to change { DiscourseKanban::Board.count }.by(1)
        board = result[:board]
        expect(board.name).to eq("New Board")
        expect(board.slug).to eq("new-board")
        expect(board.created_by_id).to eq(manager.id)
      end

      context "with columns" do
        let(:raw) do
          {
            "name" => "With Columns",
            "columns" => [{ "title" => "Backlog" }, { "title" => "Done" }],
          }
        end

        it "creates columns" do
          result
          board = result[:board]
          expect(board.columns.count).to eq(2)
          expect(board.columns.order(:position).pluck(:title)).to eq(%w[Backlog Done])
        end
      end
    end
  end
end
