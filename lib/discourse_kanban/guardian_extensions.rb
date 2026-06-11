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

      group_ids = board.effective_read_group_ids

      # Anonymous visitors have no group memberships and are granted access only
      # through the anonymous auto-group.
      return group_ids.include?(Group::AUTO_GROUPS[:anonymous_users]) if anonymous?

      user.in_any_groups?(group_ids)
    end

    def can_write_board?(board)
      return false if anonymous?
      return true if is_admin? && !user.is_system_user?

      user.in_any_groups?(board.allow_write_group_ids)
    end

    def can_view_card?(card)
      can_read_board?(card.board)
    end
  end
end
