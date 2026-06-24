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

  it "accepts a preset key, a bare hex, or no color, but rejects malformed values" do
    expect(board.columns.build(title: "A", position: 0, color: "purple")).to be_valid
    expect(board.columns.build(title: "B", position: 1, color: "1a2b3c")).to be_valid
    expect(board.columns.build(title: "C", position: 2, color: "f0a")).to be_valid
    expect(board.columns.build(title: "D", position: 3, color: nil)).to be_valid

    # The client stores hex without a leading "#", so a "#"-prefixed value is malformed.
    expect(board.columns.build(title: "E", position: 4, color: "#1a2b3c")).not_to be_valid
    expect(board.columns.build(title: "F", position: 5, color: "blue ish")).not_to be_valid
  end
end
