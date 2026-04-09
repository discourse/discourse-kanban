import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import TopicStatus from "discourse/components/topic-status";
import DMenu from "discourse/float-kit/components/d-menu";
import categoryBadge from "discourse/helpers/category-badge";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { renderAvatar } from "discourse/helpers/user-avatar";
import renderTags from "discourse/lib/render-tags";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import { kanbanBoardUrl, kanbanCardUrl } from "../lib/kanban-urls";
import AutoLinkedText from "./auto-linked-text";
import KanbanCardDetailModal from "./modal/kanban-card-detail";
import KanbanTopicCardDetailModal from "./modal/kanban-topic-card-detail";

export function shouldInsertSourceDropIndicator(root = document) {
  return !root.querySelector(
    ".kanban-column__drop-indicator:not(.kanban-column__drop-indicator--source)"
  );
}

export default class KanbanCard extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked dragging = false;
  dragHideTimer = null;
  dragImageElement = null;

  willDestroy() {
    super.willDestroy(...arguments);
    const isActiveDragSource =
      this.dragging || this.dragHideTimer || this.dragImageElement;

    this.#clearDragHideTimer();
    this.#cleanupDragImage();

    if (isActiveDragSource) {
      this.#removeDropIndicators();
    }
  }

  get isTopicCard() {
    return this.args.card.card_type === "topic" && this.args.card.topic;
  }

  get topic() {
    return this.args.card.topic;
  }

  get cardTitle() {
    return this.isTopicCard ? this.topic.title : this.args.card.title;
  }

  get tagsHtml() {
    if (!this.args.board.show_tags || !this.topic?.tags) {
      return null;
    }

    const columnTags = new Set(
      (this.args.columnTags || []).map((t) => t.toLowerCase())
    );

    const filtered = this.topic.tags.filter(
      (t) => !columnTags.has(t.toLowerCase())
    );

    if (!filtered.length) {
      return null;
    }

    return renderTags(null, { tags: filtered });
  }

  get category() {
    if (this.args.allSameCategory || !this.topic?.category_id) {
      return null;
    }
    return Category.findById(this.topic.category_id);
  }

  get isDetailed() {
    return this.args.board.card_style === "detailed";
  }

  get showImage() {
    return this.args.board.show_topic_thumbnail && this.topic?.image_url;
  }

  get allAssignedUsers() {
    if (this.topic?.all_assigned_users?.length) {
      return this.topic.all_assigned_users;
    }
    if (this.topic?.assigned_to_user) {
      return [this.topic.assigned_to_user];
    }
    const floaterAssignment = this.args.card.assigned_to;
    if (!this.isTopicCard && floaterAssignment?.type === "User") {
      return [floaterAssignment];
    }
    return [];
  }

  get assignedUser() {
    return this.allAssignedUsers[0] ?? null;
  }

  get assignedGroup() {
    const floaterAssignment = this.args.card.assigned_to;
    if (!this.isTopicCard && floaterAssignment?.type === "Group") {
      return floaterAssignment;
    }
    return null;
  }

  get assignedAvatarHtml() {
    const users = this.allAssignedUsers;
    if (!users.length) {
      return null;
    }
    return users
      .map((user) =>
        renderAvatar(user, {
          avatarTemplatePath: "avatar_template",
          usernamePath: "username",
          imageSize: "tiny",
        })
      )
      .join("");
  }

  get lastPosterUsername() {
    if (this.isTopicCard) {
      return this.topic?.last_poster?.username;
    }
    return this.args.card.created_by?.username;
  }

  get activityDate() {
    if (this.isTopicCard) {
      return this.topic?.bumped_at;
    }
    return this.args.card.created_at;
  }

  get activityClass() {
    if (!this.args.board.show_activity_indicators || !this.activityDate) {
      return "";
    }

    const date = moment(this.activityDate);
    if (date < moment().add(-20, "days")) {
      return "card-stale";
    }
    if (date < moment().add(-7, "days")) {
      return "card-no-recent-activity";
    }
    return "";
  }

  get topicStatusModel() {
    if (!this.isTopicCard) {
      return null;
    }
    return { closed: this.topic?.closed };
  }

  get canShowActions() {
    return this.args.canWrite;
  }

  get canAssign() {
    return (
      this.isTopicCard &&
      this.siteSettings.assign_enabled &&
      this.currentUser?.can_assign
    );
  }

  get isTopicAssigned() {
    return this.allAssignedUsers.length > 0 || !!this.topic?.assigned_to_group;
  }

  get hasDetails() {
    const card = this.args.card;
    return !!(card.notes || card.labels?.length);
  }

  @action
  openDetailModal() {
    const board = this.args.board;
    const boardUrl = kanbanBoardUrl(board);
    const cardUrlPath = kanbanCardUrl(board, this.args.card.id);

    DiscourseURL.replaceState(cardUrlPath);

    this.modal
      .show(KanbanCardDetailModal, {
        model: {
          card: this.args.card,
          canWrite: this.args.canWrite,
          onUpdateCard: this.args.onUpdateCard,
        },
      })
      .finally(() => {
        if (!this.isDestroying && !this.isDestroyed) {
          DiscourseURL.replaceState(boardUrl);
        }
      });
  }

  @action
  openTopicDetailModal() {
    const board = this.args.board;
    const boardUrl = kanbanBoardUrl(board);
    const cardUrlPath = kanbanCardUrl(board, this.args.card.id);
    let navigatedAway = false;

    DiscourseURL.replaceState(cardUrlPath);

    this.modal
      .show(KanbanTopicCardDetailModal, {
        model: {
          card: this.args.card,
          columnTitle: this.args.columnTitle,
          columnIcon: this.args.columnIcon,
          onNavigateAway: (url) => {
            navigatedAway = true;
            DiscourseURL.routeTo(url);
          },
        },
      })
      .finally(() => {
        if (!navigatedAway && !this.isDestroying && !this.isDestroyed) {
          DiscourseURL.replaceState(boardUrl);
        }
      });
  }

  @action
  assignTopic() {
    const taskActions = getOwner(this).lookup("service:task-actions");
    taskActions.showAssignModal(this.topic, {
      isAssigned: this.isTopicAssigned,
      targetType: "Topic",
      onSuccess: () => this.args.onRefreshBoard?.(),
    });
  }

  @action
  async unassignTopic() {
    const taskActions = getOwner(this).lookup("service:task-actions");
    await taskActions.unassign(this.topic.id, "Topic");
    this.args.onRefreshBoard?.();
  }

  @action
  onCardClick(event) {
    if (
      event.target.closest(".kanban-card__actions-trigger") ||
      event.target.closest("[data-content]") ||
      event.target.closest("a")
    ) {
      return;
    }
    if (this.isTopicCard) {
      this.openTopicDetailModal();
    } else {
      this.openDetailModal();
    }
  }

  @action
  onCardKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.onCardClick(event);
    }
  }

  @action
  removeCard() {
    this.args.onDeleteCard(this.args.card.id);
  }

  @action
  dragStart(event) {
    if (!this.args.canWrite) {
      event.preventDefault();
      return;
    }

    const cardRect = event.currentTarget.getBoundingClientRect();
    this.#setDragImage(event, event.currentTarget, cardRect);

    this.args.onDragStart({
      cardId: this.args.card.id,
      topicId: this.args.card.topic_id,
      fromColumnId: this.args.card.column_id,
      cardHeight: cardRect.height,
      hasPlacedIndicator: false,
    });
    event.dataTransfer.effectAllowed = "move";
    event.stopPropagation();

    this.#scheduleDragSourceHide(event.currentTarget, cardRect.height);
  }

  @action
  dragEnd() {
    this.args.onDragEnd?.(this.args.card.id);
    this.#clearDragHideTimer();
    this.#removeDropIndicators();
    this.dragging = false;
    this.#cleanupDragImage();
  }

  #scheduleDragSourceHide(cardElement, cardHeight) {
    this.#clearDragHideTimer();

    this.dragHideTimer = setTimeout(() => {
      this.dragHideTimer = null;

      if (!this.isDestroying && !this.isDestroyed) {
        if (shouldInsertSourceDropIndicator()) {
          this.#insertSourceDropIndicator(cardElement, cardHeight);
        }
        this.dragging = true;
      }
    }, 0);
  }

  #clearDragHideTimer() {
    if (this.dragHideTimer) {
      clearTimeout(this.dragHideTimer);
      this.dragHideTimer = null;
    }
  }

  #setDragImage(event, cardElement, cardRect) {
    if (!event.dataTransfer?.setDragImage) {
      return;
    }

    this.#cleanupDragImage();

    const dragImage = cardElement.cloneNode(true);
    dragImage.classList.remove("kanban-card--dragging");
    dragImage.classList.add("kanban-card--drag-image");
    dragImage.style.width = `${cardRect.width}px`;
    dragImage.style.height = `${cardRect.height}px`;
    dragImage.setAttribute("aria-hidden", "true");

    document.body.append(dragImage);
    this.dragImageElement = dragImage;

    // Fallback for programmatic or test drags where the pointer coordinates are 0.
    const offsetX =
      event.clientX > 0 ? Math.max(event.clientX - cardRect.left, 0) : 24;
    const offsetY =
      event.clientY > 0 ? Math.max(event.clientY - cardRect.top, 0) : 24;

    event.dataTransfer.setDragImage(dragImage, offsetX, offsetY);
  }

  #cleanupDragImage() {
    this.dragImageElement?.remove();
    this.dragImageElement = null;
  }

  #insertSourceDropIndicator(cardElement, cardHeight) {
    const cardsContainer = cardElement.closest(".kanban-column__cards");
    if (!cardsContainer) {
      return;
    }

    this.#removeDropIndicators();

    const indicator = document.createElement("div");
    indicator.className =
      "kanban-column__drop-indicator kanban-column__drop-indicator--source";
    indicator.style.height = `${cardHeight}px`;

    cardsContainer.insertBefore(indicator, cardElement);
  }

  #removeDropIndicators() {
    document
      .querySelectorAll(".kanban-column__drop-indicator")
      .forEach((indicator) => indicator.remove());
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class={{concatClass
        "kanban-card"
        (if this.dragging "kanban-card--dragging")
        (unless this.isTopicCard "kanban-card--floater")
        (if @isDropHighlighted "kanban-card--drop-highlighted")
        this.activityClass
      }}
      draggable={{if @canWrite "true" "false"}}
      role="button"
      tabindex="0"
      data-card-id={{@card.id}}
      data-topic-id={{@card.topic_id}}
      {{on "dragstart" this.dragStart}}
      {{on "dragend" this.dragEnd}}
      {{on "click" this.onCardClick}}
      {{on "keydown" this.onCardKeydown}}
    >
      <div class="kanban-card__row kanban-card__title-row">
        {{#if this.topicStatusModel}}
          <TopicStatus @topic={{this.topicStatusModel}} />
        {{/if}}
        {{#if this.isTopicCard}}
          <span class="kanban-card__title kanban-card__title--topic">
            {{this.cardTitle}}
          </span>
        {{else}}
          <span class="kanban-card__title"><AutoLinkedText
              @text={{this.cardTitle}}
            /></span>
        {{/if}}
        {{#if this.canShowActions}}
          <DMenu
            @identifier="kanban-card-actions"
            @icon="ellipsis"
            @triggerClass="btn-flat btn-small kanban-card__actions-trigger"
          >
            <:content>
              <DropdownMenu as |dropdown|>
                {{#unless this.isTopicCard}}
                  <dropdown.item>
                    <DButton
                      @action={{this.openDetailModal}}
                      @icon="pencil"
                      @label="edit"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{@onPromoteToTopic}}
                      @icon="plus"
                      @label="discourse_kanban.board.new_topic"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                {{/unless}}
                {{#if this.canAssign}}
                  {{#if this.isTopicAssigned}}
                    <dropdown.item>
                      <DButton
                        @action={{this.unassignTopic}}
                        @icon="user-xmark"
                        @label="discourse_kanban.board.unassign"
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  {{/if}}
                  <dropdown.item>
                    <DButton
                      @action={{this.assignTopic}}
                      @icon="user-plus"
                      @label={{if
                        this.isTopicAssigned
                        "discourse_kanban.board.reassign"
                        "discourse_kanban.board.assign"
                      }}
                      class="btn-transparent"
                    />
                  </dropdown.item>
                {{/if}}
                <dropdown.item>
                  <DButton
                    @action={{this.removeCard}}
                    @icon="trash-can"
                    @label="discourse_kanban.board.remove_card"
                    class="btn-transparent btn-danger"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
        {{#unless this.isDetailed}}
          {{#if this.activityDate}}
            <span class="kanban-card__date">
              {{formatDate this.activityDate format="tiny" noTitle="true"}}
            </span>
          {{/if}}
        {{/unless}}
      </div>

      {{#unless this.isTopicCard}}
        {{#if this.hasDetails}}
          <div class="kanban-card__row kanban-card__indicators">
            {{#each @card.labels as |label|}}
              <span class="kanban-card__label">{{label}}</span>
            {{/each}}
            {{#if @card.notes}}
              <span class="kanban-card__notes-indicator" title={{@card.notes}}>
                {{icon "file-lines"}}
              </span>
            {{/if}}
          </div>
        {{/if}}
      {{/unless}}

      {{#if this.tagsHtml}}
        <div class="kanban-card__row kanban-card__tags">
          {{trustHTML this.tagsHtml}}
        </div>
      {{/if}}

      <div class="kanban-card__row">
        {{#if this.category}}
          <div class="kanban-card__category">
            {{categoryBadge this.category}}
          </div>
        {{/if}}

        {{#unless this.isDetailed}}
          {{#if this.allAssignedUsers.length}}
            <div class="kanban-card__assignments">
              {{#each this.allAssignedUsers as |user|}}
                <div class="kanban-card__assigned-to">
                  {{icon "user-plus"}}{{user.username}}
                </div>
              {{/each}}
            </div>
          {{/if}}
          {{#if this.assignedGroup}}
            <div class="kanban-card__assignments">
              <div class="kanban-card__assigned-to">
                {{icon "group"}}{{this.assignedGroup.name}}
              </div>
            </div>
          {{/if}}
        {{/unless}}
      </div>

      {{#if this.isDetailed}}
        <div class="kanban-card__row kanban-card__detail-row">
          <div class="kanban-card__last-post-by">
            {{#if this.activityDate}}
              {{formatDate this.activityDate format="tiny" noTitle="true"}}
            {{/if}}
            {{#if this.lastPosterUsername}}
              ({{this.lastPosterUsername}})
            {{/if}}
          </div>

          {{#if this.assignedAvatarHtml}}
            <div class="kanban-card__assignments-avatars">
              {{trustHTML this.assignedAvatarHtml}}
            </div>
          {{else if this.assignedGroup}}
            <div class="kanban-card__assignments">
              <div class="kanban-card__assigned-to">
                {{icon "group"}}{{this.assignedGroup.name}}
              </div>
            </div>
          {{/if}}
        </div>
      {{/if}}

      {{#if this.showImage}}
        <div class="kanban-card__row kanban-card__thumbnail-row">
          <img class="kanban-card__thumbnail" src={{this.topic.image_url}} />
        </div>
      {{/if}}
    </div>
  </template>
}
