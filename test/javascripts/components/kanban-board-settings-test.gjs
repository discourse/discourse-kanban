import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
      const group = this.site.groups[0];
      this.board.acl = [
        {
          type: "group",
          id: group.id,
          permission: "manage",
          display_name: group.name,
        },
      ];
      this.model = {
        board: this.board,
        isNew: true,
        onSave: sinon.spy(),
        onDelete: () => {},
      };
      this.closeModal = sinon.spy();
    });

    test("slug placeholder is set to the slugified board name", async function (assert) {
      await render(
        <template>
          <KanbanBoardSettings @model={{this.model}} @inline={{true}} />
        </template>
      );

      assert.dom(".discourse-kanban-board-settings-modal").exists();
      await click(".discourse-kanban-editable-title__text");
      await fillIn(".discourse-kanban-editable-title__input", "Apollo Program");

      assert.strictEqual(
        formKit().field("slug").inputElement.placeholder,
        "apollo-program"
      );
    });

    test("reports confirmed access loss when the saved modal closes", async function (assert) {
      const dialog = getOwner(this).lookup("service:dialog");
      sinon.stub(dialog, "confirm").resolves(true);

      pretender.post("/access-control/evaluate.json", () =>
        response(422, {
          errors: ["You will lose permission to manage this board."],
          extras: {
            current_user_will_lose_permission: true,
            loss_warning_permissions: ["manage"],
          },
        })
      );

      await render(
        <template>
          <KanbanBoardSettings
            @model={{this.model}}
            @closeModal={{this.closeModal}}
            @inline={{true}}
          />
        </template>
      );

      await formKit().submit();

      assert.true(this.model.onSave.calledOnce, "the board is saved");
      assert.deepEqual(
        this.closeModal.firstCall.args,
        [{ reloadAfterSave: true }],
        "the modal requests a reload after it closes"
      );
    });
  }
);
