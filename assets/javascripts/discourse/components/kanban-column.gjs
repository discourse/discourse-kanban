import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { animateCardReorder, captureCardRects } from "../lib/kanban-motion";
import KanbanCard from "./kanban-card";
import KanbanAddTopicAsCardModal from "./modal/kanban-add-topic-as-card";
import KanbanCardDetailModal from "./modal/kanban-card-detail";

export function shouldAnimateDropIndicatorPlacement({
  hadIndicator,
  columnId,
  fromColumnId,
  hasPlacedIndicator,
}) {
  return hadIndicator || columnId !== fromColumnId || hasPlacedIndicator;
}

export default class KanbanColumn extends Component {
  @service modal;

  get cardCount() {
    return this.args.column.cards?.length || 0;
  }

  get columnTags() {
    const allColumns = this.args.allColumns || [];
    return allColumns.map((col) => col.tag_name).filter(Boolean);
  }

  get columnIndex() {
    const allColumns = this.args.allColumns || [];
    return allColumns.findIndex((col) => col.id === this.args.column.id);
  }

  get lastColumnIndex() {
    return (this.args.allColumns?.length || 0) - 1;
  }

  @action
  async startAddCard(closeMenu) {
    await closeMenu();
    this.modal.show(KanbanCardDetailModal, {
      model: {
        card: {},
        isNew: true,
        canWrite: true,
        onCreateCard: (data) =>
          this.args.onAddCard({ ...data, columnId: this.args.column.id }),
      },
    });
  }

  @action
  async addTopicAsCard(closeMenu) {
    await closeMenu();
    this.modal.show(KanbanAddTopicAsCardModal, {
      model: {
        onAddTopicAsCard: (data) =>
          this.args.onAddCard({ ...data, columnId: this.args.column.id }),
      },
    });
  }

  @action
  editColumn(closeMenu) {
    closeMenu();
    this.args.onEditColumn(this.args.column.id);
  }

  @action
  moveLeft(closeMenu) {
    closeMenu();
    this.args.onMoveColumn(this.args.column.id, -1);
  }

  @action
  moveRight(closeMenu) {
    closeMenu();
    this.args.onMoveColumn(this.args.column.id, 1);
  }

  @action
  clearColumn(closeMenu) {
    closeMenu();
    this.args.onClearColumn(this.args.column.id);
  }

  @action
  deleteColumn(closeMenu) {
    closeMenu();
    this.args.onDeleteColumn(this.args.column.id);
  }

  @action
  dragOver(event) {
    event.preventDefault();
    const dragData = this.args.dragData;
    if (!dragData) {
      return;
    }

    event.currentTarget.classList.add("drag-target");

    const cardsContainer = event.currentTarget.querySelector(
      ".kanban-column__cards"
    );
    if (!cardsContainer) {
      return;
    }

    let indicator = cardsContainer.querySelector(
      ".kanban-column__drop-indicator"
    );
    const hadIndicator = !!indicator;
    if (!indicator) {
      indicator = document.createElement("div");
      indicator.className = "kanban-column__drop-indicator";
    }
    indicator.style.height = `${dragData.cardHeight}px`;

    const cardElements = [...cardsContainer.querySelectorAll(".kanban-card")];
    let insertBefore = null;

    for (const cardEl of cardElements) {
      const elCardId = parseInt(cardEl.dataset.cardId, 10);
      if (elCardId === dragData.cardId) {
        continue;
      }
      const rect = cardEl.getBoundingClientRect();
      if (event.clientY <= rect.top + rect.height / 2) {
        insertBefore = cardEl;
        break;
      }
    }

    const emptyMsg = cardsContainer.querySelector(".kanban-column__empty");
    if (emptyMsg) {
      emptyMsg.hidden = true;
    }

    if (
      this.#indicatorMatchesPosition(cardsContainer, indicator, insertBefore)
    ) {
      return;
    }

    const shouldAnimate = shouldAnimateDropIndicatorPlacement({
      hadIndicator,
      columnId: this.args.column.id,
      fromColumnId: dragData.fromColumnId,
      hasPlacedIndicator: dragData.hasPlacedIndicator,
    });

    const previousRects = shouldAnimate
      ? captureCardRects(cardsContainer, {
          skipCardIds: [dragData.cardId],
        })
      : null;

    indicator.classList.remove("kanban-column__drop-indicator--source");

    if (insertBefore) {
      cardsContainer.insertBefore(indicator, insertBefore);
    } else {
      cardsContainer.appendChild(indicator);
    }

    if (shouldAnimate) {
      animateCardReorder(cardsContainer, previousRects, {
        skipCardIds: [dragData.cardId],
      });
    }

    dragData.hasPlacedIndicator = true;
  }

  @action
  dragLeave(event) {
    event.preventDefault();
    if (!event.currentTarget.contains(event.relatedTarget)) {
      event.currentTarget.classList.remove("drag-target");
      this.removeDropIndicator(event.currentTarget, { animate: true });
    }
  }

