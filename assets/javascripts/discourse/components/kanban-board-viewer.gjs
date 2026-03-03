import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
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
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { kanbanBoardUrl, kanbanCardUrl } from "../lib/kanban-urls";
import KanbanColumn from "./kanban-column";
import KanbanBoardSettings from "./modal/kanban-board-settings";
import KanbanCardDetailModal from "./modal/kanban-card-detail";
import KanbanColumnSettings from "./modal/kanban-column-settings";

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
  @service dialog;
  @service messageBus;
  @service modal;
  @service router;
  @service toasts;

  @tracked board;
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
    this.board = { ...this.args.model.board };
    this.columns = this.args.model.columns.map((col) => ({
      ...col,
      cards: [...(col.cards || [])],
    }));

    if (this.args.initialCardId) {
      schedule("afterRender", () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        const card = this.#findCard(this.args.initialCardId);
        if (card) {
          this.#openCardModalWithUrl(card);
        } else {
          DiscourseURL.replaceState(kanbanBoardUrl(this.board));
        }
      });
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._clearDropHighlight();
    this._cleanupPromotion();
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
      case "columns_reordered":
        this.#handleColumnsReordered(data.column_order);
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

  #handleColumnsReordered(columnOrder) {
    const orderMap = new Map(columnOrder.map((id, idx) => [id, idx]));
    this.columns = [...this.columns].sort(
      (a, b) =>
        (orderMap.get(a.id) ?? Infinity) - (orderMap.get(b.id) ?? Infinity)
    );
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
      const result = await ajax(
        `/kanban/boards/${this.board.id}/cards/${card.id}`,
        {
          type: "PUT",
          data: {
            client_id: this.messageBus.clientId,
            card: {
              column_id: toColumnId,
              after_card_id: afterCardId,
            },
          },
        }
      );
      if (result?.card) {
        this.columns = this.columns.map((col) => ({
          ...col,
          cards: col.cards.map((c) =>
            c.id === card.id ? { ...c, ...result.card } : c
          ),
        }));
      }
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
    if (topicId) {
      try {
        const result = await ajax(`/kanban/boards/${this.board.id}/cards`, {
          type: "POST",
          data: {
            client_id: this.messageBus.clientId,
            card: { column_id: columnId, topic_id: topicId },
          },
        });
        this.#appendCardToColumn(result.card, columnId);
        return;
      } catch (error) {
        if (this.#isTopicNotFoundError(error)) {
          await this.#createFallbackFloater(title, columnId);
          return;
        }
        popupAjaxError(error);
        return;
      }
    }

    try {
      const result = await ajax(`/kanban/boards/${this.board.id}/cards`, {
        type: "POST",
        data: {
          client_id: this.messageBus.clientId,
          card: { column_id: columnId, title },
        },
      });
      this.#appendCardToColumn(result.card, columnId);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #isTopicNotFoundError(error) {
    return error?.jqXHR?.status === 404;
  }

  #appendCardToColumn(card, columnId) {
    if (!card) {
      return;
    }
    this.columns = this.columns.map((col) => {
      if (col.id === columnId) {
        return { ...col, cards: [...col.cards, card] };
      }
      return col;
    });
  }

  async #createFallbackFloater(title, columnId) {
    try {
      const result = await ajax(`/kanban/boards/${this.board.id}/cards`, {
        type: "POST",
        data: {
          client_id: this.messageBus.clientId,
          card: { column_id: columnId, title },
        },
      });
      this.#appendCardToColumn(result.card, columnId);
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

  // Column management actions

  @action
  openAddColumnModal(closeMenu) {
    closeMenu();
    this.modal.show(KanbanColumnSettings, {
      model: {
        column: null,
        board: this.board,
        onSave: (columnData) => this.addColumn(columnData),
      },
    });
  }

  @action
  openEditColumnModal(columnId) {
    const column = this.columns.find((c) => c.id === columnId);
    if (!column) {
      return;
    }
    this.modal.show(KanbanColumnSettings, {
      model: {
        column,
        board: this.board,
        onSave: (columnData) => this.editColumn(columnId, columnData),
      },
    });
  }

  _serializeColumn(col) {
    return {
      id: col.id,
      title: col.title,
      icon: col.icon,
      filter_query: col.filter_query,
      move_to_tag: col.move_to_tag,
      move_to_category_id: col.move_to_category_id,
      move_to_assigned:
        col.move_to_assigned === "_user" ? "" : col.move_to_assigned,
      move_to_status: col.move_to_status,
      wip_limit: col.wip_limit,
    };
  }

  @action
  async addColumn(columnData) {
    const columnsPayload = this.columns.map((col) =>
      this._serializeColumn(col)
    );
    columnsPayload.push(this._serializeColumn(columnData));
    await this._saveColumnsUpdate(columnsPayload);
  }

  @action
  async editColumn(columnId, columnData) {
    const columnsPayload = this.columns.map((col) => {
      if (col.id === columnId) {
        return this._serializeColumn({ ...col, ...columnData });
      }
      return this._serializeColumn(col);
    });
    await this._saveColumnsUpdate(columnsPayload);
  }

  @action
  async moveColumn(columnId, direction) {
    const index = this.columns.findIndex((c) => c.id === columnId);
    if (index === -1) {
      return;
    }
    const newIndex = index + direction;
    if (newIndex < 0 || newIndex >= this.columns.length) {
      return;
    }

    const snapshot = this.columns;
    const reordered = [...this.columns];
    [reordered[index], reordered[newIndex]] = [
      reordered[newIndex],
      reordered[index],
    ];

    this.columns = reordered;
    try {
      const result = await ajax(`/kanban/boards/${this.board.id}/move-column`, {
        type: "POST",
        data: {
          column_id: columnId,
          direction,
          client_id: this.messageBus.clientId,
        },
      });
      if (result?.column_order) {
        this.#handleColumnsReordered(result.column_order);
      }
    } catch (error) {
      this.columns = snapshot;
      popupAjaxError(error);
    }
  }

  @action
  deleteColumn(columnId) {
    this.dialog.confirm({
      message: i18n("discourse_kanban.board.confirm_delete_column"),
      didConfirm: async () => {
        const columnsPayload = this.columns
          .filter((col) => col.id !== columnId)
          .map((col) => this._serializeColumn(col));
        try {
          await this._saveColumnsUpdate(columnsPayload);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  // Board settings actions

  @action
  openBoardSettings(closeMenu) {
    closeMenu();
    this.modal.show(KanbanBoardSettings, {
      model: {
        board: this.board,
        isNew: false,
        onSave: (boardData) => this.saveBoardSettings(boardData),
        onDelete: () => this.deleteBoard(),
      },
    });
  }

  @action
  async saveBoardSettings(boardData) {
    const columnsPayload = this.columns.map((col) =>
      this._serializeColumn(col)
    );

    const payload = {
      board: {
        ...boardData,
        columns: columnsPayload,
      },
    };

    const originalSlug = this.board.slug;

    const result = await ajax(`/kanban/boards/${this.board.id}`, {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify(payload),
    });

    if (result.board) {
      this.board = { ...this.board, ...result.board };
      if (result.board.columns) {
        this.columns = this.columns.map((col) => {
          const serverCol = result.board.columns.find((s) => s.id === col.id);
          return serverCol ? { ...col, ...serverCol } : col;
        });
      }
    }

    this.toasts.success({
      data: { message: i18n("saved") },
      duration: "short",
    });

    if (this.board.slug && this.board.slug !== originalSlug) {
      this.router.replaceWith("kanbanBoard", this.board.slug, this.board.id);
    }
  }

  @action
  deleteBoard(closeMenu) {
    closeMenu?.();
    this.dialog.confirm({
      message: i18n("discourse_kanban.manage.confirm_delete"),
      didConfirm: async () => {
        try {
          await ajax(`/kanban/boards/${this.board.id}`, {
            type: "DELETE",
          });
          this.router.transitionTo("kanbanBoards");
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  async _saveColumnsUpdate(columnsPayload) {
    const payload = {
      board: {
        name: this.board.name,
        slug: this.board.slug,
        base_filter_query: this.board.base_filter_query,
        card_style: this.board.card_style,
        show_tags: this.board.show_tags,
        show_topic_thumbnail: this.board.show_topic_thumbnail,
        show_activity_indicators: this.board.show_activity_indicators,
        require_confirmation: this.board.require_confirmation,
        allow_read_group_ids: this.board.allow_read_group_ids || [],
        allow_write_group_ids: this.board.allow_write_group_ids || [],
        columns: columnsPayload,
      },
    };

    const result = await ajax(`/kanban/boards/${this.board.id}`, {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify(payload),
    });

    this.toasts.success({
      data: { message: i18n("saved") },
      duration: "short",
    });

    await this.#handleBoardUpdated();

    if (result.board) {
      this.board = { ...this.board, ...result.board };
    }
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

  #findCard(cardId) {
    for (const col of this.columns) {
      const card = col.cards.find((c) => c.id === cardId);
      if (card) {
        return card;
      }
    }
    return null;
  }

  #openCardModalWithUrl(card) {
    const boardUrl = kanbanBoardUrl(this.board);
    const cardUrlPath = kanbanCardUrl(this.board, card.id);

    DiscourseURL.replaceState(cardUrlPath);
    this.modal
      .show(KanbanCardDetailModal, {
        model: {
          card,
          canWrite: this.canWrite,
          onUpdateCard: this.onUpdateCard,
        },
      })
      .finally(() => {
        if (!this.isDestroying && !this.isDestroyed) {
          DiscourseURL.replaceState(boardUrl);
        }
      });
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
          {{#if this.canManage}}
            <DMenu
              @identifier="kanban-board-controls"
              @icon="ellipsis"
              @title="discourse_kanban.board.controls"
              @triggerClass="btn-flat"
            >
              <:content as |args|>
                <DropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.openAddColumnModal args.close}}
                      @icon="plus"
                      @label="discourse_kanban.board.add_column"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.openBoardSettings args.close}}
                      @icon="gear"
                      @label="discourse_kanban.board.board_settings"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.deleteBoard args.close}}
                      @icon="trash-can"
                      @label="discourse_kanban.board.delete_board"
                      class="btn-transparent btn-danger"
                    />
                  </dropdown.item>
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
          {{#if this.fullscreen}}
            <DButton
              @action={{this.exitFullscreen}}
              @icon="discourse-compress"
              @title="discourse_kanban.board.exit_fullscreen"
              class="btn-flat kanban-board-viewer__exit-fullscreen"
            />
          {{else}}
            <DButton
              @action={{this.toggleFullscreen}}
              @icon="discourse-expand"
              @title="discourse_kanban.board.fullscreen"
              class="btn-flat"
            />
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
              @canManage={{this.canManage}}
              @allSameCategory={{this.allSameCategory}}
              @dropHighlightCardId={{this.dropHighlightCardId}}
              @dragData={{this.dragData}}
              @onDragStart={{this.onDragStart}}
              @onDrop={{this.onDrop}}
              @onAddCard={{this.onAddCard}}
              @onUpdateCard={{this.onUpdateCard}}
              @onDeleteCard={{this.onDeleteCard}}
              @onPromoteToTopic={{this.onPromoteToTopic}}
              @onEditColumn={{this.openEditColumnModal}}
              @onMoveColumn={{this.moveColumn}}
              @onDeleteColumn={{this.deleteColumn}}
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
