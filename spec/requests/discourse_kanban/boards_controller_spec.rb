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
    SiteSetting.discourse_kanban_enabled = true
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
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Backlog", position: 0, icon: "list")
      board.cards.create!(
        card_type: :topic,
        membership_mode: :manual_in,
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

    it "includes topic details for detailed cards" do
      topic = Fabricate(:topic, category: category)
      board =
        DiscourseKanban::Board.create!(
          name: "Detailed",
          slug: "detailed",
          card_style: "detailed",
          created_by_id: admin.id,
        )
      col = board.columns.create!(title: "Col", position: 0)
      board.cards.create!(
        card_type: :topic,
        membership_mode: :manual_in,
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

      board = DiscourseKanban::Board.create!(name: "Mixed", slug: "mixed", created_by_id: admin.id)
      col = board.columns.create!(title: "Col", position: 0)

      board.cards.create!(
        card_type: :topic,
        membership_mode: :manual_in,
        topic_id: visible_topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )
      board.cards.create!(
        card_type: :topic,
        membership_mode: :manual_in,
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

    it "backfills cards for topics matching the board filter" do
      topic = Fabricate(:topic, category: category)
      board =
        DiscourseKanban::Board.create!(
          name: "Auto Board",
          slug: "auto-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Backlog", position: 0)

      sign_in(admin)
      get "/kanban/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      cards = response.parsed_body["columns"][0]["cards"]
      expect(cards.length).to eq(1)
      expect(cards[0]["topic"]["id"]).to eq(topic.id)
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
