# frozen_string_literal: true

RSpec.describe DiscourseKanban::CardPayloadSerializer do
  fab!(:admin)
  fab!(:viewer, :user)
  fab!(:allowed_group, :group)
  fab!(:private_category) { Fabricate(:private_category, group: allowed_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:board) { Fabricate(:kanban_board, created_by: admin) }
  fab!(:column) { Fabricate(:kanban_column, board:) }
  fab!(:card) do
    Fabricate(
      :kanban_card,
      board:,
      column:,
      card_type: :topic,
      topic: private_topic,
      created_by: admin,
    )
  end

  before { enable_current_plugin }

  it "omits topic details when the scoped user cannot see the topic" do
    payload = described_class.new(card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload).to include(topic_id: private_topic.id)
    expect(payload).not_to have_key(:topic)
  end

  it "includes topic details when the scoped user can see the topic" do
    allowed_group.add(viewer)

    payload = described_class.new(card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload[:topic]).to include(title: private_topic.title, slug: private_topic.slug)
  end
end
