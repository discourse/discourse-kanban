# frozen_string_literal: true

module DiscourseKanban
  class MoveTopicToColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :topic_id, :integer
      attribute :to_column_id, :integer
      attribute :after_card_id, :integer

      validates :board_id, presence: true
      validates :topic_id, presence: true
      validates :to_column_id, presence: true
    end

    model :board
    policy :can_write
    model :topic
    policy :can_see_topic
    model :column

    transaction do
      step :apply_topic_mutations
      step :upsert_card
    end

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      board.can_write?(guardian)
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_see_topic(topic:, guardian:)
      guardian.can_see?(topic)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.to_column_id)
    end

    def apply_topic_mutations(topic:, column:, guardian:)
      TopicMutator.apply!(topic:, column:, guardian:)
    end

    def upsert_card(board:, topic:, column:, params:, guardian:)
      card = board.cards.find_or_initialize_by(topic_id: topic.id, column_id: column.id)
      is_new = card.new_record?

      card.assign_attributes(
        card_type: :topic,
        membership_mode: :manual_in,
        updated_by_id: guardian.user.id,
      )
      card.created_by_id ||= guardian.user.id

      if is_new
        CardOrdering.append_to_column!(card, column)
      else
        CardOrdering.place_card!(card, column:, after_card_id: params.after_card_id)
      end

      card.save!
      context[:card] = card
      context[:is_new_card] = is_new
    end
  end
end
