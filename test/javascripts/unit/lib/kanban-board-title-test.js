import { module, test } from "qunit";
import { kanbanBoardTitle } from "discourse/plugins/discourse-kanban/discourse/lib/kanban-board-title";

module("Unit | Lib | kanban-board-title", function () {
  test("prefers the Unicode name", function (assert) {
    const board = { name: "Launch :rocket:", unicode_name: "Launch 🚀" };

    assert.strictEqual(kanbanBoardTitle(board), "Launch 🚀");
  });

  test("falls back to the original name", function (assert) {
    assert.strictEqual(kanbanBoardTitle({ name: "Launch" }), "Launch");
    assert.strictEqual(kanbanBoardTitle(), undefined);
  });
});
