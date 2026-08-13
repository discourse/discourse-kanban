# frozen_string_literal: true

RSpec.describe Jobs::DiscourseKanban::SyncTopicForKanban do
  fab!(:topic)

  before { enable_current_plugin }

  describe "#execute" do
    it "syncs the topic" do
      DiscourseKanban::TopicSync.expects(:sync_topic).with(topic)

      described_class.new.execute(topic_id: topic.id)
    end

    it "does nothing when the plugin is disabled" do
      SiteSetting.discourse_kanban_enabled = false
      DiscourseKanban::TopicSync.expects(:sync_topic).never

      described_class.new.execute(topic_id: topic.id)
    end

    it "does nothing when no topic_id is given" do
      DiscourseKanban::TopicSync.expects(:sync_topic).never

      described_class.new.execute(topic_id: nil)
    end

    it "does nothing when the topic no longer exists" do
      DiscourseKanban::TopicSync.expects(:sync_topic).never

      described_class.new.execute(topic_id: topic.id + 1000)
    end
  end
end
