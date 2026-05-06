# frozen_string_literal: true

RSpec.describe DiscourseKanban::OneboxHandler do
  fab!(:admin)

  before { enable_current_plugin }

  fab!(:board) do
    DiscourseKanban::Board.create!(
      name: "Roadmap board",
      slug: "roadmap-board",
      created_by_id: admin.id,
    )
  end

  fab!(:topic) { Fabricate(:topic, title: "Topic card headline") }

  fab!(:column) { board.columns.create!(title: "Todo", position: 0) }

  fab!(:floater_card) do
    board.cards.create!(
      card_type: :floater,
      title: "Standalone card title",
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )
  end

  fab!(:topic_card) do
    board.cards.create!(
      card_type: :topic,
      topic_id: topic.id,
      column_id: column.id,
      position: 1,
      created_by_id: admin.id,
    )
  end
end
