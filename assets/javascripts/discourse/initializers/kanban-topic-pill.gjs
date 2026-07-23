import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";
import KanbanTopicPill from "../components/kanban-topic-pill";

// Shows the pill in the docked header's tags row (.topic-header-extra).
// That row has no plugin outlet, so mount on the title-suffix outlet and
// render into the row with in-element; the destination is resolved after
// render because the row isn't in the DOM yet when this connector renders.
class HeaderExtraPill extends Component {
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

      api.renderInOutlet(
        "topic-category",
        <template><KanbanTopicPill @topic={{@outletArgs.topic}} /></template>
      );

      api.renderInOutlet("header-topic-title-suffix", HeaderExtraPill);
    });
  },
};
