# frozen_string_literal: true

RSpec.describe DiscourseKanban::TopicBoardMemberships do
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

  let(:list_item_json) do
    ->(user) { TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json }
  end

  let(:topic_view_json) do
    lambda do |user|
      TopicViewSerializer.new(
        TopicView.new(topic, user),
        scope: Guardian.new(user),
        root: false,
      ).as_json
    end
  end

  describe "topic list item serializer" do
    it "includes memberships for users who can read the board" do
      expect(list_item_json.call(reader)[:kanban_memberships]).to eq(
        [
          {
            board_id: board.id,
            board_name: "Sales",
            board_slug: "sales",
            board_column_count: 1,
            board_created_by: {
              username: board.created_by.username,
              avatar_template: board.created_by.avatar_template,
            },
            cards: [
              {
                card_id: card.id,
                column_id: column.id,
                column_title: "In progress",
                column_color: "0088cc",
                column_icon: "angles-up",
              },
            ],
          },
        ],
      )
    end

    it "omits memberships for users who cannot read the board" do
      other_user = Fabricate(:user)
      expect(list_item_json.call(other_user)).not_to have_key(:kanban_memberships)
    end

    it "omits the attribute when the plugin is disabled" do
      SiteSetting.discourse_kanban_enabled = false
      expect(list_item_json.call(reader)).not_to have_key(:kanban_memberships)
    end

    it "omits the attribute for topics without cards" do
      card.destroy!
      topic.kanban_board_cards = nil
      expect(list_item_json.call(reader)).not_to have_key(:kanban_memberships)
    end

    it "groups multiple topic cards from the same board into one membership" do
      second_column = Fabricate(:kanban_column, board:, title: "Done", position: 1, color: "00aa66")
      second_card = Fabricate(:kanban_topic_card, board:, column: second_column, topic:)

      membership = list_item_json.call(reader)[:kanban_memberships].sole

      expect(membership[:board_id]).to eq(board.id)
      expect(membership[:board_column_count]).to eq(2)
      expect(membership[:cards].pluck(:card_id)).to eq([card.id, second_card.id])
    end

    it "uses preloaded cards when present" do
      DiscourseKanban::TopicBoardMemberships.preload([topic])
      expect(topic.kanban_board_cards.map(&:id)).to eq([card.id])

      queries =
        track_sql_queries { list_item_json.call(reader) }.select { |q| q.include?("kanban_cards") }
      expect(queries).to be_empty
    end

    it "batches board ACL checks" do
      2.times do |index|
        extra_board =
          Fabricate(
            :kanban_board,
            name: "Board #{index}",
            slug: "board-#{index}",
            created_by: admin,
          )
        extra_column = Fabricate(:kanban_column, board: extra_board, position: 0)
        Fabricate(:kanban_topic_card, board: extra_board, column: extra_column, topic:)
        Fabricate(
          :access_control_list_with_groups,
          target: extra_board,
          permission: "view",
          groups: [read_group],
        )
      end
      topic.kanban_board_cards = nil

      acl_queries =
        track_sql_queries do
          DiscourseKanban::TopicBoardMemberships.serialize(topic, Guardian.new(reader.reload))
        end.select { |query| query.include?("access_control_lists") }

      expect(acl_queries.size).to be <= 2
    end
  end

  describe "topic view serializer" do
    it "includes memberships for users who can read the board" do
      memberships = topic_view_json.call(reader)[:kanban_memberships]
      expect(memberships.flat_map { |membership| membership[:cards] }.pluck(:card_id)).to eq(
        [card.id],
      )
    end

    it "omits memberships for users who cannot read the board" do
      other_user = Fabricate(:user)
      expect(topic_view_json.call(other_user)).not_to have_key(:kanban_memberships)
    end
  end
end
