import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import bodyClass from "discourse/helpers/body-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import KanbanColumn from "./kanban-column";

const onWindowResize = modifier((element, [callback]) => {
  const wrappedCallback = () => callback(element);
  window.addEventListener("resize", wrappedCallback);
  return () => window.removeEventListener("resize", wrappedCallback);
});

function calcOffset(element) {
  schedule("afterRender", () => {
    element.style.setProperty(
      "--kanban-offset-top",
      `${element.getBoundingClientRect().top}px`
    );
  });
}

export default class KanbanBoardViewer extends Component {
  @service appEvents;
  @service composer;
  @service messageBus;
  @service router;

  @tracked columns;
  @tracked dragData = null;
  @tracked dropHighlightCardId = null;
  @tracked fullscreen = false;

  setupMessageBus = modifier(() => {
    const channel = `/kanban/boards/${this.board.id}`;
    this.messageBus.subscribe(channel, this.onBoardMessage);
    return () => this.messageBus.unsubscribe(channel, this.onBoardMessage);
  });

  constructor() {
    super(...arguments);
    this.columns = this.args.model.columns.map((col) => ({
      ...col,
      cards: [...(col.cards || [])],
    }));
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._clearDropHighlight();
    this._cleanupPromotion();
  }

  get board() {
    return this.args.model.board;
  }

  @bind
  onBoardMessage(data) {
    if (data.client_id && data.client_id === this.messageBus.clientId) {
      return;
    }

    switch (data.type) {
      case "card_created":
        this.#handleCardCreated(data.card);
        break;
      case "card_updated":
        this.#handleCardUpdated(data.card);
        break;
      case "card_moved":
        this.#handleCardMoved(data.card);
        break;
      case "card_deleted":
        this.#handleCardDeleted(data.card_id);
        break;
      case "board_updated":
        this.#handleBoardUpdated();
        break;
    }
  }

