import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import DiscourseURL from "discourse/lib/url";
import { columnColorVariable } from "../lib/kanban-column-helpers";
import {
  kanbanColumnTitle,
  kanbanMembershipBoardName,
} from "../lib/kanban-title";
import { membershipCardUrl } from "../lib/kanban-topic-pill";

export default class KanbanBoardsMenu extends Component {
  get memberships() {
    return this.args.data.memberships;
  }

  @action
  goToBoard(membership) {
    this.args.close();
    DiscourseURL.routeTo(membershipCardUrl(membership));
  }

  <template>
    <DropdownMenu as |dropdown|>
      {{#each this.memberships as |membership|}}
        <dropdown.item>
          <DButton
            @action={{fn this.goToBoard membership}}
            class="btn-transparent kanban-boards-menu__item --with-description"
          >
            <div class="kanban-boards-menu__item-texts">
              <span
                class="kanban-boards-menu__item-label"
              >{{kanbanMembershipBoardName membership}}</span>
              {{#each membership.cards as |card|}}
                <span
                  class="kanban-boards-menu__column"
                  style={{columnColorVariable card.column_color}}
                >
                  {{#if card.column_icon}}
                    {{icon card.column_icon}}
                  {{/if}}
                  {{kanbanColumnTitle card}}
                </span>
              {{/each}}
            </div>
          </DButton>
        </dropdown.item>
      {{/each}}
    </DropdownMenu>
  </template>
}
