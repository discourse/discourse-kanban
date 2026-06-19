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
      step :update_acl
      step :update_board
      step :replace_columns
      step :remove_non_matching_cards
      step :create_histories
    end

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.id)
    end

    def can_manage(guardian:)
      guardian.can_update_board?
    end

    def update_acl(board:, guardian:)
      # TODO (martin) Add logging here for the difference of old + new permissions
      # and who changed them
      AccessControlList.where(target: board).destroy_all
      AccessControlList.insert_all!(
        AccessControlList.expand_list(
          context[:raw_board_params]["acl"],
          board,
          # TODO (martin) Need to define this in a central place, maybe some
          # register_acl_owner plugin API? Or easy lookup for Plugin.self.acl_owner?
          "plugin:discourse-kanban",
        ),
      )
    end

    def update_board(board:, guardian:)
      raw = context[:raw_board_params]&.dup || {}
      context[:histories] = {}
      if raw.key?("tag_names")
        raw["tag_ids"] = VisibleTagResolver.resolve_names!(raw.delete("tag_names"), guardian:)
      end
      board.assign_attributes(raw.except("columns", "acl"))
      board.updated_by_id = guardian.user.id

      if board.name_changed?
        context[:histories][:renamed] = { previous_value: board.name_was, new_value: board.name }
      end

      if board.allow_read_group_ids_changed?
        context[:histories][:permissions_changed] ||= {}
        context[:histories][:permissions_changed].merge!(
          previous_allow_read_group_ids: board.allow_read_group_ids_was,
          new_allow_read_group_ids: board.allow_read_group_ids,
        )
      end

      if board.allow_write_group_ids_changed?
        context[:histories][:permissions_changed] ||= {}
        context[:histories][:permissions_changed].merge!(
          previous_allow_write_group_ids: board.allow_write_group_ids_was,
          new_allow_write_group_ids: board.allow_write_group_ids,
        )
      end

      if board.category_ids_changed?
        context[:histories][:constraints_changed] ||= {}
        context[:histories][:constraints_changed].merge!(
          previous_category_ids: board.category_ids_was,
          new_category_ids: board.category_ids,
        )
      end

      if board.tag_ids_changed?
        context[:histories][:constraints_changed] ||= {}
        context[:histories][:constraints_changed].merge!(
          previous_tag_ids: board.tag_ids_was,
          new_tag_ids: board.tag_ids,
        )
      end

      if board.slug_changed?
        context[:histories][:slug_changed] = {
          previous_value: board.slug_was,
          new_value: board.slug,
        }
      end

      board.save!
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

    def remove_non_matching_cards(board:, guardian:)
      if board.has_constraints?
        non_matching_card_ids =
          DB.query_single(
            <<~SQL,
            SELECT c.id FROM discourse_kanban_cards c
            JOIN topics t ON t.id = c.topic_id
            WHERE c.board_id = :board_id AND c.card_type = #{Card.card_types[:topic]}
              AND NOT (
                (:cat_empty OR t.category_id = ANY(:category_ids))
                AND (:tag_empty OR EXISTS (
                  SELECT 1 FROM topic_tags tt WHERE tt.topic_id = t.id AND tt.tag_id = ANY(:tag_ids)
                ))
              )
          SQL
            board_id: board.id,
            category_ids: pg_array(board.category_ids),
            tag_ids: pg_array(board.tag_ids),
            cat_empty: board.category_ids.empty?,
            tag_empty: board.tag_ids.empty?,
          )
      else
        non_matching_card_ids = []
      end

      Card.where(id: non_matching_card_ids).delete_all if non_matching_card_ids.present?
      context[:cards_removed_count] = non_matching_card_ids.length
    end

    def pg_array(ids)
      "{#{ids.join(",")}}"
    end

    def create_histories(board:, guardian:, histories:)
      histories.each do |action, details|
        BoardHistory.create!(
          board:,
          acting_user: guardian.user,
          action: "board_#{action}",
          details:,
        )
      end
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end
  end
end
