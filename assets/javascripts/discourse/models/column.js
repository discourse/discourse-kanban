import { tracked } from "@glimmer/tracking";

export default class Column {
  static create(args = {}) {
    return new Column(args);
  }

  @tracked cards;
  @tracked icon;
  @tracked id;
  @tracked move_to_assigned;
  @tracked move_to_category_id;
  @tracked move_to_status;
  @tracked position;
  @tracked tag_id;
  @tracked tag_name;
  @tracked title;

  constructor(args = {}) {
    Object.assign(this, args);
  }
}
