# frozen_string_literal: true

module DiscourseKanban
  class DestroyCard
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer

      validates :board_id, presence: true
      validates :id, presence: true
    end

    model :board
    policy :can_write
    model :card
    policy :card_is_deletable
    step :destroy

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      board.can_write?(guardian)
    end

    def fetch_card(board:, params:)
      board.cards.find_by(id: params.id)
    end

    def card_is_deletable(card:)
      return true if card.floater?

      topic = card.topic
      column = card.column
      return true if topic.blank? || column.blank?

      combined = column.combined_query
      return true if combined.blank?

      !Board.topic_matches_query?(topic, combined)
    end

    def destroy(card:)
      card.destroy!
    end
  end
end
