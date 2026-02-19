import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import KanbanBoardForm from "../components/kanban-board-form";

export default <template>
  <div class="kanban-configure-nav">
    <LinkTo @route="kanbanBoards" class="btn btn-transparent back-button">
      {{icon "chevron-left"}}
      {{i18n "discourse_kanban.manage.all_boards"}}
    </LinkTo>
    <LinkTo
      @route="kanbanBoard"
      @models={{array @controller.model.slug @controller.model.id}}
      class="btn btn-transparent back-button"
    >
      {{i18n "discourse_kanban.manage.view_board"}}
      {{icon "chevron-right"}}
    </LinkTo>
  </div>

  <div class="kanban-board-form-container">
    <KanbanBoardForm @model={{@controller.model}} />
  </div>
</template>
