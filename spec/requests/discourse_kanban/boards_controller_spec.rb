# frozen_string_literal: true

RSpec.describe DiscourseKanban::BoardsController do
  fab!(:admin)
  fab!(:reader, :user)
  fab!(:writer, :user)
  fab!(:manager, :user)
  fab!(:outsider, :user)
  fab!(:read_group, :group)
  fab!(:write_group, :group)
  fab!(:manage_group, :group)
  fab!(:category) { Fabricate(:category, name: "General") }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_manage_board_allowed_groups = manage_group.id.to_s
    read_group.add(reader)
    write_group.add(writer)
    manage_group.add(manager)
  end

  describe "GET /kanban/boards" do
    it "returns only boards visible to the current user" do
      other_group = Fabricate(:group)

      visible =
        DiscourseKanban::Board.create!(
          name: "Visible",
          slug: "visible",
          allow_read_group_ids: [read_group.id],
          created_by_id: admin.id,
        )
      DiscourseKanban::Board.create!(
        name: "Hidden",
        slug: "hidden",
        allow_read_group_ids: [other_group.id],
        created_by_id: admin.id,
      )

      visible.columns.create!(title: "One", position: 0)

      sign_in(reader)
      get "/kanban/boards.json"

      expect(response.status).to eq(200)
      slugs = response.parsed_body["boards"].map { |b| b["slug"] }
      expect(slugs).to contain_exactly("visible")
    end

    it "returns all boards for admins" do
      other_group = Fabricate(:group)

      DiscourseKanban::Board.create!(
        name: "Private",
        slug: "private",
        allow_read_group_ids: [other_group.id],
        created_by_id: admin.id,
      )

      sign_in(admin)
      get "/kanban/boards.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["boards"].length).to eq(1)
    end
  end

  describe "GET /kanban/boards/:id" do
    it "returns full board payload with columns and cards" do
      topic = Fabricate(:topic, category: category)
      board =
        DiscourseKanban::Board.create!(
          name: "Sprint",
          slug: "sprint",
          show_tags: true,
          card_style: "detailed",
          show_activity_indicators: true,
          allow_write_group_ids: [write_group.id],
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Backlog", position: 0, icon: "list")
      board.cards.create!(
        card_type: :topic,
        topic_id: topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(writer)
      get "/kanban/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      body = response.parsed_body

      board_data = body["board"]
      expect(board_data["name"]).to eq("Sprint")
      expect(board_data["can_write"]).to eq(true)
      expect(board_data["show_tags"]).to eq(true)
      expect(board_data["card_style"]).to eq("detailed")

      columns = body["columns"]
      expect(columns.length).to eq(1)
      expect(columns[0]["title"]).to eq("Backlog")
      expect(columns[0]["icon"]).to eq("list")
      expect(columns[0]["default_sort"]).to eq("priority")
      expect(columns[0]["cards"].length).to eq(1)

      card = columns[0]["cards"][0]
      expect(card["card_type"]).to eq("topic")
      expect(card["topic"]["title"]).to eq(topic.title)
      expect(card["topic"]["slug"]).to eq(topic.slug)
    end

    it "includes can_manage for users in the manage group" do
      board =
        DiscourseKanban::Board.create!(name: "Test", slug: "test-manage", created_by_id: admin.id)
      board.columns.create!(title: "Col", position: 0)

      sign_in(manager)
      get "/kanban/boards/#{board.id}.json"

      expect(response.parsed_body["board"]["can_manage"]).to eq(true)
    end

    it "includes can_manage for admins" do
      board =
        DiscourseKanban::Board.create!(
          name: "Test",
          slug: "test-admin-manage",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Col", position: 0)

      sign_in(admin)
      get "/kanban/boards/#{board.id}.json"

      expect(response.parsed_body["board"]["can_manage"]).to eq(true)
    end

    it "sets can_manage to false for users not in the manage group" do
      board =
        DiscourseKanban::Board.create!(
          name: "Test",
          slug: "test-nomanage",
          allow_read_group_ids: [read_group.id],
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Col", position: 0)

      sign_in(reader)
      get "/kanban/boards/#{board.id}.json"

      expect(response.parsed_body["board"]["can_manage"]).to eq(false)
    end

    it "includes the creator's username and avatar_template" do
      board =
        DiscourseKanban::Board.create!(
          name: "Creator Test",
          slug: "creator-test",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Col", position: 0)

      sign_in(admin)
      get "/kanban/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      created_by = response.parsed_body["board"]["created_by"]
      expect(created_by).to be_present
      expect(created_by["username"]).to eq(admin.username)
      expect(created_by["avatar_template"]).to eq(admin.avatar_template)
    end

    it "includes topic details for detailed cards" do
      topic = Fabricate(:topic, category: category)
      board =
        DiscourseKanban::Board.create!(
          name: "Detailed",
          slug: "detailed",
          card_style: "detailed",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Col", position: 0)
      board.cards.create!(
        card_type: :topic,
        topic_id: topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(admin)
      get "/kanban/boards/#{board.id}.json"

      topic_data = response.parsed_body["columns"][0]["cards"][0]["topic"]
      expect(topic_data["image_url"]).to be_present.or be_nil
      expect(topic_data).to have_key("last_poster")
      expect(topic_data["bumped_at"]).to be_present
      expect(topic_data["category_id"]).to eq(category.id)
    end

    it "filters out topics the user cannot see" do
      private_category = Fabricate(:private_category, group: write_group)
      visible_topic = Fabricate(:topic, category: category)
      private_topic = Fabricate(:topic, category: private_category)

      board =
        DiscourseKanban::Board.create!(
          name: "Mixed",
          slug: "mixed",
          category_ids: [category.id, private_category.id],
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Col", position: 0)

      board.cards.create!(
        card_type: :topic,
        topic_id: visible_topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )
      board.cards.create!(
        card_type: :topic,
        topic_id: private_topic.id,
        column_id: col.id,
        position: 1,
        created_by_id: admin.id,
      )

      sign_in(reader)
      get "/kanban/boards/#{board.id}.json"

      card_titles = response.parsed_body["columns"][0]["cards"].map { |c| c["topic"]["title"] }
      expect(card_titles).to include(visible_topic.title)
      expect(card_titles).not_to include(private_topic.title)
    end

    it "does not backfill cards into unconstrained columns even when the board filter matches" do
      topic = Fabricate(:topic, category: category)
      board =
        DiscourseKanban::Board.create!(
          name: "Auto Board",
          slug: "auto-board",
          category_ids: [category.id],
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      sign_in(admin)
      get "/kanban/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      cards = response.parsed_body["columns"][0]["cards"]
      expect(cards).to eq([])
      expect(board.cards.where(topic_id: topic.id)).to be_blank
    end

    it "orders recency columns by computed recency" do
      board =
        DiscourseKanban::Board.create!(
          name: "Recent Board",
          slug: "recent-board",
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Done", position: 0, default_sort: "recency")
      old_card =
        board.cards.create!(
          card_type: :floater,
          title: "Old",
          column_id: col.id,
          position: 0,
          column_changed_at: 5.days.ago,
          created_by_id: admin.id,
        )
      new_card =
        board.cards.create!(
          card_type: :floater,
          title: "New",
          column_id: col.id,
          position: 10_000,
          column_changed_at: 5.days.ago,
          created_by_id: admin.id,
        )
      old_card.update_columns(updated_at: 4.days.ago)
      new_card.update_columns(updated_at: 1.hour.ago)

      sign_in(admin)
      get "/kanban/boards/#{board.id}.json"

      card_titles = response.parsed_body["columns"][0]["cards"].map { |card| card["title"] }
      expect(card_titles).to eq(%w[New Old])
      expect(response.parsed_body["columns"][0]["cards"][0]["recency_at"]).to be_present
    end

    it "denies access to users without read permission" do
      board =
        DiscourseKanban::Board.create!(
          name: "Secret",
          slug: "secret",
          allow_read_group_ids: [read_group.id],
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Col", position: 0)

      sign_in(outsider)
      get "/kanban/boards/#{board.id}.json"

      expect(response.status).to eq(403)
    end
  end

  describe "POST /kanban/boards" do
    it "creates a board for users in the manage group" do
      sign_in(manager)

      post "/kanban/boards.json",
           params: {
             board: {
               name: "Engineering",
               slug: "engineering",
               columns: [{ title: "Backlog" }, { title: "In Progress" }],
             },
           }

      expect(response.status).to eq(201)
      board = DiscourseKanban::Board.find_by(slug: "engineering")
      expect(board).to be_present
      expect(board.columns.count).to eq(2)
      expect(board.columns.order(:position).pluck(:title)).to eq(["Backlog", "In Progress"])
    end

    it "creates a board for admin users" do
      sign_in(admin)

      post "/kanban/boards.json", params: { board: { name: "Admin Board", slug: "admin-board" } }

      expect(response.status).to eq(201)
    end

    it "persists column default sort" do
      board =
        DiscourseKanban::Board.create!(
          name: "Sort Board",
          slug: "sort-board",
          created_by_id: admin.id,
        )
      column = board.columns.create!(title: "Col", position: 0)

      sign_in(manager)

      put "/kanban/boards/#{board.id}.json",
          params: {
            board: {
              name: board.name,
              columns: [{ id: column.id, title: "Col", default_sort: "recency" }],
            },
          }

      expect(response.status).to eq(200)
      expect(column.reload.default_sort).to eq("recency")
      expect(response.parsed_body["board"]["columns"][0]["default_sort"]).to eq("recency")
    end

    it "rejects users not in the manage group" do
      sign_in(outsider)

      post "/kanban/boards.json", params: { board: { name: "Nope", slug: "nope" } }

      expect(response.status).to eq(403)
    end
  end

  describe "PUT /kanban/boards/:id" do
    it "updates board attributes for users in the manage group" do
      board =
        DiscourseKanban::Board.create!(name: "Old Name", slug: "old-name", created_by_id: admin.id)
      board.columns.create!(title: "Col", position: 0)

      sign_in(manager)

      put "/kanban/boards/#{board.id}.json",
          params: {
            board: {
              name: "New Name",
              show_tags: true,
              columns: [{ id: board.columns.first.id, title: "Renamed" }],
            },
          }

      expect(response.status).to eq(200)
      board.reload
      expect(board.name).to eq("New Name")
      expect(board.show_tags).to eq(true)
      expect(board.columns.first.title).to eq("Renamed")
    end

    it "rejects users not in the manage group" do
      board =
        DiscourseKanban::Board.create!(
          name: "Protected",
          slug: "protected",
          allow_write_group_ids: [write_group.id],
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/kanban/boards/#{board.id}.json", params: { board: { name: "Hacked" } }

      expect(response.status).to eq(403)
    end
  end

  describe "POST /kanban/boards/:id/move-column" do
    fab!(:sales_tag, :tag) { Fabricate(:tag, name: "sales") }
    fab!(:board_mc) do
      DiscourseKanban::Board.create!(
        name: "Move Col",
        slug: "move-col",
        tag_ids: [sales_tag.id],
        created_by_id: admin.id,
      )
    end
    fab!(:col_a) { board_mc.columns.create!(title: "A", position: 0) }
    fab!(:col_b) { board_mc.columns.create!(title: "B", position: 1) }
    fab!(:col_c) { board_mc.columns.create!(title: "C", position: 2) }

    it "swaps column positions and returns the new order" do
      sign_in(admin)

      post "/kanban/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 1,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["column_order"]).to eq([col_a.id, col_c.id, col_b.id])
      expect(col_b.reload.position).to eq(2)
      expect(col_c.reload.position).to eq(1)
    end

    it "returns 403 for non-manager users" do
      sign_in(outsider)

      post "/kanban/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 1,
           }

      expect(response.status).to eq(403)
    end

    it "returns 403 for anonymous users" do
      post "/kanban/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 1,
           }

      expect(response.status).to eq(403)
    end

    it "returns 404 for a nonexistent board" do
      sign_in(admin)

      post "/kanban/boards/0/move-column.json", params: { column_id: col_b.id, direction: 1 }

      expect(response.status).to eq(404)
    end

    it "returns 404 for a nonexistent column" do
      sign_in(admin)

      post "/kanban/boards/#{board_mc.id}/move-column.json", params: { column_id: 0, direction: 1 }

      expect(response.status).to eq(404)
    end

    it "returns 400 for an invalid direction" do
      sign_in(admin)

      post "/kanban/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 5,
           }

      expect(response.status).to eq(400)
    end

    it "returns 422 when moving past the boundary" do
      sign_in(admin)

      post "/kanban/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_c.id,
             direction: 1,
           }

      expect(response.status).to eq(422)
    end
  end

  describe "DELETE /kanban/boards/:id" do
    it "deletes a board for users in the manage group" do
      board =
        DiscourseKanban::Board.create!(
          name: "Deletable",
          slug: "deletable",
          created_by_id: admin.id,
        )

      sign_in(manager)

      expect { delete "/kanban/boards/#{board.id}.json" }.to change {
        DiscourseKanban::Board.count
      }.by(-1)

      expect(response.status).to eq(204)
    end

    it "rejects users not in the manage group" do
      board =
        DiscourseKanban::Board.create!(
          name: "Protected",
          slug: "protected",
          created_by_id: admin.id,
        )

      sign_in(outsider)

      delete "/kanban/boards/#{board.id}.json"

      expect(response.status).to eq(403)
    end
  end
end
