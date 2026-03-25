# frozen_string_literal: true

module DiscourseKanban
  class ClearColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :column_id, :integer

      validates :board_id, presence: true
      validates :column_id, presence: true
    end

    model :board
    policy :can_write
    model :column
    step :clear

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      board.can_write?(guardian)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.column_id)
    end

    def clear(board:, column:)
      cards = Card.where(board_id: board.id, column_id: column.id)

      cards.where(card_type: :topic).update_all(
        membership_mode: Card.membership_modes[:manual_out],
        column_id: nil,
      )

      cards.where(card_type: :floater).delete_all
    end
  end
end
