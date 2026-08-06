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
      this.model = {
        board: null,
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

      assert.dom(".discourse-kanban-board-settings-modal").exists();
      await fillIn(".discourse-kanban-editable-title__input", "Apollo Program");

      assert.strictEqual(
        formKit().field("slug").inputElement.placeholder,
        "apollo-program"
      );
    });

    test("default ACL is created using manage board allowed groups and logged in users", async function (assert) {
      await render(
        <template>
          <KanbanBoardSettings @model={{this.model}} @inline={{true}} />
        </template>
      );

      assert.dom(".discourse-kanban-board-settings-modal").exists();

      assert.dom(".d-access-control__row.--group[data-row-id='1']").exists();
      assert.dom(".d-access-control__row.--group[data-row-id='2']").exists();
      assert.dom(".d-access-control__row.--group[data-row-id='5']").exists();
    });

    test("default ACL does not include logged_in_users twice if they are in discourse_kanban_manage_board_allowed_groups", async function (assert) {
      this.siteSettings.discourse_kanban_manage_board_allowed_groups = "1|2|5";
      await render(
        <template>
          <KanbanBoardSettings @model={{this.model}} @inline={{true}} />
        </template>
      );

      assert.dom(".discourse-kanban-board-settings-modal").exists();

      assert.dom(".d-access-control__row.--group[data-row-id='1']").exists();
      assert.dom(".d-access-control__row.--group[data-row-id='2']").exists();
      assert
        .dom(".d-access-control__row.--group[data-row-id='5']")
        .exists({ count: 1 });
    });
  }
);
