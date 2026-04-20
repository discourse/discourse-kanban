import { tracked } from "@glimmer/tracking";

export default class Card {
  static create(args = {}) {
    return new Card(args);
  }

  @tracked assigned_to;
  @tracked board_id;
  @tracked card_type;
  @tracked column_id;
  @tracked created_at;
  @tracked created_by;
  @tracked id;
  @tracked notes;
  @tracked position;
  @tracked tag_ids;
  @tracked tags;
  @tracked title;

  constructor(args = {}) {
    Object.assign(this, args);
  }
}
