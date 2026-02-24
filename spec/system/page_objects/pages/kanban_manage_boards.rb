# frozen_string_literal: true

module PageObjects
  module Pages
    class KanbanManageBoards < PageObjects::Pages::Base
      def visit_page
        page.visit "/kanban"
        self
      end

      def click_new_board
        find(".discourse-kanban-manage__header .btn-primary").click
        self
      end

      def has_board_listed?(name)
        has_css?(".kanban-board-card", text: name)
      end

      def has_no_board_listed?(name)
        has_no_css?(".kanban-board-card", text: name)
      end

      def has_empty_state?
        has_css?(".kanban-boards-empty")
      end

      def has_new_board_button?
        has_css?(".discourse-kanban-manage__header .btn-primary")
      end

      def has_no_new_board_button?
        has_no_css?(".discourse-kanban-manage__header .btn-primary")
      end

      def click_board(board_name)
        find(".kanban-board-card__name", text: board_name).click
        self
      end

      # Board settings modal interactions

      def fill_modal_board_name(name)
        within(".kanban-board-settings-modal") do
          all("input[type='text']").first.fill_in(with: name)
        end
        self
      end

      def toggle_modal_require_confirmation
        within(".kanban-board-settings-modal") do
          find("label", text: I18n.t("js.discourse_kanban.manage.require_confirmation")).find(
            "input[type='checkbox']",
          ).click
        end
        self
      end

      def save_board_modal
        within(".kanban-board-settings-modal") { find(".btn-primary").click }
        self
      end

      def delete_from_board_modal
        within(".kanban-board-settings-modal") { find(".btn-danger").click }
        self
      end

      # Board viewer interactions

      def open_board_menu
        find(".kanban-board-viewer__controls [data-identifier='kanban-board-controls']").click
        self
      end

      def click_board_settings_menu_item
        find(".btn-transparent", text: I18n.t("js.discourse_kanban.board.board_settings")).click
        self
      end

      def click_add_column_menu_item
        find(".btn-transparent", text: I18n.t("js.discourse_kanban.board.add_column")).click
        self
      end

      def click_delete_board_menu_item
        find(
          ".btn-transparent.btn-danger",
          text: I18n.t("js.discourse_kanban.board.delete_board"),
        ).click
        self
      end

      # Column settings modal interactions

      def fill_modal_column_title(title)
        within(".kanban-column-settings-modal") do
          all("input[type='text']").first.fill_in(with: title)
        end
        self
      end

      def save_column_modal
        within(".kanban-column-settings-modal") { find(".btn-primary").click }
        self
      end

      def has_column?(title)
        has_css?(".kanban-column__title", text: title)
      end
    end
  end
end
