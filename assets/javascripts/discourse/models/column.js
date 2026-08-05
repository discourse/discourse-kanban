import { tracked } from "@glimmer/tracking";
import Card from "./card";

export default class Column {
  static create(args = {}) {
    if (args instanceof Column) {
      return args;
    }
    return new Column(args);
  }

  @tracked cards;
  @tracked color;
  @tracked default_sort;
  @tracked icon;
  @tracked id;
  @tracked move_to_assigned;
  @tracked move_to_category_id;
  @tracked move_to_status;
  @tracked position;
  @tracked tag_id;
  @tracked tag_name;
  @tracked title;
  @tracked unicode_title;

  constructor(args = {}) {
    Object.assign(this, args);
    this.cards = (args.cards || []).map((card) => Card.create(card));
  }

  get fancyTitle() {
    return this.unicode_title || this.title;
  }
}
