# frozen_string_literal: true

RSpec.describe DiscourseKanban::TopicMovesController do
  fab!(:admin)
  fab!(:writer, :user)
  fab!(:write_group, :group)
  fab!(:category) { Fabricate(:category, name: "Todo") }
  fab!(:topic) { Fabricate(:topic, category: category, user: writer) }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
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
    expect(card.membership_mode).to eq("manual_in")
  end
end
