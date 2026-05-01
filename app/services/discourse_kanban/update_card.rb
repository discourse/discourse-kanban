# frozen_string_literal: true

module DiscourseKanban
  class UpdateCard
    include Service::Base

    options do
      attribute :raw_card_params, default: {}
      attribute :constraint_fix
    end

    params do
      attribute :board_id, :integer
      attribute :id, :integer
      attribute :topic_id, :integer
      attribute :column_id, :integer
      attribute :title, :string
      attribute :notes
      attribute :after_card_id, :integer
      attribute :assigned_to_name, :string
      attribute :tag_ids, :array
      attribute :tag_names, :array

      validates :board_id, presence: true
      validates :id, presence: true
    end

    model :board
    policy :can_write
    model :card
    model :column
    step :capture_original_state

    step :resolve_promotion
    step :update_attributes
    step :place_and_save

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      guardian.can_write_board?(board)
    end

    def fetch_card(board:, params:)
      board.cards.find_by(id: params.id)
    end

    def capture_original_state(card:)
      context[:original_column_id] = card.column_id
      context[:adopted_floater_id] = nil
    end

    def fetch_column(board:, card:, params:)
      if params.column_id.present?
        board.columns.find_by(id: params.column_id)
      else
        card.column
      end
    end

    def resolve_promotion(card:, column:, params:, guardian:, options:, board:)
      return unless card.floater? && params.topic_id.present?

      topic = Topic.find_by(id: params.topic_id)
      raise Discourse::NotFound if topic.nil?
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)
      if Category.exists?(topic_id: topic.id)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.category_definition_topic"),
              )
      end

      constraint_fix = options.constraint_fix.presence || context[:constraint_fix]

      if constraint_fix.present?
        ConstraintFixer.apply!(fix: constraint_fix, board:, topic:, guardian:)
      end

      unless board.topic_will_match_after_mutation?(topic, column)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.topic_does_not_match_constraints"),
              )
      end

      card_assignee = card.assigned_to
      validate_assignment_carry_over!(card_assignee, column, guardian)

      existing = board.cards.find_by(topic_id: topic.id, column_id: column.id)
      if existing
        context[:card] = adopt_existing_topic_card!(
          card,
          existing,
          column,
          params,
          guardian,
          options:,
        )
        context[:promoted] = true
        assign_card_assignee_to_topic(card_assignee, topic, column, guardian)
        return
      end

      card.topic_id = topic.id
      card.title = nil
      card.notes = nil
      card.tag_ids = []
      card.assigned_to_id = nil
      card.assigned_to_type = nil
      card.updated_by_id = guardian.user.id
      TopicMutator.apply!(topic:, column:, guardian:)
      assign_card_assignee_to_topic(card_assignee, topic, column, guardian)
      context[:promoted] = true
    end

    def update_attributes(card:, params:, guardian:, options:)
      raw = options.raw_card_params.presence || context[:raw_card_params] || {}
      if card.floater? && !context[:promoted]
        card.title = params.title || card.title
        card.notes = raw.key?("notes") ? raw["notes"] : card.notes
        if raw.key?("tag_ids") || raw.key?("tag_names")
          card.tag_ids = resolve_all_tag_ids(params.tag_ids, params.tag_names, guardian)
        end
        card.assigned_to = resolve_assignee(raw["assigned_to_name"], guardian) if raw.key?(
          "assigned_to_name",
        )
        card.updated_by_id = guardian.user.id
      elsif !context[:promoted]
        card.updated_by_id = guardian.user.id
      end
    end

    def resolve_assignee(name, guardian)
      return nil if name.blank?

      unless guardian.can_assign?
        raise Discourse::InvalidAccess.new(I18n.t("discourse_kanban.errors.cannot_assign"))
      end

      user = User.find_by_username(name)
      return user if user&.active

      group = Group.find_by(name: name)
      return group if group && guardian.can_see_group?(group)

      raise Discourse::InvalidParameters.new(
              I18n.t("discourse_kanban.errors.invalid_assignee", name: name),
            )
    end

    def place_and_save(card:, column:, params:, guardian:, options:, board:, original_column_id:)
      raw = options.raw_card_params.presence || context[:raw_card_params] || {}
      tags_changed = raw.key?("tag_ids") || raw.key?("tag_names")
      position_first = raw.key?("after_card_id") && raw["after_card_id"].blank?
      needs_placement =
        context[:promoted] || column.id != card.column_id || raw.key?("after_card_id")

      Card.transaction do
        column_changed =
          !context[:promoted] && card.topic? && column.id != card.column_id && card.topic.present?

        if column_changed
          constraint_fix = options.constraint_fix.presence || context[:constraint_fix]

          if constraint_fix.present?
            ConstraintFixer.apply!(fix: constraint_fix, board:, topic: card.topic, guardian:)
          end

          unless board.topic_will_match_after_mutation?(card.topic, column)
            raise Discourse::InvalidParameters.new(
                    I18n.t("discourse_kanban.errors.topic_does_not_match_constraints"),
                  )
          end
        end

        if needs_placement
          CardOrdering.place_card!(
            card,
            column:,
            after_card_id: params.after_card_id,
            position_first:,
          )
        end

        if card.floater? && (column.id != original_column_id || tags_changed)
          LooseCardTagMutator.apply_to_card!(card:, column:)
        end
        TopicMutator.apply!(topic: card.topic, column:, guardian:) if column_changed

        card.save!
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      raise unless unique_topic_card_violation?(error)

      if context[:promoted] && params.topic_id.present?
        existing =
          board
            .cards
            .where(topic_id: params.topic_id, column_id: column.id)
            .where.not(id: card.id)
            .first!
        context[:card] = adopt_existing_topic_card!(
          card,
          existing,
          column,
          params,
          guardian,
          options:,
        )
      else
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.topic_already_in_column"),
              )
      end
    end

    def adopt_existing_topic_card!(floater, existing, column, params, guardian, options:)
      floater.reload if floater.changed?
      floater_id = floater.id

      raw = options.raw_card_params.presence || context[:raw_card_params] || {}
      position_first = raw.key?("after_card_id") && raw["after_card_id"].blank?

      Card.transaction do
        existing = existing.lock!
        context[:original_column_id] = existing.column_id
        existing.updated_by_id = guardian.user.id
        topic = existing.topic || Topic.find_by(id: params.topic_id)
        raise Discourse::NotFound if topic.nil?
        TopicMutator.apply!(topic:, column:, guardian:)
        CardOrdering.place_card!(
          existing,
          column:,
          after_card_id: params.after_card_id,
          position_first:,
        )
        existing.save!
        floater.destroy!
      end

      context[:adopted_floater_id] = floater_id
      existing
    end

    def unique_topic_card_violation?(error)
      [error, error.cause, error.cause&.cause].compact.any? do |candidate|
        candidate.message.include?("idx_kanban_cards_unique_topic_per_column") ||
          topic_card_constraint_name(candidate) == "idx_kanban_cards_unique_topic_per_column"
      end
    end

    def validate_assignment_carry_over!(assignee, column, guardian)
      return if assignee.blank?
      return unless defined?(::Assigner)
      return if column.move_to_assigned.present? && column.move_to_assigned != "*"

      unless guardian.can_assign?
        raise Discourse::InvalidAccess.new(I18n.t("discourse_kanban.errors.cannot_assign"))
      end
    end

    def assign_card_assignee_to_topic(assignee, topic, column, guardian)
      return if assignee.blank?
      return unless defined?(::Assigner)
      return if column.move_to_assigned.present? && column.move_to_assigned != "*"

      result = ::Assigner.new(topic, guardian.user).assign(assignee, skip_small_action_post: true)

      unless result[:success]
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.assignment_carry_over_failed"),
              )
      end
    end

    def resolve_all_tag_ids(tag_ids, tag_names, guardian)
      ids = Card.normalize_tag_ids!(tag_ids)
      names = Array(tag_names).compact_blank
      if names.present?
        tags = DiscourseTagging.find_or_create_tags!(names, guardian)
        ids = (ids + tags.map(&:id)).uniq
      end
      ids
    end

    def topic_card_constraint_name(error)
      return unless defined?(PG::Result)
      return unless error.respond_to?(:result)

      error.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end
end
