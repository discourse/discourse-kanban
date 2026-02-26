import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
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
import Category from "discourse/models/category";
import KanbanCardDetailModal from "./modal/kanban-card-detail";

export default class KanbanCard extends Component {
  @service modal;

  @tracked dragging = false;

  get isTopicCard() {
    return this.args.card.card_type === "topic" && this.args.card.topic;
  }

  get topic() {
    return this.args.card.topic;
  }

  get cardTitle() {
    return this.isTopicCard ? this.topic.title : this.args.card.title;
  }

  get topicUrl() {
    if (!this.isTopicCard) {
      return null;
    }
    const t = this.topic;
    return `/t/${t.slug}/${t.id}`;
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
    return [];
  }

  get assignedUser() {
    return this.allAssignedUsers[0] ?? null;
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
    return this.args.card.updated_by?.username;
  }

  get activityDate() {
    if (this.isTopicCard) {
      return this.topic?.bumped_at;
    }
    return this.args.card.updated_at;
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

  get hasDetails() {
    const card = this.args.card;
    return !!(card.notes || card.labels?.length || card.due_at);
  }

  get isOverdue() {
    return (
      this.args.card.due_at &&
      moment(this.args.card.due_at).isBefore(moment(), "day")
    );
  }

  @action
  openDetailModal() {
    this.modal.show(KanbanCardDetailModal, {
      model: {
        card: this.args.card,
        canWrite: this.args.canWrite,
        onUpdateCard: this.args.onUpdateCard,
      },
    });
  }

  @action
  onCardClick(event) {
    if (this.isTopicCard) {
      return;
    }
    if (
      event.target.closest(".kanban-card__actions-trigger") ||
      event.target.closest("[data-content]")
    ) {
      return;
    }
    this.openDetailModal();
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
    this.dragging = true;
    const cardHeight = event.currentTarget.getBoundingClientRect().height;
    this.args.onDragStart({
      cardId: this.args.card.id,
      topicId: this.args.card.topic_id,
      fromColumnId: this.args.card.column_id,
      cardHeight,
    });
    event.dataTransfer.effectAllowed = "move";
    event.stopPropagation();
  }

  @action
  dragEnd() {
    this.dragging = false;
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class={{concatClass
        "kanban-card"
        (if this.dragging "dragging")
        (unless this.isTopicCard "kanban-card--floater")
        (if @isDropHighlighted "kanban-card--drop-highlighted")
        this.activityClass
      }}
      draggable={{if @canWrite "true" "false"}}
      role={{unless this.isTopicCard "button"}}
      data-card-id={{@card.id}}
      data-topic-id={{@card.topic_id}}
      {{on "dragstart" this.dragStart}}
      {{on "dragend" this.dragEnd}}
      {{on "click" this.onCardClick}}
    >
      <div class="kanban-card__row kanban-card__title-row">
        {{#if this.topicStatusModel}}
          <TopicStatus @topic={{this.topicStatusModel}} />
        {{/if}}
        {{#if this.topicUrl}}
          <a href={{this.topicUrl}} class="kanban-card__title">
            {{this.cardTitle}}
          </a>
        {{else}}
          <span class="kanban-card__title">{{this.cardTitle}}</span>
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
            {{#if @card.due_at}}
              <span
                class={{concatClass
                  "kanban-card__due-date"
                  (if this.isOverdue "kanban-card__due-date--overdue")
                }}
              >
                {{icon "clock"}}
                {{formatDate @card.due_at format="tiny" noTitle="true"}}
              </span>
            {{/if}}
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
          {{htmlSafe this.tagsHtml}}
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
              {{htmlSafe this.assignedAvatarHtml}}
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
