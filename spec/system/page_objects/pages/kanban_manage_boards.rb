# frozen_string_literal: true

module PageObjects
  module Pages
    class KanbanManageBoards < PageObjects::Pages::Base
      def visit_page
        page.visit "/kanban"
        self
      end

      def visit_new
        page.visit "/kanban/boards/new"
        self
      end

      def click_new_board
        find(".discourse-kanban-manage__header .btn-primary").click
        self
      end

      def click_back
        find("a.back-button").click
        self
      end

      def click_edit(board_name)
        find(".kanban-boards-table tr", text: board_name).find(".btn").click
        self
      end

      def has_board_listed?(name)
        has_css?(".kanban-boards-table tr", text: name)
      end

      def has_no_board_listed?(name)
        has_no_css?(".kanban-boards-table tr", text: name)
      end

      def has_empty_state?
        has_css?(".discourse-kanban-manage__empty")
      end

      def has_new_board_button?
        has_css?(".discourse-kanban-manage__header .btn-primary")
      end

      def has_no_new_board_button?
        has_no_css?(".discourse-kanban-manage__header .btn-primary")
      end

      def has_edit_button?(board_name)
        within(find(".kanban-boards-table tr", text: board_name)) { has_css?(".btn") }
      end

      def has_no_edit_button?(board_name)
        within(find(".kanban-boards-table tr", text: board_name)) { has_no_css?(".btn") }
      end

      def click_delete
        find(".kanban-board-form .btn-danger").click
        self
      end
    end
  end
end
