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
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { kanbanBoardUrl } from "../lib/kanban-urls";
import KanbanColumn from "./kanban-column";
import KanbanBoardSettings from "./modal/kanban-board-settings";
import KanbanCardDetailModal from "./modal/kanban-card-detail";
import KanbanColumnSettings from "./modal/kanban-column-settings";
import KanbanConstraintFix from "./modal/kanban-constraint-fix";
import KanbanTopicCardDetailModal from "./modal/kanban-topic-card-detail";

const onWindowResize = modifier((element, [callback]) => {
  const wrappedCallback = () => callback(element);
  window.addEventListener("resize", wrappedCallback);

  const visualViewport = window.visualViewport;
  if (visualViewport) {
    visualViewport.addEventListener("resize", wrappedCallback);
  }

  return () => {
    window.removeEventListener("resize", wrappedCallback);
    if (visualViewport) {
      visualViewport.removeEventListener("resize", wrappedCallback);
    }
  };
});

function calcAvailableHeight(element) {
  schedule("afterRender", () => {
    const vv = window.visualViewport;
    const viewportHeight = vv?.height ?? window.innerHeight;
    const offsetTop = vv?.offsetTop ?? 0;
    const top = element.getBoundingClientRect().top - offsetTop;
    const available = viewportHeight - top;
    document.documentElement.style.setProperty(
      "--kanban-available-height",
      `${available}px`
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

  setupMessageBus = modifier((element) => {
    const channel = `/kanban/boards/${this.board.id}`;
    this.messageBus.subscribe(channel, this.onBoardMessage);

    const handleKeyboardMove = (event) => {
      this.#handleCardMoved(event.detail);
    };
    element.addEventListener("kanban:card-moved", handleKeyboardMove);

    return () => {
      this.messageBus.unsubscribe(channel, this.onBoardMessage);
      element.removeEventListener("kanban:card-moved", handleKeyboardMove);
    };
  });

  _promotionAppEventListenersBound = false;
  _promotionRouteListenerBound = false;

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
          this.#openInitialCardModal(card);
        } else {
          DiscourseURL.routeTo(kanbanBoardUrl(this.board));
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
      case "column_cleared":
        this.#handleColumnCleared(data.column_id);
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
    if (card.topic_id && !card.topic) {
      this.#handleBoardUpdated();
      return;
    }

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
    const existing = this.#findCard(card.id);
    const mergedCard = existing ? { ...existing, ...card } : card;

    const withoutCard = this.columns.map((col) => ({
      ...col,
      cards: col.cards.filter((c) => c.id !== card.id),
    }));

    this.columns = withoutCard.map((col) => {
      if (col.id === mergedCard.column_id) {
        const cards = [...col.cards];
        const insertIndex = cards.findIndex(
          (c) => c.position > mergedCard.position
        );
        if (insertIndex === -1) {
          cards.push(mergedCard);
        } else {
          cards.splice(insertIndex, 0, mergedCard);
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

  #handleColumnCleared(columnId) {
    this.columns = this.columns.map((col) => {
      if (col.id === columnId) {
        return { ...col, cards: [] };
      }
      return col;
    });
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
      Object.assign(this.board, result);
    } catch {
      // Board may have been deleted — no action needed
    }
  }

  @bind
  refreshBoard() {
    return this.#handleBoardUpdated();
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
  onDragEnd(cardId) {
    setTimeout(() => {
      if (this.dragData?.cardId === cardId) {
        this.dragData = null;
      }
    }, 0);
  }

  @action
  async onDrop(cardId, toColumnId, afterCardId, fromColumnId) {
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

    const card = fromColumn.cards[cardIndex];
    const isSameColumn = fromColumnId === toColumnId;
    let constraintFix = null;

    if (!isSameColumn && card.topic) {
      const mismatches = this._checkConstraintMismatches(card.topic, toColumn);
      if (mismatches) {
        constraintFix = await this._showConstraintFixModal(
          card,
          toColumn,
          mismatches
        );
        if (!constraintFix) {
          return;
        }
      }
    }

    if (!isSameColumn && !constraintFix && this.board.require_confirmation) {
      const confirmed = await this._confirmMove(card, toColumn);
      if (!confirmed) {
        return;
      }
    }

    const snapshot = this.columns.map((col) => ({
      ...col,
      cards: col.cards.map((c) => ({ ...c })),
    }));

    fromColumn.cards.splice(cardIndex, 1);

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

    const data = {
      client_id: this.messageBus.clientId,
      card: {
        column_id: toColumnId,
        after_card_id: afterCardId,
      },
    };
    if (constraintFix) {
      data.constraint_fix = constraintFix;
    }

    try {
      const result = await ajax(
        `/kanban/boards/${this.board.id}/cards/${card.id}`,
        { type: "PUT", data }
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
      this.columns = snapshot;
      popupAjaxError(error);
    }
  }

  _checkConstraintMismatches(topic, targetColumn) {
    const board = this.board;
    const hasCategories = board.category_ids?.length > 0;
    const hasTags = board.tag_names?.length > 0;

    if (!hasCategories && !hasTags) {
      return null;
    }

    const effectiveCategoryId =
      targetColumn.move_to_category_id || topic.category_id;
    const needsCategory =
      hasCategories && !board.category_ids.includes(effectiveCategoryId);

    const effectiveTagNames = [...(topic.tags || [])];
    if (targetColumn.tag_name) {
      const siblingTagNames = this.columns
        .filter((c) => c.tag_name && c.id !== targetColumn.id)
        .map((c) => c.tag_name);
      const filtered = effectiveTagNames.filter(
        (t) => !siblingTagNames.includes(t)
      );
      if (!filtered.includes(targetColumn.tag_name)) {
        filtered.push(targetColumn.tag_name);
      }
      effectiveTagNames.length = 0;
      effectiveTagNames.push(...filtered);
    }
    const needsTags =
      hasTags && !board.tag_names.some((t) => effectiveTagNames.includes(t));

    if (!needsCategory && !needsTags) {
      return null;
    }

    return {
      needsCategory,
      needsTags,
      boardCategoryIds: board.category_ids || [],
      boardTagNames: board.tag_names || [],
    };
  }

  _showConstraintFixModal(card, column, mismatches) {
    return new Promise((resolve) => {
      this.modal.show(KanbanConstraintFix, {
        model: {
          topic: card.topic,
          board: this.board,
          column,
          mismatches,
          onConfirm: (result) => resolve(result),
          onCancel: () => resolve(null),
        },
      });
    });
  }

  _confirmMove(card, toColumn) {
    return new Promise((resolve) => {
      const cardTitle = card.topic?.title || card.title || "";
      this.dialog.yesNoConfirm({
        message: i18n("discourse_kanban.board.move_confirm", {
          topic_title: cardTitle,
          column_title: toColumn.title,
        }),
        didConfirm: () => resolve(true),
        didCancel: () => resolve(false),
      });
    });
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
  async onAddCard({
    topicId,
    title,
    columnId,
    notes,
    labels,
    assigned_to_name,
  }) {
    if (topicId) {
      try {
        const constraintFix = await this.#resolveConstraintFixForCreate(
          topicId,
          columnId
        );
        if (constraintFix === false) {
          return;
        }

        const data = {
          client_id: this.messageBus.clientId,
          card: { column_id: columnId, topic_id: topicId },
        };
        if (constraintFix) {
          data.constraint_fix = constraintFix;
        }

        const result = await ajax(`/kanban/boards/${this.board.id}/cards`, {
          type: "POST",
          data,
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
      const cardData = { column_id: columnId, title };
      if (notes) {
        cardData.notes = notes;
      }
      if (labels?.length) {
        cardData.labels = labels;
      }
      if (assigned_to_name) {
        cardData.assigned_to_name = assigned_to_name;
      }

      const result = await ajax(`/kanban/boards/${this.board.id}/cards`, {
        type: "POST",
        data: {
          client_id: this.messageBus.clientId,
          card: cardData,
        },
      });
      this.#appendCardToColumn(result.card, columnId);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #resolveConstraintFixForCreate(topicId, columnId) {
    const board = this.board;
    const hasConstraints =
      board.category_ids?.length > 0 || board.tag_names?.length > 0;
    if (!hasConstraints) {
      return null;
    }

    let topicData;
    try {
      topicData = await ajax(`/t/${topicId}.json`);
    } catch {
      return null;
    }

    const topic = {
      category_id: topicData.category_id,
      tags: topicData.tags || [],
    };
    const column = this.columns.find((c) => c.id === columnId);
    if (!column) {
      return null;
    }

    const mismatches = this._checkConstraintMismatches(topic, column);
    if (!mismatches) {
      return null;
    }

    return this._showConstraintFixModal(
      { topic: topicData },
      column,
      mismatches
    );
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
    this.#bindPromotionListeners();

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
    closeMenu?.();
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
      tag_name: col.tag_name || null,
      move_to_category_id: col.move_to_category_id,
      move_to_assigned:
        col.move_to_assigned === "_user" ? "" : col.move_to_assigned,
      move_to_status: col.move_to_status,
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

  @action
  clearColumn(columnId) {
    const column = this.columns.find((col) => col.id === columnId);
    const cardCount = column?.cards?.length || 0;
    if (cardCount === 0) {
      return;
    }

    this.dialog.confirm({
      message: i18n("discourse_kanban.board.confirm_clear_column", {
        count: cardCount,
        column_title: column.title,
      }),
      didConfirm: async () => {
        const snapshot = this.columns.map((col) => ({
          ...col,
          cards: [...col.cards],
        }));

        this.columns = this.columns.map((col) => {
          if (col.id === columnId) {
            return { ...col, cards: [] };
          }
          return col;
        });

        try {
          await ajax(
            `/kanban/boards/${this.board.id}/columns/${columnId}/cards`,
            {
              type: "DELETE",
              data: { client_id: this.messageBus.clientId },
            }
          );
        } catch (error) {
          this.columns = snapshot;
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
        category_ids: this.board.category_ids || [],
        tag_names: this.board.tag_names || [],
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
      this.#unbindPromotionRouteListener();
      this._promotingCardId = null;
    }
  }

  _cleanupPromotion() {
    this._promotingCardId = null;
    this.#unbindPromotionAppEventListeners();
    this.#unbindPromotionRouteListener();
  }

  #bindPromotionListeners() {
    if (!this._promotionAppEventListenersBound) {
      this.appEvents.on("topic:created", this, this._onTopicCreated);
      this.appEvents.on("composer:cancelled", this, this._cleanupPromotion);
      this._promotionAppEventListenersBound = true;
    }

    if (!this._promotionRouteListenerBound) {
      this.router.on("routeWillChange", this._onRouteWillChange);
      this._promotionRouteListenerBound = true;
    }
  }

  #unbindPromotionAppEventListeners() {
    if (!this._promotionAppEventListenersBound) {
      return;
    }

    this.appEvents.off("topic:created", this, this._onTopicCreated);
    this.appEvents.off("composer:cancelled", this, this._cleanupPromotion);
    this._promotionAppEventListenersBound = false;
  }

  #unbindPromotionRouteListener() {
    if (!this._promotionRouteListenerBound) {
      return;
    }

    this.router.off("routeWillChange", this._onRouteWillChange);
    this._promotionRouteListenerBound = false;
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

  #openInitialCardModal(card) {
    const boardUrl = kanbanBoardUrl(this.board);
    const isTopicCard = card.card_type === "topic" && card.topic;
    const ModalComponent = isTopicCard
      ? KanbanTopicCardDetailModal
      : KanbanCardDetailModal;
    let navigatedAway = false;

    const column = this.columns.find((col) => col.id === card.column_id);
    const model = isTopicCard
      ? {
          card,
          columnTitle: column?.title,
          columnIcon: column?.icon,
          onNavigateAway: (url) => {
            navigatedAway = true;
            DiscourseURL.routeTo(url);
          },
        }
      : { card, canWrite: this.canWrite, onUpdateCard: this.onUpdateCard };

    this.modal.show(ModalComponent, { model }).finally(() => {
      if (!navigatedAway && !this.isDestroying && !this.isDestroyed) {
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
      {{this.setupMessageBus}}
      {{onWindowResize calcAvailableHeight}}
      {{didInsert calcAvailableHeight}}
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
              @onDragEnd={{this.onDragEnd}}
              @onDrop={{this.onDrop}}
              @onAddCard={{this.onAddCard}}
              @onUpdateCard={{this.onUpdateCard}}
              @onDeleteCard={{this.onDeleteCard}}
              @onPromoteToTopic={{this.onPromoteToTopic}}
              @onRefreshBoard={{this.refreshBoard}}
              @onEditColumn={{this.openEditColumnModal}}
              @onMoveColumn={{this.moveColumn}}
              @onDeleteColumn={{this.deleteColumn}}
              @onClearColumn={{this.clearColumn}}
              @allColumns={{this.columns}}
            />
          {{/each}}
        </div>
      {{else}}
        <div class="kanban-board-viewer__empty">
          <div class="kanban-board-viewer__empty-column">
            {{icon "table-columns"}}
            <h3>{{i18n "discourse_kanban.board.empty_board"}}</h3>
            <p>{{i18n "discourse_kanban.board.empty_board_cta"}}</p>
            {{#if this.canManage}}
              <DButton
                @action={{this.openAddColumnModal}}
                @icon="plus"
                @label="discourse_kanban.board.add_column"
                class="btn-primary"
              />
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
