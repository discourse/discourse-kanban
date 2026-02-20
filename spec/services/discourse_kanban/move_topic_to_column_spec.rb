# frozen_string_literal: true

RSpec.describe DiscourseKanban::MoveTopicToColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:to_column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category, user: writer) }
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Board",
        slug: "board-mtc",
        allow_write_group_ids: [write_group.id],
        allow_read_group_ids: [read_group.id],
        created_by_id: admin.id,
      )
    end
    fab!(:column) { board.columns.create!(title: "Doing", position: 0) }

    let(:params) { { board_id: board.id, topic_id: topic.id, to_column_id: column.id } }
    let(:dependencies) { { guardian: Guardian.new(admin) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      write_group.add(writer)
      read_group.add(reader)
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a card for the topic" do
        card = result[:card]
        expect(card.topic_id).to eq(topic.id)
        expect(card.column_id).to eq(column.id)
        expect(card.membership_mode).to eq("manual_in")
      end

      it "marks the card as new" do
        expect(result[:is_new_card]).to eq(true)
      end
    end

    context "when topic already has a card on the board" do
      before do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :auto,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      it { is_expected.to run_successfully }

      it "updates the existing card" do
        expect(result[:is_new_card]).to eq(false)
        expect(result[:card].membership_mode).to eq("manual_in")
      end
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, topic_id: topic.id, to_column_id: column.id } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when topic is not found" do
      let(:params) { { board_id: board.id, topic_id: 0, to_column_id: column.id } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, topic_id: topic.id, to_column_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot see topic" do
      let(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      let(:private_topic) { Fabricate(:topic, category: private_category) }
      let(:params) { { board_id: board.id, topic_id: private_topic.id, to_column_id: column.id } }
      let(:dependencies) { { guardian: Guardian.new(writer) } }

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when user cannot write to board" do
      let(:dependencies) { { guardian: Guardian.new(reader) } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
