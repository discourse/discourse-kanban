# frozen_string_literal: true

RSpec.describe DiscourseKanban::ColumnsReplacer do
  fab!(:admin)
  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test", created_by_id: admin.id)
  end

  before { enable_current_plugin }

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
      expect(columns.last.default_sort).to eq("priority")
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
        title: "Floater",
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      DiscourseKanban::ColumnsReplacer.replace!(board:, columns_payload: [], user: admin)

      expect(board.cards.reload.count).to eq(0)
    end

    it "deletes topic cards in removed columns" do
      topic = Fabricate(:topic)
      col = board.columns.create!(title: "Gone", position: 0)
      card =
        board
          .cards
          .find_or_initialize_by(topic_id: topic.id)
          .tap do |c|
            c.assign_attributes(
              card_type: :topic,
              column_id: col.id,
              position: 0,
              created_by_id: admin.id,
            )
            c.save!
          end

      DiscourseKanban::ColumnsReplacer.replace!(board:, columns_payload: [], user: admin)

      expect(DiscourseKanban::Card.find_by(id: card.id)).to be_nil
    end

    it "persists default sort" do
      DiscourseKanban::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "title" => "Recent", "default_sort" => "recency" }],
        user: admin,
      )

      expect(board.columns.last.default_sort).to eq("recency")
    end

    it "rejects invalid default sort" do
      expect {
        DiscourseKanban::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "title" => "Broken", "default_sort" => "random" }],
          user: admin,
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    describe "when a tag is provided" do
      fab!(:tag)

      it "creates a new column with the tag" do
        DiscourseKanban::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "title" => "Backlog", "tag_name" => tag.name }],
          user: admin,
        )

        expect(board.columns.last.tag).to eq(tag)
      end

      it "creates the tag when it doesn't exist and the user can create tags" do
        DiscourseKanban::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "title" => "Backlog", "tag_name" => "brand-new" }],
          user: admin,
        )

        expect(board.columns.last.tag.name).to eq("brand-new")
      end

      it "raises an error if the tag is not found and the user cannot create tags" do
        user = Fabricate(:user)
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]

        expect {
          DiscourseKanban::ColumnsReplacer.replace!(
            board:,
            columns_payload: [{ "title" => "Backlog", "tag_name" => "unknown" }],
            user: user,
          )
        }.to raise_error(
          Discourse::InvalidParameters,
          I18n.t("discourse_kanban.errors.unknown_tag_name", tag_name: "unknown"),
        )
      end

      it "raises an error if a tag has already been used for another column" do
        expect {
          DiscourseKanban::ColumnsReplacer.replace!(
            board:,
            columns_payload: [
              { "title" => "Backlog", "tag_name" => tag.name },
              { "title" => "Done", "tag_name" => tag.name },
            ],
            user: admin,
          )
        }.to raise_error(
          Discourse::InvalidParameters,
          I18n.t("discourse_kanban.errors.cannot_use_same_tag_multiple_times", tag_name: tag.name),
        )
      end
    end
  end
end
