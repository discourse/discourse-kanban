# frozen_string_literal: true

module DiscourseKanban
  class ViewBoard
    include Service::Base

    params { attribute :id, :integer }

    model :board
    policy :board_not_already_viewed_today
    policy :can_read_board
    step :create_view_history

    private

    def fetch_board(params:)
      DiscourseKanban::Board.find_by(id: params.id)
    end

    def board_not_already_viewed_today(board:, guardian:)
      RateLimiter.new(
        guardian.user,
        "kanban_board_viewed_#{board.id}",
        1,
        24.hours,
        apply_limit_to_staff: true,
      ).performed!(raise_error: false)
    end

    def can_read_board(guardian:, board:)
      guardian.can_read_board?(board)
    end

    def create_view_history(guardian:, board:)
      BoardHistory.create!(
        board:,
        acting_user: guardian.user,
        action: BoardHistory.actions[:board_viewed],
      )
    end
  end
end
