import { withPluginApi } from "discourse/lib/plugin-api";
import RightSidebarPanel from "../discourse/components/right-sidebar-panel";

export default {
  name: "kanban-blocks",

  initialize() {
    withPluginApi((api) => {
      api.renderInOutlet("sidebar-right", RightSidebarPanel);
    });
  },
};
