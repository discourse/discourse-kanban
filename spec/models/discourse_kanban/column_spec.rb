# frozen_string_literal: true

RSpec.describe DiscourseKanban::Column do
  fab!(:admin)

  before { enable_current_plugin }

  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test-column", created_by_id: admin.id)
  end

  it "defaults to priority sorting" do
    column = board.columns.create!(title: "Backlog", position: 0)

    expect(column.default_sort).to eq("priority")
    expect(column).to be_priority
  end

  it "supports recency sorting" do
    column = board.columns.create!(title: "Done", position: 0, default_sort: "recency")

    expect(column.default_sort).to eq("recency")
    expect(column).to be_recency
  end
end
