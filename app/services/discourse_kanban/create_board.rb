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
      guardian.can_manage_kanban_boards?
    end

    def create_board(guardian:)
      raw = context[:raw_board_params] || {}
      attrs = raw.except("columns")
      board = Board.new(attrs)
      board.created_by_id = guardian.user.id
      board.updated_by_id = guardian.user.id
      board.save!
      board
    end

    def replace_columns(board:, guardian:)
      raw = context[:raw_board_params] || {}
      ColumnsReplacer.replace!(board:, columns_payload: raw["columns"] || [], user: guardian.user)
    end
  end
end
