# frozen_string_literal: true

module DiscourseKanban
  class UpdateBoard
    include Service::Base

    params do
      attribute :id, :integer
      attribute :client_id, :string

      validates :id, presence: true
    end

    model :board
    policy :can_manage

    transaction do
      step :update_board
      step :replace_columns
    end

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.id)
    end

    def can_manage(guardian:)
      guardian.can_manage_kanban_boards?
    end

    def update_board(board:, guardian:)
      raw = context[:raw_board_params] || {}
      attrs = raw.except("columns")
      board.assign_attributes(attrs)
      board.updated_by_id = guardian.user.id
      board.save!
    end

    def replace_columns(board:, guardian:)
      raw = context[:raw_board_params] || {}
      ColumnsReplacer.replace!(board:, columns_payload: raw["columns"] || [], user: guardian.user)
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end
  end
end
