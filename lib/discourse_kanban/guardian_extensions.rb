# frozen_string_literal: true

module DiscourseKanban
  module GuardianExtensions
    def can_manage_kanban_boards?
      return false if anonymous?
      return true if is_admin?

      user.in_any_groups?(SiteSetting.discourse_kanban_manage_board_allowed_groups_map)
    end

    def can_create_board?
      can_manage_kanban_boards?
    end

    def can_destroy_board?
      can_manage_kanban_boards?
    end

    def can_move_board_column?
      can_manage_kanban_boards?
    end

    def can_update_board?
      can_manage_kanban_boards?
    end

    def can_read_board?(board)
      return true if board.public_read?
      return true if can_write_board?(board)

      # Board writers can read it as well
      user.in_any_groups?(board.effective_read_group_ids)
    end

    def can_write_board?(board)
      return false if anonymous?
      return true if is_admin? && !user.is_system_user?

      user.in_any_groups?(board.allow_write_group_ids)
    end
  end
end
