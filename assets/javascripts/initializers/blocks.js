import TopicSidebarBlock from "discourse/components/topic-sidebar-block";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "kanban-blocks",

  initialize() {
    withPluginApi((api) => {
      api.renderBlocks("sidebar-right", [
        {
          block: TopicSidebarBlock,
          id: "topic-sidebar-block",
          conditions: [
            { type: "route", urls: ["/kanban/boards/**/**/card/**"] },
          ],
        },
      ]);
    });
  },
};
