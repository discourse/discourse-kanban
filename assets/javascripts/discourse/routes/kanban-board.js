import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { sortCardsForColumn } from "../lib/kanban-card-ordering";

export default class KanbanBoardRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return this.controller?.model?.board?.name;
  }

  model(params) {
    return ajax(`/kanban/boards/${params.id}.json`);
  }

  afterModel(model, transition) {
    const board = model.board;
    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith("kanbanBoard", board.slug, board.id);
    }

    model.board.columns = model.board.columns.map((col) => {
      col.cards = sortCardsForColumn(col, col.cards || []);
      return col;
    });
  }
}
