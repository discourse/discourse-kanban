import { tracked } from "@glimmer/tracking";

export default class Board {
  static create(args = {}) {
    return new Board(args);
  }

  @tracked anonymous_can_read;
  @tracked can_manage;
  @tracked can_write;
  @tracked card_style;
  @tracked category_ids;
  @tracked columns;
  @tracked id;
  @tracked name;
  @tracked require_confirmation;
  @tracked show_tags;
  @tracked show_topic_thumbnail;
  @tracked slug;
  @tracked tag_ids;
  @tracked tag_names;

  constructor(args = {}) {
    Object.assign(this, args);
  }
}
