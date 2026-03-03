import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardCardRoute extends DiscourseRoute {
  @service router;

  model(params) {
    return ajax(`/kanban/boards/${params.id}.json`).then((data) => ({
      ...data,
      initialCardId: parseInt(params.card_id, 10),
    }));
  }

  afterModel(model, transition) {
    const board = model.board;
    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith(
        "kanbanBoardCard",
        board.slug,
        board.id,
        transition.to.params.card_id
      );
    }
  }
}
