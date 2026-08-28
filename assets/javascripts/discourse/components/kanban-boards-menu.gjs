import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import DiscourseURL from "discourse/lib/url";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { columnColorVariable } from "../lib/kanban-column-helpers";
import { membershipCardUrl } from "../lib/kanban-topic-pill";

export default class KanbanBoardsMenu extends Component {
  get memberships() {
    return this.args.data.memberships.map((membership) => ({
      ...membership,
      fancyTitle: membership.unicode_board_name || membership.board_name,
      cards: membership.cards.map((card) => ({
        ...card,
        fancyTitle: card.unicode_column_title || card.column_title,
      })),
    }));
  }

  @action
  goToBoard(membership) {
    this.args.close();
    DiscourseURL.routeTo(membershipCardUrl(membership));
  }

  <template>
    <DDropdownMenu as |dropdown|>
      {{#each this.memberships as |membership|}}
        <dropdown.item>
          <DButton
            @action={{fn this.goToBoard membership}}
            class="btn-transparent kanban-boards-menu__item --with-description"
          >
            <div class="kanban-boards-menu__item-texts">
              <span
                class="kanban-boards-menu__item-label"
              >{{membership.fancyTitle}}</span>
              {{#each membership.cards as |card|}}
                <span
                  class="kanban-boards-menu__column"
                  style={{columnColorVariable card.column_color}}
                >
                  {{#if card.column_icon}}
                    {{icon card.column_icon}}
                  {{/if}}
                  {{card.fancyTitle}}
                </span>
              {{/each}}
            </div>
          </DButton>
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
