import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";

export default class KanbanBoardNewRoute extends DiscourseRoute {
  model() {
    return new TrackedObject({
      name: null,
      slug: null,
      base_filter_query: null,
      card_style: "detailed",
      show_tags: false,
      show_topic_thumbnail: false,
      show_activity_indicators: false,
      require_confirmation: true,
      allow_read_group_ids: [],
      allow_write_group_ids: [],
      columns: [],
    });
  }
}
