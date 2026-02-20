# frozen_string_literal: true

describe "Kanban Board Viewer", type: :system do
  fab!(:user)
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:manage_group, :group)
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
  end

  def create_board(attrs = {})
    DiscourseKanban::Board.create!(
      {
        name: "Sprint Board",
        slug: "sprint-board",
        created_by_id: admin.id,
        require_confirmation: true,
        show_tags: true,
        show_activity_indicators: true,
      }.merge(attrs),
    )
  end

  def add_topic_card(board, column, topic)
    board.cards.create!(
      topic_id: topic.id,
      column_id: column.id,
      card_type: :topic,
      membership_mode: :manual_in,
      position: column.cards.count,
      created_by_id: admin.id,
    )
  end

  context "when viewing a board" do
    it "displays columns and cards" do
      board = create_board
      col_todo = board.columns.create!(title: "To Do", position: 0, icon: "list")
      col_done = board.columns.create!(title: "Done", position: 1, icon: "check")

      topic1 = Fabricate(:topic, title: "Implement login page", category: category)
      topic2 = Fabricate(:topic, title: "Write unit tests", category: category)
      topic3 = Fabricate(:topic, title: "Deploy to staging", category: category)

      add_topic_card(board, col_todo, topic1)
      add_topic_card(board, col_todo, topic2)
      add_topic_card(board, col_done, topic3)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_board_title("Sprint Board")
      expect(board_viewer).to have_column("To Do")
      expect(board_viewer).to have_column("Done")
      expect(board_viewer).to have_card_in_column("To Do", "Implement login page")
      expect(board_viewer).to have_card_in_column("To Do", "Write unit tests")
      expect(board_viewer).to have_card_in_column("Done", "Deploy to staging")
      expect(board_viewer.card_count_in_column("To Do")).to eq(2)
      expect(board_viewer.card_count_in_column("Done")).to eq(1)
    end
  end

  context "when visiting a board with the wrong slug" do
    it "redirects to the correct slug" do
      board = create_board
      board.columns.create!(title: "To Do", position: 0)

      sign_in(user)
      board_viewer.visit_board_with_slug("wrong-slug", board)

      expect(board_viewer).to have_board_title("Sprint Board")
      expect(page).to have_current_path("/kanban/boards/sprint-board/#{board.id}")
    end
  end

  context "when dragging cards with confirmation" do
    it "moves card after confirming" do
      board = create_board(allow_write_group_ids: [Group::AUTO_GROUPS[:everyone]])
      col_todo = board.columns.create!(title: "To Do", position: 0)
      col_done = board.columns.create!(title: "Done", position: 1, move_to_status: "closed")

      topic1 = Fabricate(:topic, title: "Fix the bug", category: category)
      add_topic_card(board, col_todo, topic1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_card_in_column("To Do", "Fix the bug")

      board_viewer.drag_card_to_column("Fix the bug", "Done")
      dialog.click_yes

      expect(board_viewer).to have_card_in_column("Done", "Fix the bug")
      expect(board_viewer).to have_no_card_in_column("To Do", "Fix the bug")
    end
  end

  context "when user has read-only access" do
    it "cards are not draggable" do
      board = create_board
      col_todo = board.columns.create!(title: "To Do", position: 0)

      topic1 = Fabricate(:topic, title: "Read only topic", category: category)
      add_topic_card(board, col_todo, topic1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_card_in_column("To Do", "Read only topic")
      expect(board_viewer.card_draggable?("Read only topic")).to eq(false)
    end
  end

  context "when cards have tags" do
    it "shows tags but filters column tags" do
      board = create_board(show_tags: true, allow_write_group_ids: [Group::AUTO_GROUPS[:everyone]])
      col_todo = board.columns.create!(title: "To Do", position: 0, move_to_tag: "priority")
      col_done = board.columns.create!(title: "Done", position: 1)

      topic1 = Fabricate(:topic, title: "Tagged topic", category: category, tags: [tag1, tag2])
      add_topic_card(board, col_todo, topic1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_tag_on_card("Tagged topic", "frontend")
      expect(board_viewer).to have_no_tag_on_card("Tagged topic", "priority")
    end
  end

  context "when show_activity_indicators is enabled" do
    it "shows stale indicator for old topics" do
      board = create_board(show_activity_indicators: true)
      col_todo = board.columns.create!(title: "To Do", position: 0)

      topic1 = Fabricate(:topic, title: "Stale topic", category: category, bumped_at: 25.days.ago)
      add_topic_card(board, col_todo, topic1)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_activity_indicator("Stale topic", "card-stale")
    end
  end

  context "with floater cards" do
    it "creates a floater card via the add card button" do
      board = create_board(allow_write_group_ids: [Group::AUTO_GROUPS[:everyone]])
      board.columns.create!(title: "To Do", position: 0)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_add_card_button_in_column("To Do")
      board_viewer.click_add_card("To Do")
      board_viewer.fill_card_title("My new task")
      board_viewer.submit_card

      expect(board_viewer).to have_floater_card_in_column("To Do", "My new task")
      expect(DiscourseKanban::Card.find_by(title: "My new task")).to be_present
    end

    it "allows inline editing of a floater card title" do
      board = create_board(allow_write_group_ids: [Group::AUTO_GROUPS[:everyone]])
      col_todo = board.columns.create!(title: "To Do", position: 0)
      board.cards.create!(
        card_type: :floater,
        membership_mode: :manual_in,
        title: "Old task name",
        column_id: col_todo.id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_floater_card_in_column("To Do", "Old task name")

      board_viewer.click_floater_title("Old task name")
      expect(board_viewer).to have_card_edit_input
      board_viewer.fill_card_edit("Updated task name")
      board_viewer.save_card_edit_with_enter

      expect(board_viewer).to have_floater_card_in_column("To Do", "Updated task name")
      expect(DiscourseKanban::Card.find_by(title: "Updated task name")).to be_present
    end

    it "does not show add card button for read-only users" do
      board = create_board
      board.columns.create!(title: "To Do", position: 0)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_no_add_card_button_in_column("To Do")
    end
  end

  context "with controls menu" do
    it "toggles fullscreen mode" do
      board = create_board
      board.columns.create!(title: "To Do", position: 0)

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_no_fullscreen
      board_viewer.open_controls_menu
      board_viewer.click_fullscreen

      expect(board_viewer).to have_fullscreen
      board_viewer.click_exit_fullscreen
      expect(board_viewer).to have_no_fullscreen
    end

    it "shows configure option for users in the manage group" do
      board = create_board
      board.columns.create!(title: "To Do", position: 0)

      sign_in(manager)
      board_viewer.visit_board(board)

      board_viewer.open_controls_menu
      expect(board_viewer).to have_configure_option
    end

    it "hides configure option for users not in the manage group" do
      board = create_board
      board.columns.create!(title: "To Do", position: 0)

      sign_in(user)
      board_viewer.visit_board(board)

      board_viewer.open_controls_menu
      expect(board_viewer).to have_no_configure_option
    end
  end
end
