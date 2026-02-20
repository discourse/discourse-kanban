import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const KanbanBoards = <template>
  <div class="discourse-kanban-manage">
    <div class="discourse-kanban-manage__header">
      <div>
        <h2>{{i18n "discourse_kanban.manage.title"}}</h2>
        <p>{{i18n "discourse_kanban.manage.description"}}</p>
      </div>
      {{#if @controller.currentUser.can_manage_kanban_boards}}
        <LinkTo @route="kanbanBoardNew" class="btn btn-primary">
          {{icon "plus"}}
          {{i18n "discourse_kanban.manage.new"}}
        </LinkTo>
      {{/if}}
    </div>

    {{#if @controller.model.length}}
      <div class="kanban-boards-grid">
        {{#each @controller.model as |board|}}
          <div class="kanban-board-card">
            <div class="kanban-board-card__header">
              <LinkTo
                @route="kanbanBoard"
                @models={{array board.slug board.id}}
                class="kanban-board-card__name"
              >
                {{board.name}}
              </LinkTo>
              {{#if board.can_manage}}
                <LinkTo
                  @route="kanbanBoardConfigure"
                  @models={{array board.slug board.id}}
                  class="btn btn-flat btn-icon no-text btn-small kanban-board-card__configure"
                  title={{i18n "discourse_kanban.board.configure"}}
                >
                  {{icon "gear"}}
                </LinkTo>
              {{/if}}
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
        {{#if @controller.currentUser.can_manage_kanban_boards}}
          <LinkTo @route="kanbanBoardNew" class="btn btn-primary">
            {{icon "plus"}}
            {{i18n "discourse_kanban.manage.new"}}
          </LinkTo>
        {{/if}}
      </div>
    {{/if}}
  </div>
</template>;

export default KanbanBoards;
