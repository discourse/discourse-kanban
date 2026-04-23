# frozen_string_literal: true

module DiscourseKanban
  class ColumnsReplacer
    def self.replace!(board:, columns_payload:, user:)
      guardian = Guardian.new(user)
      current_columns = board.columns.index_by(&:id)
      kept_column_ids = []
      used_tag_ids = []

      Array(columns_payload).each_with_index do |raw_col, index|
        col_payload = raw_col.with_indifferent_access
        id = col_payload[:id].presence&.to_i
        column = id && current_columns[id] ? current_columns[id] : board.columns.build

        tag_name = col_payload[:tag_name].presence
        resolved_tag_id = nil
        if tag_name
          resolved_tag_id = Tag.find_by(name: tag_name)&.id
          if resolved_tag_id.nil? && guardian.can_create_tag?
            cleaned = DiscourseTagging.clean_tag(tag_name)
            resolved_tag_id = Tag.create!(name: cleaned).id if cleaned.present?
          end
          if resolved_tag_id.nil?
            raise Discourse::InvalidParameters.new(
                    I18n.t("discourse_kanban.errors.unknown_tag_name", tag_name: tag_name),
                  )
          end
          if used_tag_ids.include?(resolved_tag_id)
            raise Discourse::InvalidParameters.new(
                    I18n.t(
                      "discourse_kanban.errors.cannot_use_same_tag_multiple_times",
                      tag_name: tag_name,
                    ),
                  )
          end
          used_tag_ids << resolved_tag_id
        end

        column.assign_attributes(
          title: col_payload[:title],
          icon: col_payload[:icon],
          tag_id: resolved_tag_id,
          move_to_category_id: col_payload[:move_to_category_id],
          move_to_assigned: col_payload[:move_to_assigned],
          move_to_status: col_payload[:move_to_status],
          position: index,
        )

        column.save!
        kept_column_ids << column.id
      end

      removed_columns = board.columns.where.not(id: kept_column_ids)
      removed_column_ids = removed_columns.pluck(:id)

      board.cards.where(column_id: removed_column_ids).delete_all if removed_column_ids.present?

      removed_columns.delete_all
    end
  end
end
