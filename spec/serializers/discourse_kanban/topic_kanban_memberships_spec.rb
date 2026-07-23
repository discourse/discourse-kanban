# frozen_string_literal: true

RSpec.describe "topic kanban_memberships serialization" do
  fab!(:admin)
  fab!(:reader, :user)
  fab!(:read_group, :group)
  fab!(:topic)

  fab!(:board) { Fabricate(:kanban_board, name: "Sales", slug: "sales", created_by: admin) }
  fab!(:column) do
    Fabricate(:kanban_column, board:, title: "In progress", color: "0088cc", icon: "angles-up")
  end
  fab!(:card) { Fabricate(:kanban_topic_card, board:, column:, topic:) }

  before do
    enable_current_plugin
    read_group.add(reader)
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "view",
      groups: [read_group],
    )
  end

  def list_item_json(user)
    TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json
  end

  def topic_view_json(user)
    TopicViewSerializer.new(TopicView.new(topic, user), scope: Guardian.new(user), root: false)
      .as_json
  end

  describe "topic list item serializer" do
    it "includes memberships for users who can read the board" do
      expect(list_item_json(reader)[:kanban_memberships]).to eq(
        [
          {
            card_id: card.id,
            board_id: board.id,
            board_name: "Sales",
            board_slug: "sales",
            board_column_count: 1,
            board_created_by: {
              username: board.created_by.username,
              avatar_template: board.created_by.avatar_template,
            },
            column_id: column.id,
            column_title: "In progress",
            column_color: "0088cc",
            column_icon: "angles-up",
          },
        ],
      )
    end

    it "omits memberships for users who cannot read the board" do
      other_user = Fabricate(:user)
      expect(list_item_json(other_user)).not_to have_key(:kanban_memberships)
    end

    it "omits the attribute when the plugin is disabled" do
      SiteSetting.discourse_kanban_enabled = false
      expect(list_item_json(reader)).not_to have_key(:kanban_memberships)
    end

    it "omits the attribute for topics without cards" do
      card.destroy!
      topic.kanban_board_cards = nil
      expect(list_item_json(reader)).not_to have_key(:kanban_memberships)
    end

    it "uses preloaded cards when present" do
      DiscourseKanban::TopicBoardMemberships.preload([topic])
      expect(topic.kanban_board_cards.map(&:id)).to eq([card.id])

      queries =
        track_sql_queries { list_item_json(reader) }.select { |q| q.include?("kanban_cards") }
      expect(queries).to be_empty
    end
  end

  describe "topic view serializer" do
    it "includes memberships for users who can read the board" do
      memberships = topic_view_json(reader)[:kanban_memberships]
      expect(memberships.map { |m| m[:card_id] }).to eq([card.id])
    end

    it "omits memberships for users who cannot read the board" do
      other_user = Fabricate(:user)
      expect(topic_view_json(other_user)).not_to have_key(:kanban_memberships)
    end
  end
end
