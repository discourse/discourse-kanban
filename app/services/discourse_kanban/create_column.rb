# frozen_string_literal: true

module DiscourseKanban
  class CreateColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :title, :string
      attribute :icon, :string
      attribute :default_sort, :string
      attribute :tag_name, :string
      attribute :move_to_category_id, :integer
      attribute :move_to_assigned, :string
      attribute :move_to_status, :string
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :title, presence: true
    end

    model :board
    policy :can_manage

    transaction { model :column, :create_column }

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_board?(board)
    end

    def create_column(board:, params:, guardian:)
      position = (board.columns.maximum(:position) || -1) + 1
      ColumnMutator.apply!(
        column: board.columns.build,
        attributes: params.to_hash,
        guardian:,
        position:,
      )
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end
  end
end
