# frozen_string_literal: true

module DiscourseKanban
  class CreateCard
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :column_id, :integer
      attribute :topic_id, :integer
      attribute :title, :string
      attribute :notes, :string
      attribute :due_at
      attribute :after_card_id, :integer
      attribute :labels, :array

      validates :board_id, presence: true
      validates :column_id, presence: true
    end

    model :board
    policy :can_write
    model :column

    step :create_card

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      board.can_write?(guardian)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.column_id)
    end

    def create_card(board:, column:, params:, guardian:)
      card =
        if params.topic_id.present?
          build_topic_card(board, column, params, guardian)
        else
          build_floater_card(board, column, params, guardian)
        end
      context[:card] = card
    end

    def build_topic_card(board, column, params, guardian)
      topic = Topic.find_by(id: params.topic_id)
      raise Discourse::NotFound if topic.nil?
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)
      if Category.exists?(topic_id: topic.id)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_kanban.errors.category_definition_topic"),
              )
      end

      card = board.cards.find_or_initialize_by(topic_id: topic.id)
      card.card_type = :topic
      card.membership_mode = :manual_in
      card.updated_by_id = guardian.user.id
      card.created_by_id ||= guardian.user.id

      if card.new_record?
        CardOrdering.append_to_column!(card, column)
      else
        CardOrdering.place_card!(card, column:, after_card_id: params.after_card_id)
      end

      card.save!
      card
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      unless unique_topic_card_violation?(error) || board.cards.where(topic_id: topic.id).exists?
        raise
      end

      card = board.cards.find_by!(topic_id: topic.id)
      card.membership_mode = :manual_in
      card.updated_by_id = guardian.user.id
      card.created_by_id ||= guardian.user.id
      CardOrdering.place_card!(card, column:, after_card_id: params.after_card_id)
      card.save!
      card
    end

    def build_floater_card(board, column, params, guardian)
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: params.title,
          notes: params.notes,
          labels: params.labels || [],
          due_at: params.due_at,
          created_by_id: guardian.user.id,
          updated_by_id: guardian.user.id,
        )

      CardOrdering.append_to_column!(card, column)
      card.save!
      card
    end

    def unique_topic_card_violation?(error)
      [error, error.cause, error.cause&.cause].compact.any? do |candidate|
        candidate.message.include?("idx_kanban_cards_unique_topic_per_board") ||
          topic_card_constraint_name(candidate) == "idx_kanban_cards_unique_topic_per_board"
      end
    end

    def topic_card_constraint_name(error)
      return unless defined?(PG::Result)
      return unless error.respond_to?(:result)

      error.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end
end
