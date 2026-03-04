import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { TOPIC_URL_REGEXP } from "discourse/lib/url";
import autoFocus from "discourse/modifiers/auto-focus";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import KanbanCard from "./kanban-card";

const onWindowResize = modifier((element, [callback]) => {
  const wrappedCallback = () => callback(element);
  window.addEventListener("resize", wrappedCallback);
  return () => window.removeEventListener("resize", wrappedCallback);
});

function calcColumnFooterHeight(element) {
  schedule("afterRender", () => {
    document.documentElement.style.setProperty(
      "--kanban-column-footer-height",
      `${element.clientHeight}px`
    );
  });
}

function calcColumnHeaderHeight(element) {
  schedule("afterRender", () => {
    document.documentElement.style.setProperty(
      "--kanban-column-header-height-observed",
      `${element.clientHeight}px`
    );
  });
}

export default class KanbanColumn extends Component {
  @service dialog;

  @tracked isAdding = false;
  @tracked newCardTitle = "";

  get cardCount() {
    return this.args.column.cards?.length || 0;
  }

  get wipLimit() {
    return this.args.column.wip_limit;
  }

  get isOverWipLimit() {
    return this.wipLimit && this.cardCount > this.wipLimit;
  }

  get isAtWipLimit() {
    return this.wipLimit && this.cardCount === this.wipLimit;
  }

  get columnTags() {
    const allColumns = this.args.allColumns || [];
    return allColumns.map((col) => col.move_to_tag).filter(Boolean);
  }

  get columnIndex() {
    const allColumns = this.args.allColumns || [];
    return allColumns.findIndex((col) => col.id === this.args.column.id);
  }

  get lastColumnIndex() {
    return (this.args.allColumns?.length || 0) - 1;
  }

  @action
  startAddCard() {
    this.isAdding = true;
    this.newCardTitle = "";
  }

  @action
  cancelAdd() {
    this.isAdding = false;
    this.newCardTitle = "";
  }

  @action
  onTitleInput(event) {
    this.newCardTitle = event.target.value;
  }

  @action
  onTitleKeydown(event) {
    if (event.key === "Enter" && this.newCardTitle.trim()) {
      event.preventDefault();
      this.submitCard();
    } else if (event.key === "Escape") {
      this.cancelAdd();
    }
  }

  @action
  submitCard() {
    const title = this.newCardTitle.trim();
    if (!title) {
      return;
    }
    const topicId = this.#extractTopicId(title);
    this.args.onAddCard({ title, topicId, columnId: this.args.column.id });
    this.newCardTitle = "";
  }

  #extractTopicId(text) {
    if (/^\d+$/.test(text)) {
      return parseInt(text, 10);
    }

    if (text.startsWith("http") || text.startsWith("/t/")) {
      const slugMatch = TOPIC_URL_REGEXP.exec(text);
      if (slugMatch) {
        return parseInt(slugMatch[2], 10);
      }

      const shortMatch = /\/t\/(\d+)(?:\/\d+)?\/?$/.exec(text);
      if (shortMatch) {
        return parseInt(shortMatch[1], 10);
      }
    }

    return null;
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
    if (!indicator) {
      indicator = document.createElement("div");
      indicator.className = "kanban-column__drop-indicator";
      indicator.style.height = `${dragData.cardHeight}px`;
    }

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

    if (insertBefore) {
      cardsContainer.insertBefore(indicator, insertBefore);
    } else {
      cardsContainer.appendChild(indicator);
    }
  }

  @action
  dragLeave(event) {
    event.preventDefault();
    if (!event.currentTarget.contains(event.relatedTarget)) {
      event.currentTarget.classList.remove("drag-target");
      this.removeDropIndicator(event.currentTarget);
    }
  }

  @action
  drop(event) {
    event.preventDefault();
    event.currentTarget.classList.remove("drag-target");

    const dragData = this.args.dragData;
    if (!dragData) {
      this.removeDropIndicator(event.currentTarget);
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

    this.removeDropIndicator(event.currentTarget);

    const isSameColumn = dragData.fromColumnId === this.args.column.id;

    const performDrop = () => {
      this.args.onDrop(dragData.cardId, this.args.column.id, afterCardId);
    };

    if (!isSameColumn && this.args.board.require_confirmation) {
      const cardTitle = this.findCardTitle(dragData);
      this.dialog.yesNoConfirm({
        message: i18n("discourse_kanban.board.move_confirm", {
          topic_title: cardTitle,
          column_title: this.args.column.title,
        }),
        didConfirm: performDrop,
      });
    } else {
      performDrop();
    }
  }

  removeDropIndicator(columnEl) {
    columnEl.querySelector(".kanban-column__drop-indicator")?.remove();
    const emptyMsg = columnEl.querySelector(".kanban-column__empty");
    if (emptyMsg) {
      emptyMsg.hidden = false;
    }
  }

  findCardTitle(dragData) {
    const allColumns = this.args.allColumns || [];
    for (const col of allColumns) {
      const card = col.cards?.find((c) => c.id === dragData.cardId);
      if (card) {
        return card.topic?.title || card.title || "";
      }
    }
    return "";
  }

  <template>
    <div
      class="kanban-column"
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
          <span
            class="kanban-column__count
              {{if this.isOverWipLimit 'kanban-column__count--over-limit'}}
              {{if this.isAtWipLimit 'kanban-column__count--at-limit'}}"
          >
            {{#if this.wipLimit}}
              {{i18n
                "discourse_kanban.board.wip_count"
                count=this.cardCount
                limit=this.wipLimit
              }}
            {{else}}
              {{this.cardCount}}
            {{/if}}
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
            @canWrite={{@canWrite}}
            @allSameCategory={{@allSameCategory}}
            @isDropHighlighted={{eq @dropHighlightCardId card.id}}
            @onDragStart={{@onDragStart}}
            @onUpdateCard={{@onUpdateCard}}
            @onDeleteCard={{@onDeleteCard}}
            @onPromoteToTopic={{fn @onPromoteToTopic card.id}}
            @columnTags={{this.columnTags}}
          />
        {{else}}
          <div class="kanban-column__empty">
            {{i18n "discourse_kanban.board.no_cards"}}
          </div>
        {{/each}}
      </div>

      {{#if @canWrite}}
        <div
          class="kanban-column__footer"
          {{didInsert calcColumnFooterHeight}}
          {{onWindowResize calcColumnFooterHeight}}
        >
          {{#if this.isAdding}}
            <div
              class="kanban-column__add-card-form"
              {{didInsert calcColumnFooterHeight}}
            >
              <textarea
                class="kanban-column__card-title-input"
                placeholder={{i18n
                  "discourse_kanban.board.card_title_placeholder"
                }}
                value={{this.newCardTitle}}
                {{on "input" this.onTitleInput}}
                {{on "keydown" this.onTitleKeydown}}
                {{autoFocus}}
              />
              <div class="kanban-column__add-card-actions">
                <DButton
                  @action={{this.submitCard}}
                  @label="discourse_kanban.board.add_card"
                  class="btn-primary btn-small"
                />
                <DButton
                  @action={{this.cancelAdd}}
                  @icon="xmark"
                  class="btn-flat btn-small kanban-column__cancel-add"
                />
              </div>
            </div>
          {{else}}
            <DButton
              @action={{this.startAddCard}}
              @icon="plus"
              @label="discourse_kanban.board.add_card"
              class="kanban-column__add-btn"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
