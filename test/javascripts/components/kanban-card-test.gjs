import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import KanbanCard from "discourse/plugins/discourse-kanban/discourse/components/kanban-card";
import KanbanFabricators from "discourse/plugins/discourse-kanban/discourse/lib/fabricators";

module("Integration | Component | KanbanCard", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new KanbanFabricators(getOwner(this));
    this.card = this.fabricators.card();
    this.board = this.fabricators.board();
    this.card.board_id = this.board.id;
  });

  test("renders basic card", async function (assert) {
    await render(
      <template>
        <KanbanCard @card={{this.card}} @board={{this.board}} />
      </template>
    );
    assert.dom(".discourse-kanban-card").exists();
    assert.dom(".discourse-kanban-card__title").hasText(this.card.title);
  });

  test("suppresses column tags on floater cards", async function (assert) {
    this.card.tags = [
      { id: 1, name: "todo", slug: "todo" },
      { id: 2, name: "unrelated", slug: "unrelated" },
    ];
    this.columnTags = ["todo"];

    await render(
      <template>
        <KanbanCard
          @card={{this.card}}
          @board={{this.board}}
          @columnTags={{this.columnTags}}
        />
      </template>
    );

    assert.dom(".discourse-kanban-card__tags").hasText("unrelated");
    assert.dom(".discourse-kanban-card__tags").doesNotContainText("todo");
  });
});

module(
  "Integration | Component | KanbanCard | Discourse Assign",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.fabricators = new KanbanFabricators(getOwner(this));
      this.card = this.fabricators.card();
      this.board = this.fabricators.board();
      this.board.card_style = "detailed";
      this.card.board_id = this.board.id;
      this.currentUser.can_assign = true;
      this.siteSettings.assign_enabled = true;
    });

    test("does not render assign button when assign_enabled is false", async function (assert) {
      this.siteSettings.assign_enabled = false;
      await render(
        <template>
          <KanbanCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-kanban-card__assign-btn").doesNotExist();
    });

    test("renders assign button for a floating card", async function (assert) {
      this.card.card_type = "floater";
      await render(
        <template>
          <KanbanCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-kanban-card__assign-btn").exists();
    });

    test("renders assign button for a topic card", async function (assert) {
      const topic = this.fabricators.coreFabricators.topic();
      this.card.card_type = "topic";
      this.card.topic_id = topic.id;
      this.card.topic = topic;

      await render(
        <template>
          <KanbanCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-kanban-card__assign-btn").exists();
    });

    test("does not render assignment for a closed topic card", async function (assert) {
      const topic = this.fabricators.coreFabricators.topic();
      topic.closed = true;
      this.card.card_type = "topic";
      this.card.topic_id = topic.id;
      this.card.topic = topic;
      topic.closed = true;
      await render(
        <template>
          <KanbanCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-kanban-card__assign-btn").doesNotExist();
    });
  }
);
