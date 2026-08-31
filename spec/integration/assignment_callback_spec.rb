# frozen_string_literal: true

describe "Kanban sync from the Assignment after_commit callback", if: defined?(Assignment) do
  fab!(:topic)
  fab!(:user)

  before do
    enable_current_plugin
    SiteSetting.assign_enabled = true
  end

  it "enqueues a kanban sync for the topic when an assignment is created" do
    expect_enqueued_with(
      job: Jobs::DiscourseKanban::SyncTopicForKanban,
      args: {
        topic_id: topic.id,
      },
    ) { Fabricate(:topic_assignment, topic: topic, target: topic) }
  end

  it "enqueues a kanban sync for the topic when an assignment is updated" do
    assignment = Fabricate(:topic_assignment, topic: topic, target: topic)

    expect_enqueued_with(
      job: Jobs::DiscourseKanban::SyncTopicForKanban,
      args: {
        topic_id: topic.id,
      },
    ) { assignment.update!(assigned_to: user) }
  end

  it "enqueues a kanban sync for the topic when an assignment is destroyed" do
    assignment = Fabricate(:topic_assignment, topic: topic, target: topic)

    expect_enqueued_with(
      job: Jobs::DiscourseKanban::SyncTopicForKanban,
      args: {
        topic_id: topic.id,
      },
    ) { assignment.destroy! }
  end

  it "cancels any sync already scheduled for the topic" do
    # The job name passed to `cancel_scheduled_job` must camelcase into the job's
    # full class name, otherwise nothing is ever cancelled.
    Jobs
      .expects(:cancel_scheduled_job)
      .with do |job_name, opts|
        "Jobs::#{job_name.to_s.camelcase}" == Jobs::DiscourseKanban::SyncTopicForKanban.name &&
          opts == { topic_id: topic.id }
      end
      .at_least_once

    Fabricate(:topic_assignment, topic: topic, target: topic)
  end

  it "does not enqueue a sync when the plugin is disabled" do
    SiteSetting.discourse_kanban_enabled = false

    expect_enqueued_with(
      job: Jobs::DiscourseKanban::SyncTopicForKanban,
      args: {
        topic_id: topic.id,
      },
      expectation: false,
    ) { Fabricate(:topic_assignment, topic: topic, target: topic) }
  end
end
