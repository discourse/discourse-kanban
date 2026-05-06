# frozen_string_literal: true

module DiscourseKanban
  class OneboxHandler
    def self.handle(url, route)
      if route[:card_id].present?
        build_card_onebox(url, route[:card_id], route[:id])
      else
        build_board_onebox(url, route[:id])
      end
    end

    private

    def self.build_card_onebox(url, card_id, board_id)
      ""
    end

    def self.build_board_onebox(url, board_id)
      board = DiscourseKanban::Board.find_by(id: board_id)
      return "" if !board || !Discourse.system_user.guardian.can_read_board?(board)

      tag_html = ""
      if board.tags.any?
        tag_hashtags = board.tags.map { |tag| "##{tag.name}" }.join("\n")
        tag_html =
          Nokogiri::HTML5.fragment(PrettyText.cook(tag_hashtags)).css("a").map(&:to_s).join("\n")
      end

      category_html = ""
      if board.categories.any?
        category_hashtags = board.categories.map { |category| "##{category.name}" }.join("\n")
        category_html =
          Nokogiri::HTML5
            .fragment(PrettyText.cook(category_hashtags))
            .css("a")
            .map(&:to_s)
            .join("\n")
      end

      # TODO (martin) Handle :emoji codes: in board title
      args = {
        board_url: url,
        board_name: board.name,
        board_tags: tag_html,
        board_categories: category_html,
        board_columns:
          board
            .columns
            .select(:title, :icon)
            .map { |column| { name: column.title, icon: column.icon } },
        creator_username: board.created_by.username,
        creator_avatar_url: board.created_by.small_avatar_url,
        created_by:
          I18n.t("discourse_kanban.onebox.created_by", username: board.created_by.display_name),
        column_count: I18n.t("discourse_kanban.onebox.column_count", count: board.columns.count),
        onebox_type: I18n.t("discourse_kanban.onebox.board"),
        tags_preview: board.tags.any?,
        categories_preview: board.categories.any?,
        columns_preview: board.columns.any?,
        restricted: board.allow_read_group_ids.any?,
      }

      Mustache.render(DiscourseKanban.board_onebox_template, args)
    end
  end
end
