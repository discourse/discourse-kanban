# frozen_string_literal: true

module DiscourseKanban
  class DestroyBoard
    include Service::Base

    params do
      attribute :id, :integer
      attribute :client_id, :string

      validates :id, presence: true
    end

    model :board
    policy :can_manage
    step :publish_update
    step :destroy

    private

    def fetch_board(params:)
      Board.find_by(id: params.id)
    end

    def can_manage(guardian:)
      guardian.can_manage_kanban_boards?
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end

    def destroy(board:)
      board.destroy!
    end
  end
end
