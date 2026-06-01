import { triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Kanban keyboard shortcuts help", function (needs) {
  needs.user();
  needs.settings({ discourse_kanban_enabled: true });

  test("lists the current kanban shortcuts", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert.dom(".shortcut-category-kanban h2").hasText("Kanban");
    assert.dom(".shortcut-category-kanban tbody tr").exists({ count: 4 });

    assert
      .dom(".shortcut-category-kanban tbody")
      .includesText("Navigate boards / columns");
    assert
      .dom(".shortcut-category-kanban tbody")
      .includesText("Navigate between cards");
    assert
      .dom(".shortcut-category-kanban tbody")
      .includesText("Move selected card to an adjacent column");
    assert
      .dom(".shortcut-category-kanban tbody")
      .includesText("Reorder selected card within a manually sorted column");
  });
});
