# frozen_string_literal: true

describe "Kanban Board Viewer" do
  fab!(:user)
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:manage_group, :group)
  fab!(:write_group, :group)
  fab!(:category)
  fab!(:tag1, :tag) { Fabricate(:tag, name: "priority") }
  fab!(:tag2, :tag) { Fabricate(:tag, name: "frontend") }

  let(:board_viewer) { PageObjects::Pages::KanbanBoardViewer.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
    SiteSetting.discourse_kanban_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
    write_group.add(user)
  end

  class CreateBoardResult
    attr_reader :board, :columns

    def initialize(board, columns = {})
      @board = board
      @columns = columns
    end

    def column(title)
      columns[title]
    end
  end

  def create_board(attrs = {}, with_columns: [])
    board =
      DiscourseKanban::Board.create!(
        {
          name: "Sprint Board",
          slug: "sprint-board",
          created_by_id: admin.id,
          require_confirmation: true,
          show_tags: true,
          show_activity_indicators: true,
          category_ids: [category.id],
        }.merge(attrs),
      )

    columns =
      with_columns.each_with_object({}) do |column_attrs, hash|
        title = column_attrs[:title] || column_attrs["title"]
        hash[title] = board.columns.create!(column_attrs)
      end

    CreateBoardResult.new(board, columns)
  end

  def add_topic_card(board, column, topic)
    card = board.cards.find_by(topic_id: topic.id)
    if card
      card.update!(column_id: column.id) if card.column_id != column.id
      return card
    end
    board.cards.create!(
      topic_id: topic.id,
      column_id: column.id,
      card_type: :topic,
      position: column.cards.count,
      created_by_id: admin.id,
    )
  end

  context "when viewing a board" do
    it "displays columns and cards" do
      result =
        create_board(
          { tag_ids: [tag1.id, tag2.id] },
          with_columns: [
            { title: "To Do", position: 0, icon: "list", tag_id: tag1.id },
            { title: "Done", position: 1, icon: "check", tag_id: tag2.id },
          ],
        )
      board = result.board

      topic_1 = Fabricate(:topic, title: "Implement login page", category: category, tags: [tag1])
      topic2 =
        Fabricate(
          :topic,
          title: "Write integration test coverage",
          category: category,
          tags: [tag1],
        )
      topic3 = Fabricate(:topic, title: "Deploy to staging", category: category, tags: [tag2])

      add_topic_card(board, result.column("To Do"), topic_1)
      add_topic_card(board, result.column("To Do"), topic2)
      add_topic_card(board, result.column("Done"), topic3)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_board_title("Sprint Board")
      expect(board_viewer).to have_column("To Do")
      expect(board_viewer).to have_column("Done")
      expect(board_viewer).to have_card_in_column("To Do", "Implement login page")
      expect(board_viewer).to have_card_in_column("To Do", "Write integration test coverage")
      expect(board_viewer).to have_card_in_column("Done", "Deploy to staging")
      expect(board_viewer.card_count_in_column("To Do")).to eq(2)
      expect(board_viewer.card_count_in_column("Done")).to eq(1)
    end
  end

  context "when visiting a board with the wrong slug" do
    it "redirects to the correct slug" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])

      sign_in(user)
      board_viewer.visit_board_with_slug("wrong-slug", result.board)

      expect(board_viewer).to have_board_title("Sprint Board")
      expect(page).to have_current_path("/kanban/boards/sprint-board/#{result.board.id}")
    end
  end

  context "when dragging cards with confirmation" do
    it "moves card after confirming" do
      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }, { title: "Done", position: 1 }],
        )
      board = result.board

      topic_1 = Fabricate(:topic, title: "Fix critical checkout regression", category: category)
      add_topic_card(board, result.column("To Do"), topic_1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_card_in_column("To Do", "Fix critical checkout regression")

      board_viewer.drag_card_to_column("Fix critical checkout regression", "Done")
      dialog.click_yes

      expect(board_viewer).to have_card_in_column("Done", "Fix critical checkout regression")
      expect(board_viewer).to have_no_card_in_column("To Do", "Fix critical checkout regression")
    end
  end

  context "when dragging cards without confirmation" do
    it "moves card immediately" do
      result =
        create_board(
          { allow_write_group_ids: [write_group.id], require_confirmation: false },
          with_columns: [{ title: "To Do", position: 0 }, { title: "Done", position: 1 }],
        )
      board = result.board

      topic_1 = Fabricate(:topic, title: "Polish release checklist", category: category)
      add_topic_card(board, result.column("To Do"), topic_1)

      sign_in(user)
      board_viewer.visit_board(board)

      board_viewer.drag_card_to_column("Polish release checklist", "Done")

      expect(board_viewer).to have_card_in_column("Done", "Polish release checklist")
      expect(board_viewer).to have_no_card_in_column("To Do", "Polish release checklist")
    end
  end

  context "when user has read-only access" do
    it "cards are not draggable" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])
      board = result.board

      topic_1 = Fabricate(:topic, title: "Read only topic", category: category)
      add_topic_card(board, result.column("To Do"), topic_1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_card_in_column("To Do", "Read only topic")
      expect(board_viewer.card_draggable?("Read only topic")).to eq(false)
    end
  end

  context "when cards have tags" do
    it "shows tags but filters column tags" do
      result =
        create_board(
          { show_tags: true, allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0, tag_id: tag1.id }],
        )
      board = result.board

      topic_1 =
        Fabricate(
          :topic,
          title: "Refine frontend labeling workflow",
          category: category,
          tags: [tag1, tag2],
        )
      add_topic_card(board, result.column("To Do"), topic_1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_tag_on_card("Refine frontend labeling workflow", "frontend")
      expect(board_viewer).to have_no_tag_on_card("Refine frontend labeling workflow", "priority")
    end
  end

  context "when show_activity_indicators is enabled" do
    it "shows stale indicator for old topics" do
      result =
        create_board(
          { show_activity_indicators: true },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board

      topic_1 =
        Fabricate(
          :topic,
          title: "Audit inactive onboarding checklist",
          category: category,
          bumped_at: 25.days.ago,
        )
      add_topic_card(board, result.column("To Do"), topic_1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_activity_indicator(
        "Audit inactive onboarding checklist",
        "card-stale",
      )
    end
  end

  context "with floater cards" do
    it "creates a floater card via the add card button" do
      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_add_card_button_in_column("To Do")
      board_viewer.click_add_card("To Do")
      board_viewer.fill_card_title("My new task")
      board_viewer.submit_card

      expect(board_viewer).to have_floater_card_in_column("To Do", "My new task")
      expect(DiscourseKanban::Card.find_by(title: "My new task")).to be_present
    end

    it "persists tags when creating a floater card" do
      SiteSetting.tagging_enabled = true

      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board

      sign_in(admin)
      board_viewer.visit_board(board)

      board_viewer.click_add_card("To Do")
      board_viewer.fill_card_title("Tagged task")
      board_viewer.select_card_detail_tag(tag1.name)
      board_viewer.submit_card

      expect(board_viewer).to have_floater_card_in_column("To Do", "Tagged task")
      expect(board_viewer).to have_card_tag("Tagged task", tag1.name)
      expect(DiscourseKanban::Card.find_by!(title: "Tagged task").tag_ids).to eq([tag1.id])
    end

    it "opens the card detail modal when clicking a floater card" do
      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board
      board.cards.create!(
        card_type: :floater,
        title: "Old task name",
        column_id: result.column("To Do").id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(admin)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_floater_card_in_column("To Do", "Old task name")

      board_viewer.click_floater_card("Old task name")
      expect(board_viewer).to have_card_detail_modal
      board_viewer.fill_card_detail_title("Updated task name")
      board_viewer.save_card_detail

      expect(board_viewer).to have_floater_card_in_column("To Do", "Updated task name")
      expect(DiscourseKanban::Card.find_by(title: "Updated task name")).to be_present
    end

    it "shows an edit action in the floater card menu" do
      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board
      board.cards.create!(
        card_type: :floater,
        title: "Old task name",
        column_id: result.column("To Do").id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(admin)
      board_viewer.visit_board(board)

      board_viewer.open_card_actions("Old task name")
      expect(board_viewer).to have_edit_card_action
      board_viewer.click_edit_card
      expect(board_viewer).to have_card_detail_modal
      board_viewer.cancel_card_detail
    end

    it "adds tags to a card via the tag chooser" do
      SiteSetting.tagging_enabled = true
      Tag.find_or_create_by!(name: "urgent")

      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board
      board.cards.create!(
        card_type: :floater,
        title: "Tag me",
        column_id: result.column("To Do").id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(admin)
      board_viewer.visit_board(board)

      board_viewer.click_floater_card("Tag me")
      expect(board_viewer).to have_card_detail_modal

      board_viewer.select_card_detail_tag("urgent")
      expect(board_viewer).to have_card_detail_tag("urgent")

      board_viewer.save_card_detail
      expect(board_viewer).to have_card_tag("Tag me", "urgent")
    end

    it "creates a new tag from the card detail modal" do
      SiteSetting.tagging_enabled = true
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board
      board.cards.create!(
        card_type: :floater,
        title: "Needs new tag",
        column_id: result.column("To Do").id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(admin)
      board_viewer.visit_board(board)

      board_viewer.click_floater_card("Needs new tag")
      expect(board_viewer).to have_card_detail_modal

      board_viewer.create_card_detail_tag("brand-new-tag")
      expect(board_viewer).to have_card_detail_tag("brand-new-tag")

      board_viewer.save_card_detail

      expect(board_viewer).to have_card_tag("Needs new tag", "brand-new-tag")
      card = DiscourseKanban::Card.find_by!(title: "Needs new tag")
      tag = Tag.find_by(name: "brand-new-tag")
      expect(tag).to be_present
      expect(card.tag_ids).to include(tag.id)
    end

    it "tabs from the title to notes and leaves close last" do
      result =
        create_board(
          { allow_write_group_ids: [write_group.id] },
          with_columns: [{ title: "To Do", position: 0 }],
        )
      board = result.board

      sign_in(admin)
      board_viewer.visit_board(board)

      board_viewer.click_add_card("To Do")
      expect(board_viewer).to have_card_detail_modal

      find(".kanban-card-detail-modal .kanban-editable-title__input").send_keys(:tab)
      expect(page.active_element).to eq(
        first(
          ".kanban-card-detail-modal .form-kit__field[data-name='notes'] .d-editor-button-bar button",
          minimum: 1,
        ),
      )

      find(".kanban-card-detail-modal .d-modal-cancel").send_keys(:tab)

      expect(page.active_element).to eq(
        find(".kanban-card-detail-modal .kanban-card-detail-modal__close"),
      )
    end

    it "does not show add card button for read-only users" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])

      sign_in(user)
      board_viewer.visit_board(result.board)

      expect(board_viewer).to have_no_add_card_button_in_column("To Do")
    end
  end

  context "with topic card detail modal" do
    it "opens the topic detail modal when clicking a topic card" do
      result = create_board({ show_tags: true }, with_columns: [{ title: "To Do", position: 0 }])
      board = result.board

      topic = Fabricate(:topic, title: "Implement search feature", category: category, tags: [tag1])
      Fabricate(:post, topic: topic, raw: "Here is the **plan** for implementing search.")
      Fabricate(:post, topic: topic, raw: "Looks great, let's do it!")

      add_topic_card(board, result.column("To Do"), topic)

      sign_in(user)
      board_viewer.visit_board(board)

      board_viewer.click_topic_card("Implement search feature")
      expect(board_viewer).to have_topic_card_detail_modal
      expect(board_viewer).to have_topic_card_detail_cooked
      expect(board_viewer).to have_topic_card_detail_category
      expect(board_viewer).to have_topic_card_detail_tags
      expect(board_viewer).to have_topic_card_detail_reply_count
      expect(page).to have_current_path(
        "/kanban/boards/sprint-board/#{board.id}/card/#{board.cards.last.id}",
      )

      find(".modal-close").click
      expect(board_viewer).to have_no_topic_card_detail_modal
      expect(page).to have_current_path("/kanban/boards/sprint-board/#{board.id}")
    end

    it "opens the topic detail modal when visiting a card URL directly" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])
      board = result.board

      topic = Fabricate(:topic, title: "Fix the login bug on mobile", category: category)
      Fabricate(:post, topic: topic, raw: "Login is broken on mobile.")

      card = add_topic_card(board, result.column("To Do"), topic)

      sign_in(user)
      board_viewer.visit_card(board, card)

      expect(board_viewer).to have_board_title("Sprint Board")
      expect(board_viewer).to have_topic_card_detail_modal
      expect(board_viewer).to have_topic_card_detail_cooked
    end
  end

  context "with controls menu" do
    it "toggles fullscreen mode" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])

      sign_in(user)
      board_viewer.visit_board(result.board)

      expect(board_viewer).to have_no_fullscreen
      board_viewer.click_fullscreen

      expect(board_viewer).to have_fullscreen
      board_viewer.click_exit_fullscreen
      expect(board_viewer).to have_no_fullscreen
    end

    it "shows board settings option for users in the manage group" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])

      sign_in(manager)
      board_viewer.visit_board(result.board)

      board_viewer.open_controls_menu
      expect(board_viewer).to have_board_settings_option
    end

    it "hides board settings option for users not in the manage group" do
      result = create_board(with_columns: [{ title: "To Do", position: 0 }])

      sign_in(user)
      board_viewer.visit_board(result.board)

      board_viewer.open_controls_menu
      expect(board_viewer).to have_no_board_settings_option
    end
  end

  context "when board tag filter excludes topics that match column tag" do
    fab!(:tag_car, :tag) { Fabricate(:tag, name: "car") }
    fab!(:tag_animal, :tag) { Fabricate(:tag, name: "animal") }
    fab!(:tag_fast, :tag) { Fabricate(:tag, name: "fast") }

    it "does not show topics missing the board tag even if they have the column tag" do
      result =
        create_board(
          { tag_ids: [tag_car.id], category_ids: [], slug: "car-board", name: "Car Board" },
          with_columns: [{ title: "Fast", position: 0, tag_id: tag_fast.id }],
        )

      Fabricate(
        :topic,
        title: "My fast car topic for testing",
        category: category,
        tags: [tag_car, tag_fast],
      )
      Fabricate(
        :topic,
        title: "My fast animal topic for testing",
        category: category,
        tags: [tag_animal, tag_fast],
      )

      sign_in(user)
      board_viewer.visit_board(result.board)

      expect(board_viewer).to have_card_in_column("Fast", "My fast car topic for testing")
      expect(board_viewer).to have_no_card_in_column("Fast", "My fast animal topic for testing")
    end
  end
end
