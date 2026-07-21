# frozen_string_literal: true

module DiscourseKanban
  module GuardianExtensions
    def can_manage_kanban_boards?
      in_any_groups?(SiteSetting.discourse_kanban_manage_board_allowed_groups_map)
    end

    def can_create_board?
      can_manage_kanban_boards?
    end

    def can_destroy_board?(board)
      can_manage_kanban_boards? && has_acl_permission?(board, "manage")
    end

    def can_manage_board?(board)
      can_manage_kanban_boards? && has_acl_permission?(board, "manage")
    end

    def can_read_board?(board)
      return true if board.anonymous_can_read?
      return true if can_write_board?(board)

      has_acl_permission?(board, "view")
    end

    def can_write_board?(board)
      has_any_acl_permission?(board, %w[edit manage])
    end

    def can_view_card?(card)
      can_read_board?(card.board)
    end
  end
end
