# frozen_string_literal: true

module DiscourseKanban
  class CardsController < BaseController
    before_action :ensure_logged_in

    def create
      DiscourseKanban::CreateCard.call(
        guardian:,
        params: card_mutation_params.to_h.merge("board_id" => params[:board_id]),
      ) do
        on_success do |card:, board:|
          payload = card_payload(card)
          Publisher.publish_card_created!(board, payload, client_id: message_bus_client_id)
          render json: { card: payload }, status: :created
        end
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_model_not_found(:column) do
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
        end
        on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def update
      raw_params = card_mutation_params.to_h

      DiscourseKanban::UpdateCard.call(
        guardian:,
        params: raw_params.merge("board_id" => params[:board_id], "id" => params[:id]),
        raw_card_params: raw_params,
      ) do
        on_success do |card:, board:, original_column_id:, adopted_floater_id:|
          card.topic&.reload
          response = card_payload(card)

          if adopted_floater_id
            Publisher.publish_card_deleted!(
              board,
              adopted_floater_id,
              client_id: message_bus_client_id,
            )
            Publisher.publish_card_created!(board, response, client_id: message_bus_client_id)
          elsif card.column_id != original_column_id
            Publisher.publish_card_moved!(board, response, client_id: message_bus_client_id)
          else
            Publisher.publish_card_updated!(board, response, client_id: message_bus_client_id)
          end

          render json: { card: response, adopted_floater_id: adopted_floater_id }
        end
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_model_not_found(:card) do
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.card_not_found"))
        end
        on_model_not_found(:column) do
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
        end
        on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def destroy
      DiscourseKanban::DestroyCard.call(
        guardian:,
        params: {
          board_id: params[:board_id],
          id: params[:id],
        },
      ) do
        on_success do |card:, board:|
          Publisher.publish_card_deleted!(board, card.id, client_id: message_bus_client_id)
          head :no_content
        end
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_model_not_found(:card) do
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.card_not_found"))
        end
        on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
        on_failed_policy(:card_is_deletable) do
          render json: {
                   errors: [I18n.t("discourse_kanban.errors.topic_covered_by_filter")],
                 },
                 status: :unprocessable_entity
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
