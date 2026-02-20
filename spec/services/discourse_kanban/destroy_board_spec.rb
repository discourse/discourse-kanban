# frozen_string_literal: true

RSpec.describe DiscourseKanban::DestroyBoard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      DiscourseKanban::Board.create!(name: "Delete Me", slug: "delete-me", created_by_id: admin.id)
    end

    let(:params) { { id: board.id } }
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
      let(:params) { { id: 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: Guardian.new(outsider) } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "destroys the board" do
        result
        expect(DiscourseKanban::Board.find_by(id: board.id)).to be_nil
      end
    end
  end
end
