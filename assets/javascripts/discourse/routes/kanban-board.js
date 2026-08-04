import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { kanbanBoardTitle } from "../lib/kanban-board-title";
import { sortCardsForColumn } from "../lib/kanban-card-ordering";

export default class KanbanBoardRoute extends DiscourseRoute {
  @service router;

  queryParams = {
    card: { refreshModel: true },
  };

  titleToken() {
    return kanbanBoardTitle(this.controller?.model?.board);
  }

  model(params, transition) {
    return ajax(`/kanban/boards/${params.id}.json`).then((data) => ({
      ...data,
      highlightCardId: parseInt(transition.to.queryParams.card, 10) || null,
    }));
  }

  afterModel(model, transition) {
    const board = model.board;
    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith("kanbanBoard", board.slug, board.id, {
        queryParams: { card: transition.to.queryParams.card },
      });
    }

    model.board.columns = model.board.columns.map((col) => {
      col.cards = sortCardsForColumn(col, col.cards || []);
      return col;
    });
  }
}
