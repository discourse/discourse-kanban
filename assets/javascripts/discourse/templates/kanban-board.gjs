import bodyClass from "discourse/helpers/body-class";
import KanbanBoardViewer from "../components/kanban-board-viewer";

export default <template>
  {{bodyClass "kanban-board"}}
  <KanbanBoardViewer @model={{@controller.model}} />
</template>
