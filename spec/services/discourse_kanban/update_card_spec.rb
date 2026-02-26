# frozen_string_literal: true

RSpec.describe DiscourseKanban::UpdateCard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) do
      described_class.call(params:, raw_card_params: raw_card_params, **dependencies)
    end

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category, user: writer) }
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Board",
        slug: "board-uc",
        allow_write_group_ids: [write_group.id],
        allow_read_group_ids: [read_group.id],
        created_by_id: admin.id,
      )
    end
    fab!(:col_todo) { board.columns.create!(title: "To Do", position: 0) }
    fab!(:col_done) { board.columns.create!(title: "Done", position: 1) }

    let(:raw_card_params) { {} }
    let(:dependencies) { { guardian: Guardian.new(writer) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      write_group.add(writer)
      read_group.add(reader)
    end

    context "when updating a floater card title" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Old",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "title" => "New" } }
      let(:params) { { board_id: board.id, id: card.id, title: "New" } }

      it { is_expected.to run_successfully }

      it "updates the title" do
        result
        expect(card.reload.title).to eq("New")
      end
    end

    context "when moving a card between columns" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Move me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }

      it { is_expected.to run_successfully }

      it "moves the card to the new column" do
        result
        expect(card.reload.column_id).to eq(col_done.id)
      end

      it "records the original column id" do
        expect(result[:original_column_id]).to eq(col_todo.id)
      end
    end

    context "when preserving notes and due_at when not provided" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Keep details",
          notes: "Important note",
          due_at: 2.days.from_now.change(usec: 0),
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "title" => "Updated" } }
      let(:params) { { board_id: board.id, id: card.id, title: "Updated" } }

      it "preserves notes and due_at" do
        original_notes = card.notes
        original_due = card.due_at
        result
        card.reload
        expect(card.notes).to eq(original_notes)
        expect(card.due_at.to_i).to eq(original_due.to_i)
      end
    end

    context "when promoting a floater to a topic card" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          notes: "Some notes",
          labels: %w[urgent],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: Guardian.new(admin) } }

      it { is_expected.to run_successfully }

      it "converts the card to a topic card" do
        result_card = result[:card]
        expect(result_card).to be_topic
        expect(result_card.topic_id).to eq(topic.id)
        expect(result_card.title).to be_nil
        expect(result_card.notes).to be_nil
        expect(result_card.labels).to eq([])
      end
    end

    context "when adopting an existing topic card" do
      fab!(:existing_topic_card) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_out,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: Guardian.new(admin) } }

      it { is_expected.to run_successfully }

      it "sets original_column_id to the adopted card's original column" do
        expect(result[:original_column_id]).to be_nil
      end

      it "sets adopted_floater_id to the floater's id" do
        expect(result[:adopted_floater_id]).to eq(card.id)
      end

      it "destroys the floater" do
        result
        expect(DiscourseKanban::Card.find_by(id: card.id)).to be_nil
      end
    end

    context "when moving a card to position 0 in a column" do
      fab!(:card_a) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Card A",
          column_id: col_done.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:card_b) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Card B",
          column_id: col_done.id,
          position: 1,
          created_by_id: admin.id,
        )
      end

      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Move to first",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "column_id" => col_done.id.to_s, "after_card_id" => "" } }
      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }

      it { is_expected.to run_successfully }

      it "places the card first in the column" do
        result
        card.reload
        card_a.reload
        card_b.reload
        expect(card.column_id).to eq(col_done.id)
        expect(card.position).to be < card_a.position
        expect(card_a.position).to be < card_b.position
      end
    end

    context "when moving a topic card into a column with a manual_out marker for the same topic" do
      fab!(:card) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :auto,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:manual_out_card) do
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_out,
          topic_id: topic.id,
          column_id: col_done.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }
      let(:raw_card_params) { { "column_id" => col_done.id.to_s } }
      let(:dependencies) { { guardian: Guardian.new(admin) } }

      it { is_expected.to run_successfully }

      it "clears the manual_out marker and moves the card" do
        marker_id = manual_out_card.id
        result
        expect(DiscourseKanban::Card.find_by(id: marker_id)).to be_nil
        expect(card.reload.column_id).to eq(col_done.id)
      end
    end

    context "when card is not found" do
      let(:params) { { board_id: board.id, id: 0 } }

      it { is_expected.to fail_to_find_a_model(:card) }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, id: 1 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot write" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Protected",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }
      let(:dependencies) { { guardian: Guardian.new(reader) } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
