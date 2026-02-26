# frozen_string_literal: true

describe "Manage Kanban Boards", type: :system do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:regular_user, :user)
  fab!(:manage_group, :group)
  fab!(:category)
  fab!(:todo_tag, :tag) { Fabricate(:tag, name: "todo") }

  let(:boards_page) { PageObjects::Pages::KanbanManageBoards.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
    SiteSetting.discourse_kanban_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
  end

  context "when user is in the manage group" do
    before { sign_in(manager) }

    it "supports the full board lifecycle" do
      boards_page.visit_page
      expect(boards_page).to have_empty_state

      boards_page.click_new_board
      boards_page.fill_modal_board_name("Sprint Board")
      boards_page.toggle_modal_require_confirmation
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = DiscourseKanban::Board.last
      expect(board.name).to eq("Sprint Board")
      expect(board.require_confirmation).to eq(false)

      boards_page.visit_page
      expect(boards_page).to have_board_listed("Sprint Board")

      boards_page.click_board("Sprint Board")
      boards_page.open_board_menu
      boards_page.click_board_settings_menu_item
      boards_page.fill_modal_board_name("Updated Board")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(board.reload.name).to eq("Updated Board")

      boards_page.visit_page
      expect(boards_page).to have_board_listed("Updated Board")

      boards_page.click_board("Updated Board")
      boards_page.open_board_menu
      boards_page.click_board_settings_menu_item
      boards_page.delete_from_board_modal
      dialog.click_yes

      expect(boards_page).to have_empty_state
      expect(DiscourseKanban::Board.count).to eq(0)
    end

    it "can add columns to a board" do
      boards_page.visit_page
      boards_page.click_new_board
      boards_page.fill_modal_board_name("Workflow Board")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      boards_page.open_board_menu
      boards_page.click_add_column_menu_item
      boards_page.fill_modal_column_title("To Do")
      boards_page.save_column_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      boards_page.open_board_menu
      boards_page.click_add_column_menu_item
      boards_page.fill_modal_column_title("Done")
      boards_page.save_column_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = DiscourseKanban::Board.last
      expect(board.name).to eq("Workflow Board")
      expect(board.columns.order(:position).pluck(:title)).to eq(["To Do", "Done"])

      expect(boards_page).to have_column("To Do")
      expect(boards_page).to have_column("Done")
    end

    it "keeps simple columns as move-only lanes when board base filter query is blank" do
      board =
        DiscourseKanban::Board.create!(
          name: "Simple Board",
          slug: "simple-board",
          created_by_id: admin.id,
        )

      boards_page.visit_page
      boards_page.click_board("Simple Board")
      boards_page.open_board_menu
      boards_page.click_add_column_menu_item

      expect(boards_page).to have_column_modal_mode("simple")

      boards_page.fill_modal_column_title("Todo")
      boards_page.select_modal_column_tag(todo_tag.name)
      boards_page.save_column_modal

      column = board.reload.columns.find_by(title: "Todo")
      expect(column.move_to_tag).to eq(todo_tag.name)
      expect(column.filter_query).to eq("")
    end

    it "auto-sets filter query from tag in simple mode when board base filter query exists" do
      board =
        DiscourseKanban::Board.create!(
          name: "Base Filter Board",
          slug: "base-filter-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )

      boards_page.visit_page
      boards_page.click_board("Base Filter Board")
      boards_page.open_board_menu
      boards_page.click_add_column_menu_item

      expect(boards_page).to have_column_modal_mode("simple")

      boards_page.fill_modal_column_title("Todo")
      boards_page.select_modal_column_tag(todo_tag.name)
      boards_page.save_column_modal

      column = board.reload.columns.find_by(title: "Todo")
      expect(column.move_to_tag).to eq(todo_tag.name)
      expect(column.filter_query).to eq("tags:#{todo_tag.name}")
    end

    it "opens advanced mode when editing a column with advanced settings" do
      board =
        DiscourseKanban::Board.create!(
          name: "Advanced Board",
          slug: "advanced-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Doing", position: 0, filter_query: "status:closed")

      boards_page.visit_page
      boards_page.click_board("Advanced Board")
      boards_page.open_column_menu("Doing")
      boards_page.click_edit_column_menu_item

      expect(boards_page).to have_column_modal_mode("advanced")
    end

    it "resets advanced settings when switching back to simple mode" do
      board =
        DiscourseKanban::Board.create!(
          name: "Switch Board",
          slug: "switch-board",
          base_filter_query: "category:#{category.slug}",
          created_by_id: admin.id,
        )
      board.columns.create!(
        title: "Doing",
        position: 0,
        move_to_tag: todo_tag.name,
        filter_query: "status:closed",
        move_to_status: "closed",
      )

      boards_page.visit_page
      boards_page.click_board("Switch Board")
      boards_page.open_column_menu("Doing")
      boards_page.click_edit_column_menu_item

      expect(boards_page).to have_column_modal_mode("advanced")

      boards_page.switch_column_modal_mode("simple")
      dialog.click_yes
      boards_page.save_column_modal

      column = board.reload.columns.find_by(title: "Doing")
      expect(column.filter_query).to eq("tags:#{todo_tag.name}")
      expect(column.move_to_status).to eq("")
      expect(column.move_to_assigned).to eq("")
      expect(column.move_to_category_id).to be_nil
    end
  end

  context "when user is a regular user not in the manage group" do
    before { sign_in(regular_user) }

    it "can see the boards list but not management controls" do
      board =
        DiscourseKanban::Board.create!(
          name: "Visible Board",
          slug: "visible",
          created_by_id: admin.id,
        )
      board.columns.create!(title: "Col", position: 0)

      boards_page.visit_page

      expect(boards_page).to have_board_listed("Visible Board")
      expect(boards_page).to have_no_new_board_button
    end
  end

  context "when user is an admin" do
    before { sign_in(admin) }

    it "can manage boards regardless of group membership" do
      boards_page.visit_page
      expect(boards_page).to have_new_board_button

      boards_page.click_new_board
      boards_page.fill_modal_board_name("Admin Board")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(DiscourseKanban::Board.find_by(name: "Admin Board")).to be_present
    end
  end
end
