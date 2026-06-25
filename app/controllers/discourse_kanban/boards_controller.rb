# frozen_string_literal: true

module DiscourseKanban
  class BoardsController < BaseController
    before_action :ensure_logged_in, only: %i[create update destroy move_column constraint_preview]
    before_action :find_board!, only: %i[show]
    before_action :ensure_board_read!, only: %i[show]

    def respond
      render body: nil
    end
    def index
      boards =
        DiscourseKanban::Board
          .includes(:columns, :created_by)
          .with_any_acl_permissions(guardian, %w[view edit manage])
          .to_a
      tag_name_map = build_tag_name_map(*boards)
      render json: { boards: boards.map { |board| board_payload(board, tag_name_map:) } }
    end

    def show
      TopicSync.backfill_board(@board)

      # TODO (martin) We can further refactor this whole controller action
      # to be in a service, for now let's just log the view history,
      # it doesn't matter if this fails silently.
      DiscourseKanban::ViewBoard.call(guardian:, params: { id: @board.id })

      topic_includes = %i[tags last_poster]
      topic_includes << :assignment if Topic.reflect_on_association(:assignment)
      cards =
        @board.cards.with_column.includes(:created_by, :assigned_to, topic: topic_includes).to_a
      visible_topic_ids = visible_topic_ids_for(cards)

      assignments_by_topic = preload_all_assignments(cards, visible_topic_ids)
      tags_by_id = preload_floater_card_tags(cards)

      tag_name_map = build_tag_name_map(@board)
      board_columns = @board.columns.to_a
      cards_by_column =
        cards
          .reject { |card| card.topic? && !visible_topic_ids.include?(card.topic_id) }
          .group_by(&:column_id)
      columns =
        board_columns.map do |column|
          column_payload(column, tag_name_map:).merge(
            cards:
              sort_cards_for_column(column, cards_by_column[column.id] || []).map do |card|
                CardPayloadSerializer.new(
                  card,
                  root: false,
                  scope: guardian,
                  assignments_by_topic:,
                  tags_by_id:,
                ).as_json
              end,
          )
        end

      render json: {
               board:
                 board_payload(
                   @board,
                   tag_name_map:,
                   include_acl: guardian.can_manage_kanban_board?(@board),
                 ),
               columns: columns,
             }
    end

    def create
      raw = board_mutation_params.to_h

      DiscourseKanban::CreateBoard.call(guardian:, params: raw, raw_board_params: raw) do |result|
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
        on_success do |board:, cards_removed_count:|
          response = { board: board_payload(board, include_acl: guardian.can_manage_board?(board)) }
          response[:cards_removed_count] = cards_removed_count if cards_removed_count.to_i > 0
          render json: response
        end
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

    def constraint_preview
      board = DiscourseKanban::Board.find(params[:id])
      guardian.ensure_can_manage_board!(board)

      new_category_ids = Array(params[:category_ids]).map(&:to_i).reject(&:zero?)
      new_tag_ids =
        if params[:tag_names].present?
          Tag.where(name: Array(params[:tag_names])).pluck(:id)
        else
          []
        end

      cat_empty = new_category_ids.empty?
      tag_empty = new_tag_ids.empty?

      if cat_empty && tag_empty
        count = 0
      else
        count =
          DB.query_single(
            <<~SQL,
              SELECT COUNT(*) FROM discourse_kanban_cards c
              JOIN topics t ON t.id = c.topic_id
              WHERE c.board_id = :board_id AND c.card_type = #{DiscourseKanban::Card.card_types[:topic]}
                AND NOT (
                  (:cat_empty OR t.category_id = ANY(:category_ids))
                  AND (:tag_empty OR EXISTS (
                    SELECT 1 FROM topic_tags tt WHERE tt.topic_id = t.id AND tt.tag_id = ANY(:tag_ids)
                  ))
                )
            SQL
            board_id: board.id,
            category_ids: "{#{new_category_ids.join(",")}}",
            tag_ids: "{#{new_tag_ids.join(",")}}",
            cat_empty: cat_empty,
            tag_empty: tag_empty,
          ).first
      end

      render json: { cards_to_remove: count }
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
        on_failed_policy(:can_destroy) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    private

    def sort_cards_for_column(column, cards)
      if column.recency?
        cards.sort_by { |card| [card.recency_at || Time.zone.at(0), card.id] }.reverse
      else
        cards.sort_by { |card| [card.position, card.id] }
      end
    end

    def preload_all_assignments(cards, visible_topic_ids)
      return {} unless defined?(Assignment)

      topic_ids = cards.select(&:topic?).map(&:topic_id).compact & visible_topic_ids
      return {} if topic_ids.empty?

      Assignment
        .where(topic_id: topic_ids, active: true, assigned_to_type: "User")
        .includes(:assigned_to)
        .group_by(&:topic_id)
    end

    def preload_floater_card_tags(cards)
      return {} unless SiteSetting.tagging_enabled

      tag_ids = cards.reject(&:topic?).flat_map(&:tag_ids).uniq
      return {} if tag_ids.empty?

      DiscourseTagging.filter_visible(Tag.where(id: tag_ids), guardian).index_by(&:id)
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
