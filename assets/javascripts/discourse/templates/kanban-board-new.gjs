import BackButton from "discourse/components/back-button";
import KanbanBoardForm from "../components/kanban-board-form";

export default <template>
  <BackButton @route="kanbanBoards" />

  <div class="kanban-board-form-container">
    <KanbanBoardForm @model={{@controller.model}} />
  </div>
</template>
