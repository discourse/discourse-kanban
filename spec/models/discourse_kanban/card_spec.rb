# frozen_string_literal: true

RSpec.describe DiscourseKanban::Card do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test-card", created_by_id: admin.id)
  end
  fab!(:column) { board.columns.create!(title: "Col", position: 0) }

  describe "validations" do
    it "is valid as a floater with title and column" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "A task",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).to be_valid
    end

    it "is valid as a topic card with topic and column" do
      card =
        board.cards.build(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).to be_valid
    end

    it "requires title for floater cards" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: nil,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:title]).to include("can't be blank")
    end

    it "requires topic_id for topic cards" do
      card =
        board.cards.build(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: nil,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:topic_id]).to include("can't be blank")
    end

    it "normalizes card_type to topic when topic_id is present" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.valid?
      expect(card.card_type).to eq("topic")
    end

    it "requires column_id for floater cards" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Orphan",
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:column_id]).to include("can't be blank")
    end

    it "allows nil column_id for manual_out topic cards" do
      card =
        board.cards.build(
          card_type: :topic,
          membership_mode: :manual_out,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).to be_valid
    end

    it "requires column_id for manual_in topic cards" do
      card =
        board.cards.build(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:column_id]).to include("can't be blank")
    end

    it "requires position" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "No position",
          column_id: column.id,
          position: nil,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:position]).to include("can't be blank")
    end
  end

  describe "normalize_card_type" do
    it "auto-sets card_type to topic when topic_id is present" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.valid?
      expect(card.card_type).to eq("topic")
    end

    it "does not change card_type when topic_id is blank" do
      card =
        board.cards.build(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Floater",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.valid?
      expect(card.card_type).to eq("floater")
    end
  end

  describe "scopes" do
    it ".with_column returns only cards with a column" do
      in_col =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "In column",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      board.cards.create!(
        card_type: :topic,
        membership_mode: :manual_out,
        topic_id: topic.id,
        column_id: nil,
        position: 0,
        created_by_id: admin.id,
      )

      expect(described_class.with_column.pluck(:id)).to eq([in_col.id])
    end

    it ".ordered sorts by position then id" do
      card_b =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "B",
          column_id: column.id,
          position: 1,
          created_by_id: admin.id,
        )
      card_a =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "A",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )

      expect(described_class.ordered.pluck(:id)).to eq([card_a.id, card_b.id])
    end
  end
end
