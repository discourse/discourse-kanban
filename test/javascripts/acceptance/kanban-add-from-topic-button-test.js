import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Kanban add topic footer button", function (needs) {
  needs.user({ can_edit_any_kanban_boards: true });

  test("renders with the core topic footer buttons and opens its menu", async function (assert) {
    pretender.get("/kanban/boards-list", () =>
      response({
        boards: [
          {
            id: 1,
            name: "Roadmap",
            columns: [
              { id: 11, title: "Next", cards: [] },
              { id: 12, title: "Done", cards: [] },
            ],
          },
        ],
      })
    );

    await visit("/t/internationalization-localization/280");

    assert
      .dom(
        ".topic-footer-main-buttons__actions #topic-footer-button-kanban-add-from-topic"
      )
      .exists();
    assert
      .dom(
        "#topic-footer-button-kanban-add-from-topic .d-icon-discourse-kanban"
      )
      .exists();

    await click("#topic-footer-button-kanban-add-from-topic");

    assert.dom(".kanban-add-from-topic-menu").exists();

    await triggerEvent(".kanban-add-from-topic-menu__board-item", "mouseenter");

    assert
      .dom(".kanban-add-from-topic-column-menu__column")
      .exists({ count: 2 });
  });
});
