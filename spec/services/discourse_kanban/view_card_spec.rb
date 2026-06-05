# frozen_string_literal: true

RSpec.describe DiscourseKanban::ViewCard do
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
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }
    fab!(:card) do
      board.cards.create!(
        card_type: :floater,
        title: "View Me",
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )
    end

    let(:params) { { id: card.id } }
    let(:dependencies) { { guardian: reader.guardian } }

    before do
      enable_current_plugin
      read_group.add(reader)
    end

    context "when card is not found" do
      let(:params) { { id: 0 } }

      it { is_expected.to fail_to_find_a_model(:card) }
    end

    context "when card was already viewed today" do
      before do
        RateLimiter.enable
        described_class.call(params:, **dependencies)
      end

      after { RateLimiter.disable }

      it { is_expected.to fail_a_policy(:card_not_already_viewed_today) }
    end

    context "when user cannot view the card" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_view_card) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a card view history record" do
        expect { result }.to change {
          DiscourseKanban::CardHistory.where(action: :card_viewed, card_id: card.id).count
        }.by(1)
      end

      it "records the acting user and board" do
        result
        history = DiscourseKanban::CardHistory.where(action: :card_viewed, card_id: card.id).last
        expect(history).to have_attributes(acting_user_id: reader.id, board_id: board.id)
      end
    end
  end
end
