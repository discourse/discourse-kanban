# frozen_string_literal: true

module DiscourseKanban
  # Resolves which kanban boards a topic belongs to (via its topic cards) so
  # topic lists and topic pages can surface a link back to the board.
  module TopicBoardMemberships
    def self.preload(topics)
      topics = Array(topics)
      return if topics.empty?

      cards_by_topic_id = cards_query(topics.map(&:id)).group_by(&:topic_id)

      topics.each { |topic| topic.kanban_board_cards = cards_by_topic_id[topic.id] || [] }
    end

    def self.cards_for(topic)
      topic.kanban_board_cards || cards_query(topic.id).to_a
    end

    def self.serialize(topic, guardian)
      cards_for(topic)
        .select { |card| guardian.can_read_board?(card.board) }
        .map do |card|
          created_by = card.board.created_by

          {
            card_id: card.id,
            board_id: card.board.id,
            board_name: card.board.name,
            board_slug: card.board.slug,
            board_column_count: card.board.columns.size,
            board_created_by:
              created_by &&
                { username: created_by.username, avatar_template: created_by.avatar_template },
            column_id: card.column.id,
            column_title: card.column.title,
            column_color: card.column.color,
            column_icon: card.column.icon,
          }
        end
    end

    def self.cards_query(topic_ids)
      DiscourseKanban::Card
        .topic
        .with_column
        .where(topic_id: topic_ids)
        .includes(:column, board: %i[created_by columns])
    end
    private_class_method :cards_query
  end
end
