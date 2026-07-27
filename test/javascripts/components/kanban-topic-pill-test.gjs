import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import KanbanTopicPill from "discourse/plugins/discourse-kanban/discourse/components/kanban-topic-pill";

function membership({ boardId, boardName, cardId, columnId, columnTitle }) {
  return {
    board_id: boardId,
    board_name: boardName,
    board_slug: boardName.toLowerCase(),
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

  test("lists each board with its column chips in the multi-board menu", async function (assert) {
    this.topic = {
      kanban_memberships: [
        membership({
          boardId: 1,
          boardName: "Sales",
          cardId: 101,
          columnId: 11,
          columnTitle: "In progress",
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

    const labels = [
      ...document.querySelectorAll(".kanban-topic-pill__menu-item-label"),
    ].map((el) => el.textContent.trim());
    assert.deepEqual(labels, ["Sales", "Support"]);
    assert
      .dom(".kanban-topic-pill__menu-item .kanban-topic-pill__column")
      .exists({ count: 2 });
  });
});
