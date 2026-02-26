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
      true
    end

    def destroy(card:)
      if card.topic? && card.column_id.present?
        card.update!(membership_mode: :manual_out)
      else
        card.destroy!
      end
    end
  end
end
