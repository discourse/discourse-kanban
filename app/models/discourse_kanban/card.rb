# frozen_string_literal: true

module DiscourseKanban
  class Card < ActiveRecord::Base
    self.table_name = "discourse_kanban_cards"

    belongs_to :board, class_name: "DiscourseKanban::Board", inverse_of: :cards
    belongs_to :column, class_name: "DiscourseKanban::Column", inverse_of: :cards, optional: true
    belongs_to :topic, -> { with_deleted }, optional: true
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true
    belongs_to :assigned_to, polymorphic: true, optional: true

    enum :card_type, { floater: 0, topic: 1 }, default: :floater
    enum :membership_mode, { auto: 0, manual_in: 1, manual_out: 2 }, default: :manual_in

    validates :position, presence: true

    validate :validate_type_integrity
    validate :validate_column_integrity

    before_validation :normalize_card_type

    scope :with_column, -> { where.not(column_id: nil).where.not(membership_mode: :manual_out) }
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

# == Schema Information
#
# Table name: discourse_kanban_cards
#
#  id               :bigint           not null, primary key
#  assigned_to_type :string
#  card_type        :integer          default("floater"), not null
#  due_at           :datetime
#  labels           :text             default([]), not null, is an Array
#  membership_mode  :integer          default("manual_in"), not null
#  notes            :text
#  position         :bigint           default(0), not null
#  title            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  assigned_to_id   :bigint
#  board_id         :bigint           not null
#  column_id        :bigint
#  created_by_id    :bigint
#  topic_id         :bigint
#  updated_by_id    :bigint
#
# Indexes
#
#  idx_kanban_cards_assigned_to              (assigned_to_type,assigned_to_id)
#  idx_kanban_cards_board_column_position    (board_id,column_id,position)
#  idx_kanban_cards_board_id                 (board_id)
#  idx_kanban_cards_column_id                (column_id)
#  idx_kanban_cards_topic_id                 (topic_id)
#  idx_kanban_cards_unique_topic_per_column  (board_id,column_id,topic_id) UNIQUE WHERE ((topic_id IS NOT NULL) AND (column_id IS NOT NULL))
#
# Foreign Keys
#
#  fk_rails_...  (board_id => discourse_kanban_boards.id) ON DELETE => cascade
#  fk_rails_...  (column_id => discourse_kanban_columns.id) ON DELETE => nullify
#  fk_rails_...  (topic_id => topics.id) ON DELETE => cascade
#
