import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import KanbanBoardAccess from "discourse/plugins/discourse-kanban/discourse/components/kanban-board-access";

module("Integration | Component | KanbanBoardAccess", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a row per access entry", async function (assert) {
    const value = [
      { group_id: 4, level: "viewer" },
      { group_id: 10, level: "editor" },
    ];
    const noop = () => {};

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{noop}} />
      </template>
    );

    assert.dom(".kanban-board-access__row").exists({ count: 2 });
    assert.dom(".kanban-board-access__row[data-group-id='4']").exists();
    assert.dom(".kanban-board-access__row[data-group-id='10']").exists();
  });

  test("changing a level emits the updated access list", async function (assert) {
    let captured;
    const value = [{ group_id: 10, level: "editor" }];
    const onChange = (next) => (captured = next);

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{onChange}} />
      </template>
    );

    await click(
      ".kanban-board-access__row[data-group-id='10'] .kanban-board-access__level"
    );
    await click(".fk-d-menu__inner-content .kanban-board-access__level-viewer");

    assert.deepEqual(captured, [{ group_id: 10, level: "viewer" }]);
  });
});
