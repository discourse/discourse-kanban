# frozen_string_literal: true

module DiscourseKanban
  class BaseController < ::ApplicationController
    requires_plugin DiscourseKanban::PLUGIN_NAME

    before_action :ensure_plugin_enabled

    private

    def ensure_plugin_enabled
      raise Discourse::InvalidAccess.new unless SiteSetting.discourse_kanban_enabled?
    end

    def find_board!
      board_id = params[:board_id] || params[:id]
      @board = DiscourseKanban::Board.find_by(id: board_id)
      if @board.blank?
        raise Discourse::NotFound.new(I18n.t("discourse_kanban.errors.board_not_found"))
      end
    end

    def ensure_board_read!
      unless guardian.can_read_board?(@board)
        raise Discourse::InvalidAccess.new(I18n.t("discourse_kanban.errors.board_read_forbidden"))
      end
    end

    def board_payload(board, tag_name_map: nil)
      tag_name_map ||= build_tag_name_map(board)

      {
        id: board.id,
        name: board.name,
        slug: board.slug,
        category_ids: board.category_ids,
        tag_ids: board.tag_ids,
        tag_names: board.tag_ids.filter_map { |id| tag_name_map[id] }.sort,
        allow_read_group_ids: board.allow_read_group_ids,
        allow_write_group_ids: board.allow_write_group_ids,
        require_confirmation: board.require_confirmation,
        show_tags: board.show_tags,
        card_style: board.card_style,
        show_topic_thumbnail: board.show_topic_thumbnail,
        can_write: guardian.can_write_board?(board),
        can_manage: guardian.can_manage_kanban_boards?,
        created_by: created_by_payload(board.created_by),
        columns: board.columns.map { |column| column_payload(column, tag_name_map:) },
      }
    end

    def created_by_payload(user)
      return nil if user.blank?

      { username: user.username, avatar_template: user.avatar_template }
    end

    def column_payload(column, tag_name_map: {})
      {
        id: column.id,
        title: column.title,
        icon: column.icon,
        position: column.position,
        default_sort: column.default_sort,
        tag_id: column.tag_id,
        tag_name: column.tag_id ? tag_name_map[column.tag_id] : nil,
        move_to_category_id: column.move_to_category_id,
        move_to_assigned: column.move_to_assigned,
        move_to_status: column.move_to_status,
      }
    end

    def build_tag_name_map(*boards)
      all_tag_ids = boards.flat_map { |b| b.tag_ids + b.columns.filter_map(&:tag_id) }.uniq
      return {} if all_tag_ids.empty?
      Tag.where(id: all_tag_ids).pluck(:id, :name).to_h
    end

    def card_mutation_params
      params.require(:card).permit(
        :topic_id,
        :column_id,
        :title,
        :notes,
        :after_card_id,
        :assigned_to_name,
        tag_ids: [],
        tag_names: [],
      )
    end

    def constraint_fix_params
      params.permit(constraint_fix: [:category_id, tag_names: []])[:constraint_fix]
    end

    def message_bus_client_id
      params[:client_id]
    end

    def board_mutation_params
      params.require(:board).permit(
        :name,
        :slug,
        :require_confirmation,
        :show_tags,
        :card_style,
        :show_topic_thumbnail,
        allow_read_group_ids: [],
        allow_write_group_ids: [],
        category_ids: [],
        tag_names: [],
        columns: %i[
          id
          title
          icon
          position
          default_sort
          tag_name
          move_to_category_id
          move_to_assigned
          move_to_status
        ],
      )
    end
  end
end
