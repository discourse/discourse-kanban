import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import KanbanBoardSettings from "./modal/kanban-board-settings";

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
      <div class="discourse-kanban-manage__header">
        <div>
          <h2>{{i18n "discourse_kanban.manage.title"}}</h2>
          <p>{{i18n "discourse_kanban.manage.description"}}</p>
        </div>
        {{#if @canManageBoards}}
          <DButton
            @action={{this.openNewBoardModal}}
            @icon="plus"
            @label="discourse_kanban.manage.new"
            class="btn-primary"
          />
        {{/if}}
      </div>

      {{#if @boards.length}}
        <div class="kanban-boards-grid">
          {{#each @boards as |board|}}
            <div class="kanban-board-card">
              <div class="kanban-board-card__header">
                <LinkTo
                  @route="kanbanBoard"
                  @models={{array board.slug board.id}}
                  class="kanban-board-card__name"
                >
                  {{board.name}}
                </LinkTo>
              </div>

              <div class="kanban-board-card__columns">
                {{#if board.columns.length}}
                  {{#each board.columns as |column|}}
                    <span class="kanban-board-card__column-pill">
                      {{#if column.icon}}
                        {{icon column.icon}}
                      {{/if}}
                      {{column.title}}
                    </span>
                  {{/each}}
                {{else}}
                  <span class="kanban-board-card__no-columns">
                    {{i18n "discourse_kanban.manage.no_columns"}}
                  </span>
                {{/if}}
              </div>

              <div class="kanban-board-card__footer">
                <span class="kanban-board-card__badge">
                  {{i18n
                    "discourse_kanban.manage.column_count"
                    count=board.columns.length
                  }}
                </span>
                {{#if (eq board.card_style "simple")}}
                  <span class="kanban-board-card__badge">
                    {{i18n "discourse_kanban.manage.card_style_simple"}}
                  </span>
                {{/if}}
                {{#if board.allow_read_group_ids.length}}
                  <span
                    class="kanban-board-card__badge kanban-board-card__badge--restricted"
                    title={{i18n "discourse_kanban.manage.restricted_access"}}
                  >
                    {{icon "lock"}}
                  </span>
                {{/if}}
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="kanban-boards-empty">
          {{icon "table-columns"}}
          <h3>{{i18n "discourse_kanban.manage.empty_title"}}</h3>
          <p>{{i18n "discourse_kanban.manage.get_started"}}</p>
          {{#if @canManageBoards}}
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
