# frozen_string_literal: true

module DiscourseKanban
  class ColumnsReplacer
    def self.replace!(board:, columns_payload:, user:)
      current_columns = board.columns.index_by(&:id)
      kept_column_ids = []

      Array(columns_payload).each_with_index do |raw_col, index|
        col_payload = raw_col.with_indifferent_access
        id = col_payload[:id].presence&.to_i
        column = id && current_columns[id] ? current_columns[id] : board.columns.build

        column.assign_attributes(
          title: col_payload[:title],
          icon: col_payload[:icon],
          filter_query: col_payload[:filter_query],
          move_to_tag: col_payload[:move_to_tag],
          move_to_category_id: col_payload[:move_to_category_id],
          move_to_assigned: col_payload[:move_to_assigned],
          move_to_status: col_payload[:move_to_status],
          wip_limit: col_payload[:wip_limit],
          position: index,
        )

        column.save!
        kept_column_ids << column.id
      end

      removed_columns = board.columns.where.not(id: kept_column_ids)
      removed_column_ids = removed_columns.pluck(:id)

      if removed_column_ids.present?
        board
          .cards
          .where(column_id: removed_column_ids, card_type: Card.card_types[:floater])
          .delete_all
        board
          .cards
          .where(column_id: removed_column_ids, card_type: Card.card_types[:topic])
          .update_all(
            column_id: nil,
            membership_mode: Card.membership_modes[:manual_out],
            updated_by_id: user.id,
            updated_at: Time.zone.now,
          )
      end

      removed_columns.delete_all
    end
  end
end
