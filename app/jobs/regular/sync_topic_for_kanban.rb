# frozen_string_literal: true

module Jobs
  class SyncTopicForKanban < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.discourse_kanban_enabled?

      topic_id = args[:topic_id]
      return if topic_id.blank?

      topic = Topic.find_by(id: topic_id)
      return if topic.blank?

      DiscourseKanban::TopicSync.sync_topic(topic)
    end
  end
end
