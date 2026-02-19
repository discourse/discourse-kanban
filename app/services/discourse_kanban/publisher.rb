# frozen_string_literal: true

module DiscourseKanban
  module Publisher
    CHANNEL_PREFIX = "/kanban/boards"

    def self.publish_card_created!(board, card_payload, client_id:)
      publish_card_event!(board, "card_created", card_payload, client_id:)
    end

    def self.publish_card_updated!(board, card_payload, client_id:)
      publish_card_event!(board, "card_updated", card_payload, client_id:)
    end

    def self.publish_card_moved!(board, card_payload, client_id:)
      publish_card_event!(board, "card_moved", card_payload, client_id:)
    end

    def self.publish_card_deleted!(board, card_id, client_id:)
      publish!(board, { type: "card_deleted", client_id: client_id, card_id: card_id })
    end

    def self.publish_board_updated!(board, client_id:)
      publish!(board, { type: "board_updated", client_id: client_id })
    end

    def self.publish_card_event!(board, type, card_payload, client_id:)
      publish!(board, { type: type, client_id: client_id, card: card_payload })
    end
    private_class_method :publish_card_event!

    def self.publish!(board, data)
      group_ids = board.effective_read_group_ids
      opts = {}
      opts[:group_ids] = group_ids if group_ids.present?

      MessageBus.publish("#{CHANNEL_PREFIX}/#{board.id}", data, opts)
    end
    private_class_method :publish!
  end
end
