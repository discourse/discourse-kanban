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

    let(:channel) { "/kanban/boards/#{board.id}" }
    let(:client_id) { "test-123" }
    let(:messages) { MessageBus.track_publish(channel) { result } }
    let(:params) do
      { board_id: board.id, topic_id: topic.id, to_column_id: column.id, client_id: client_id }
    end
    let(:dependencies) { { guardian: Guardian.new(admin) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      write_group.add(writer)
      read_group.add(reader)
    end

    context "when contract is invalid" do
      let(:params) { { board_id: board.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, topic_id: topic.id, to_column_id: column.id } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot write to board" do
      let(:dependencies) { { guardian: Guardian.new(reader) } }

      it { is_expected.to fail_a_policy(:can_write) }
    end

    context "when topic is not found" do
      let(:params) { { board_id: board.id, topic_id: 0, to_column_id: column.id } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user cannot see topic" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }

      let(:params) { { board_id: board.id, topic_id: private_topic.id, to_column_id: column.id } }
      let(:dependencies) { { guardian: Guardian.new(writer) } }

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when user cannot edit topic" do
      fab!(:other_user, :user)

      let(:dependencies) { { guardian: Guardian.new(other_user) } }

      before { write_group.add(other_user) }

      it { is_expected.to fail_a_policy(:can_edit_topic) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, topic_id: topic.id, to_column_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when topic has no existing card" do
      it { is_expected.to run_successfully }

      it "creates a topic card on the column" do
        card = result[:card]
        expect(card).to be_previously_new_record
        expect(card.topic_id).to eq(topic.id)
        expect(card.column_id).to eq(column.id)
        expect(card.card_type).to eq("topic")
        expect(card.membership_mode).to eq("manual_in")
      end

      it "sets creator and updater to the acting user" do
        card = result[:card]
        expect(card.created_by_id).to eq(admin.id)
        expect(card.updated_by_id).to eq(admin.id)
      end

      it "publishes a card_created event scoped to board read groups" do
        expect(messages.size).to eq(1)
        msg = messages.first
        expect(msg.data[:type]).to eq("card_created")
        expect(msg.data[:client_id]).to eq(client_id)
        expect(msg.data[:card][:topic_id]).to eq(topic.id)
        expect(msg.group_ids).to contain_exactly(write_group.id, read_group.id)
      end
    end

    context "when topic already has a card on the column" do
      fab!(:existing_card) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :auto,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: writer.id,
        )
      end

      it { is_expected.to run_successfully }

      it "upgrades the existing card to manual_in" do
        card = result[:card]
        expect(card.id).to eq(existing_card.id)
        expect(card).not_to be_previously_new_record
        expect(card.membership_mode).to eq("manual_in")
      end

      it "preserves the original creator" do
        expect(result[:card].created_by_id).to eq(writer.id)
      end

      it "publishes a card_moved event" do
        expect(messages.size).to eq(1)
        expect(messages.first.data[:type]).to eq("card_moved")
        expect(messages.first.data[:client_id]).to eq(client_id)
      end
    end

    context "when column has a move_to_tag mutation" do
      fab!(:tag) { Fabricate(:tag, name: "in-progress") }

      before { column.update!(move_to_tag: "in-progress") }

      it "applies the tag to the topic" do
        result
        expect(topic.reload.tags.map(&:name)).to include("in-progress")
      end
    end
  end
end
