# frozen_string_literal: true

module DiscourseKanban
  class CardsController < BaseController
    before_action :ensure_logged_in
    before_action :find_board!
    before_action :ensure_board_write!

    def create
      payload = card_mutation_params.to_h
      column = @board.columns.find_by(id: payload["column_id"])
      if column.blank?
        raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
      end

      card =
        if payload["topic_id"].present?
          build_topic_card(payload, column)
        else
          build_floater_card(payload, column)
        end

      payload = card_payload(card)
      Publisher.publish_card_created!(@board, payload, client_id: message_bus_client_id)
      render json: { card: payload }, status: :created
    end

    def update
      payload = card_mutation_params.to_h
      card = @board.cards.find_by(id: params[:id])
      raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.card_not_found")) if card.blank?

      original_column_id = card.column_id

      column = card.column
      if payload["column_id"].present?
        column = @board.columns.find_by(id: payload["column_id"])
        if column.blank?
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
        end
      end
      if column.blank?
        raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
      end

      promoted = false
      if card.floater? && payload["topic_id"].present?
        card = promote_floater_to_topic!(card, payload["topic_id"], column)
        promoted = true
      elsif card.floater?
        card.assign_attributes(
          title: payload["title"] || card.title,
          notes: payload["notes"],
          due_at: payload["due_at"],
          labels: payload["labels"] || card.labels,
          updated_by_id: current_user.id,
        )
      else
        card.updated_by_id = current_user.id
      end

      if !promoted && card.topic? && column.id != card.column_id && card.topic.present?
        DiscourseKanban::TopicMutator.apply!(topic: card.topic, column:, guardian:)
      end

      DiscourseKanban::CardOrdering.place_card!(
        card,
        column:,
        after_card_id: payload["after_card_id"],
      )
      card.save!

      response = card_payload(card)
      if column.id != original_column_id
        Publisher.publish_card_moved!(@board, response, client_id: message_bus_client_id)
      else
        Publisher.publish_card_updated!(@board, response, client_id: message_bus_client_id)
      end

      render json: { card: response }
    end

    def destroy
      card = @board.cards.find_by(id: params[:id])
      raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.card_not_found")) if card.blank?

      card_id = card.id

      if card.topic?
        handle_topic_card_delete(card)
      else
        card.destroy!
        Publisher.publish_card_deleted!(@board, card_id, client_id: message_bus_client_id)
        head :no_content
      end
    end

    private

    def promote_floater_to_topic!(floater, topic_id, column)
      topic = Topic.find(topic_id)
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)
      if Category.exists?(topic_id: topic.id)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.category_definition_topic"),
              )
      end

      existing = @board.cards.find_by(topic_id: topic.id)
      if existing
        existing.membership_mode = :manual_in
        existing.updated_by_id = current_user.id
        floater.destroy!
        Publisher.publish_card_deleted!(@board, floater.id, client_id: message_bus_client_id)
        DiscourseKanban::TopicMutator.apply!(topic:, column:, guardian:)
        existing
      else
        floater.topic_id = topic.id
        floater.title = nil
        floater.notes = nil
        floater.labels = []
        floater.due_at = nil
        floater.membership_mode = :manual_in
        floater.updated_by_id = current_user.id
        DiscourseKanban::TopicMutator.apply!(topic:, column:, guardian:)
        floater
      end
    end

    def build_topic_card(payload, column)
      topic = Topic.find(payload["topic_id"])
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)
      if Category.exists?(topic_id: topic.id)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.category_definition_topic"),
              )
      end

      card = @board.cards.find_or_initialize_by(topic_id: topic.id)
      card.card_type = :topic
      card.membership_mode = :manual_in
      card.updated_by_id = current_user.id
      card.created_by_id ||= current_user.id

      if card.new_record?
        DiscourseKanban::CardOrdering.append_to_column!(card, column)
      else
        DiscourseKanban::CardOrdering.place_card!(
          card,
          column:,
          after_card_id: payload["after_card_id"],
        )
      end

      card.save!
      card
    end

    def build_floater_card(payload, column)
      card =
        @board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: payload["title"],
          notes: payload["notes"],
          labels: payload["labels"] || [],
          due_at: payload["due_at"],
          created_by_id: current_user.id,
          updated_by_id: current_user.id,
        )

      DiscourseKanban::CardOrdering.append_to_column!(card, column)
      card.save!
      card
    end

    def handle_topic_card_delete(card)
      topic = card.topic
      column = card.column

      if topic.present? && column.present?
        combined = column.combined_query
        if combined.present? && Board.topic_matches_query?(topic, combined)
          return(
            render json: {
                     errors: [I18n.t("discourse_kanban.errors.topic_covered_by_filter")],
                   },
                   status: :unprocessable_entity
          )
        end
      end

      card_id = card.id
      card.destroy!
      Publisher.publish_card_deleted!(@board, card_id, client_id: message_bus_client_id)
      head :no_content
    end
  end
end
