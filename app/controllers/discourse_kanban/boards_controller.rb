# frozen_string_literal: true

module DiscourseKanban
  class BoardsController < BaseController
    before_action :ensure_logged_in, only: %i[create update destroy move_column]
    before_action :find_board!, only: %i[show]
    before_action :ensure_board_read!, only: %i[show]

    def respond
      render body: nil
    end

    def index
      boards =
        DiscourseKanban::Board.includes(:columns).to_a.select { |board| board.can_read?(guardian) }
      render json: { boards: boards.map { |board| board_payload(board) } }
    end

    def show
      TopicSync.backfill_board(@board)

      topic_includes = %i[tags last_poster]
      topic_includes << :assignment if Topic.reflect_on_association(:assignment)
      cards =
        @board.cards.with_column.ordered.includes(:created_by, :assigned_to, topic: topic_includes)
      visible_topic_ids = visible_topic_ids_for(cards)

      assignments_by_topic = preload_all_assignments(cards, visible_topic_ids)

      columns = @board.columns.map { |column| column_payload(column).merge(cards: []) }
      columns_by_id = columns.index_by { |column| column[:id] }

      cards.each do |card|
        next if card.topic? && !visible_topic_ids.include?(card.topic_id)

        columns_by_id[card.column_id]&.[](:cards)&.push(
          CardPayloadSerializer.new(card, root: false, assignments_by_topic:).as_json,
        )
      end

      render json: { board: board_payload(@board), columns: columns }
    end

    def create
      raw = board_mutation_params.to_h

      DiscourseKanban::CreateBoard.call(guardian:, params: raw, raw_board_params: raw) do
        on_success { |board:| render json: { board: board_payload(board) }, status: :created }
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def update
      raw = board_mutation_params.to_h

      DiscourseKanban::UpdateBoard.call(
        guardian:,
        params: raw.merge("id" => params[:id], "client_id" => params[:client_id]),
        raw_board_params: raw,
      ) do
        on_success { |board:| render json: { board: board_payload(board) } }
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def move_column
      DiscourseKanban::MoveColumn.call(
        guardian:,
        params:
          params
            .permit(:column_id, :direction)
            .to_h
            .merge("board_id" => params[:id], "client_id" => message_bus_client_id),
      ) do
        on_success { |column_order:| render json: { column_order: column_order } }
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_model_not_found(:column) do
          raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.column_not_found"))
        end
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def destroy
      DiscourseKanban::DestroyBoard.call(
        guardian:,
        params: {
          id: params[:id],
          client_id: params[:client_id],
        },
      ) do
        on_success { head :no_content }
        on_model_not_found(:board) { raise Discourse::NotFound }
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    private

    def preload_all_assignments(cards, visible_topic_ids)
      return {} unless defined?(Assignment)

      topic_ids = cards.select(&:topic?).map(&:topic_id).compact & visible_topic_ids
      return {} if topic_ids.empty?

      Assignment
        .where(topic_id: topic_ids, active: true, assigned_to_type: "User")
        .includes(:assigned_to)
        .group_by(&:topic_id)
    end

    def visible_topic_ids_for(cards)
      topic_ids = cards.select(&:topic?).map(&:topic_id).uniq
      return [] if topic_ids.empty?

      Topic
        .listable_topics
        .secured(guardian)
        .where(id: topic_ids)
        .where.not(id: Category.where.not(topic_id: nil).select(:topic_id))
        .pluck(:id)
    end
  end
end
