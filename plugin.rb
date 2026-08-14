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
register_asset "stylesheets/kanban-oneboxes.scss"
register_asset "stylesheets/kanban-topic-pill.scss"
register_asset "stylesheets/kanban-add-from-topic-menu.scss"
register_svg_icon "table-columns"
register_svg_icon "discourse-kanban"

module ::DiscourseKanban
  PLUGIN_NAME = "discourse-kanban"
end

require_relative "lib/discourse_kanban/engine"

after_initialize do
  reloadable_patch { |plugin| Guardian.prepend DiscourseKanban::GuardianExtensions }

  # Register any column icons already in the DB so they appear in the SVG sprite
  begin
    if ActiveRecord::Base.connection.data_source_exists?(:discourse_kanban_columns) &&
         ActiveRecord::Base.connection.column_exists?(:discourse_kanban_columns, :default_sort)
      DiscourseKanban::Column
        .where.not(icon: [nil, ""])
        .distinct
        .pluck(:icon)
        .each { |icon| DiscoursePluginRegistry.register_svg_icon(icon) }
    end
  rescue ActiveRecord::NoDatabaseError,
         ActiveRecord::StatementInvalid,
         ActiveRecord::DatabaseConnectionError
    # Database may not exist/may have pending migrations yet during db:create / db:migrate bootstrap.
  end

  # When a column's icon changes, register it and expire the sprite cache
  add_model_callback(DiscourseKanban::Column, :after_commit) do
    if saved_change_to_icon? && icon.present?
      DiscoursePluginRegistry.register_svg_icon(icon)
      SvgSprite.expire_cache
    end
  end

  add_to_serializer(:current_user, :can_manage_kanban_boards) do
    object.guardian.can_manage_kanban_boards?
  end

  add_to_class(:topic, :kanban_board_cards_map) { @kanban_board_cards_map }
  add_to_class(:topic, :kanban_board_cards_map=) { |cards| @kanban_board_cards_map = cards }

  TopicList.on_preload do |topics, topic_list|
    next unless SiteSetting.discourse_kanban_enabled

    result =
      DiscourseKanban::TopicBoardMemberships.call(
        guardian: Guardian.new(topic_list.current_user),
        options: {
          topics:,
        },
      )
    cards_map = result[:cards_map]
    topics.each { |topic| topic.kanban_board_cards_map = cards_map.fetch(topic.id, {}) }
  end

  add_to_serializer(
    :topic_list_item,
    :kanban_memberships,
    include_condition: -> { SiteSetting.discourse_kanban_enabled && kanban_memberships.present? },
  ) do
    @kanban_memberships ||=
      begin
        cards_map = object.kanban_board_cards_map
        if cards_map.nil?
          result =
            DiscourseKanban::TopicBoardMemberships.call(
              guardian: scope,
              options: {
                topics: [object],
              },
            )
          cards_map = result[:cards_map].fetch(object.id, {})
        end

        ActiveModel::ArraySerializer.new(
          cards_map.values,
          each_serializer: DiscourseKanban::TopicBoardMembershipSerializer,
          scope:,
        ).as_json
      end
  end

  add_to_serializer(
    :topic_view,
    :kanban_memberships,
    include_condition: -> { SiteSetting.discourse_kanban_enabled && kanban_memberships.present? },
  ) do
    @kanban_memberships ||=
      begin
        topic = object.topic
        result =
          DiscourseKanban::TopicBoardMemberships.call(guardian: scope, options: { topics: [topic] })
        cards_map = result[:cards_map].fetch(topic.id, {})
        ActiveModel::ArraySerializer.new(
          cards_map.values,
          each_serializer: DiscourseKanban::TopicBoardMembershipSerializer,
          scope:,
        ).as_json
      end
  end

  DiscoursePluginRegistry.register_acl_target_class(DiscourseKanban::Board, self)

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

  Oneboxer.register_local_handler("discourse_kanban/boards") do |url, route, opts|
    ::DiscourseKanban::OneboxHandler.handle(url, route, opts)
  end

  InlineOneboxer.register_local_handler("discourse_kanban/boards") do |url, route, opts|
    ::DiscourseKanban::InlineOneboxHandler.handle(url, route, opts)
  end

  if defined?(Assignment)
    add_model_callback(Assignment, :after_commit) do
      next unless SiteSetting.discourse_kanban_enabled?

      begin
        tid = self.topic_id
        next if tid.blank?

        Jobs.cancel_scheduled_job("DiscourseKanban::SyncTopicForKanban", topic_id: tid)
        Jobs.enqueue_in(5.seconds, Jobs::DiscourseKanban::SyncTopicForKanban, topic_id: tid)
      rescue StandardError => e
        Rails.logger.warn(
          "DiscourseKanban: failed to enqueue sync after assignment change for topic #{tid}: #{e.message}",
        )
      end
    end
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

  register_stat("total_boards", stat_type: :kanban) { DiscourseKanban::Statistics.total_boards }
  register_stat("created_boards", stat_type: :kanban) { DiscourseKanban::Statistics.created_boards }
  register_stat("viewed_boards", stat_type: :kanban) { DiscourseKanban::Statistics.viewed_boards }
  register_stat("active_boards", stat_type: :kanban) { DiscourseKanban::Statistics.active_boards }
  register_stat("active_users", stat_type: :kanban) { DiscourseKanban::Statistics.active_users }
  register_stat("participating_users", stat_type: :kanban) do
    DiscourseKanban::Statistics.participating_users
  end
end
