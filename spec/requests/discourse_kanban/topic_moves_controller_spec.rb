# frozen_string_literal: true

RSpec.describe DiscourseKanban::TopicMovesController do
  fab!(:admin)
  fab!(:writer, :user)
  fab!(:assignee, :user)
  fab!(:write_group, :group)
  fab!(:assign_group, :group)
  fab!(:category) { Fabricate(:category, name: "Todo") }
  fab!(:topic) { Fabricate(:topic, category: category, user: writer) }

  before do
    enable_current_plugin
    write_group.add(writer)
  end

  it "creates or updates a topic card on move" do
    board =
      DiscourseKanban::Board.create!(
        name: "Todo",
        slug: "todo-3",
        allow_write_group_ids: [write_group.id],
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Doing", position: 0)

    sign_in(admin)

    post "/kanban/boards/#{board.id}/topic-moves.json",
         params: {
           topic_id: topic.id,
           to_column_id: column.id,
         }

    expect(response.status).to eq(201)

    card = board.cards.find_by(topic_id: topic.id)
    expect(card).to be_present
    expect(card.column_id).to eq(column.id)
    expect(card.card_type).to eq("topic")
  end

  it "omits private assignment metadata from move response" do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
    writer.update!(moderator: true)
    Fabricate(:topic_assignment, topic:, assigned_to: assignee)
    board =
      DiscourseKanban::Board.create!(
        name: "Todo",
        slug: "todo-assignments",
        allow_write_group_ids: [write_group.id],
        created_by_id: admin.id,
      )
    column = board.columns.create!(title: "Doing", position: 0)

    sign_in(writer)

    post "/kanban/boards/#{board.id}/topic-moves.json",
         params: {
           topic_id: topic.id,
           to_column_id: column.id,
         }

    expect(response.status).to eq(201)
    expect(response.parsed_body.dig("card", "topic").keys).not_to include(
      "assigned_to_user",
      "assigned_to_group",
      "all_assigned_users",
      "assignments",
    )
  end
end
