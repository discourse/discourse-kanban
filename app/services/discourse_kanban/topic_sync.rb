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

      # 2. Assign each topic to ALL matching columns
      has_base = board.base_filter_query.present?
      lowest_blank_column_id =
        columns.select { |col| col.filter_query.blank? }.map(&:id).min if has_base

      topic_to_columns = Hash.new { |h, k| h[k] = Set.new }
      columns.each do |col|
        ids = column_topic_ids[col.id] || next
        target_id = (has_base && col.filter_query.blank?) ? lowest_blank_column_id : col.id
        ids.each { |tid| topic_to_columns[tid] << target_id }
      end

      # 3. Load all existing topic cards for this board in one query
      existing_cards =
        board
          .cards
          .where(card_type: :topic)
          .where.not(topic_id: nil)
          .pluck(:id, :topic_id, :column_id, :membership_mode)
      existing_by_topic_column = {}
      manual_out_topic_ids = Set.new
      manual_in_by_topic = Hash.new { |h, k| h[k] = Set.new }
      existing_cards.each do |card_id, topic_id, column_id, membership_mode|
        existing_by_topic_column[[topic_id, column_id]] = { id: card_id, membership_mode: }
        if manual_out_mode?(membership_mode) && column_id.nil?
          manual_out_topic_ids << topic_id
        elsif manual_in_mode?(membership_mode)
          manual_in_by_topic[topic_id] << column_id
        end
      end

      # 4. Diff: compute creates and deletes (no moves — each column independently has or doesn't have a card)
      to_create = []
      to_delete = []

      topic_to_columns.each do |topic_id, target_column_ids|
        next if manual_out_topic_ids.include?(topic_id)
        target_column_ids.each do |target_column_id|
          next if manual_in_by_topic[topic_id].include?(target_column_id)
          existing = existing_by_topic_column[[topic_id, target_column_id]]
          to_create << { topic_id:, column_id: target_column_id } if existing.nil?
        end
      end

      existing_cards.each do |card_id, topic_id, column_id, membership_mode|
        next unless auto_membership?(membership_mode)
        next if topic_to_columns[topic_id]&.include?(column_id)
        to_delete << card_id
      end

      # 5. Apply changes in bulk
      apply_bulk_changes(board, to_create:, to_delete:)
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
      existing_cards = board.cards.where(topic_id: topic.id).to_a
      return if existing_cards.any? { |c| c.manual_out? && c.column_id.nil? }

      manual_in_column_ids = existing_cards.select(&:manual_in?).map(&:column_id).to_set

      matching_columns = board.all_matching_columns(topic)
      matching_column_ids = matching_columns.map(&:id).to_set
      existing_column_ids = existing_cards.map(&:column_id).to_set

      matching_columns.each do |col|
        next if existing_column_ids.include?(col.id)
        next if manual_in_column_ids.include?(col.id)

        card = build_auto_card(board:, topic:)
        card.updated_by_id = Discourse.system_user.id
        CardOrdering.append_to_column!(card, col)
        card.save!
      end

      existing_cards.each do |card|
        next unless card.auto?
        next if matching_column_ids.include?(card.column_id)
        card.destroy!
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
          .group_by { |(_, board_id, _, _, _)| board_id }
          .transform_values do |rows|
            rows.map do |card_id, _, column_id, membership_mode, card_type|
              { id: card_id, column_id:, membership_mode:, card_type: }
            end
          end

      matcher_context = build_query_matcher_context

      remove_card_ids = []
      create_targets = []

      boards.each do |board_id, base_filter_query|
        existing_cards = existing_cards_by_board[board_id] || []

        non_topic = existing_cards.find { |c| !topic_card_type?(c[:card_type]) }
        if non_topic
          Rails.logger.warn(
            "DiscourseKanban::TopicSync skipping board #{board_id} for topic #{topic.id}: existing " \
              "card #{non_topic[:id]} has unexpected card_type=#{non_topic[:card_type].inspect}",
          )
          next
        end

        if existing_cards.any? { |c| manual_out_mode?(c[:membership_mode]) && c[:column_id].nil? }
          next
        end

        manual_in_column_ids =
          existing_cards
            .select { |c| manual_in_mode?(c[:membership_mode]) }
            .map { |c| c[:column_id] }
            .to_set

        matching_column_ids =
          all_matching_column_ids(
            topic:,
            board_id:,
            base_filter_query:,
            columns_by_board:,
            matcher_context:,
          )

        existing_column_ids = existing_cards.map { |c| c[:column_id] }.to_set
        matching_set = matching_column_ids.to_set

        matching_column_ids.each do |col_id|
          next if manual_in_column_ids.include?(col_id)
          create_targets << { board_id:, column_id: col_id } if existing_column_ids.exclude?(col_id)
        end

        existing_cards.each do |c|
          next unless auto_membership?(c[:membership_mode])
          remove_card_ids << c[:id] if matching_set.exclude?(c[:column_id])
        end
      end

      { remove_card_ids:, create_targets: }
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

    def self.all_matching_column_ids(
      topic:,
      board_id:,
      base_filter_query:,
      columns_by_board:,
      matcher_context:
    )
      board_columns = columns_by_board[board_id]
      return [] if board_columns.blank?

      if base_filter_query.present?
        return [] unless query_matches_topic?(topic:, query: base_filter_query, matcher_context:)

        lowest_blank_column_id =
          board_columns.select { |_, _, fq| fq.blank? }.map { |col_id, _, _| col_id }.min

        result = []
        board_columns.each do |column_id, _, filter_query|
          if filter_query.blank?
            result << lowest_blank_column_id if result.exclude?(lowest_blank_column_id)
          else
            combined_query = [base_filter_query, filter_query].reject(&:blank?).join(" ")
            if query_matches_topic?(topic:, query: combined_query, matcher_context:)
              result << column_id
            end
          end
        end

        return result
      end

      result = []
      board_columns.each do |column_id, _, filter_query|
        next if filter_query.blank?

        result << column_id if query_matches_topic?(topic:, query: filter_query, matcher_context:)
      end

      result
    end

    def self.query_matches_topic?(topic:, query:, matcher_context:)
      Board.topic_matches_query?(topic, query, matcher_context:)
    end

    def self.apply_sync_plan(topic:, plan:)
      remove_auto_cards(card_ids: plan[:remove_card_ids])
      create_auto_cards(topic:, targets: plan[:create_targets])
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

    def self.manual_membership_mode?(membership_mode)
      membership_mode == Card.membership_modes[:manual_in] ||
        membership_mode == Card.membership_modes[:manual_out]
    end

    def self.manual_out_mode?(membership_mode)
      membership_mode == Card.membership_modes[:manual_out] || membership_mode.to_s == "manual_out"
    end

    def self.manual_in_mode?(membership_mode)
      membership_mode == Card.membership_modes[:manual_in] || membership_mode.to_s == "manual_in"
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
        candidate.message.include?("idx_kanban_cards_unique_topic_per_column") ||
          topic_card_constraint_name(candidate) == "idx_kanban_cards_unique_topic_per_column"
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

    def self.apply_bulk_changes(board, to_create:, to_delete:)
      return if to_create.empty? && to_delete.empty?

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
      end
    end

    def self.auto_membership?(mode)
      mode == Card.membership_modes[:auto] || mode == "auto"
    end
  end
end
