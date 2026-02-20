# frozen_string_literal: true

RSpec.describe DiscourseKanban::ColumnsReplacer do
  fab!(:admin)
  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test", created_by_id: admin.id)
  end

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  describe ".replace!" do
    it "creates new columns from payload" do
      DiscourseKanban::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "title" => "Backlog" }, { "title" => "Done", "icon" => "check" }],
        user: admin,
      )

      columns = board.columns.order(:position)
      expect(columns.count).to eq(2)
      expect(columns.first.title).to eq("Backlog")
      expect(columns.first.position).to eq(0)
      expect(columns.last.title).to eq("Done")
      expect(columns.last.icon).to eq("check")
      expect(columns.last.position).to eq(1)
    end

    it "updates existing columns by id" do
      col = board.columns.create!(title: "Old", position: 0)

      DiscourseKanban::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "id" => col.id, "title" => "New" }],
        user: admin,
      )

      expect(col.reload.title).to eq("New")
    end

    it "removes columns not in the payload" do
      col1 = board.columns.create!(title: "Keep", position: 0)
      col2 = board.columns.create!(title: "Remove", position: 1)

      DiscourseKanban::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "id" => col1.id, "title" => "Keep" }],
        user: admin,
      )

      expect(board.columns.reload.pluck(:id)).to contain_exactly(col1.id)
      expect(DiscourseKanban::Column.find_by(id: col2.id)).to be_nil
    end

    it "deletes floater cards in removed columns" do
      col = board.columns.create!(title: "Gone", position: 0)
      board.cards.create!(
        card_type: :floater,
        membership_mode: :manual_in,
        title: "Floater",
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      DiscourseKanban::ColumnsReplacer.replace!(board:, columns_payload: [], user: admin)

      expect(board.cards.reload.count).to eq(0)
    end

    it "marks topic cards in removed columns as manual_out" do
      topic = Fabricate(:topic)
      col = board.columns.create!(title: "Gone", position: 0)
      card =
        board
          .cards
          .find_or_initialize_by(topic_id: topic.id)
          .tap do |c|
            c.assign_attributes(
              card_type: :topic,
              membership_mode: :manual_in,
              column_id: col.id,
              position: 0,
              created_by_id: admin.id,
            )
            c.save!
          end

      DiscourseKanban::ColumnsReplacer.replace!(board:, columns_payload: [], user: admin)

      card.reload
      expect(card.column_id).to be_nil
      expect(card.membership_mode).to eq("manual_out")
      expect(card.updated_by_id).to eq(admin.id)
    end
  end
end
