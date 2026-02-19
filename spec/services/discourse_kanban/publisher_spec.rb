# frozen_string_literal: true

RSpec.describe DiscourseKanban::Publisher do
  fab!(:admin)
  fab!(:write_group, :group)
  fab!(:read_group, :group)

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  fab!(:board) do
    DiscourseKanban::Board.create!(
      name: "Test Board",
      slug: "test-publisher",
      allow_write_group_ids: [write_group.id],
      allow_read_group_ids: [read_group.id],
      created_by_id: admin.id,
    )
  end
  fab!(:column) { board.columns.create!(title: "To Do", position: 0) }
  fab!(:card) do
    board.cards.create!(
      card_type: :floater,
      membership_mode: :manual_in,
      title: "Test card",
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )
  end

  let(:card_data) { { id: card.id, column_id: column.id, title: "Test card" } }
  let(:channel) { "/kanban/boards/#{board.id}" }
  let(:test_client_id) { "abc123" }

  describe ".publish_card_created!" do
    it "publishes a card_created message with group_ids and client_id" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_created!(board, card_data, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.data[:type]).to eq("card_created")
      expect(msg.data[:client_id]).to eq(test_client_id)
      expect(msg.data[:card]).to eq(card_data)
      expect(msg.group_ids).to contain_exactly(write_group.id, read_group.id)
    end
  end

  describe ".publish_card_updated!" do
    it "publishes a card_updated message" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_updated!(board, card_data, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data[:type]).to eq("card_updated")
      expect(messages.first.data[:card]).to eq(card_data)
    end
  end

  describe ".publish_card_moved!" do
    it "publishes a card_moved message" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_moved!(board, card_data, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data[:type]).to eq("card_moved")
      expect(messages.first.data[:card]).to eq(card_data)
    end
  end

  describe ".publish_card_deleted!" do
    it "publishes a card_deleted message with card_id" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_deleted!(board, card.id, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.data[:type]).to eq("card_deleted")
      expect(msg.data[:client_id]).to eq(test_client_id)
      expect(msg.data[:card_id]).to eq(card.id)
    end
  end

  describe ".publish_board_updated!" do
    it "publishes a board_updated message" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_board_updated!(board, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.data[:type]).to eq("board_updated")
      expect(msg.data[:client_id]).to eq(test_client_id)
    end
  end

  context "with a public board" do
    fab!(:public_board) do
      DiscourseKanban::Board.create!(
        name: "Public Board",
        slug: "test-publisher-public",
        created_by_id: admin.id,
      )
    end

    it "publishes without group_ids restriction" do
      messages =
        MessageBus.track_publish("/kanban/boards/#{public_board.id}") do
          described_class.publish_board_updated!(public_board, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.group_ids).to be_nil
    end
  end
end
