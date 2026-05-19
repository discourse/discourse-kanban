// import TopicSidebarBlock from "discourse/components/topic-sidebar-block";
import { withPluginApi } from "discourse/lib/plugin-api";
import RightSidebarPanel from "../discourse/components/right-sidebar-panel";

export default {
  name: "kanban-blocks",

  initialize() {
    withPluginApi((api) => {
      api.renderInOutlet("sidebar-right", RightSidebarPanel);
      // api.renderBlocks("sidebar-right", [
      //   {
      //     block: TopicSidebarBlock,
      //     id: "topic-sidebar-block",
      //     conditions: [
      //       { type: "route", urls: ["/kanban/boards/**/**/card/**"] },
      //     ],
      //   },
      // ]);
    });
  },
};
