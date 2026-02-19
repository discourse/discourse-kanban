# frozen_string_literal: true

module DiscourseKanban
  class Card < ActiveRecord::Base
    self.table_name = "discourse_kanban_cards"

    belongs_to :board, class_name: "DiscourseKanban::Board", inverse_of: :cards
    belongs_to :column, class_name: "DiscourseKanban::Column", inverse_of: :cards, optional: true
    belongs_to :topic, optional: true
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true

    enum :card_type, { floater: 0, topic: 1 }, default: :floater
    enum :membership_mode, { auto: 0, manual_in: 1, manual_out: 2 }, default: :manual_in

    validates :position, presence: true

    validate :validate_type_integrity
    validate :validate_column_integrity

    before_validation :normalize_card_type

    scope :with_column, -> { where.not(column_id: nil) }
    scope :ordered, -> { order(:position, :id) }

    private

    def normalize_card_type
      return if topic_id.blank?

      self.card_type = :topic
    end

    def validate_type_integrity
      if topic?
        errors.add(:topic_id, :blank) if topic_id.blank?
      else
        errors.add(:title, :blank) if title.blank?
        errors.add(:topic_id, :present) if topic_id.present?
      end
    end

    def validate_column_integrity
      return if topic? && manual_out?
      return if column_id.present?

      errors.add(:column_id, :blank)
    end
  end
end
