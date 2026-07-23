import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";
import KanbanTopicPill from "../components/kanban-topic-pill";

// Renders only in the mobile topic list layout; the desktop layout gets the
// pill inline with the category/tags line via the wrapper outlet below.
class MobileTopicListPill extends Component {
  static shouldRender(args, context) {
    return context.site.mobileView;
  }

  <template><KanbanTopicPill @topic={{@outletArgs.topic}} /></template>
}

// Wraps the category badge shown when scrolling puts the topic title into
// the site header; the outlet only receives the category, so the topic
// comes from the header service.
class HeaderCategoriesPill extends Component {
  @service header;

  <template>
    {{yield}}
    <KanbanTopicPill @topic={{this.header.topicInfo}} />
  </template>
}

// Core only renders the header categories row when the topic has a visible
// category badge, so uncategorized topics get the pill in the tags row
// (.topic-header-extra) instead. That row has no outlet, so render into it
// with in-element. Mirrors the categories-wrapper guard in header/topic/info.
class HeaderExtraPill extends Component {
  static shouldRender(args, { siteSettings }) {
    const category = args.topic?.category;
    const categoriesRowVisible =
      category &&
      (!category.isUncategorizedCategory ||
        !siteSettings.suppress_uncategorized_badge);
    return !categoriesRowVisible;
  }

  @tracked destination = null;

  constructor() {
    super(...arguments);
    schedule("afterRender", () => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.destination = document.querySelector(
        ".d-header .topic-header-extra"
      );
    });
  }

  <template>
    {{#if this.destination}}
      {{#in-element this.destination insertBefore=null}}
        <KanbanTopicPill @topic={{@outletArgs.topic}} />
      {{/in-element}}
    {{/if}}
  </template>
}

export default {
  name: "kanban-topic-pill",

  initialize() {
    withPluginApi((api) => {
      api.renderInOutlet(
        "topic-list-topic-cell-link-bottom-line",
        <template>
          {{yield}}
          <KanbanTopicPill @topic={{@outletArgs.topic}} />
        </template>
      );

      api.renderInOutlet("topic-list-main-link-bottom", MobileTopicListPill);

      api.renderInOutlet(
        "topic-category",
        <template><KanbanTopicPill @topic={{@outletArgs.topic}} /></template>
      );

      api.renderInOutlet("header-categories-wrapper", HeaderCategoriesPill);
      api.renderInOutlet("header-topic-title-suffix", HeaderExtraPill);
    });
  },
};
