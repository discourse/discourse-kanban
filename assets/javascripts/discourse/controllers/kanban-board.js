import Controller from "@ember/controller";

export default class KanbanBoardController extends Controller {
  queryParams = ["card"];
  card = null;
}
