# frozen_string_literal: true

module DiscourseKanban
  class Column < ActiveRecord::Base
    self.table_name = "discourse_kanban_columns"
    self.ignored_columns = %w[wip_limit filter_query move_to_tag]

    belongs_to :board, class_name: "DiscourseKanban::Board", inverse_of: :columns
    has_many :cards, class_name: "DiscourseKanban::Card", dependent: :nullify, inverse_of: :column

    validates :title, presence: true
    validates :position, presence: true

    def matches_topic?(topic)
      tag_id.present? && topic.tag_ids.include?(tag_id)
    end
  end
end

# == Schema Information
#
# Table name: discourse_kanban_columns
#
#  id                  :bigint           not null, primary key
#  icon                :string
#  move_to_assigned    :string
#  move_to_status      :string
#  position            :integer          default(0), not null
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  board_id            :bigint           not null
#  move_to_category_id :bigint
#  tag_id              :integer
#
# Indexes
#
#  idx_kanban_columns_board_id        (board_id)
#  idx_kanban_columns_board_position  (board_id,position)
#  idx_kanban_columns_tag_id          (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (board_id => discourse_kanban_boards.id) ON DELETE => cascade
#  fk_rails_...  (move_to_category_id => categories.id) ON DELETE => nullify
#
