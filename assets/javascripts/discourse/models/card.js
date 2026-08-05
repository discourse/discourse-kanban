import { tracked } from "@glimmer/tracking";

export default class Card {
  static create(args = {}) {
    if (args instanceof Card) {
      return args;
    }
    return new Card(args);
  }

  @tracked assigned_to;
  @tracked board_id;
  @tracked card_type;
  @tracked column_id;
  @tracked created_at;
  @tracked column_changed_at;
  @tracked created_by;
  @tracked id;
  @tracked notes;
  @tracked position;
  @tracked recency_at;
  @tracked tag_ids;
  @tracked tags;
  @tracked title;
  @tracked topic;
  @tracked unicode_title;
  @tracked updated_at;

  constructor(args = {}) {
    Object.assign(this, args);
  }

  get fancyTitle() {
    const titleSource =
      this.card_type === "topic" && this.topic ? this.topic : this;
    return titleSource.unicode_title || titleSource.title;
  }
}
