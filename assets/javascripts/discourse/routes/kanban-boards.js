import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class KanbanBoardsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("discourse_kanban.manage.title");
  }

  async model() {
    const data = await ajax("/kanban/boards.json");
    return data.boards;
  }
}
