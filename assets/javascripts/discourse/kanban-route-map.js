export default function () {
  this.route("kanbanBoards", { path: "/kanban" });
  this.route("kanbanBoardNew", { path: "/kanban/boards/new" });
  this.route("kanbanBoardConfigure", {
    path: "/kanban/boards/:slug/:id/configure",
  });
  this.route("kanbanBoard", { path: "/kanban/boards/:slug/:id" });
}
