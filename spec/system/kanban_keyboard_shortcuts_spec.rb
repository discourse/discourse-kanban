# frozen_string_literal: true

describe "Kanban Keyboard Shortcuts", type: :system do
  fab!(:user)
  fab!(:admin)
  fab!(:write_group, :group)

  let(:board_viewer) { PageObjects::Pages::KanbanBoardViewer.new }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
    write_group.add(user)
  end

  def create_board(attrs = {})
    DiscourseKanban::Board.create!(
      {
        name: "Sprint Board",
        slug: "sprint-board",
        created_by_id: admin.id,
        allow_write_group_ids: [write_group.id],
      }.merge(attrs),
    )
  end

  def add_floater_card(board, column, title)
    board.cards.create!(
      card_type: :floater,
      membership_mode: :manual_in,
      title: title,
      column_id: column.id,
      position: column.cards.count,
      created_by_id: admin.id,
    )
  end

  def press_key(*keys)
    find("body").send_keys(*keys)
  end

  context "when navigating cards on a board" do
    fab!(:board) do
      Fabricate(:user) # ensure admin exists
      b =
        DiscourseKanban::Board.create!(
          name: "Sprint Board",
          slug: "sprint-board",
          created_by_id: User.last.id,
          allow_write_group_ids: [write_group.id],
        )
      col1 = b.columns.create!(title: "To Do", position: 0)
      col2 = b.columns.create!(title: "Done", position: 1)
      3.times do |i|
        b.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Todo #{i + 1}",
          column_id: col1.id,
          position: i,
          created_by_id: User.last.id,
        )
      end
      2.times do |i|
        b.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Done #{i + 1}",
          column_id: col2.id,
          position: i,
          created_by_id: User.last.id,
        )
      end
      b
    end

    it "selects first card with j" do
      sign_in(user)
      board_viewer.visit_board(board)

      press_key("j")

      expect(page).to have_css(".kanban-card--kb-selected")
    end

    it "moves selection down with j and up with k" do
      sign_in(user)
      board_viewer.visit_board(board)

      press_key("j")
      first_selected = find(".kanban-card--kb-selected").text

      press_key("j")
      second_selected = find(".kanban-card--kb-selected").text

      expect(first_selected).not_to eq(second_selected)

      press_key("k")
      back_to_first = find(".kanban-card--kb-selected").text

      expect(back_to_first).to eq(first_selected)
    end

    it "moves between columns with h and l" do
      sign_in(user)
      board_viewer.visit_board(board)

      # Start in first column
      press_key("j")
      first_col_card = find(".kanban-card--kb-selected")
      first_column = first_col_card.ancestor(".kanban-column")

      # Move to second column
      press_key("l")
      second_col_card = find(".kanban-card--kb-selected")
      second_column = second_col_card.ancestor(".kanban-column")

      expect(first_column).not_to eq(second_column)

      # Move back
      press_key("h")
      back_card = find(".kanban-card--kb-selected")
      back_column = back_card.ancestor(".kanban-column")

      expect(back_column).to eq(first_column)
    end

    it "clears selection with Escape" do
      sign_in(user)
      board_viewer.visit_board(board)

      press_key("j")
      expect(page).to have_css(".kanban-card--kb-selected")

      press_key(:escape)
      expect(page).to have_no_css(".kanban-card--kb-selected")
    end

    it "does not interfere with input fields" do
      sign_in(user)
      board_viewer.visit_board(board)

      board_viewer.click_add_card("To Do")
      input = find(".kanban-column__card-title-input")
      input.send_keys("hjkl")

      expect(input.value).to include("hjkl")
      expect(page).to have_no_css(".kanban-card--kb-selected")
    end
  end

  context "when navigating the boards list" do
    before do
      3.times do |i|
        DiscourseKanban::Board.create!(
          name: "Board #{i + 1}",
          slug: "board-#{i + 1}",
          created_by_id: admin.id,
        )
      end
    end

    it "selects boards with h/l and opens with Enter" do
      sign_in(user)
      visit "/kanban"

      expect(page).to have_css(".kanban-board-card", count: 3)

      press_key("l")
      expect(page).to have_css(".kanban-board-card--kb-selected")

      first_selected = find(".kanban-board-card--kb-selected")
      first_name = first_selected.find(".kanban-board-card__name").text

      press_key("l")
      second_name = find(".kanban-board-card--kb-selected .kanban-board-card__name").text

      expect(second_name).not_to eq(first_name)

      press_key("h")
      back_name = find(".kanban-board-card--kb-selected .kanban-board-card__name").text

      expect(back_name).to eq(first_name)

      press_key(:enter)
      expect(page).to have_current_path(%r{/kanban/boards/})
    end
  end

  context "when moving cards with Shift shortcuts" do
    it "moves card to next column with Shift+l" do
      board = create_board
      col_todo = board.columns.create!(title: "To Do", position: 0)
      col_done = board.columns.create!(title: "Done", position: 1)
      add_floater_card(board, col_todo, "Move me")

      sign_in(user)
      board_viewer.visit_board(board)

      expect(board_viewer).to have_card_in_column("To Do", "Move me")

      # Select the card
      press_key("j")
      expect(page).to have_css(".kanban-card--kb-selected")

      # Move it right
      press_key(:shift, "l")

      expect(board_viewer).to have_card_in_column("Done", "Move me")
      expect(board_viewer).to have_no_card_in_column("To Do", "Move me")
    end
  end
end
