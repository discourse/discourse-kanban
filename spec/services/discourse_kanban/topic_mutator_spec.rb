# frozen_string_literal: true

RSpec.describe DiscourseKanban::TopicMutator do
  fab!(:admin)
  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:target_category) { Fabricate(:category, name: "Done") }
  fab!(:post) { Fabricate(:post, topic: Fabricate(:topic, category: category, user: user)) }
  fab!(:topic) { post.topic }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
  end

  fab!(:board) do
    DiscourseKanban::Board.create!(name: "Test", slug: "test-mutator", created_by_id: admin.id)
  end

  describe ".apply!" do
    it "raises InvalidAccess when user is nil" do
      column = board.columns.create!(title: "Col", position: 0)

      expect {
        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(nil))
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises InvalidAccess when user cannot edit the topic" do
      column = board.columns.create!(title: "Col", position: 0)
      other_user = Fabricate(:user)

      topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))

      expect {
        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(other_user))
      }.to raise_error(Discourse::InvalidAccess)
    end

    context "with move_to_tag" do
      before { SiteSetting.tagging_enabled = true }

      it "adds the configured tag to the topic" do
        Fabricate(:tag, name: "in-progress")
        column =
          board.columns.create!(title: "In Progress", position: 0, move_to_tag: "in-progress")

        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))

        expect(topic.reload.tags.map(&:name)).to include("in-progress")
      end

      it "preserves existing tags" do
        existing_tag = Fabricate(:tag, name: "existing")
        Fabricate(:tag, name: "new-tag")
        topic.tags << existing_tag

        column = board.columns.create!(title: "Col", position: 0, move_to_tag: "new-tag")

        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))

        tag_names = topic.reload.tags.map(&:name)
        expect(tag_names).to include("existing")
        expect(tag_names).to include("new-tag")
      end

      it "removes tags from other columns on the same board" do
        Fabricate(:tag, name: "todo")
        Fabricate(:tag, name: "doing")
        Fabricate(:tag, name: "done")
        unrelated_tag = Fabricate(:tag, name: "unrelated")

        board.columns.create!(title: "Todo", position: 0, move_to_tag: "todo")
        doing_column = board.columns.create!(title: "Doing", position: 1, move_to_tag: "doing")
        board.columns.create!(title: "Done", position: 2, move_to_tag: "done")

        topic.tags = [Tag.find_by(name: "todo"), unrelated_tag]

        described_class.apply!(topic: topic, column: doing_column, guardian: Guardian.new(admin))

        tag_names = topic.reload.tags.map(&:name)
        expect(tag_names).to contain_exactly("doing", "unrelated")
      end

      it "does nothing when move_to_tag is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_tag: "")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.not_to change { topic.reload.tags.count }
      end
    end

    context "with move_to_category_id" do
      it "moves the topic to the target category" do
        column =
          board.columns.create!(title: "Done", position: 0, move_to_category_id: target_category.id)

        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))

        expect(topic.reload.category_id).to eq(target_category.id)
      end

      it "raises NotFound for a missing category" do
        doomed_category = Fabricate(:category)
        column =
          board.columns.create!(title: "Col", position: 0, move_to_category_id: doomed_category.id)
        doomed_category.destroy!

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.to raise_error(Discourse::NotFound)
      end

      it "does nothing when move_to_category_id is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_category_id: nil)

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.not_to change { topic.reload.category_id }
      end
    end

    context "with move_to_status" do
      it "closes the topic when status is 'closed'" do
        column = board.columns.create!(title: "Closed", position: 0, move_to_status: "closed")

        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))

        expect(topic.reload.closed).to eq(true)
      end

      it "opens the topic when status is not 'closed'" do
        topic.update_status("closed", true, admin)
        expect(topic.reload.closed).to eq(true)

        column = board.columns.create!(title: "Open", position: 0, move_to_status: "open")

        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))

        expect(topic.reload.closed).to eq(false)
      end

      it "does nothing when move_to_status is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_status: "")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.not_to change { topic.reload.closed }
      end
    end

    context "with move_to_assigned" do
      it "does nothing when Assigner is not defined" do
        column = board.columns.create!(title: "Col", position: 0, move_to_assigned: "someone")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.not_to raise_error
      end

      it "does nothing when move_to_assigned is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_assigned: "")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.not_to raise_error
      end

      it "does nothing when move_to_assigned is '*'" do
        column = board.columns.create!(title: "Col", position: 0, move_to_assigned: "*")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: Guardian.new(admin))
        }.not_to raise_error
      end
    end
  end
end
