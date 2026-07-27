import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import KanbanTopicPill from "discourse/plugins/discourse-kanban/discourse/components/kanban-topic-pill";

function membership({
  boardId,
  boardName,
  cardId,
  columnId,
  columnTitle,
  createdBy,
}) {
  return {
    board_id: boardId,
    board_name: boardName,
    board_slug: boardName.toLowerCase(),
    board_column_count: 2,
    board_created_by: createdBy,
    cards: [
      {
        card_id: cardId,
        column_id: columnId,
        column_title: columnTitle,
        column_color: "0088cc",
        column_icon: "list",
      },
    ],
  };
}

module("Integration | Component | KanbanTopicPill", function (hooks) {
  setupRenderingTest(hooks);

  test("renders one board pill when the topic has multiple cards on that board", async function (assert) {
    const sales = membership({
      boardId: 1,
      boardName: "Sales",
      cardId: 101,
      columnId: 11,
      columnTitle: "In progress",
    });
    sales.cards.push({
      card_id: 102,
      column_id: 12,
      column_title: "Done",
      column_color: "00aa66",
      column_icon: "check",
    });
    this.topic = { kanban_memberships: [sales] };

    await render(
      <template><KanbanTopicPill @topic={{this.topic}} /></template>
    );

    assert.dom("a.kanban-topic-pill").hasText("Sales");
    assert
      .dom("a.kanban-topic-pill")
      .hasAttribute("href", "/kanban/boards/sales/1?card=101")
      .hasAttribute("title", "This topic is in 2 columns of the Sales board");
    assert.dom(".kanban-topic-pill--multiple").doesNotExist();
  });

  test("identifies board creators by display name in the multi-board menu", async function (assert) {
    this.topic = {
      kanban_memberships: [
        membership({
          boardId: 1,
          boardName: "Sales",
          cardId: 101,
          columnId: 11,
          columnTitle: "In progress",
          createdBy: {
            username: "jordan",
            display_name: "jordan",
            avatar_template: "/letter_avatar_proxy/v4/letter/j/{size}.png",
          },
        }),
        membership({
          boardId: 2,
          boardName: "Support",
          cardId: 201,
          columnId: 21,
          columnTitle: "Queued",
        }),
      ],
    };

    await render(
      <template><KanbanTopicPill @topic={{this.topic}} /></template>
    );
    await click(".kanban-topic-pill--multiple");

    assert
      .dom(".kanban-topic-pill__fact")
      .hasText(
        "Created by jordan",
        "the avatar is accompanied by creator text"
      );
  });
});
