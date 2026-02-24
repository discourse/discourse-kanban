# frozen_string_literal: true

# name: discourse-kanban
# about: Kanban boards with optional topic backing and board-level ACLs.
# meta_topic_id: 118164
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-kanban
# required_version: 2.7.0

enabled_site_setting :discourse_kanban_enabled

register_asset "stylesheets/kanban-manage.scss"
register_asset "stylesheets/kanban-board.scss"
register_svg_icon "table-columns"

module ::DiscourseKanban
  PLUGIN_NAME = "discourse-kanban"
end

require_relative "lib/discourse_kanban/engine"

after_initialize do
  # Register any column icons already in the DB so they appear in the SVG sprite
  begin
    if DiscourseKanban::Column.table_exists?
      DiscourseKanban::Column
        .where.not(icon: [nil, ""])
        .distinct
        .pluck(:icon)
        .each { |icon| DiscoursePluginRegistry.register_svg_icon(icon) }
    end
  rescue ActiveRecord::NoDatabaseError
    # Database may not exist yet during db:create / db:migrate bootstrap.
  end

  # When a column's icon changes, register it and expire the sprite cache
  add_model_callback(DiscourseKanban::Column, :after_commit) do
    if saved_change_to_icon? && icon.present?
      DiscoursePluginRegistry.register_svg_icon(icon)
      SvgSprite.expire_cache
    end
  end

  add_to_class(:guardian, :can_manage_kanban_boards?) do
    is_admin? || @user&.in_any_groups?(SiteSetting.discourse_kanban_manage_board_allowed_groups_map)
  end

  add_to_serializer(:current_user, :can_manage_kanban_boards) do
    object.guardian.can_manage_kanban_boards?
  end

  on(:topic_created) do |topic|
    DiscourseKanban::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("DiscourseKanban: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_tags_changed) do |topic, _|
    DiscourseKanban::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("DiscourseKanban: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_status_updated) do |topic, _, _|
    DiscourseKanban::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("DiscourseKanban: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_recovered) do |topic, _|
    DiscourseKanban::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("DiscourseKanban: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_destroyed) do |topic, _|
    DiscourseKanban::TopicSync.remove_topic(topic.id)
  rescue StandardError => e
    Rails.logger.warn("DiscourseKanban: failed to remove topic #{topic&.id}: #{e.message}")
  end

  add_model_callback(Topic, :after_commit) do
    next unless SiteSetting.discourse_kanban_enabled?
    next unless saved_changes?

    begin
      if saved_changes.key?("deleted_at") && deleted_at.present?
        DiscourseKanban::TopicSync.remove_topic(id)
        next
      end

      tracked_changes = %w[category_id archetype visible]
      next if (saved_changes.keys & tracked_changes).empty?

      DiscourseKanban::TopicSync.sync_topic(self)
    rescue StandardError => e
      Rails.logger.warn("DiscourseKanban: after_commit sync failed for topic #{id}: #{e.message}")
    end
  end
end
