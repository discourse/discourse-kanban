import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
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
          {{i18n "discourse_kanban.manage.new"}}
        </LinkTo>
      {{/if}}
    </div>

    {{#if @controller.model.length}}
      <table class="kanban-boards-table">
        <thead>
          <tr>
            <th>{{i18n "discourse_kanban.manage.table.name"}}</th>
            <th>{{i18n "discourse_kanban.manage.table.slug"}}</th>
            <th>{{i18n "discourse_kanban.manage.table.columns"}}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.model as |board|}}
            <tr>
              <td>
                <LinkTo
                  @route="kanbanBoard"
                  @models={{array board.slug board.id}}
                >
                  {{board.name}}
                </LinkTo>
              </td>
              <td><code>{{board.slug}}</code></td>
              <td>{{board.columns.length}}</td>
              <td>
                {{#if board.can_manage}}
                  <LinkTo
                    @route="kanbanBoardConfigure"
                    @models={{array board.slug board.id}}
                    class="btn btn-small"
                  >
                    {{i18n "discourse_kanban.manage.table.edit"}}
                  </LinkTo>
                {{/if}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <p class="discourse-kanban-manage__empty">
        {{i18n "discourse_kanban.manage.get_started"}}
      </p>
    {{/if}}
  </div>
</template>;

export default KanbanBoards;