  @action
  drop(event) {
    event.preventDefault();
    event.currentTarget.classList.remove("drag-target");

    const dragData = this.args.dragData;
    if (!dragData) {
      this.removeDropIndicator(event.currentTarget, { animate: false });
      return;
    }

    const cardsContainer = event.currentTarget.querySelector(
      ".kanban-column__cards"
    );
    let afterCardId = null;

    if (cardsContainer) {
      const cardElements = [...cardsContainer.querySelectorAll(".kanban-card")];
      for (const cardEl of cardElements) {
        const elCardId = parseInt(cardEl.dataset.cardId, 10);
        if (elCardId === dragData.cardId) {
          continue;
        }
        const rect = cardEl.getBoundingClientRect();
        if (event.clientY > rect.top + rect.height / 2) {
          afterCardId = elCardId;
        }
      }
    }

    this.removeDropIndicator(event.currentTarget, { animate: false });

    this.args.onDrop(
      dragData.cardId,
      this.args.column.id,
      afterCardId,
      dragData.fromColumnId
    );
  }

  removeDropIndicator(columnEl, { animate = false } = {}) {
    const cardsContainer = columnEl.querySelector(".kanban-column__cards");
    const indicator = columnEl.querySelector(".kanban-column__drop-indicator");
    const dragData = this.args.dragData;

    if (!indicator) {
      columnEl
        .querySelector(".kanban-column__empty")
        ?.removeAttribute("hidden");
      return;
    }

    const previousRects =
      animate && cardsContainer
        ? captureCardRects(cardsContainer, {
            skipCardIds: dragData ? [dragData.cardId] : [],
          })
        : null;

    indicator.remove();

    const emptyMsg = columnEl.querySelector(".kanban-column__empty");
    if (emptyMsg) {
      emptyMsg.hidden = false;
    }

    if (cardsContainer && previousRects) {
      animateCardReorder(cardsContainer, previousRects, {
        skipCardIds: dragData ? [dragData.cardId] : [],
      });
    }
  }

  #indicatorMatchesPosition(cardsContainer, indicator, insertBefore) {
    if (indicator.parentElement !== cardsContainer) {
      return false;
    }

    if (insertBefore) {
      return indicator.nextElementSibling === insertBefore;
    }

    return indicator === cardsContainer.lastElementChild;
  }

  <template>
    <div
      class="kanban-column"
      data-column-id={{@column.id}}
      {{on "dragover" this.dragOver}}
      {{on "dragleave" this.dragLeave}}
      {{on "drop" this.drop}}
    >
      <div class="kanban-column__header">
        <span class="kanban-column__header-content">
          <span class="kanban-column__title">
            {{#if @column.icon}}{{icon @column.icon}}{{/if}}
            {{@column.title}}
          </span>
          <span class="kanban-column__count">
            {{this.cardCount}}
          </span>
        </span>
        {{#if @canManage}}
          <DMenu
            @identifier="kanban-column-controls"
            @icon="ellipsis"
            @title="discourse_kanban.board.column_controls"
            @triggerClass="btn-flat btn-small kanban-column__menu-trigger"
          >
            <:content as |args|>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{fn this.editColumn args.close}}
                    @icon="pencil"
                    @label="discourse_kanban.board.edit_column"
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.moveLeft args.close}}
                    @icon="arrow-left"
                    @label="discourse_kanban.board.move_left"
                    @disabled={{eq this.columnIndex 0}}
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.moveRight args.close}}
                    @icon="arrow-right"
                    @label="discourse_kanban.board.move_right"
                    @disabled={{eq this.columnIndex this.lastColumnIndex}}
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.clearColumn args.close}}
                    @icon="xmark"
                    @label="discourse_kanban.board.clear_column"
                    @disabled={{eq this.cardCount 0}}
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.deleteColumn args.close}}
                    @icon="trash-can"
                    @label="discourse_kanban.board.delete_column"
                    class="btn-transparent btn-danger"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
      </div>

      <div class="kanban-column__cards">
        {{#each @column.cards key="id" as |card|}}
          <KanbanCard
            @card={{card}}
            @board={{@board}}
            @columnTitle={{@column.title}}
            @columnIcon={{@column.icon}}
            @canWrite={{@canWrite}}
            @allSameCategory={{@allSameCategory}}
            @isDropHighlighted={{eq @dropHighlightCardId card.id}}
            @onDragStart={{@onDragStart}}
            @onDragEnd={{@onDragEnd}}
            @onUpdateCard={{@onUpdateCard}}
            @onDeleteCard={{@onDeleteCard}}
            @onPromoteToTopic={{fn @onPromoteToTopic card.id}}
            @onRefreshBoard={{@onRefreshBoard}}
            @columnTags={{this.columnTags}}
          />
        {{else}}
          <div class="kanban-column__empty">
            {{i18n "discourse_kanban.board.no_cards"}}
          </div>
        {{/each}}
      </div>

      {{#if @canWrite}}
        <div class="kanban-column__footer">
          <DMenu
            @identifier="kanban-column-add"
            @icon="plus"
            @label={{i18n "discourse_kanban.board.add_card"}}
            @triggerClass="kanban-column__add-btn"
          >
            <:content as |args|>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{fn this.startAddCard args.close}}
                    @icon="plus"
                    @label="discourse_kanban.board.add_card"
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.addTopicAsCard args.close}}
                    @icon="link"
                    @label="discourse_kanban.board.add_topic_as_card"
                    class="btn-transparent"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      {{/if}}
    </div>
  </template>
}
