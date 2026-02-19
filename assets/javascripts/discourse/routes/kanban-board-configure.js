import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardConfigureRoute extends DiscourseRoute {
  async model(params) {
    const data = await ajax(`/kanban/boards/${params.id}.json`);
    return new TrackedObject(data.board);
  }
}
