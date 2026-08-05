# frozen_string_literal: true

module DiscourseKanban
  class TopicBoardMembershipSerializer < ApplicationSerializer
    attributes :board_id, :board_name, :unicode_board_name, :board_slug, :cards

    def board_id
      board.id
    end

    def board_name
      board.name
    end

    def unicode_board_name
      board.unicode_name
    end

    def board_slug
      board.slug
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
