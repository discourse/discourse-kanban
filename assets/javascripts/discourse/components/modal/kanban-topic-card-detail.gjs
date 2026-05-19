import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DecoratedHtml from "discourse/components/decorated-html";
import categoryBadge from "discourse/helpers/category-badge";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import renderTags from "discourse/lib/render-tags";
import Category from "discourse/models/category";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class KanbanTopicCardDetail extends Component {
  @tracked loading = true;
  @tracked cooked = null;
  @tracked loadError = false;

  constructor() {
    super(...arguments);
    this.loadFirstPost();
  }

  get topic() {
    return this.args.model.card.topic;
  }

  get topicUrl() {
    const t = this.topic;
    return `/t/${t.slug}/${t.id}`;
  }

  get category() {
    if (!this.topic?.category_id) {
      return null;
    }
    return Category.findById(this.topic.category_id);
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

  get assignedGroupName() {
    return this.topic?.assigned_to_group?.name;
  }

  get replyCount() {
    const count = this.topic?.posts_count;
    return count > 1 ? count - 1 : 0;
  }

  get lastPoster() {
    return this.topic?.last_poster;
  }

  get columnData() {
    const { columnTitle, columnIcon } = this.args.model;
    if (!columnTitle) {
      return null;
    }
    return { title: columnTitle, icon: columnIcon };
  }

  get tagsHtml() {
    if (!this.topic?.tags?.length) {
      return null;
    }
    return renderTags(null, { tags: this.topic.tags });
  }

  async loadFirstPost() {
    try {
      const post = await ajax(
        `/posts/by_number/${this.args.model.card.topic_id}/1.json`
      );
      this.cooked = post.cooked;
    } catch {
      this.loadError = true;
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{this.topic.title}}
      @closeModal={{@closeModal}}
      class="discourse-kanban-topic-card-detail-modal"
    >
      <:body>
        {{! template-lint-disable no-invalid-interactive }}
        {{#if
          (or
            this.category
            this.tagsHtml
            this.allAssignedUsers.length
            this.columnData
          )
        }}
          <div class="discourse-kanban-topic-card-detail__meta">
            {{#if this.category}}
              {{categoryBadge this.category link=true}}
            {{/if}}
            {{#if this.tagsHtml}}
              <span class="discourse-kanban-topic-card-detail__tags">
                {{trustHTML this.tagsHtml}}
              </span>
            {{/if}}
            {{#if this.allAssignedUsers.length}}
              <span class="discourse-kanban-topic-card-detail__assigned">
                {{icon "user-plus"}}
                {{#each this.allAssignedUsers as |user|}}
                  <a
                    href="/u/{{user.username}}/activity/assigned"
                    class="discourse-kanban-topic-card-detail__username"
                  >{{user.username}}</a>
                {{/each}}
              </span>
            {{else if this.assignedGroupName}}
              <span class="discourse-kanban-topic-card-detail__assigned">
                {{icon "group-plus"}}
                <span
                  class="discourse-kanban-topic-card-detail__username"
                >{{this.assignedGroupName}}</span>
              </span>
            {{/if}}
            {{#if this.columnData}}
              <span class="discourse-kanban-column__title">
                {{#if this.columnData.icon}}{{icon this.columnData.icon}}{{/if}}
                {{this.columnData.title}}
              </span>
            {{/if}}
          </div>
        {{/if}}

        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.loadError}}
            <div class="discourse-kanban-topic-card-detail__error">
              {{i18n "discourse_kanban.board.topic_load_error"}}
            </div>
          {{else}}
            <div class="discourse-kanban-topic-card-detail__cooked">
              <DecoratedHtml
                @html={{trustHTML this.cooked}}
                @className="cooked"
              />
            </div>
          {{/if}}
        </ConditionalLoadingSpinner>

        {{#if this.replyCount}}
          <div class="discourse-kanban-topic-card-detail__stats">
            {{icon "comments"}}
            {{i18n
              "discourse_kanban.board.topic_reply_count"
              count=this.replyCount
            }}
            {{#if this.lastPoster}}
              <span
                class="discourse-kanban-topic-card-detail__separator"
              >·</span>
              {{i18n
                "discourse_kanban.board.topic_last_reply"
                username=this.lastPoster.username
              }}
              {{formatDate this.topic.bumped_at format="medium"}}
            {{/if}}
          </div>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @href={{this.topicUrl}}
          class="btn-primary"
          @action={{this.viewTopic}}
          @icon="up-right-from-square"
          @label="discourse_kanban.board.view_topic"
        />
      </:footer>
    </DModal>
  </template>
}
