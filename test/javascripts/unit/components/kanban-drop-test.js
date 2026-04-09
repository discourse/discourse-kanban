import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import KanbanBoardViewer from "discourse/plugins/discourse-kanban/discourse/components/kanban-board-viewer";
import { shouldInsertSourceDropIndicator } from "discourse/plugins/discourse-kanban/discourse/components/kanban-card";
import KanbanColumn, {
  shouldAnimateDropIndicatorPlacement,
} from "discourse/plugins/discourse-kanban/discourse/components/kanban-column";

function createDropTarget() {
  const column = document.createElement("div");
  column.className = "kanban-column";

  const cardsContainer = document.createElement("div");
  cardsContainer.className = "kanban-column__cards";

  column.append(cardsContainer);
  return column;
}

module("Discourse Kanban | Unit | Components | kanban drop", function (hooks) {
  setupTest(hooks);

  test("the initial placeholder in the source column does not animate", function (assert) {
    assert.false(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: false,
        columnId: 10,
        fromColumnId: 10,
        hasPlacedIndicator: false,
      }),
      "it skips the first placeholder animation in the source column"
    );
    assert.true(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: true,
        columnId: 10,
        fromColumnId: 10,
        hasPlacedIndicator: true,
      }),
      "it still animates after the placeholder already exists"
    );
    assert.true(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: false,
        columnId: 20,
        fromColumnId: 10,
        hasPlacedIndicator: false,
      }),
      "it still animates the initial placement in a different column"
    );
    assert.true(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: false,
        columnId: 10,
        fromColumnId: 10,
        hasPlacedIndicator: true,
      }),
      "it animates when re-entering the source column later in the drag"
    );
  });

  test("source placeholder insertion is skipped once a live placeholder exists", function (assert) {
    const root = document.createElement("div");

    assert.true(
      shouldInsertSourceDropIndicator(root),
      "it allows the source placeholder before any live placeholder exists"
    );

    const sourceIndicator = document.createElement("div");
    sourceIndicator.className =
      "kanban-column__drop-indicator kanban-column__drop-indicator--source";
    root.append(sourceIndicator);

    assert.true(
      shouldInsertSourceDropIndicator(root),
      "it ignores the hidden source placeholder"
    );

    const liveIndicator = document.createElement("div");
    liveIndicator.className = "kanban-column__drop-indicator";
    root.append(liveIndicator);

    assert.false(
      shouldInsertSourceDropIndicator(root),
      "it skips inserting the source placeholder after dragover has created a live placeholder"
    );
  });

  test("drops preserve the source column after drag state has cleared", function (assert) {
    const onDrop = sinon.spy();
    const removeDropIndicator = sinon.spy();

    const component = Object.assign(Object.create(KanbanColumn.prototype), {
      args: {
        dragData: {
          cardId: 101,
          fromColumnId: 10,
          cardHeight: 48,
          hasPlacedIndicator: false,
        },
        column: { id: 20, title: "Done" },
        board: { require_confirmation: true },
        allColumns: [],
        onDrop,
      },
      findCardTitle() {
        return "Fix checkout";
      },
      removeDropIndicator,
    });

    component.drop({
      preventDefault() {},
      clientY: 0,
      currentTarget: createDropTarget(),
    });

    component.args.dragData = null;

    assert.true(removeDropIndicator.calledOnce);
    assert.true(
      onDrop.calledOnceWithExactly(101, 20, null, 10),
      "it passes the original source column into the drop callback"
    );
  });

  test("board viewer completes a drop with explicit source column after dragData is cleared", async function (assert) {
    pretender.put("/kanban/boards/1/cards/101", (request) => {
      const data = parsePostData(request.requestBody);

      assert.strictEqual(data.client_id, "test-client");
      assert.strictEqual(data.card.column_id, "20");
      assert.strictEqual(data.card.after_card_id, "102");

      return response({
        card: {
          id: 101,
          column_id: 20,
          position: 1,
          topic_id: 9001,
        },
      });
    });

    const highlightDroppedCard = sinon.spy();
    const viewer = Object.assign(Object.create(KanbanBoardViewer.prototype), {
      board: { id: 1 },
      columns: [
        {
          id: 10,
          cards: [{ id: 101, column_id: 10, position: 0, topic_id: 9001 }],
        },
        {
          id: 20,
          cards: [{ id: 102, column_id: 20, position: 0, topic_id: 9002 }],
        },
      ],
      dragData: null,
      messageBus: { clientId: "test-client" },
      _highlightDroppedCard: highlightDroppedCard,
    });

    await viewer.onDrop(101, 20, 102, 10);

    assert.deepEqual(
      viewer.columns
        .find((column) => column.id === 10)
        .cards.map(({ id }) => id),
      [],
      "it removes the card from the source column"
    );
    assert.deepEqual(
      viewer.columns
        .find((column) => column.id === 20)
        .cards.map(({ id }) => id),
      [102, 101],
      "it inserts the card into the target column"
    );
    assert.true(
      highlightDroppedCard.calledOnceWithExactly(101),
      "it still highlights the dropped card after the save succeeds"
    );
  });
});
