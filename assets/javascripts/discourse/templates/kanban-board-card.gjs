import { array } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";
import KanbanBoardViewer from "../components/kanban-board-viewer";

export default <template>
  {{bodyClass "kanban-board"}}
  {{#each (array @controller.model) as |model|}}
    <KanbanBoardViewer
      @model={{model}}
      @initialCardId={{model.initialCardId}}
    />
  {{/each}}
</template>
