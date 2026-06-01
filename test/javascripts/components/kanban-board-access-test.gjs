import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
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

  test("renders only the add button when the list is empty", async function (assert) {
    const value = [];
    const noop = () => {};

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{noop}} />
      </template>
    );

    assert.dom(".kanban-board-access__rows").doesNotExist();
    assert.dom(".kanban-board-access__add").exists();
  });

  test("clicking the add button reveals the group chooser", async function (assert) {
    const value = [];
    const noop = () => {};

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{noop}} />
      </template>
    );

    await click(".kanban-board-access__add");

    assert.dom(".kanban-board-access__chooser").exists();
    assert.dom(".kanban-board-access__add").doesNotExist();
  });

  test("selecting a group adds it as a new row with default editor level", async function (assert) {
    let captured;
    const value = [];
    const onChange = (next) => (captured = next);

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{onChange}} />
      </template>
    );

    await click(".kanban-board-access__add");
    await selectKit(".kanban-board-access__chooser").expand();
    await selectKit(".kanban-board-access__chooser").selectRowByValue(10);

    assert.deepEqual(captured, [{ group_id: 10, level: "editor" }]);
  });

  test("anonymous group is added as viewer by default", async function (assert) {
    let captured;
    const value = [];
    const onChange = (next) => (captured = next);

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{onChange}} />
      </template>
    );

    await click(".kanban-board-access__add");
    await selectKit(".kanban-board-access__chooser").expand();
    await selectKit(".kanban-board-access__chooser").selectRowByValue(4);

    assert.deepEqual(captured, [{ group_id: 4, level: "viewer" }]);
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

    await fillIn(
      ".kanban-board-access__row[data-group-id='10'] .kanban-board-access__level",
      "viewer"
    );

    assert.deepEqual(captured, [{ group_id: 10, level: "viewer" }]);
  });

  test("selecting remove deletes the row", async function (assert) {
    let captured;
    const value = [
      { group_id: 4, level: "viewer" },
      { group_id: 10, level: "editor" },
    ];
    const onChange = (next) => (captured = next);

    await render(
      <template>
        <KanbanBoardAccess @value={{value}} @onChange={{onChange}} />
      </template>
    );

    await fillIn(
      ".kanban-board-access__row[data-group-id='10'] .kanban-board-access__level",
      "remove"
    );

    assert.deepEqual(captured, [{ group_id: 4, level: "viewer" }]);
  });
});
