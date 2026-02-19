# frozen_string_literal: true

module DiscourseKanban
  class BoardsController < BaseController
    before_action :ensure_logged_in, only: %i[create update destroy]
    before_action :find_board!, only: %i[show update destroy]
    before_action :ensure_board_read!, only: %i[show]
    before_action :ensure_board_manage!, only: %i[create update destroy]

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
      cards = @board.cards.with_column.ordered.includes(:updated_by, topic: topic_includes)
      visible_topic_ids = visible_topic_ids_for(cards)

      columns = @board.columns.map { |column| column_payload(column).merge(cards: []) }
      columns_by_id = columns.index_by { |column| column[:id] }

      cards.each do |card|
        next if card.topic? && !visible_topic_ids.include?(card.topic_id)

        columns_by_id[card.column_id]&.[](:cards)&.push(card_payload(card))
      end

      render json: { board: board_payload(@board), columns: columns }
    end

    def create
      payload = board_mutation_params.to_h
      columns_payload = payload.delete("columns") || []

      board = DiscourseKanban::Board.new(payload)
      board.created_by_id = current_user.id
      board.updated_by_id = current_user.id

      DiscourseKanban::Board.transaction do
        board.save!
        replace_columns!(board, columns_payload)
      end

      render json: { board: board_payload(board) }, status: :created
    end

    def update
      payload = board_mutation_params.to_h
      columns_payload = payload.delete("columns") || []

      DiscourseKanban::Board.transaction do
        @board.assign_attributes(payload)
        @board.updated_by_id = current_user.id
        @board.save!
        replace_columns!(@board, columns_payload)
      end

      Publisher.publish_board_updated!(@board, client_id: message_bus_client_id)
      render json: { board: board_payload(@board) }
    end

    def destroy
      Publisher.publish_board_updated!(@board, client_id: message_bus_client_id)
      @board.destroy!
      head :no_content
    end

    private

    def replace_columns!(board, columns_payload)
      current_columns = board.columns.index_by(&:id)
      kept_column_ids = []

      columns_payload.each_with_index do |column_payload, index|
        id = column_payload["id"].presence&.to_i
        column = id && current_columns[id] ? current_columns[id] : board.columns.build

        column.assign_attributes(
          title: column_payload["title"],
          icon: column_payload["icon"],
          filter_query: column_payload["filter_query"],
          move_to_tag: column_payload["move_to_tag"],
          move_to_category_id: column_payload["move_to_category_id"],
          move_to_assigned: column_payload["move_to_assigned"],
          move_to_status: column_payload["move_to_status"],
          position: index,
        )

        column.save!
        kept_column_ids << column.id
      end

      removed_columns = board.columns.where.not(id: kept_column_ids)
      removed_column_ids = removed_columns.pluck(:id)

      if removed_column_ids.present?
        board
          .cards
          .where(
            column_id: removed_column_ids,
            card_type: DiscourseKanban::Card.card_types[:floater],
          )
          .delete_all
        board
          .cards
          .where(column_id: removed_column_ids, card_type: DiscourseKanban::Card.card_types[:topic])
          .update_all(
            column_id: nil,
            membership_mode: DiscourseKanban::Card.membership_modes[:manual_out],
            updated_by_id: current_user.id,
            updated_at: Time.zone.now,
          )
      end

      removed_columns.delete_all
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
