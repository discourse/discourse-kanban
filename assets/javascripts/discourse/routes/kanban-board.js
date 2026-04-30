import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { sortCardsForColumn } from "../lib/kanban-card-ordering";
import Board from "../models/board";
import Card from "../models/card";
import Column from "../models/column";

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

    model.board = Board.create(model.board);
    model.board.columns = model.board.columns.map((col) => {
      const colModel = Column.create(col);
      colModel.cards = sortCardsForColumn(colModel, colModel.cards || []).map(
        (card) => Card.create(card)
      );
      return colModel;
    });
  }
}