  #handleCardCreated(card) {
    this.columns = this.columns.map((col) => {
      if (col.id === card.column_id) {
        const cards = [...col.cards];
        const insertIndex = cards.findIndex((c) => c.position > card.position);
        if (insertIndex === -1) {
          cards.push(card);
        } else {
          cards.splice(insertIndex, 0, card);
        }
        return { ...col, cards };
      }
      return col;
    });
  }

  #handleCardUpdated(card) {
    this.columns = this.columns.map((col) => ({
      ...col,
      cards: col.cards.map((c) => (c.id === card.id ? { ...c, ...card } : c)),
    }));
  }

  #handleCardMoved(card) {
    const withoutCard = this.columns.map((col) => ({
      ...col,
      cards: col.cards.filter((c) => c.id !== card.id),
    }));

    this.columns = withoutCard.map((col) => {
      if (col.id === card.column_id) {
        const cards = [...col.cards];
        const insertIndex = cards.findIndex((c) => c.position > card.position);
        if (insertIndex === -1) {
          cards.push(card);
        } else {
          cards.splice(insertIndex, 0, card);
        }
        return { ...col, cards };
      }
      return col;
    });
  }

  #handleCardDeleted(cardId) {
    this.columns = this.columns.map((col) => ({
      ...col,
      cards: col.cards.filter((c) => c.id !== cardId),
    }));
  }

  async #handleBoardUpdated() {
    try {
      const result = await ajax(`/kanban/boards/${this.board.id}.json`);
      if (result.columns) {
        this.columns = result.columns;
      }
    } catch {
      // Board may have been deleted — no action needed
    }
  }

  get canWrite() {
    return this.board.can_write;
  }

  get canManage() {
    return this.board.can_manage;
  }

  get allSameCategory() {
    let seenCategory = null;
    for (const col of this.columns) {
      for (const card of col.cards || []) {
        const catId = card.topic?.category_id;
        if (catId == null) {
          continue;
        }
        if (seenCategory === null) {
          seenCategory = catId;
        } else if (seenCategory !== catId) {
          return false;
        }
      }
    }
    return true;
  }

  @action
  toggleFullscreen() {
    this.fullscreen = !this.fullscreen;
  }

  @action
  exitFullscreen() {
    this.fullscreen = false;
  }

  @action
  onDragStart(data) {
    this.dragData = data;
  }

  @action
  async onDrop(cardId, toColumnId, afterCardId) {
    const fromColumnId = this.dragData?.fromColumnId;
    if (!fromColumnId) {
      return;
    }

    const fromColumn = this.columns.find((c) => c.id === fromColumnId);
    const toColumn = this.columns.find((c) => c.id === toColumnId);
    if (!fromColumn || !toColumn) {
      return;
    }

    const cardIndex = fromColumn.cards.findIndex((c) => c.id === cardId);
    if (cardIndex === -1) {
      return;
    }

    const isSameColumn = fromColumnId === toColumnId;
    const originalCards = isSameColumn ? [...fromColumn.cards] : null;

    const [card] = fromColumn.cards.splice(cardIndex, 1);

    let insertIndex = toColumn.cards.length;
    if (afterCardId != null) {
      const idx = toColumn.cards.findIndex((c) => c.id === afterCardId);
      if (idx !== -1) {
        insertIndex = idx + 1;
      }
    } else {
      insertIndex = 0;
    }
    toColumn.cards.splice(insertIndex, 0, card);
    card.column_id = toColumnId;

    this.columns = this.columns.map((col) => {
      if (col.id === fromColumnId || col.id === toColumnId) {
        return { ...col, cards: [...col.cards] };
      }
      return col;
    });
    this.dragData = null;

    try {
      await ajax(`/kanban/boards/${this.board.id}/cards/${card.id}`, {
        type: "PUT",
        data: {
          client_id: this.messageBus.clientId,
          card: {
            column_id: toColumnId,
            after_card_id: afterCardId,
          },
        },
      });
      this._highlightDroppedCard(card.id);
    } catch (error) {
      if (isSameColumn) {
        fromColumn.cards = originalCards;
      } else {
        card.column_id = fromColumnId;
        toColumn.cards.splice(toColumn.cards.indexOf(card), 1);
        fromColumn.cards.splice(cardIndex, 0, card);
      }
      this.columns = this.columns.map((col) => {
        if (col.id === fromColumnId || col.id === toColumnId) {
          return { ...col, cards: [...col.cards] };
        }
        return col;
      });
      popupAjaxError(error);
    }
  }

  @action
  async onDeleteCard(cardId) {
    const snapshot = this.columns.map((col) => ({
      ...col,
      cards: [...col.cards],
    }));

    this.columns = this.columns.map((col) => ({
      ...col,
      cards: col.cards.filter((c) => c.id !== cardId),
    }));

    try {
      await ajax(`/kanban/boards/${this.board.id}/cards/${cardId}`, {
        type: "DELETE",
        data: { client_id: this.messageBus.clientId },
      });
    } catch (error) {
      this.columns = snapshot;
      popupAjaxError(error);
    }
  }

  @action
  async onUpdateCard(cardId, updates) {
    try {
      const result = await ajax(
        `/kanban/boards/${this.board.id}/cards/${cardId}`,
        {
          type: "PUT",
          data: { client_id: this.messageBus.clientId, card: updates },
        }
      );

      if (result.card) {
        if (result.adopted_floater_id) {
          this.columns = this.columns.map((col) => ({
            ...col,
            cards: col.cards.filter((c) => c.id !== cardId),
          }));
          this.#handleCardMoved(result.card);
        } else {
          this.columns = this.columns.map((col) => ({
            ...col,
            cards: col.cards.map((c) =>
              c.id === cardId ? { ...c, ...result.card } : c
            ),
          }));
        }
      }
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  @action
  async onAddCard({ topicId, title, columnId }) {
    const cardData = { column_id: columnId };
    if (topicId) {
      cardData.topic_id = topicId;
    } else {
      cardData.title = title;
    }

    try {
      const result = await ajax(`/kanban/boards/${this.board.id}/cards`, {
        type: "POST",
        data: { client_id: this.messageBus.clientId, card: cardData },
      });

      if (result.card) {
        this.columns = this.columns.map((col) => {
          if (col.id === columnId) {
            return { ...col, cards: [...col.cards, result.card] };
          }
          return col;
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onPromoteToTopic(cardId) {
    let card;
    let column;
    for (const col of this.columns) {
      const found = col.cards.find((c) => c.id === cardId);
      if (found) {
        card = found;
        column = col;
        break;
      }
    }
    if (!card) {
      return;
    }

    this._promotingCardId = cardId;

    this.appEvents.on("topic:created", this, this._onTopicCreated);
    this.appEvents.on("composer:cancelled", this, this._cleanupPromotion);
    this.router.on("routeWillChange", this._onRouteWillChange);

    const opts = { title: card.title };
    if (card.notes) {
      opts.body = card.notes;
    }
    if (card.labels?.length) {
      opts.tags = card.labels;
    }
    const categoryId = column.move_to_category_id;
    if (categoryId) {
      opts.category = Category.findById(categoryId);
    }
    this.composer.openNewTopic(opts);
  }

  @bind
  _onTopicCreated(createdPost) {
    const cardId = this._promotingCardId;
    this._cleanupPromotion();
    this.onUpdateCard(cardId, { topic_id: createdPost.topic_id });
  }

  @bind
  _onRouteWillChange(transition) {
    if (this._promotingCardId) {
      transition.abort();
      this.router.off("routeWillChange", this._onRouteWillChange);
      this._promotingCardId = null;
    }
  }

  _cleanupPromotion() {
    this._promotingCardId = null;
    this.appEvents.off("topic:created", this, this._onTopicCreated);
    this.appEvents.off("composer:cancelled", this, this._cleanupPromotion);
    this.router.off("routeWillChange", this._onRouteWillChange);
  }

  _highlightDroppedCard(cardId) {
    this._clearDropHighlight();
    this.dropHighlightCardId = null;

    schedule("afterRender", () => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.dropHighlightCardId = cardId;
      this._dropHighlightTimeout = setTimeout(() => {
        if (this.dropHighlightCardId === cardId) {
          this.dropHighlightCardId = null;
        }
        this._dropHighlightTimeout = null;
      }, 1000);
    });
  }

  _clearDropHighlight() {
    if (this._dropHighlightTimeout) {
      clearTimeout(this._dropHighlightTimeout);
      this._dropHighlightTimeout = null;
    }
  }

  <template>
    {{#if this.fullscreen}}
      {{bodyClass "kanban-fullscreen"}}
    {{/if}}

    <div
      class="kanban-board-viewer {{if this.fullscreen 'is-fullscreen'}}"
      {{onWindowResize calcOffset}}
      {{didInsert calcOffset}}
      {{this.setupMessageBus}}
    >
      <div class="kanban-board-viewer__header">
        <h2 class="kanban-board-viewer__title">{{this.board.name}}</h2>

        <div class="kanban-board-viewer__controls">
          {{#if this.fullscreen}}
            <DButton
              @action={{this.exitFullscreen}}
              @icon="discourse-compress"
              @title="discourse_kanban.board.exit_fullscreen"
              class="btn-flat kanban-board-viewer__exit-fullscreen"
            />
          {{else}}
            <DMenu
              @identifier="kanban-board-controls"
              @icon="ellipsis"
              @title="discourse_kanban.board.controls"
              @triggerClass="btn-flat"
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @action={{this.toggleFullscreen}}
                      @icon="discourse-expand"
                      @label="discourse_kanban.board.fullscreen"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  {{#if this.canManage}}
                    <dropdown.item>
                      <DButton
                        @route="kanbanBoardConfigure"
                        @routeModels={{array this.board.slug this.board.id}}
                        @icon="gear"
                        @label="discourse_kanban.board.configure"
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  {{/if}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </div>

      {{#if this.columns.length}}
        <div class="kanban-board-container">
          {{#each this.columns key="id" as |column|}}
            <KanbanColumn
              @column={{column}}
              @board={{this.board}}
              @canWrite={{this.canWrite}}
              @allSameCategory={{this.allSameCategory}}
              @dropHighlightCardId={{this.dropHighlightCardId}}
              @dragData={{this.dragData}}
              @onDragStart={{this.onDragStart}}
              @onDrop={{this.onDrop}}
              @onAddCard={{this.onAddCard}}
              @onUpdateCard={{this.onUpdateCard}}
              @onDeleteCard={{this.onDeleteCard}}
              @onPromoteToTopic={{this.onPromoteToTopic}}
              @allColumns={{this.columns}}
            />
          {{/each}}
        </div>
      {{else}}
        <div class="kanban-board-viewer__empty">
          {{i18n "discourse_kanban.board.empty_board"}}
        </div>
      {{/if}}
    </div>
  </template>
}
