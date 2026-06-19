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
      step :create_acl
      step :create_history
    end

    private

    def can_manage(guardian:)
      guardian.can_create_board?
    end

    def create_board(guardian:)
      raw = context[:raw_board_params]&.dup || {}
      if raw.key?("tag_names")
        raw["tag_ids"] = VisibleTagResolver.resolve_names!(raw.delete("tag_names"), guardian:)
      end
      board = Board.new(raw.except("columns", "acl"))
      board.created_by_id = guardian.user.id
      board.updated_by_id = guardian.user.id
      board.save!
      board
    end

    def replace_columns(board:, guardian:)
      raw = context[:raw_board_params] || {}
      ColumnsReplacer.replace!(
        board:,
        columns_payload: raw["columns"] || [],
        user: guardian.user,
        guardian:,
      )
    end

    def create_acl(board:)
      raw = context[:raw_board_params] || {}
      # TODO (martin) We need to add the current user as Owner here
      # when we have the user functionality ready for ACLs
      AccessControlList.insert_all!(
        AccessControlList.expand_list(
          raw["acl"],
          board,
          # TODO (martin) Need to define this in a central place, maybe some
          # register_acl_owner plugin API? Or easy lookup for Plugin.self.acl_owner?
          "plugin:discourse-kanban",
        ),
      )
    end

    def create_history(board:, guardian:)
      BoardHistory.create!(
        board:,
        acting_user: guardian.user,
        action: BoardHistory.actions[:board_created],
      )
    end
  end
end
