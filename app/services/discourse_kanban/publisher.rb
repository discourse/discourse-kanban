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

    def self.publish_column_cleared!(board, column_id, client_id:)
      publish!(board, { type: "column_cleared", client_id: client_id, column_id: column_id })
    end

    def self.publish_board_updated!(board, client_id:)
      publish!(board, { type: "board_updated", client_id: client_id })
    end

    def self.publish_columns_reordered!(board, column_order, client_id:)
      publish!(
        board,
        { type: "columns_reordered", client_id: client_id, column_order: column_order },
      )
    end

    def self.publish_card_event!(board, type, card_payload, client_id:)
      # Strip topic data from broadcast payloads to prevent leaking
      # private topic details to board readers who lack category access.
      # Clients merge with existing state or refetch through the
      # authorized show endpoint.
      safe_payload = card_payload.except("topic", :topic)
      publish!(board, { type: type, client_id: client_id, card: safe_payload })
    end
    private_class_method :publish_card_event!

    def self.publish!(board, data)
      group_ids = board.effective_read_group_ids
      opts = {}
      # Anonymous viewers belong to no group, so a board readable by anonymous
      # users must broadcast to everyone rather than being group-restricted.
      if group_ids.present? && !group_ids.include?(Group::AUTO_GROUPS[:anonymous_users])
        opts[:group_ids] = group_ids
      end

      MessageBus.publish("#{CHANNEL_PREFIX}/#{board.id}", data, opts)
    end
    private_class_method :publish!
  end
end
