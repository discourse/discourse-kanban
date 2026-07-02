# frozen_string_literal: true

module DiscourseKanban
  class DestroyColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :id, presence: true
    end

    model :board
    policy :can_manage
    model :column

    transaction { step :destroy_column }

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.id)
    end

    def destroy_column(column:)
      ColumnMutator.destroy!(column:)
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end
  end
end
