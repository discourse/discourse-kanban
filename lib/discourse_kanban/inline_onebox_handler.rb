# frozen_string_literal: true

module DiscourseKanban
  class InlineOneboxHandler
    def self.handle(url, route, opts = {})
      if route[:card_id].present?
        build_card_onebox(url, route[:card_id], route[:id], opts)
      else
        build_board_onebox(url, route[:id])
      end
    end

    private

    def self.build_card_onebox(url, card_id, board_id, opts)
      board = DiscourseKanban::Board.find_by(id: board_id)
      return if !board || !board.anonymous_can_read?

      card = DiscourseKanban::Card.includes(:topic).find_by(id: card_id, board_id: board_id)
      return if !card
      if card.topic? &&
           (
             card.topic.blank? ||
               Oneboxer.local_topic(card.topic.url, { id: card.topic_id }, opts).blank?
           )
        return
      end

      title =
        I18n.t(
          "discourse_kanban.onebox.inline_to_card",
          card_name: Emoji.gsub_emoji_to_unicode(card.resolved_title),
          board_name: Emoji.gsub_emoji_to_unicode(board.name),
        )

      { url: url, title: title }
    end

    def self.build_board_onebox(url, board_id)
      board = DiscourseKanban::Board.find_by(id: board_id)
      return if !board || !board.anonymous_can_read?

      title =
        I18n.t(
          "discourse_kanban.onebox.inline_to_board",
          board_name: Emoji.gsub_emoji_to_unicode(board.name),
        )

      { url: url, title: title }
    end
  end
end
