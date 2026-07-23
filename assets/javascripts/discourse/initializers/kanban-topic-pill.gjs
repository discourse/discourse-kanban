import Component from "@glimmer/component";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { escapeExpression } from "discourse/lib/utilities";
import KanbanTopicPill from "../components/kanban-topic-pill";
import { kanbanBoardUrl } from "../lib/kanban-urls";

// The mobile topic list is a different template without the desktop cell's
// bottom-line outlet, so it needs its own connector; the mobileView guard
// stops it from double-rendering on desktop, where this outlet also exists.
class MobileTopicListPill extends Component {
  static shouldRender(args, context) {
    return context.site.mobileView;
  }

  <template><KanbanTopicPill @topic={{@outletArgs.topic}} /></template>
}

function pillHtml(membership) {
  const boardUrl = kanbanBoardUrl({
    slug: membership.board_slug,
    id: membership.board_id,
  });
  const href = `${boardUrl}?card=${membership.cards[0].card_id}`;
  const name = escapeExpression(membership.board_name);

  return `<a class="kanban-topic-pill" href="${href}">${iconHTML(
    "table-columns"
  )}<span class="kanban-topic-pill__label">${name}</span></a>`;
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

      // The docked header renders its tags row as raw HTML via renderTags,
      // so inject there like discourse-assign does. Only the header calls
      // renderTags without params; the other locations pass a mode and are
      // covered by the component connectors above.
      api.addTagsHtmlCallback((topic, params) => {
        if (params) {
          return;
        }

        const memberships = topic.kanban_memberships;
        if (!memberships?.length) {
          return;
        }

        return memberships.map(pillHtml).join("");
      });
    });
  },
};
