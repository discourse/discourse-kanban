# frozen_string_literal: true

module DiscourseKanban
  class CheckBoardTopicConstraintMismatches
    include Service::Base

    params do
      attribute :id, :integer
      attribute :topic_id, :integer
      attribute :target_column_id, :integer

      validates :id, presence: true
      validates :topic_id, presence: true
      validates :target_column_id, presence: true
    end

    model :board
    policy :can_edit_board
    model :topic
    policy :can_view_topic
    model :target_column
    model :categories_needed, optional: true
    model :tags_needed, optional: true

    private

    def fetch_board(params:)
      Board.find_by(id: params.id)
    end

    def can_edit_board(board:, guardian:)
      guardian.can_write_board?(board)
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_view_topic(topic:, guardian:)
      guardian.can_see?(topic)
    end

    def fetch_target_column(params:, board:)
      board.columns.find_by(id: params.target_column_id)
    end

    # If the column's category (or the topic's current category) is outside the board's
    # categories, return the board categories so the user can choose a replacement.
    def fetch_categories_needed(topic:, target_column:, board:)
      return [] if board.category_ids.empty?

      effective_category_id = target_column.move_to_category_id || topic.category_id
      return [] if board.category_ids.include?(effective_category_id)

      board.category_ids
    end

    # If none of the effective tags belong to the board, return its tags so the user can
    # choose a replacement.
    def fetch_tags_needed(topic:, target_column:, board:)
      return [] if board.tag_ids.empty?

      board_tag_names = board.tags.map(&:name)
      effective_tag_names = topic.tags.map(&:name)

      # A topic should only have the tag for its new column. Remove tags from the other
      # columns, including every column tag when the target column is untagged.
      sibling_tag_names =
        board.columns.filter_map { |column| column.tag&.name if column.id != target_column.id }
      effective_tag_names -= sibling_tag_names

      if target_column.tag.present?
        target_tag_name = target_column.tag.name
        effective_tag_names << target_tag_name if effective_tag_names.exclude?(target_tag_name)
      end

      return [] if board_tag_names.any? { |tag_name| effective_tag_names.include?(tag_name) }

      board_tag_names
    end
  end
end
