export default function () {
  this.route("kanbanBoards", { path: "/kanban" });
  this.route("kanbanBoard", { path: "/kanban/boards/:slug/:id" });
  this.route("kanbanBoardCard", {
    path: "/kanban/boards/:slug/:id/card/:card_id",
  });
}
