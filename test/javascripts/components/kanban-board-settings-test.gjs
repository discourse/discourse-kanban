import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import KanbanBoardSettings from "discourse/plugins/discourse-kanban/discourse/components/modal/kanban-board-settings";
import KanbanFabricators from "discourse/plugins/discourse-kanban/discourse/lib/fabricators";

module(
  "Integration | Component | KanbanBoardSettings | New board",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.fabricators = new KanbanFabricators(getOwner(this));
      this.board = this.fabricators.board();
      this.model = {
        board: this.board,
        isNew: true,
        onSave: () => {},
        onDelete: () => {},
      };
      this.closeModal = () => {};
    });

    test("slug placeholder is set to the slugified board name", async function (assert) {
      await render(
        <template>
          <KanbanBoardSettings @model={{this.model}} @inline={{true}} />
        </template>
      );

      assert.dom(".kanban-board-settings-modal").exists();
      await click(".kanban-editable-title__text");
      await fillIn(".kanban-editable-title__input", "Apollo Program");

      assert.strictEqual(
        formKit().field("slug").inputElement.placeholder,
        "apollo-program"
      );
    });
  }
);
