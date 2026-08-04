# frozen_string_literal: true

module DiscourseKanban
  class TopicBoardMembershipCardSerializer < ApplicationSerializer
    attributes :card_id,
               :column_id,
               :column_title,
               :unicode_column_title,
               :column_color,
               :column_icon

    def card_id
      object.id
    end

    def column
      object.column
    end

    def column_id
      column.id
    end

    def column_title
      column.title
    end

    def include_unicode_column_title?
      column.title.match?(/:[\w\-+]+:/)
    end

    def unicode_column_title
      Emoji.gsub_emoji_to_unicode(column.title)
    end

    def column_color
      column.color
    end

    def column_icon
      column.icon
    end
  end
end
