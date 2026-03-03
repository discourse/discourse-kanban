import KanbanBoardViewer from "../components/kanban-board-viewer";
import htmlClass from "discourse/helpers/html-class";
export default <template>
  {{htmlClass "kanban-board"}}
  <KanbanBoardViewer @model={{@controller.model}} />
</template>
