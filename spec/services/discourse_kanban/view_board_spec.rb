# frozen_string_literal: true

RSpec.describe DiscourseKanban::ViewBoard do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:reader, :user)
    fab!(:outsider, :user)
    fab!(:read_group, :group)
    fab!(:write_group, :group)
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Board",
        slug: "board-view",
        allow_write_group_ids: [write_group.id],
        allow_read_group_ids: [read_group.id],
        created_by_id: admin.id,
      )
    end

    let(:params) { { id: board.id } }
    let(:dependencies) { { guardian: reader.guardian } }

    before do
      enable_current_plugin
      read_group.add(reader)
    end

    context "when user is not logged in" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:is_logged_in) }
    end

    context "when board is not found" do
      let(:params) { { id: 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when board was already viewed today" do
      before do
        DiscourseKanban::BoardHistory.create!(board:, acting_user: reader, action: :board_viewed)
      end

      it { is_expected.to run_successfully }

      it "does not create a duplicate history record" do
        expect { result }.not_to change {
          DiscourseKanban::BoardHistory.where(action: :board_viewed, board_id: board.id).count
        }
      end
    end

    context "when user cannot read the board" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_read_board) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a board view history record" do
        expect { result }.to change {
          DiscourseKanban::BoardHistory.where(action: :board_viewed, board_id: board.id).count
        }.by(1)
        expect(
          DiscourseKanban::BoardHistory.where(action: :board_viewed, board_id: board.id).last,
        ).to have_attributes(acting_user_id: reader.id, board_id: board.id)
      end
    end
  end
end
