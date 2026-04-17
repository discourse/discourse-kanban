# frozen_string_literal: true

describe "Manage Kanban Boards" do
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
      expect(board.require_confirmation).to eq(true)

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

      boards_page.visit_page
      boards_page.click_new_board
      boards_page.save_board_modal
      expect(boards_page.board_form.field("name")).to have_errors("Required")
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

    it "persists board tag filter when creating a board with a tag" do
      Fabricate(:tag, name: "a11y")

      boards_page.visit_page
      boards_page.click_new_board
      boards_page.fill_modal_board_name("Accessibility Board")
      boards_page.select_modal_board_tag("a11y")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = DiscourseKanban::Board.find_by(name: "Accessibility Board")
      expect(board).to be_present
      expect(board.tag_ids).to contain_exactly(Tag.find_by(name: "a11y").id)
    end

    it "creates a column with a tag" do
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

      boards_page.fill_modal_column_title("Todo")
      boards_page.select_modal_column_tag(todo_tag.name)
      boards_page.save_column_modal

      column = board.reload.columns.find_by(title: "Todo")
      expect(column.tag_id).to eq(todo_tag.id)
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
