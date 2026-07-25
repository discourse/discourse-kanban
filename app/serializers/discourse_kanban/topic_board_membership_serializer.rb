# frozen_string_literal: true

module DiscourseKanban
  class TopicBoardMembershipSerializer < ApplicationSerializer
    attributes :board_id, :board_name, :board_slug, :board_column_count, :board_created_by, :cards

    def board_id
      board.id
    end

    def board_name
      board.name
    end

    def board_slug
      board.slug
    end

    def board_column_count
      board.columns.size
    end

    def board_created_by
      return if board.created_by.blank?

      {
        username: board.created_by.username,
        display_name: board.created_by.display_name,
        avatar_template: board.created_by.avatar_template,
      }
    end

    def cards
      object
        .sort_by { |card| [card.column.position, card.column.id, card.id] }
        .map { |card| TopicBoardMembershipCardSerializer.new(card, root: false, scope:).as_json }
    end

    private

    def board
      object.first.board
    end
  end
end
