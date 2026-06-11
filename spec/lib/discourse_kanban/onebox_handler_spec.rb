# frozen_string_literal: true

RSpec.describe DiscourseKanban::OneboxHandler do
  fab!(:admin)

  before { enable_current_plugin }

  fab!(:board) do
    DiscourseKanban::Board.create!(
      name: "Roadmap board",
      slug: "roadmap-board",
      allow_read_group_ids: [Group::AUTO_GROUPS[:anonymous_users], Group::AUTO_GROUPS[:trust_level_0]],
      created_by_id: admin.id,
    )
  end

  fab!(:topic) { Fabricate(:topic, title: "Topic card headline") }

  fab!(:column) { board.columns.create!(title: "Todo", position: 0) }
  fab!(:tag_1, :tag)
  fab!(:tag_2, :tag)
  fab!(:category) { Fabricate(:category, name: "events", slug: "events") }

  fab!(:floater_card) do
    board.cards.create!(
      card_type: :floater,
      title: "Standalone card title",
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
      tag_ids: [tag_1.id, tag_2.id],
      notes: "This is **markdown** _note_",
    )
  end

  fab!(:topic_card) do
    board.cards.create!(
      card_type: :topic,
      topic_id: topic.id,
      column_id: column.id,
      position: 1,
      created_by_id: admin.id,
    )
  end

  describe "card onebox" do
    it "returns empty string if the card does not exist" do
      floater_card.destroy!
      expect(
        DiscourseKanban::OneboxHandler.handle(
          floater_card.url,
          { id: board.id, card_id: floater_card.id },
        ),
      ).to eq("")
    end

    it "returns empty string if the user does not have permission to read the board" do
      private_group = Fabricate(:group)
      board.update!(
        allow_read_group_ids: [private_group.id],
        allow_write_group_ids: [private_group.id],
      )
      expect(
        DiscourseKanban::OneboxHandler.handle(
          floater_card.url,
          { id: board.id, card_id: floater_card.id },
        ),
      ).to eq("")
    end

    it "does not return empty string if the onebox renders successfully" do
      expect(
        DiscourseKanban::OneboxHandler.handle(
          floater_card.url,
          { id: board.id, card_id: floater_card.id },
        ),
      ).not_to eq("")
    end

    it "has the correct HTML structure" do
      onebox_html =
        DiscourseKanban::OneboxHandler.handle(
          floater_card.url,
          { id: board.id, card_id: floater_card.id },
        )

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-kanban-card__title",
          href: floater_card.url,
        },
        seen: floater_card.resolved_title,
      )

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-kanban-board-pill",
          href: board.url,
        },
        seen: board.name,
      )

      expect(onebox_html).to have_tag(
        "span",
        with: {
          class: "discourse-kanban-column-pill",
        },
        seen: column.title,
      )

      expect(onebox_html).to have_tag("div", with: { class: "discourse-kanban-card__tags" })

      floater_card.tags.each do |tag|
        expect(onebox_html).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            "data-slug": tag.name,
          },
          seen: tag.name,
        )
      end

      expect(onebox_html).to have_tag(
        "div",
        with: {
          class: "discourse-kanban-card__notes",
        },
        seen: "This is markdown note",
      )

      expect(onebox_html).to have_tag(
        "span",
        with: {
          class: "relative-date",
          "data-time": (floater_card.updated_at.to_f * 1000).to_i,
          "data-format": "tiny",
        },
      )

      expect(onebox_html).to include(
        "(#{floater_card.updated_by&.username || floater_card.created_by.username})",
      )
      expect(onebox_html).to have_tag("aside", with: { class: "onebox" })
    end
  end

  describe "board onebox" do
    it "returns empty string if the board does not exist" do
      board.destroy!
      expect(DiscourseKanban::OneboxHandler.handle(board.url, { id: board.id })).to eq("")
    end

    it "returns empty string if the user does not have permission to read the board" do
      private_group = Fabricate(:group)
      board.update!(
        allow_read_group_ids: [private_group.id],
        allow_write_group_ids: [private_group.id],
      )
      expect(DiscourseKanban::OneboxHandler.handle(board.url, { id: board.id })).to eq("")
    end

    it "does not return empty string if the onebox renders successfully" do
      expect(DiscourseKanban::OneboxHandler.handle(board.url, { id: board.id })).not_to eq("")
    end

    it "has the correct HTML structure" do
      board.update!(tag_ids: [tag_1.id, tag_2.id], category_ids: [category.id])

      onebox_html = DiscourseKanban::OneboxHandler.handle(board.url, { id: board.id })

      expect(onebox_html).to have_tag("aside", with: { class: "onebox" })

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-kanban-board-card__name",
          href: board.url,
        },
        seen: board.name,
      )

      expect(onebox_html).to have_tag(
        "div",
        with: {
          class: "discourse-kanban-board-card__constraints",
        },
      )
      expect(onebox_html).to have_tag("div", with: { class: "list-tags" })

      board.tags.each do |tag|
        expect(onebox_html).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            "data-slug": tag.name,
          },
          seen: tag.name,
        )
      end

      board.categories.each do |board_category|
        expect(onebox_html).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            "data-slug": board_category.slug,
          },
          seen: board_category.name,
        )
      end

      expect(onebox_html).to have_tag(
        "div",
        with: {
          class: "discourse-kanban-board-card__columns",
        },
      )

      board.columns.each do |board_column|
        expect(onebox_html).to have_tag(
          "span",
          with: {
            class: "discourse-kanban-column-pill",
          },
          seen: board_column.title,
        )
      end

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-kanban-board-card__creator discourse-kanban-badge trigger-user-card",
          "data-user-card": admin.username,
        },
        seen: I18n.t("discourse_kanban.onebox.created_by", username: admin.display_name),
      )

      expect(onebox_html).to have_tag(
        "span",
        with: {
          class: "discourse-kanban-badge",
        },
        seen: I18n.t("discourse_kanban.onebox.column_count", count: board.columns.count),
      )
    end

    context "when the board is restricted" do
      fab!(:private_group, :group)

      before do
        board.update!(
          allow_read_group_ids: [private_group.id],
          allow_write_group_ids: [private_group.id],
        )
        guardian = instance_double(Guardian, can_read_board?: true)
        allow(Guardian).to receive(:new).with(Discourse.system_user).and_return(guardian)
      end

      it "has the correct HTML structure" do
        onebox_html = DiscourseKanban::OneboxHandler.handle(board.url, { id: board.id })

        expect(onebox_html).to have_tag(
          "span",
          with: {
            class: "discourse-kanban-badge discourse-kanban-badge--restricted",
          },
        )
      end
    end
  end
end
