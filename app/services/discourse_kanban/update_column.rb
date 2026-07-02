# frozen_string_literal: true

module DiscourseKanban
  class UpdateColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer
      attribute :title, :string
      attribute :icon, :string
      attribute :default_sort, :string
      attribute :tag_name, :string
      attribute :move_to_category_id, :integer
      attribute :move_to_assigned, :string
      attribute :move_to_status, :string
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :id, presence: true
      validates :title, presence: true
    end

    model :board
    policy :can_manage
    model :column

    transaction { step :update_column }

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.id)
    end

    def update_column(column:, params:, guardian:)
      ColumnMutator.apply!(column:, attributes: params.to_hash, guardian:)
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end
  end
end
