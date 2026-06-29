import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import boundCategoryLink from "discourse/helpers/bound-category-link";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { eq, or } from "discourse/truth-helpers";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";
import KanbanBoardSettings from "./modal/kanban-board-settings";

function boardCategories(board) {
  return (board.category_ids || [])
    .map((id) => Category.findById(id))
    .filter(Boolean);
}

export default class KanbanBoardsPage extends Component {
  @service modal;
  @service router;
  @service toasts;

  @action
  openNewBoardModal() {
    this.modal.show(KanbanBoardSettings, {
      model: {
        board: null,
        isNew: true,
        onSave: (boardData) => this.createBoard(boardData),
        onDelete: () => {},
      },
    });
  }

  @action
  async createBoard(boardData) {
    const payload = {
      board: {
        ...boardData,
        columns: [],
      },
    };

    const result = await ajax("/kanban/boards", {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify(payload),
    });

    this.toasts.success({
      data: { message: i18n("saved") },
      duration: "short",
    });

    const savedBoard = result.board;
    this.router.transitionTo("kanbanBoard", savedBoard.slug, savedBoard.id);
  }

  <template>
    <div class="discourse-kanban-manage">
      <DPageHeader
        @titleLabel={{i18n "discourse_kanban.manage.title"}}
        @descriptionLabel={{i18n "discourse_kanban.manage.description"}}
        @hideTabs={{true}}
      >
        <:actions as |actions|>
          {{#if @canManageBoards}}
            <actions.Primary
              @action={{this.openNewBoardModal}}
              @icon="plus"
              @label="discourse_kanban.manage.new"
              class="btn-primary discourse-kanban-manage__new-board"
            />
          {{/if}}
        </:actions>
      </DPageHeader>

      {{#if @boards.length}}
        <div class="discourse-kanban-boards-grid">
          {{#each @boards as |board|}}
            <div class="discourse-kanban-board-card">
              <div class="discourse-kanban-board-card__header">
                <LinkTo
                  @route="kanbanBoard"
                  @models={{array board.slug board.id}}
                  class="discourse-kanban-board-card__name"
                >
                  {{board.name}}
                </LinkTo>
              </div>

              {{#if (or board.category_ids.length board.tag_names.length)}}
                <div class="discourse-kanban-board-card__constraints">
                  {{#each (boardCategories board) as |category|}}
                    {{boundCategoryLink category link=false}}
                  {{/each}}
                  {{#if board.tag_names.length}}
                    <div class="list-tags">
                      {{discourseTags null tags=board.tag_names}}
                    </div>
                  {{/if}}
                </div>
              {{/if}}

              <div class="discourse-kanban-board-card__columns">
                {{#if board.columns.length}}
                  {{#each board.columns as |column|}}
                    <span class="discourse-kanban-column-pill">
                      {{#if column.icon}}
                        {{icon column.icon}}
                      {{/if}}
                      {{column.title}}
                    </span>
                  {{/each}}
                {{else}}
                  <span class="discourse-kanban-board-card__no-columns">
                    {{i18n "discourse_kanban.manage.no_columns"}}
                  </span>
                {{/if}}
              </div>

              <div class="discourse-kanban-board-card__footer">
                <UserLink
                  class="discourse-kanban-board-card__creator discourse-kanban-badge"
                  @user={{board.created_by}}
                >
                  {{i18n "discourse_kanban.board.created_by"}}
                  {{avatar board.created_by imageSize="micro"}}
                </UserLink>

                <span class="discourse-kanban-badge">
                  {{i18n
                    "discourse_kanban.manage.column_count"
                    count=board.columns.length
                  }}
                </span>
                {{#if (eq board.card_style "simple")}}
                  <span class="discourse-kanban-badge">
                    {{i18n "discourse_kanban.manage.card_style_simple"}}
                  </span>
                {{/if}}
                {{#unless board.anonymous_can_read}}
                  <span
                    class="discourse-kanban-badge discourse-kanban-badge--restricted"
                    title={{i18n "discourse_kanban.manage.restricted_access"}}
                  >
                    {{icon "lock"}}
                  </span>
                {{/unless}}
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="discourse-kanban-boards-empty">
          {{icon "table-columns"}}
          <h3>{{i18n "discourse_kanban.manage.empty_title"}}</h3>
          {{#if @canManageBoards}}
            <p>{{i18n "discourse_kanban.manage.get_started"}}</p>
            <DButton
              @action={{this.openNewBoardModal}}
              @icon="plus"
              @label="discourse_kanban.manage.new"
              class="btn-primary"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
