# frozen_string_literal: true

module DiscourseKanban
  class TopicSync
    def self.backfill_board(board)
      return unless SiteSetting.discourse_kanban_enabled?

      existing_topic_ids = board.cards.where(card_type: :topic).pluck(:topic_id).to_set
      candidate_topic_ids = find_candidate_topic_ids(board)
      new_topic_ids = candidate_topic_ids - existing_topic_ids
      return if new_topic_ids.empty?

      board = Board.includes(:columns).find(board.id) unless board.association(:columns).loaded?

      Topic.where(id: new_topic_ids.to_a).find_each { |topic| sync_topic_for_board(topic:, board:) }
    end

    def self.sync_topic(topic)
      return unless SiteSetting.discourse_kanban_enabled?
      return if topic.blank? || topic.deleted_at.present?

      DiscourseKanban::Board
        .includes(:columns)
        .find_each { |board| sync_topic_for_board(topic:, board:) }
    end

    def self.remove_topic(topic_id)
      return unless SiteSetting.discourse_kanban_enabled?

      DiscourseKanban::Card.where(topic_id: topic_id).delete_all
    end

    def self.sync_topic_for_board(topic:, board:)
      existing = board.cards.find_by(topic_id: topic.id)
      return if existing&.manual_in? || existing&.manual_out?

      matching_column = board.first_matching_column(topic)

      if matching_column
        card = existing || build_auto_card(board:, topic:)
        was_new = card.new_record?
        old_column_id = card.column_id
        card.membership_mode = :auto
        card.updated_by_id = Discourse.system_user.id
        CardOrdering.append_to_column!(card, matching_column) if was_new
        card.save!

        if !was_new && old_column_id != matching_column.id
          CardOrdering.place_card!(card, column: matching_column)
        end
      else
        existing&.destroy!
      end
    end

    def self.build_auto_card(board:, topic:)
      board.cards.build(
        card_type: :topic,
        topic_id: topic.id,
        membership_mode: :auto,
        created_by_id: Discourse.system_user.id,
      )
    end

    def self.find_candidate_topic_ids(board)
      if board.base_filter_query.present?
        topic_ids_for_query(board.base_filter_query)
      else
        ids = Set.new
        board.columns.each do |column|
          next if column.filter_query.blank?
          ids.merge(topic_ids_for_query(column.combined_query))
        end
        ids
      end
    end

    def self.topic_ids_for_query(query)
      scope =
        TopicQuery.new(Discourse.system_user, limit: false, no_definitions: true).latest_results
      TopicsFilter
        .new(guardian: Guardian.new(Discourse.system_user), scope: scope)
        .filter_from_query_string(query)
        .pluck(:id)
        .to_set
    rescue StandardError
      Set.new
    end
  end
end
