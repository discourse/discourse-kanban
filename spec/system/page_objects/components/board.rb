# frozen_string_literal: true

module PageObjects
  module Components
    class Board < PageObjects::Components::Base
      def board_menu
        PageObjects::Components::DMenu.new(
          find(
            ".discourse-kanban-board-viewer__controls [data-identifier='kanban-board-controls']",
          ),
        )
      end

      def open_board_menu
        board_menu.expand
        self
      end

      def click_board_settings_menu_item
        board_menu.option("[data-identifier='board-settings']").click
        self
      end

      def click_add_column_menu_item
        board_menu.option("[data-identifier='add-column']").click
        self
      end

      def click_delete_board_menu_item
        board_menu.option("[data-identifier='delete-board']").click
        self
      end
    end
  end
end
