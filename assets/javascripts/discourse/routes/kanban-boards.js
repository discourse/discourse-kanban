import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardsRoute extends DiscourseRoute {
  async model() {
    const data = await ajax("/kanban/boards.json");
    return data.boards;
  }
}
