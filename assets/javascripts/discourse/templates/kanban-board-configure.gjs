import { array } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";
import KanbanBoardViewer from "../components/kanban-board-viewer";

export default <template>
  {{bodyClass "discourse-kanban-board"}}
  {{#each (array @controller.model) as |model|}}
    <KanbanBoardViewer
      @model={{model}}
      @openBoardSettings={{model.openBoardSettings}}
    />
  {{/each}}
</template>
