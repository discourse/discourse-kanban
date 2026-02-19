# frozen_string_literal: true

module DiscourseKanban
  class TopicMovesController < BaseController
    before_action :ensure_logged_in
    before_action :find_board!
    before_action :ensure_board_write!

    def create
      topic = Topic.find(params.require(:topic_id))
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)

      column = @board.columns.find_by(id: params.require(:to_column_id))
      if column.blank?
        raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
      end

      DiscourseKanban::TopicMutator.apply!(topic:, column:, guardian:)

      card = @board.cards.find_or_initialize_by(topic_id: topic.id)
      is_new = card.new_record?

      card.assign_attributes(
        card_type: :topic,
        membership_mode: :manual_in,
        updated_by_id: current_user.id,
      )
      card.created_by_id ||= current_user.id

      if is_new
        DiscourseKanban::CardOrdering.append_to_column!(card, column)
      else
        DiscourseKanban::CardOrdering.place_card!(
          card,
          column:,
          after_card_id: params[:after_card_id],
        )
      end

      card.save!

      payload = card_payload(card)
      if is_new
        Publisher.publish_card_created!(@board, payload, client_id: message_bus_client_id)
      else
        Publisher.publish_card_moved!(@board, payload, client_id: message_bus_client_id)
      end

      render json: { card: payload }, status: :created
    end
  end
end
