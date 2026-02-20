import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardConfigureRoute extends DiscourseRoute {
  @service router;

  async model(params) {
    const data = await ajax(`/kanban/boards/${params.id}.json`);
    this._boardSlug = data.board?.slug;
    return new TrackedObject(data.board);
  }

  afterModel(_model, transition) {
    if (this._boardSlug && transition.to.params.slug !== this._boardSlug) {
      this.router.replaceWith(
        "kanbanBoardConfigure",
        this._boardSlug,
        transition.to.params.id
      );
    }
  }
}
