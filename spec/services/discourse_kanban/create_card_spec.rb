# frozen_string_literal: true

RSpec.describe DiscourseKanban::CreateCard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:board) do
      DiscourseKanban::Board.create!(
        name: "Board",
        slug: "board",
        allow_write_group_ids: [write_group.id],
        allow_read_group_ids: [read_group.id],
        created_by_id: admin.id,
      )
    end
    fab!(:column) { board.columns.create!(title: "To Do", position: 0) }

    let(:dependencies) { { guardian: Guardian.new(writer) } }

    before do
      enable_current_plugin
      SiteSetting.discourse_kanban_enabled = true
      write_group.add(writer)
      read_group.add(reader)
    end

    context "when creating a floater card" do
      let(:params) { { board_id: board.id, column_id: column.id, title: "New Task" } }

      it { is_expected.to run_successfully }

      it "creates a floater card" do
        card = result[:card]
        expect(card.card_type).to eq("floater")
        expect(card.title).to eq("New Task")
        expect(card.column_id).to eq(column.id)
        expect(card.created_by_id).to eq(writer.id)
      end
    end

    context "when creating a topic card" do
      let(:params) { { board_id: board.id, column_id: column.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: Guardian.new(admin) } }

      it { is_expected.to run_successfully }

      it "creates a topic card" do
        card = result[:card]
        expect(card.card_type).to eq("topic")
        expect(card.topic_id).to eq(topic.id)
        expect(card.column_id).to eq(column.id)
      end
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, column_id: column.id, title: "Test" } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, column_id: 0, title: "Test" } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot write" do
      let(:params) { { board_id: board.id, column_id: column.id, title: "Test" } }
      let(:dependencies) { { guardian: Guardian.new(reader) } }

      it { is_expected.to fail_a_policy(:can_write) }
    end

    context "when topic does not exist" do
      let(:params) { { board_id: board.id, column_id: column.id, topic_id: -1 } }
      let(:dependencies) { { guardian: Guardian.new(admin) } }

      it "raises NotFound" do
        expect { result }.to raise_error(Discourse::NotFound)
      end
    end

    context "when user cannot see the topic" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }
      let(:params) { { board_id: board.id, column_id: column.id, topic_id: private_topic.id } }

      it "raises NotFound" do
        expect { result }.to raise_error(Discourse::NotFound)
      end
    end

    context "when creating a card for a category definition topic" do
      fab!(:category_with_def, :category_with_definition)
      let(:params) do
        { board_id: board.id, column_id: column.id, topic_id: category_with_def.topic_id }
      end
      let(:dependencies) { { guardian: Guardian.new(admin) } }

      it "raises an error" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end
end
