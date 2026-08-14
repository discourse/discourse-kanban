import { render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import KanbanAddFromTopicMenu from "discourse/plugins/discourse-kanban/discourse/components/kanban-add-from-topic-menu";

function board(id, name, columns) {
  return {
    id,
    name,
    unicode_name: name,
    columns: columns.map(({ id: columnId, title, icon }) => ({
      id: columnId,
      title,
      unicode_title: title,
      icon,
      cards: [],
    })),
  };
}

module("Integration | Component | KanbanAddFromTopicMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("shows skeleton rows while boards load", async function (assert) {
    let resolveBoards;
    const boardsResponse = new Promise((resolve) => {
      resolveBoards = resolve;
    });

    pretender.get("/kanban/boards", async () => {
      await boardsResponse;
      return response({
        boards: [board(1, "Roadmap", [{ id: 11, title: "Next" }])],
      });
    });

    const renderPromise = render(
      <template><KanbanAddFromTopicMenu /></template>
    );
    await waitUntil(() =>
      document.querySelector(".kanban-add-from-topic-menu__skeleton")
    );

    assert.dom(".kanban-add-from-topic-menu__skeleton").exists({ count: 3 });
    assert.dom(".kanban-add-from-topic-menu__board").doesNotExist();

    resolveBoards();
    await renderPromise;
    await settled();

    assert.dom(".kanban-add-from-topic-menu__skeleton").doesNotExist();
    assert.dom(".kanban-add-from-topic-menu__board").hasText("Roadmap");
  });

  test("only lists boards that have columns", async function (assert) {
    pretender.get("/kanban/boards", () =>
      response({
        boards: [
          board(1, "Roadmap", [{ id: 11, title: "Next" }]),
          board(2, "Empty board", []),
        ],
      })
    );

    await render(<template><KanbanAddFromTopicMenu /></template>);

    assert.dom(".kanban-add-from-topic-menu__board").hasText("Roadmap");
    assert.dom(".kanban-add-from-topic-menu__board").exists({ count: 1 });
    assert
      .dom(".kanban-add-from-topic-menu__board")
      .doesNotContainText("Empty board");
  });
});
