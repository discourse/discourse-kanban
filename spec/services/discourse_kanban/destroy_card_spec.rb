# frozen_string_literal: true

RSpec.describe DiscourseKanban::DestroyCard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category) { Fabricate(:category, name: "Kanban") }
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Board",
        slug: "board-dc",
        allow_write_group_ids: [write_group.id],
        allow_read_group_ids: [read_group.id],
        created_by_id: admin.id,
      )
    end
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }

    let(:dependencies) { { guardian: Guardian.new(writer) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      write_group.add(writer)
      read_group.add(reader)
    end

    context "when destroying a floater card" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Delete",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to run_successfully }

      it "destroys the card" do
        result
        expect(DiscourseKanban::Card.find_by(id: card.id)).to be_nil
      end
    end

    context "when destroying a topic card that doesn't match filter" do
      fab!(:card) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to run_successfully }
    end

    context "when topic card is covered by board filter" do
      before { board.update!(base_filter_query: "category:#{category.slug}") }

      fab!(:card) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to fail_a_policy(:card_is_deletable) }
    end

    context "when card is not found" do
      let(:params) { { board_id: board.id, id: 0 } }

      it { is_expected.to fail_to_find_a_model(:card) }
    end

    context "when user cannot write" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Protected",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }
      let(:dependencies) { { guardian: Guardian.new(reader) } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
