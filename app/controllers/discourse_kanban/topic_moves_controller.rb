# frozen_string_literal: true

module DiscourseKanban
  class TopicMovesController < BaseController
    before_action :ensure_logged_in

    def create
      DiscourseKanban::MoveTopicToColumn.call(
        **service_params.deep_merge(
          params: {
            board_id: params[:board_id],
            client_id: message_bus_client_id,
          },
        ),
      ) do
        on_success do |card:|
          render json: {
                   card: CardPayloadSerializer.new(card, root: false).as_json,
                 },
                 status: :created
        end
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_not_found(:column) do
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
        end
        on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_see_topic) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_edit_topic) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
