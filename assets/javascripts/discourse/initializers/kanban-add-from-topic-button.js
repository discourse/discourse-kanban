import { getOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import KanbanAddFromTopicMenu from "../components/kanban-add-from-topic-menu.gjs";

const BUTTON_ID = "kanban-add-from-topic";

export default {
  name: "kanban-add-from-topic-button",

  initialize() {
    registerTopicFooterButton({
      id: BUTTON_ID,
      icon: "discourse-kanban",
      label: "discourse_kanban.topic_footer.add_to_board",
      title: "discourse_kanban.topic_footer.add_to_board",
      classNames: ["kanban-add-from-topic-button"],
      displayed() {
        return !this.topic?.isPrivateMessage;
      },
      action() {
        const trigger = document.getElementById(
          `topic-footer-button-${BUTTON_ID}`
        );

        if (!trigger) {
          return;
        }

        getOwner(this)
          .lookup("service:menu")
          .show(trigger, {
            identifier: "kanban-add-from-topic-menu",
            component: KanbanAddFromTopicMenu,
            modalForMobile: true,
            placement: "bottom-start",
            data: { topic: this.topic },
          });
      },
    });

    withPluginApi((api) => {
      api.addTrackedTopicProperties("kanban_memberships");
      api.registerCustomPostMessageCallback(
        "kanban_topic_added_to_board",
        (controller, message) => {
          controller.model.kanban_memberships = message.kanban_memberships;
        }
      );
    });
  },
};
