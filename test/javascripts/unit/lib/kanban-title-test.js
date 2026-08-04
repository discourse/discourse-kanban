import { module, test } from "qunit";
import {
  kanbanColumnTitle,
  kanbanMembershipBoardName,
  kanbanTitle,
} from "discourse/plugins/discourse-kanban/discourse/lib/kanban-title";

module("Unit | Lib | kanban-title", function () {
  test("prefers a Unicode card or column title", function (assert) {
    const record = { title: "Launch :rocket:", unicode_title: "Launch 🚀" };

    assert.strictEqual(kanbanTitle(record), "Launch 🚀");
  });

  test("falls back to the raw title", function (assert) {
    assert.strictEqual(kanbanTitle({ title: "Launch" }), "Launch");
    assert.strictEqual(kanbanTitle(), undefined);
  });

  test("prefers a Unicode membership column title", function (assert) {
    const card = {
      column_title: "Doing :rocket:",
      unicode_column_title: "Doing 🚀",
    };

    assert.strictEqual(kanbanColumnTitle(card), "Doing 🚀");
    assert.strictEqual(kanbanColumnTitle({ column_title: "Doing" }), "Doing");
  });

  test("prefers a Unicode membership board name", function (assert) {
    const membership = {
      board_name: "Sales :fire:",
      unicode_board_name: "Sales 🔥",
    };

    assert.strictEqual(kanbanMembershipBoardName(membership), "Sales 🔥");
    assert.strictEqual(
      kanbanMembershipBoardName({ board_name: "Sales" }),
      "Sales"
    );
  });
});
