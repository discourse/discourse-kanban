import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardConfigureRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return this.controller?.model?.board?.name;
  }

  model(params) {
    return ajax(`/kanban/boards/${params.id}.json`).then((data) => ({
      ...data,
      openBoardSettings: true,
    }));
  }

  afterModel(model, transition) {
    const board = model.board;
    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith("kanbanBoardConfigure", board.slug, board.id);
    }
  }
}
