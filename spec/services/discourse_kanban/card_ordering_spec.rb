# frozen_string_literal: true

RSpec.describe DiscourseKanban::CardOrdering do
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test-ordering", created_by_id: admin.id)
  end
  fab!(:column) { board.columns.create!(title: "Col A", position: 0) }

  def create_card(title:, position:, column: nil)
    board.cards.create!(
      card_type: :floater,
      membership_mode: :manual_in,
      title: title,
      column_id: (column || self.column).id,
      position: position,
      created_by_id: admin.id,
    )
  end

  describe ".place_card!" do
    it "places a card at the end when no after_card_id given" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: 1)
      new_card = create_card(title: "New", position: 99)

      described_class.place_card!(new_card, column: column)

      expect(card1.reload.position).to eq(0)
      expect(card2.reload.position).to eq(1)
      expect(new_card.reload.position).to eq(2)
    end

    it "places a card after the specified card" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: 1)
      card3 = create_card(title: "Third", position: 2)

      described_class.place_card!(card3, column: column, after_card_id: card1.id)

      expect(card1.reload.position).to eq(0)
      expect(card3.reload.position).to eq(1)
      expect(card2.reload.position).to eq(2)
    end

    it "places a card at position 0 when after_card_id is absent and column is empty" do
      new_card = create_card(title: "Solo", position: 5)

      described_class.place_card!(new_card, column: column)

      expect(new_card.reload.position).to eq(0)
    end

    it "moves a card from one column to another" do
      col_b = board.columns.create!(title: "Col B", position: 1)
      card = create_card(title: "Mover", position: 0)
      target_card = create_card(title: "Target", position: 0, column: col_b)

      described_class.place_card!(card, column: col_b, after_card_id: target_card.id)

      expect(card.reload.column_id).to eq(col_b.id)
      expect(card.position).to eq(1)
    end

    it "reorders within the same column" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: 1)
      card3 = create_card(title: "Third", position: 2)

      described_class.place_card!(card1, column: column, after_card_id: card2.id)

      expect(card2.reload.position).to eq(0)
      expect(card1.reload.position).to eq(1)
      expect(card3.reload.position).to eq(2)
    end

    it "excludes the card itself from siblings during reorder" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: 1)

      described_class.place_card!(card2, column: column, after_card_id: card1.id)

      expect(card1.reload.position).to eq(0)
      expect(card2.reload.position).to eq(1)
    end

    it "handles invalid after_card_id by appending to end" do
      card1 = create_card(title: "First", position: 0)
      new_card = create_card(title: "New", position: 5)

      described_class.place_card!(new_card, column: column, after_card_id: -999)

      expect(card1.reload.position).to eq(0)
      expect(new_card.reload.position).to eq(1)
    end
  end

  describe ".append_to_column!" do
    it "sets position after the last card in the column" do
      create_card(title: "First", position: 0)
      create_card(title: "Second", position: 1)
      new_card = board.cards.build(card_type: :floater, title: "Appended", created_by_id: admin.id)

      described_class.append_to_column!(new_card, column)

      expect(new_card.column_id).to eq(column.id)
      expect(new_card.position).to eq(2)
    end

    it "sets position to 0 for an empty column" do
      new_card = board.cards.build(card_type: :floater, title: "First", created_by_id: admin.id)

      described_class.append_to_column!(new_card, column)

      expect(new_card.position).to eq(1)
    end

    it "does not persist the card" do
      new_card = board.cards.build(card_type: :floater, title: "Unsaved", created_by_id: admin.id)

      described_class.append_to_column!(new_card, column)

      expect(new_card).to be_new_record
    end
  end
end
