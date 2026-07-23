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
      cards = cards_for(topic)
      readable_board_ids = readable_board_ids(cards, guardian)

      cards
        .select { |card| readable_board_ids.include?(card.board_id) }
        .group_by(&:board_id)
        .values
        .map do |board_cards|
          board = board_cards.first.board
          created_by = board.created_by

          {
            board_id: board.id,
            board_name: board.name,
            board_slug: board.slug,
            board_column_count: board.columns.size,
            board_created_by:
              created_by &&
                { username: created_by.username, avatar_template: created_by.avatar_template },
            cards:
              board_cards
                .sort_by { |card| [card.column.position, card.column.id, card.id] }
                .map do |card|
                  {
                    card_id: card.id,
                    column_id: card.column.id,
                    column_title: card.column.title,
                    column_color: card.column.color,
                    column_icon: card.column.icon,
                  }
                end,
          }
        end
        .sort_by { |membership| [membership[:board_name].downcase, membership[:board_id]] }
    end

    def self.cards_query(topic_ids)
      DiscourseKanban::Card
        .topic
        .with_column
        .where(topic_id: topic_ids)
        .includes(:column, board: %i[created_by columns])
    end

    def self.readable_board_ids(cards, guardian)
      board_ids = cards.map(&:board_id).uniq
      return Set.new if board_ids.empty?

      member_board_ids =
        DiscourseKanban::Board
          .with_any_acl_permissions(guardian, %w[view edit manage])
          .where(id: board_ids)
          .pluck(:id)
      anonymous_board_ids =
        AccessControlList
          .where(
            target_type: DiscourseKanban::Board.polymorphic_name,
            target_id: board_ids,
            permission: "view",
          )
          .allowing_group(Group::AUTO_GROUPS[:anonymous_users])
          .pluck(:target_id)

      (member_board_ids + anonymous_board_ids).to_set
    end
    private_class_method :cards_query, :readable_board_ids
  end
end
