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
      unless @board.can_read?(guardian)
        raise Discourse::InvalidAccess.new(I18n.t("discourse_kanban.errors.board_read_forbidden"))
      end
    end

    def board_payload(board)
      {
        id: board.id,
        name: board.name,
        slug: board.slug,
        base_filter_query: board.base_filter_query,
        allow_read_group_ids: board.allow_read_group_ids,
        allow_write_group_ids: board.allow_write_group_ids,
        require_confirmation: board.require_confirmation,
        show_tags: board.show_tags,
        card_style: board.card_style,
        show_topic_thumbnail: board.show_topic_thumbnail,
        show_activity_indicators: board.show_activity_indicators,
        can_write: board.can_write?(guardian),
        can_manage: guardian.can_manage_kanban_boards?,
        columns: board.columns.map { |column| column_payload(column) },
      }
    end

    def column_payload(column)
      {
        id: column.id,
        title: column.title,
        icon: column.icon,
        position: column.position,
        filter_query: column.filter_query,
        move_to_tag: column.move_to_tag,
        move_to_category_id: column.move_to_category_id,
        move_to_assigned: column.move_to_assigned,
        move_to_status: column.move_to_status,
      }
    end

    def card_payload(card)
      payload = {
        id: card.id,
        board_id: card.board_id,
        column_id: card.column_id,
        card_type: card.card_type,
        membership_mode: card.membership_mode,
        position: card.position,
        title: card.title,
        notes: card.notes,
        labels: card.labels,
        due_at: card.due_at,
      }

      if card.topic?
        payload[:topic_id] = card.topic_id
        payload[:topic] = topic_card_payload(card.topic) if card.topic
      else
        payload[:updated_at] = card.updated_at
        payload[:updated_by] = { username: card.updated_by.username } if card.updated_by
      end

      payload
    end

    def topic_card_payload(topic)
      data = {
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        category_id: topic.category_id,
        tags: topic.tags.map(&:name),
        bumped_at: topic.bumped_at,
        closed: topic.closed,
        image_url: topic.image_url,
      }

      last_poster = topic.last_poster
      if last_poster
        data[:last_poster] = {
          username: last_poster.username,
          avatar_template: last_poster.avatar_template,
        }
      end

      if topic.respond_to?(:assignment) && topic.assignment&.assigned_to.is_a?(User)
        assigned = topic.assignment.assigned_to
        data[:assigned_to_user] = {
          username: assigned.username,
          avatar_template: assigned.avatar_template,
        }
      end

      data
    end

    def card_mutation_params
      params.require(:card).permit(
        :topic_id,
        :column_id,
        :title,
        :notes,
        :due_at,
        :after_card_id,
        labels: [],
      )
    end

    def message_bus_client_id
      params[:client_id]
    end

    def board_mutation_params
      params.require(:board).permit(
        :name,
        :slug,
        :base_filter_query,
        :require_confirmation,
        :show_tags,
        :card_style,
        :show_topic_thumbnail,
        :show_activity_indicators,
        allow_read_group_ids: [],
        allow_write_group_ids: [],
        columns: %i[
          id
          title
          icon
          position
          filter_query
          move_to_tag
          move_to_category_id
          move_to_assigned
          move_to_status
        ],
      )
    end
  end
end
