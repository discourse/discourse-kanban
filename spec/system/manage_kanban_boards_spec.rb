# frozen_string_literal: true

describe "Manage Kanban Boards", type: :system do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:regular_user, :user)
  fab!(:manage_group, :group)

  let(:boards_page) { PageObjects::Pages::KanbanManageBoards.new }
  let(:form) { PageObjects::Components::FormKit.new(".kanban-board-form") }
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

      form.field("name").fill_in("Sprint Board")
      form.field("require_confirmation").toggle
      form.submit

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = DiscourseKanban::Board.last
      expect(board.name).to eq("Sprint Board")
      expect(board.require_confirmation).to eq(false)

      boards_page.visit_page
      expect(boards_page).to have_board_listed("Sprint Board")

      boards_page.click_edit("Sprint Board")
      form.field("name").fill_in("Updated Board")
      form.submit

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(board.reload.name).to eq("Updated Board")

      boards_page.visit_page
      expect(boards_page).to have_board_listed("Updated Board")

      boards_page.click_edit("Updated Board")
      boards_page.click_delete
      dialog.click_yes

      expect(boards_page).to have_empty_state
      expect(DiscourseKanban::Board.count).to eq(0)
    end

    it "can create a board with columns" do
      boards_page.visit_new

      form.field("name").fill_in("Workflow Board")

      find(".kanban-columns-editor__add-btn").click
      all(".kanban-columns-editor__column-fields input[type='text']").first.fill_in(with: "To Do")

      find(".kanban-columns-editor__add-btn").click
      columns = all(".kanban-columns-editor__column")
      columns.last.all("input[type='text']").first.fill_in(with: "Done")

      form.submit
      expect(toasts).to have_success(I18n.t("js.saved"))

      board = DiscourseKanban::Board.last
      expect(board.name).to eq("Workflow Board")
      expect(board.columns.order(:position).pluck(:title)).to eq(["To Do", "Done"])
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
      expect(boards_page).to have_no_edit_button("Visible Board")
    end
  end

  context "when user is an admin" do
    before { sign_in(admin) }

    it "can manage boards regardless of group membership" do
      boards_page.visit_page
      expect(boards_page).to have_new_board_button

      boards_page.click_new_board
      form.field("name").fill_in("Admin Board")
      form.submit

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(DiscourseKanban::Board.find_by(name: "Admin Board")).to be_present
    end
  end
end
