# frozen_string_literal: true

module DiscourseKanban
  class UpdateCard
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer
      attribute :topic_id, :integer
      attribute :column_id, :integer
      attribute :title, :string
      attribute :notes
      attribute :after_card_id, :integer
      attribute :assigned_to_name, :string
      attribute :labels, :array

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
      board.can_write?(guardian)
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

    def resolve_promotion(card:, column:, params:, guardian:)
      return unless card.floater? && params.topic_id.present?

      topic = Topic.find_by(id: params.topic_id)
      raise Discourse::NotFound if topic.nil?
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)
      if Category.exists?(topic_id: topic.id)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.category_definition_topic"),
              )
      end

      existing =
        context[:board].cards.find_by(topic_id: topic.id, column_id: column.id) ||
          context[:board].cards.find_by(
            topic_id: topic.id,
            membership_mode: :manual_out,
            column_id: nil,
          )
      if existing
        context[:card] = adopt_existing_topic_card!(card, existing, column, params, guardian)
        context[:promoted] = true
        return
      end

      card.topic_id = topic.id
      card.title = nil
      card.notes = nil
      card.labels = []
      card.assigned_to_id = nil
      card.assigned_to_type = nil
      card.membership_mode = :manual_in
      card.updated_by_id = guardian.user.id
      TopicMutator.apply!(topic:, column:, guardian:)
      context[:promoted] = true
    end

    def update_attributes(card:, params:, guardian:)
      raw = context[:raw_card_params] || {}
      if card.floater? && !context[:promoted]
        card.title = params.title || card.title
        card.notes = raw.key?("notes") ? raw["notes"] : card.notes
        card.labels = params.labels || card.labels
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

      user = User.find_by_username(name)
      return user if user&.active

      group = Group.find_by(name: name)
      return group if group && guardian.can_see_group?(group)

      raise Discourse::InvalidParameters.new(
              I18n.t("discourse_kanban.errors.invalid_assignee", name: name),
            )
    end

    def place_and_save(card:, column:, params:, guardian:)
      raw = context[:raw_card_params] || {}
      position_first = raw.key?("after_card_id") && raw["after_card_id"].blank?

      Card.transaction do
        column_changed =
          !context[:promoted] && card.topic? && column.id != card.column_id && card.topic.present?

        if card.topic_id.present?
          card
            .board
            .cards
            .where(topic_id: card.topic_id, column_id: column.id, membership_mode: :manual_out)
            .where.not(id: card.id)
            .delete_all
        end

        CardOrdering.place_card!(
          card,
          column:,
          after_card_id: params.after_card_id,
          position_first:,
        )

        TopicMutator.apply!(topic: card.topic, column:, guardian:) if column_changed

        card.save!
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      raise unless unique_topic_card_violation?(error)

      if context[:promoted] && params.topic_id.present?
        board = context[:board]
        existing =
          board
            .cards
            .where(topic_id: params.topic_id, column_id: column.id)
            .where.not(id: card.id)
            .first!
        context[:card] = adopt_existing_topic_card!(card, existing, column, params, guardian)
      else
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.topic_already_in_column"),
              )
      end
    end

    def adopt_existing_topic_card!(floater, existing, column, params, guardian)
      floater.reload if floater.changed?
      floater_id = floater.id

      raw = context[:raw_card_params] || {}
      position_first = raw.key?("after_card_id") && raw["after_card_id"].blank?

      Card.transaction do
        existing = existing.lock!
        context[:original_column_id] = existing.column_id
        existing.membership_mode = :manual_in
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

    def topic_card_constraint_name(error)
      return unless defined?(PG::Result)
      return unless error.respond_to?(:result)

      error.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end
end
