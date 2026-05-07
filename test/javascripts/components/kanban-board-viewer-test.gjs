import { getOwner } from "@ember/owner";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import KanbanBoardViewer from "discourse/plugins/discourse-kanban/discourse/components/kanban-board-viewer";
import KanbanFabricators from "discourse/plugins/discourse-kanban/discourse/lib/fabricators";

function columnSelector(columnId) {
  return `.kanban-column[data-column-id="${columnId}"]`;
}

function cardSelector(cardId) {
  return `.kanban-card[data-card-id="${cardId}"]`;
}

function columnCardIds(columnId) {
  return [
    ...document.querySelectorAll(`${columnSelector(columnId)} .kanban-card`),
  ].map((card) => parseInt(card.dataset.cardId, 10));
}

function recentISO(daysAgo) {
  return new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000).toISOString();
}

function stubCardRect(cardId, { top = 0, height = 48 } = {}) {
  const card = document.querySelector(cardSelector(cardId));
  sinon.stub(card, "getBoundingClientRect").returns({
    top,
    bottom: top + height,
    left: 0,
    right: 200,
    width: 200,
    height,
  });
}

module("Integration | Component | KanbanBoardViewer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new KanbanFabricators(getOwner(this));

    this.messageBus = getOwner(this).lookup("service:message-bus");
    this.originalClientId = this.messageBus.clientId;
    this.messageBus.clientId = "test-client";
    sinon.stub(this.messageBus, "subscribe");
    sinon.stub(this.messageBus, "unsubscribe");

    this.renderBoard = async (columns, boardOverrides = {}) => {
      const board = this.fabricators.board({
        id: 1,
        can_write: true,
        can_manage: false,
      });
      board.require_confirmation = false;
      Object.assign(board, boardOverrides);

      this.model = { board, columns };
      await render(
        <template><KanbanBoardViewer @model={{this.model}} /></template>
      );
    };

    this.makeColumn = ({ id, title, cards = [], defaultSort } = {}) => {
      const column = this.fabricators.column({ id, title });
      column.default_sort = defaultSort;
      column.cards = cards;
      return column;
    };

    this.makeCard = ({ id, columnId, title, position, recencyAt } = {}) => {
      const card = this.fabricators.card({
        id,
        title,
        column_id: columnId,
      });
      card.position = position;
      card.recency_at = recencyAt;
      return card;
    };

    this.dragDataTransfer = null;
    this.dragCard = async (cardId) => {
      this.dragDataTransfer = new DataTransfer();
      stubCardRect(cardId);

      await triggerEvent(cardSelector(cardId), "dragstart", {
        clientX: 10,
        clientY: 10,
        dataTransfer: this.dragDataTransfer,
      });
    };

    this.dropOnColumn = async (columnId, { clientY = 0 } = {}) => {
      await triggerEvent(columnSelector(columnId), "drop", {
        clientY,
        dataTransfer: this.dragDataTransfer,
      });
    };
  });

  hooks.afterEach(function () {
    this.messageBus.clientId = this.originalClientId;
    sinon.restore();
  });

  test("completes a priority drop with the source column from drag start", async function (assert) {
    const sourceCard = this.makeCard({
      id: 101,
      columnId: 10,
      title: "Fix checkout",
      position: 0,
    });
    const targetCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      position: 0,
    });

    await this.renderBoard([
      this.makeColumn({ id: 10, title: "Todo", cards: [sourceCard] }),
      this.makeColumn({ id: 20, title: "Done", cards: [targetCard] }),
    ]);

    let requestData;
    pretender.put("/kanban/boards/1/cards/101", (request) => {
      requestData = parsePostData(request.requestBody);

      return response({
        card: {
          id: 101,
          column_id: 20,
          position: 1,
        },
      });
    });

    stubCardRect(102, { top: 0, height: 48 });
    await this.dragCard(101);
    await this.dropOnColumn(20, { clientY: 30 });

    assert.strictEqual(requestData.card.column_id, "20");
    assert.strictEqual(requestData.card.after_card_id, "102");
    assert.deepEqual(
      columnCardIds(10),
      [],
      "it removes the card from the source column"
    );
    assert.deepEqual(
      columnCardIds(20),
      [102, 101],
      "it inserts the card after the target card"
    );
    assert
      .dom(`${columnSelector(20)} ${cardSelector(101)}`)
      .hasClass(
        "kanban-card--drop-highlighted",
        "it highlights the dropped card"
      );
  });

  test("dropping into a recency column sends no after_card_id and places the card first", async function (assert) {
    const sourceCard = this.makeCard({
      id: 101,
      columnId: 10,
      title: "Fix checkout",
      position: 0,
    });
    const targetCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      recencyAt: recentISO(2),
    });

    await this.renderBoard([
      this.makeColumn({ id: 10, title: "Todo", cards: [sourceCard] }),
      this.makeColumn({
        id: 20,
        title: "Recent",
        cards: [targetCard],
        defaultSort: "recency",
      }),
    ]);

    let requestData;
    pretender.put("/kanban/boards/1/cards/101", (request) => {
      requestData = parsePostData(request.requestBody);

      return response({
        card: {
          id: 101,
          column_id: 20,
          position: -1,
          recency_at: recentISO(1),
        },
      });
    });

    await this.dragCard(101);
    await this.dropOnColumn(20);

    assert.strictEqual(requestData.card.column_id, "20");
    assert.strictEqual(requestData.card.after_card_id, "");
    assert.deepEqual(
      columnCardIds(10),
      [],
      "it removes the card from the source column"
    );
    assert.deepEqual(
      columnCardIds(20),
      [101, 102],
      "it sorts the moved card to the top of the recency column"
    );
  });

  test("canceling the constraint fix while adding a topic card stops creation", async function (assert) {
    let addTopicAsCardModel;
    let postRequests = 0;

    const modal = getOwner(this).lookup("service:modal");
    sinon.stub(modal, "show").callsFake((component, opts) => {
      if (opts?.model?.onAddTopicAsCard) {
        addTopicAsCardModel = opts.model;
      } else if (opts?.model?.mismatches) {
        opts.model.onCancel();
      }

      return Promise.resolve();
    });

    await this.renderBoard(
      [this.makeColumn({ id: 10, title: "Todo", cards: [] })],
      { category_ids: [1], tag_names: [] }
    );

    pretender.get("/t/777.json", () => {
      return response({ id: 777, category_id: 2, tags: [] });
    });

    pretender.post("/kanban/boards/1/cards", () => {
      postRequests++;
      return response({ card: { id: 101, column_id: 10 } });
    });

    await click(".kanban-column__add-btn");
    await click(".fk-d-menu li:last-child button");
    await addTopicAsCardModel.onAddTopicAsCard({
      topicId: 777,
      title: "Wrong category",
    });

    assert.strictEqual(postRequests, 0, "it does not create the card");
  });

  test("clicking and dragging on the board scrolls columns horizontally", async function (assert) {
    await this.renderBoard([
      this.makeColumn({
        id: 10,
        title: "Todo",
        cards: [
          this.makeCard({
            id: 101,
            columnId: 10,
            title: "Fix checkout",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 20,
        title: "Done",
        cards: [
          this.makeCard({
            id: 102,
            columnId: 20,
            title: "Ship receipts",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 30,
        title: "In Progress",
        cards: [
          this.makeCard({
            id: 103,
            columnId: 30,
            title: "Implement login page",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 40,
        title: "Review",
        cards: [
          this.makeCard({
            id: 104,
            columnId: 40,
            title: "Write integration test coverage",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 50,
        title: "Deploy",
        cards: [
          this.makeCard({
            id: 105,
            columnId: 50,
            title: "Deploy to staging",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 60,
        title: "Done",
        cards: [
          this.makeCard({
            id: 106,
            columnId: 60,
            title: "Deploy to production",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 70,
        title: "Cancelled",
        cards: [
          this.makeCard({
            id: 107,
            columnId: 70,
            title: "Cancel order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 80,
        title: "Archived",
        cards: [
          this.makeCard({
            id: 108,
            columnId: 80,
            title: "Archive order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 90,
        title: "On Hold",
        cards: [
          this.makeCard({
            id: 109,
            columnId: 90,
            title: "On hold order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 100,
        title: "Backlog",
        cards: [
          this.makeCard({
            id: 110,
            columnId: 100,
            title: "Backlog order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 110,
        title: "In Progress",
        cards: [
          this.makeCard({
            id: 111,
            columnId: 110,
            title: "In progress order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 120,
        title: "Review",
        cards: [
          this.makeCard({
            id: 112,
            columnId: 120,
            title: "Review order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 130,
        title: "Deploy",
        cards: [
          this.makeCard({
            id: 113,
            columnId: 130,
            title: "Deploy order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 140,
        title: "Done",
        cards: [
          this.makeCard({
            id: 114,
            columnId: 140,
            title: "Done order",
            position: 0,
          }),
        ],
      }),
    ]);

    const container = document.querySelector(".kanban-board-container");

    await triggerEvent(container, "pointerdown", {
      pointerId: 1,
      pointerType: "mouse",
      button: 0,
      clientX: 400,
      clientY: 100,
    });
    await triggerEvent(container, "pointermove", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: -600,
      clientY: 100,
    });

    await new Promise((resolve) => requestAnimationFrame(resolve));

    assert.strictEqual(
      container.scrollLeft,
      1000,
      "it scrolls the container by the drag distance"
    );

    await triggerEvent(container, "pointerup", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: 200,
      clientY: 100,
    });
  });

  test("same-column recency drops are ignored", async function (assert) {
    const firstCard = this.makeCard({
      id: 101,
      columnId: 20,
      title: "Fix checkout",
      recencyAt: recentISO(1),
    });
    const secondCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      recencyAt: recentISO(2),
    });
    let putRequests = 0;

    await this.renderBoard([
      this.makeColumn({
        id: 20,
        title: "Recent",
        cards: [firstCard, secondCard],
        defaultSort: "recency",
      }),
    ]);

    pretender.put("/kanban/boards/1/cards/101", () => {
      putRequests++;
      return response({ card: { id: 101, column_id: 20 } });
    });

    await this.dragCard(101);
    await this.dropOnColumn(20);

    assert.strictEqual(putRequests, 0, "it does not save ignored drops");
    assert.deepEqual(
      columnCardIds(20),
      [101, 102],
      "it leaves the recency column order unchanged"
    );
  });
});
