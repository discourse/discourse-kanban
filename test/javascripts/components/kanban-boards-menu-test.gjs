import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import KanbanBoardsMenu from "discourse/plugins/discourse-kanban/discourse/components/kanban-boards-menu";

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

module("Integration | Component | KanbanBoardsMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("lists each board with its column chips", async function (assert) {
    this.data = {
      memberships: [
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
    this.close = () => {};

    await render(
      <template>
        <KanbanBoardsMenu @data={{this.data}} @close={{this.close}} />
      </template>
    );

    const labels = [
      ...document.querySelectorAll(".kanban-boards-menu__item-label"),
    ].map((el) => el.textContent.trim());
    assert.deepEqual(labels, ["Sales", "Support"]);

    assert
      .dom(".kanban-boards-menu__item .kanban-boards-menu__column")
      .exists({ count: 2 });
    assert
      .dom(".kanban-boards-menu__column")
      .hasText("In progress", "shows the column the card sits in");
  });

  test("lists every column when a topic has several cards on one board", async function (assert) {
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
    this.data = { memberships: [sales] };
    this.close = () => {};

    await render(
      <template>
        <KanbanBoardsMenu @data={{this.data}} @close={{this.close}} />
      </template>
    );

    assert.dom(".kanban-boards-menu__item-label").exists({ count: 1 });
    assert.dom(".kanban-boards-menu__column").exists({ count: 2 });
  });
});
