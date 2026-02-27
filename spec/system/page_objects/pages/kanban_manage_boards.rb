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

      def has_column_modal_mode?(mode)
        selector =
          ".kanban-column-settings-modal input[data-identifier='kanban-column-filter-query']"

        case mode
        when "advanced"
          has_css?(selector, wait: 0)
        else
          has_no_css?(selector, wait: 0)
        end
      end

      def switch_column_modal_mode(mode)
        current_mode =
          (
            if has_css?(
                 ".kanban-column-settings-modal input[data-identifier='kanban-column-filter-query']",
                 wait: 0,
               )
              "advanced"
            else
              "simple"
            end
          )

        return self if current_mode == mode

        within(".kanban-column-settings-modal") { find(".show-advanced").click }
        self
      end

      def select_modal_column_tag(tag_name)
        within(".kanban-column-settings-modal") do
          chooser = PageObjects::Components::SelectKit.new(".mini-tag-chooser")
          chooser.expand
          chooser.search(tag_name)
          chooser.select_row_by_name(tag_name)
        end
        self
      end

      def open_column_menu(column_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          find(".kanban-column__menu-trigger", visible: :all).click
        end
        self
      end

      def click_edit_column_menu_item
        find(".btn-transparent", text: I18n.t("js.discourse_kanban.board.edit_column")).click
        self
      end

      def save_column_modal
        within(".kanban-column-settings-modal") { find(".btn-primary").click }
        self
      end

      def has_column?(title)
        has_css?(".kanban-column__title", text: /#{Regexp.escape(title)}/i)
      end
    end
  end
end
