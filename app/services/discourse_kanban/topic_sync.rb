# frozen_string_literal: true

module DiscourseKanban
  class TopicSync
    MAX_TOPICS_PER_COLUMN = 400

    def self.backfill_board(board)
      return unless SiteSetting.discourse_kanban_enabled?

      board = Board.includes(:columns).find(board.id) unless board.association(:columns).loaded?
      columns = board.columns.to_a

      # 1. One TopicsFilter query per column → { column_id => Set<topic_id> }
      column_topic_ids = build_column_topic_map(board, columns)

      # 2. Assign each topic to its FIRST matching column (column priority by position)
      has_base = board.base_filter_query.present?
      lowest_blank_column_id =
        columns.select { |col| col.filter_query.blank? }.map(&:id).min if has_base

      topic_to_column = {}
      columns.each do |col|
        ids = column_topic_ids[col.id] || next
        target_id = (has_base && col.filter_query.blank?) ? lowest_blank_column_id : col.id
        ids.each { |tid| topic_to_column[tid] ||= target_id }
      end

      # 3. Load all existing topic cards for this board in one query
      existing_cards =
        board
          .cards
          .where(card_type: :topic)
          .where.not(topic_id: nil)
          .pluck(:id, :topic_id, :column_id, :membership_mode)
      existing_by_topic = {}
      existing_cards.each do |card_id, topic_id, column_id, membership_mode|
        existing_by_topic[topic_id] = { id: card_id, column_id:, membership_mode: }
      end

      # 4. Diff: compute creates, moves, deletes
      to_create = []
      to_move = []
      to_delete = []

      topic_to_column.each do |topic_id, target_column_id|
        existing = existing_by_topic[topic_id]
        if existing.nil?
          to_create << { topic_id:, column_id: target_column_id }
        elsif auto_membership?(existing[:membership_mode]) &&
              existing[:column_id] != target_column_id
          to_move << { card_id: existing[:id], column_id: target_column_id }
        end
      end

      existing_by_topic.each do |topic_id, card_info|
        next unless auto_membership?(card_info[:membership_mode])
        next if topic_to_column.key?(topic_id)
        to_delete << card_info[:id]
      end

      # 5. Apply changes in bulk
      apply_bulk_changes(board, to_create:, to_move:, to_delete:)
    end

    def self.sync_topic(topic)
      return unless SiteSetting.discourse_kanban_enabled?
      return if topic.blank? || topic.deleted_at.present?

      with_topic_sync_retry do
        DistributedMutex.synchronize("discourse_kanban_topic_sync_#{topic.id}") do
          Card.transaction do
            lock_topic_cards(topic.id)
            plan = build_sync_plan(topic:)
            apply_sync_plan(topic:, plan:)
          end
        end
      end
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

    def self.build_sync_plan(topic:)
      boards = Board.pluck(:id, :base_filter_query)
      columns_by_board =
        Column
          .order(:board_id, :position, :id)
          .pluck(:id, :board_id, :filter_query)
          .group_by { |(_, board_id, _)| board_id }
      existing_cards_by_board =
        Card
          .where(topic_id: topic.id)
          .pluck(:id, :board_id, :column_id, :membership_mode, :card_type)
          .each_with_object(
            {},
          ) do |(card_id, board_id, column_id, membership_mode, card_type), memo|
            memo[board_id] = {
              id: card_id,
              column_id: column_id,
              membership_mode: membership_mode,
              card_type: card_type,
            }
          end

      matcher_context = build_query_matcher_context

      remove_card_ids = []
      create_targets = []
      move_targets = []

      boards.each do |board_id, base_filter_query|
        existing_card = existing_cards_by_board[board_id]
        if existing_card.present? && !topic_card_type?(existing_card[:card_type])
          Rails.logger.warn(
            "DiscourseKanban::TopicSync skipping board #{board_id} for topic #{topic.id}: existing " \
              "card #{existing_card[:id]} has unexpected card_type=#{existing_card[:card_type].inspect}",
          )
          next
        end

        next if manual_membership_mode?(existing_card&.dig(:membership_mode))

        matching_column_id =
          first_matching_column_id(
            topic:,
            board_id:,
            base_filter_query:,
            columns_by_board:,
            matcher_context:,
          )

        if matching_column_id.present?
          if existing_card.blank?
            create_targets << { board_id:, column_id: matching_column_id }
          elsif existing_card[:column_id] != matching_column_id
            move_targets << { card_id: existing_card[:id], column_id: matching_column_id }
          end
        elsif existing_card.present?
          remove_card_ids << existing_card[:id]
        end
      end

      { remove_card_ids:, create_targets:, move_targets: }
    end

    def self.build_query_matcher_context
      {
        scope:
          TopicQuery.new(Discourse.system_user, limit: false, no_definitions: true).latest_results,
        guardian: Guardian.new(Discourse.system_user),
        cache: {
        },
      }
    end

    def self.first_matching_column_id(
      topic:,
      board_id:,
      base_filter_query:,
      columns_by_board:,
      matcher_context:
    )
      board_columns = columns_by_board[board_id]
      return nil if board_columns.blank?

      if base_filter_query.present?
        return nil unless query_matches_topic?(topic:, query: base_filter_query, matcher_context:)

        lowest_blank_column_id =
          board_columns.select { |_, _, fq| fq.blank? }.map { |col_id, _, _| col_id }.min

        board_columns.each do |column_id, _, filter_query|
          return lowest_blank_column_id if filter_query.blank?

          combined_query = [base_filter_query, filter_query].reject(&:blank?).join(" ")
          return column_id if query_matches_topic?(topic:, query: combined_query, matcher_context:)
        end

        return nil
      end

      board_columns.each do |column_id, _, filter_query|
        next if filter_query.blank?

        return column_id if query_matches_topic?(topic:, query: filter_query, matcher_context:)
      end

      nil
    end

    def self.query_matches_topic?(topic:, query:, matcher_context:)
      Board.topic_matches_query?(topic, query, matcher_context:)
    end

    def self.apply_sync_plan(topic:, plan:)
      remove_auto_cards(card_ids: plan[:remove_card_ids])
      create_auto_cards(topic:, targets: plan[:create_targets])
      move_auto_cards(targets: plan[:move_targets])
    end

    def self.remove_auto_cards(card_ids:)
      return if card_ids.blank?

      Card.where(id: card_ids, membership_mode: :auto).delete_all
    end

    def self.create_auto_cards(topic:, targets:)
      return if targets.blank?

      board_ids = targets.map { |target| target[:board_id] }.uniq
      column_ids = targets.map { |target| target[:column_id] }.uniq

      boards_by_id = Board.where(id: board_ids).index_by(&:id)
      columns_by_id = Column.where(id: column_ids).index_by(&:id)

      targets.each do |target|
        board = boards_by_id[target[:board_id]]
        column = columns_by_id[target[:column_id]]
        next if board.blank? || column.blank?
        next if column.board_id != board.id

        card = build_auto_card(board:, topic:)
        card.updated_by_id = Discourse.system_user.id
        CardOrdering.append_to_column!(card, column)
        card.save!
      end
    end

    def self.move_auto_cards(targets:)
      return if targets.blank?

      card_ids = targets.map { |target| target[:card_id] }.uniq
      column_ids = targets.map { |target| target[:column_id] }.uniq

      cards_by_id = Card.where(id: card_ids, membership_mode: :auto).index_by(&:id)
      columns_by_id = Column.where(id: column_ids).index_by(&:id)

      targets.each do |target|
        card = cards_by_id[target[:card_id]]
        column = columns_by_id[target[:column_id]]
        next if card.blank? || column.blank?
        next if card.column_id == column.id
        next if card.board_id != column.board_id

        card.updated_by_id = Discourse.system_user.id
        CardOrdering.place_card!(card, column:)
      end
    end

    def self.manual_membership_mode?(membership_mode)
      membership_mode == Card.membership_modes[:manual_in] ||
        membership_mode == Card.membership_modes[:manual_out]
    end

    def self.topic_card_type?(card_type)
      card_type == Card.card_types[:topic] || card_type.to_s == "topic"
    end

    def self.lock_topic_cards(topic_id)
      Card.where(topic_id:).lock("FOR UPDATE").pluck(:id)
    end

    def self.with_topic_sync_retry
      retries = 0

      begin
        yield
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
        raise unless unique_topic_card_violation?(error) && retries < 1

        retries += 1
        retry
      end
    end

    def self.unique_topic_card_violation?(error)
      [error, error.cause, error.cause&.cause].compact.any? do |candidate|
        candidate.message.include?("idx_kanban_cards_unique_topic_per_board") ||
          topic_card_constraint_name(candidate) == "idx_kanban_cards_unique_topic_per_board"
      end
    end

    def self.topic_card_constraint_name(error)
      return unless defined?(PG::Result)
      return unless error.respond_to?(:result)

      error.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end

    def self.build_column_topic_map(board, columns)
      result = {}
      scope_base =
        TopicQuery.new(Discourse.system_user, limit: false, no_definitions: true).latest_results
      guardian = Guardian.new(Discourse.system_user)
      has_base = board.base_filter_query.present?

      if has_base
        base_ids = filtered_topic_ids(guardian:, scope: scope_base, query: board.base_filter_query)
      end

      columns.each do |col|
        query = col.filter_query

        if has_base
          if query.present?
            combined = "#{board.base_filter_query} #{query}"
            ids = filtered_topic_ids(guardian:, scope: scope_base, query: combined)
          else
            ids = base_ids
          end
        else
          next if query.blank?
          ids = filtered_topic_ids(guardian:, scope: scope_base, query:)
        end

        result[col.id] = ids
      rescue StandardError
        next
      end

      result
    end

    private_class_method def self.filtered_topic_ids(guardian:, scope:, query:)
      TopicsFilter
        .new(guardian:, scope:)
        .filter_from_query_string(query)
        .limit(MAX_TOPICS_PER_COLUMN)
        .pluck(:id)
        .to_set
    end

    def self.apply_bulk_changes(board, to_create:, to_move:, to_delete:)
      return if to_create.empty? && to_move.empty? && to_delete.empty?

      Card.transaction do
        Card.where(id: to_delete, membership_mode: :auto).delete_all if to_delete.any?

        if to_create.any?
          max_positions =
            board.cards.with_column.group(:column_id).maximum(:position).transform_values(&:to_i)

          system_user_id = Discourse.system_user.id
          now = Time.current

          to_create.each do |entry|
            col_id = entry[:column_id]
            max_positions[col_id] = (max_positions[col_id] || -CardOrdering::GAP_SIZE) +
              CardOrdering::GAP_SIZE
            pos = max_positions[col_id]

            Card.insert!(
              {
                board_id: board.id,
                column_id: col_id,
                topic_id: entry[:topic_id],
                card_type: Card.card_types[:topic],
                membership_mode: Card.membership_modes[:auto],
                position: pos,
                created_by_id: system_user_id,
                updated_by_id: system_user_id,
                created_at: now,
                updated_at: now,
              },
            )
          end
        end

        if to_move.any?
          to_move
            .group_by { |e| e[:column_id] }
            .each do |col_id, entries|
              max_pos = board.cards.with_column.where(column_id: col_id).maximum(:position).to_i
              entries.each_with_index do |entry, i|
                Card.where(id: entry[:card_id]).update_all(
                  column_id: col_id,
                  position: max_pos + (i + 1) * CardOrdering::GAP_SIZE,
                )
              end
            end
        end
      end
    end

    def self.auto_membership?(mode)
      mode == Card.membership_modes[:auto] || mode == "auto"
    end
  end
end
