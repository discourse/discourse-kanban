import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardRoute extends DiscourseRoute {
  model(params) {
    return ajax(`/kanban/boards/${params.id}.json`);
  }
}
