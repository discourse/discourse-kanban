# frozen_string_literal: true

module DiscourseKanban
  class Column < ActiveRecord::Base
    self.table_name = "discourse_kanban_columns"

    belongs_to :board, class_name: "DiscourseKanban::Board", inverse_of: :columns
    has_many :cards,
             class_name: "DiscourseKanban::Card",
             dependent: :nullify,
             inverse_of: :column

    validates :title, presence: true
    validates :position, presence: true

    def matches_topic?(topic)
      return true if filter_query.blank?

      Board.topic_matches_query?(topic, combined_query)
    end

    def combined_query
      [board.base_filter_query, filter_query].reject(&:blank?).join(" ")
    end
  end
end
