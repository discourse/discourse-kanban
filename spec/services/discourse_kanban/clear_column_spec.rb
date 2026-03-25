# frozen_string_literal: true

RSpec.describe DiscourseKanban::ClearColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category) { Fabricate(:category, name: "Kanban") }
    fab!(:topic1) { Fabricate(:topic, category: category) }
    fab!(:topic2) { Fabricate(:topic, category: category) }
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Board",
        slug: "board-cc",
        allow_write_group_ids: [write_group.id],
        allow_read_group_ids: [read_group.id],
        created_by_id: admin.id,
      )
    end
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }
    fab!(:other_column) { board.columns.create!(title: "Other", position: 1) }

    let(:dependencies) { { guardian: Guardian.new(writer) } }
    let(:params) { { board_id: board.id, column_id: column.id } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      write_group.add(writer)
      read_group.add(reader)
    end

    context "with a mix of floater and topic cards" do
      let!(:floater1) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Floater 1",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end
      let!(:floater2) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Floater 2",
          column_id: column.id,
          position: 1,
          created_by_id: admin.id,
        )
      end
      let!(:topic_card1) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic1.id,
          column_id: column.id,
          position: 2,
          created_by_id: admin.id,
        )
      end
      let!(:topic_card2) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic2.id,
          column_id: column.id,
          position: 3,
          created_by_id: admin.id,
        )
      end
      let!(:other_column_card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Other",
          column_id: other_column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      it { is_expected.to run_successfully }

      it "destroys floater cards" do
        result
        expect(DiscourseKanban::Card.find_by(id: floater1.id)).to be_nil
        expect(DiscourseKanban::Card.find_by(id: floater2.id)).to be_nil
      end

      it "sets topic cards to manual_out with nil column" do
        result
        topic_card1.reload
        topic_card2.reload
        expect(topic_card1.membership_mode).to eq("manual_out")
        expect(topic_card1.column_id).to be_nil
        expect(topic_card2.membership_mode).to eq("manual_out")
        expect(topic_card2.column_id).to be_nil
      end

      it "does not affect cards in other columns" do
        result
        expect(DiscourseKanban::Card.find_by(id: other_column_card.id)).to be_present
      end
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, column_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot write" do
      let(:dependencies) { { guardian: Guardian.new(reader) } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
