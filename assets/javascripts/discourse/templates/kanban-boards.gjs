import KanbanBoardsPage from "../components/kanban-boards-page";

export default <template>
  <KanbanBoardsPage
    @boards={{@controller.model}}
    @canManageBoards={{@controller.currentUser.can_manage_kanban_boards}}
  />
</template>
