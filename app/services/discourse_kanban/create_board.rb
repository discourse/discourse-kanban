# frozen_string_literal: true

module DiscourseKanban
  class CreateBoard
    include Service::Base

    params do
      attribute :name, :string

      validates :name, presence: true
    end

    policy :can_manage

    transaction do
      model :board, :create_board
      step :replace_columns
    end

    private

    def can_manage(guardian:)
      guardian.can_create_board?
    end

    def create_board(guardian:)
      raw = context[:raw_board_params] || {}
      ensure_new_tags_exist!(raw["tag_names"], guardian) if raw.key?("tag_names")
      board = Board.new(raw.except("columns"))
      board.created_by_id = guardian.user.id
      board.updated_by_id = guardian.user.id
      board.save!
      board
    end

    def ensure_new_tags_exist!(tag_names, guardian)
      return unless guardian.can_create_tag?
      Array(tag_names).compact_blank.each do |name|
        next if Tag.where_name([name]).exists?
        cleaned = DiscourseTagging.clean_tag(name)
        Tag.create!(name: cleaned) if cleaned.present?
      end
    end

    def replace_columns(board:, guardian:)
      raw = context[:raw_board_params] || {}
      ColumnsReplacer.replace!(board:, columns_payload: raw["columns"] || [], user: guardian.user)
    end
  end
end
