# frozen_string_literal: true

module PageObjects
  module Pages
    class KanbanBoardViewer < PageObjects::Pages::Base
      def visit_board(board)
        page.visit "/kanban/boards/#{board.slug}/#{board.id}"
        self
      end

      def visit_board_with_slug(slug, board)
        page.visit "/kanban/boards/#{slug}/#{board.id}"
        self
      end

      def has_column?(title)
        has_css?(".kanban-column__title", text: /#{Regexp.escape(title)}/i)
      end

      def has_no_column?(title)
        has_no_css?(".kanban-column__title", text: /#{Regexp.escape(title)}/i)
      end

      def has_card_in_column?(column_title, card_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_css?(".kanban-card__title", text: card_title)
        end
      end

      def has_no_card_in_column?(column_title, card_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_no_css?(".kanban-card__title", text: card_title)
        end
      end

      def card_count_in_column(column_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          all(".kanban-card").count
        end
      end

      def drag_card_to_column(card_title, target_column_title)
        find(".kanban-card", text: card_title).drag_to(
          find(".kanban-column", text: /#{Regexp.escape(target_column_title)}/i),
        )
        self
      end

      def has_board_title?(title)
        has_css?(".kanban-board-viewer__title", text: title)
      end

      def card_draggable?(card_title)
        find(".kanban-card", text: card_title)["draggable"] == "true"
      end

      def has_tag_on_card?(card_title, tag_name)
        within(find(".kanban-card", text: card_title)) do
          has_css?(".discourse-tag", text: tag_name)
        end
      end

      def has_no_tag_on_card?(card_title, tag_name)
        within(find(".kanban-card", text: card_title)) do
          has_no_css?(".discourse-tag", text: tag_name)
        end
      end

      def has_category_on_card?(card_title)
        within(find(".kanban-card", text: card_title)) { has_css?(".kanban-card__category") }
      end

      def has_activity_indicator?(card_title, type)
        has_css?(".kanban-card.#{type}", text: card_title)
      end

      def has_add_card_button_in_column?(column_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_css?(".kanban-column__add-btn")
        end
      end

      def has_no_add_card_button_in_column?(column_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_no_css?(".kanban-column__add-btn")
        end
      end

      def click_add_card(column_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          find(".kanban-column__add-btn").click
        end
        self
      end

      def fill_card_title(title)
        find(".kanban-column__card-title-input").fill_in(with: title)
        self
      end

      def submit_card
        find(".kanban-column__add-card-actions .btn-primary").click
        self
      end

      def has_floater_card_in_column?(column_title, card_title)
        within(find(".kanban-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_css?(".kanban-card--floater", text: card_title)
        end
      end

      def open_card_actions(card_title)
        within(find(".kanban-card", text: card_title)) do
          find(".kanban-card__actions-trigger", visible: :all).click
        end
        self
      end

      def has_edit_card_action?
        has_css?(
          "[data-content][data-identifier='kanban-card-actions'] .btn-transparent .d-button-label",
          text: I18n.t("js.edit"),
        )
      end

      def click_edit_card
        find(
          "[data-content][data-identifier='kanban-card-actions'] .btn-transparent",
          text: I18n.t("js.edit"),
        ).click
        self
      end

      def has_card_detail_modal?
        has_css?(".kanban-card-detail-modal")
      end

      def fill_card_detail_title(new_title)
        within(".kanban-card-detail-modal") do
          find(".kanban-card-detail__field input[type='text']", match: :first).set(new_title)
        end
        self
      end

      def fill_card_detail_label(new_label)
        within(".kanban-card-detail-modal") do
          find(".kanban-card-detail__label-input").fill_in(with: new_label)
        end
        self
      end

      def add_card_detail_label_with_enter
        within(".kanban-card-detail-modal") do
          find(".kanban-card-detail__label-input").send_keys(:enter)
        end
        self
      end

      def has_card_detail_label?(label)
        within(".kanban-card-detail-modal") do
          has_css?(".kanban-card-detail__label-chip", text: label)
        end
      end

      def save_card_detail
        within(".kanban-card-detail-modal") { find(".btn-primary", text: I18n.t("js.save")).click }
        self
      end

      def cancel_card_detail
        within(".kanban-card-detail-modal") do
          find(".d-modal-cancel", text: I18n.t("js.cancel")).click
        end
        self
      end

      def has_fullscreen?
        has_css?(".kanban-board-viewer.is-fullscreen")
      end

      def has_no_fullscreen?
        has_no_css?(".kanban-board-viewer.is-fullscreen")
      end

      def open_controls_menu
        find(".kanban-board-viewer__controls [data-identifier='kanban-board-controls']").click
        self
      end

      def has_no_controls_menu?
        has_no_css?(".kanban-board-viewer__controls [data-identifier='kanban-board-controls']")
      end

      def click_fullscreen
        find(
          ".kanban-board-viewer__controls .btn-flat[title='#{I18n.t("js.discourse_kanban.board.fullscreen")}']",
        ).click
        self
      end

      def click_exit_fullscreen
        find(".kanban-board-viewer__exit-fullscreen").click
        self
      end

      def has_board_settings_option?
        has_css?(
          "[data-content][data-identifier='kanban-board-controls'] .btn-transparent .d-button-label",
          text: I18n.t("js.discourse_kanban.board.board_settings"),
        )
      end

      def has_no_board_settings_option?
        has_no_css?(
          "[data-content][data-identifier='kanban-board-controls'] .btn-transparent .d-button-label",
          text: I18n.t("js.discourse_kanban.board.board_settings"),
        )
      end

      def click_floater_card(card_title)
        find(".kanban-card--floater", text: card_title).click
        self
      end

      def has_card_label?(card_title, label)
        within(find(".kanban-card--floater", text: card_title)) do
          has_css?(".kanban-card__label", text: label)
        end
      end

      def has_card_notes_indicator?(card_title)
        within(find(".kanban-card--floater", text: card_title)) do
          has_css?(".kanban-card__notes-indicator")
        end
      end
    end
  end
end
