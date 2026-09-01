# frozen_string_literal: true

module PageObjects
  module Components
    class KanbanAddFromTopic < PageObjects::Components::Base
      ADD_TO_BOARD_BUTTON = "#topic-footer-button-kanban-add-from-topic"
      MEMBERSHIP_PILL = "#topic-title .kanban-topic-pill"

      def add_to_column(board, column)
        select_column(board, column)
      end

      def remove_from_column(board, column)
        select_column(board, column)
      end

      def select_column(board, column)
        find(ADD_TO_BOARD_BUTTON).click
        within(".kanban-add-from-topic-menu") do
          find("button", exact_text: board.unicode_name).click
        end
        within(".kanban-add-from-topic-column-menu") do
          find("button", exact_text: column.unicode_title).click
        end
        self
      end

      def has_no_add_to_board_button?
        has_no_css?(ADD_TO_BOARD_BUTTON)
      end

      def has_membership?(board, column)
        has_css?(MEMBERSHIP_PILL, exact_text: board.unicode_name) do |pill|
          pill["title"] ==
            I18n.t(
              "js.discourse_kanban.topic_pill.title",
              board: board.unicode_name,
              column: column.unicode_title,
            )
        end
      end

      def has_membership_count?(count)
        has_css?(
          "#{MEMBERSHIP_PILL}.kanban-topic-pill--multiple",
          exact_text: I18n.t("js.discourse_kanban.topic_pill.multiple", count:),
        )
      end

      def open_memberships
        find("#{MEMBERSHIP_PILL}.kanban-topic-pill--multiple").click
        self
      end

      def has_membership_in_menu?(board, column)
        within("[data-content][data-identifier='kanban-topic-pill']") do
          find(".kanban-boards-menu__item", text: board.unicode_name).has_css?(
            ".kanban-boards-menu__column",
            text: /#{Regexp.escape(column.unicode_title)}/i,
          )
        end
      end
    end
  end
end
