import { getOwner } from "@ember/owner";
import { render, triggerEvent } from "@ember/test-helpers";
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

    this.renderBoard = async (columns) => {
      const board = this.fabricators.board({
        id: 1,
        can_write: true,
        can_manage: false,
      });
      board.require_confirmation = false;

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
      recencyAt: "2026-04-29T00:00:00.000Z",
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
          recency_at: "2026-04-30T00:00:00.000Z",
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

  test("same-column recency drops are ignored", async function (assert) {
    const firstCard = this.makeCard({
      id: 101,
      columnId: 20,
      title: "Fix checkout",
      recencyAt: "2026-04-30T00:00:00.000Z",
    });
    const secondCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      recencyAt: "2026-04-29T00:00:00.000Z",
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
