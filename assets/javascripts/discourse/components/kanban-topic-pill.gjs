import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import DiscourseURL from "discourse/lib/url";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";
import { columnColorVariable } from "../lib/kanban-column-helpers";
import { kanbanBoardUrl } from "../lib/kanban-urls";

export default class KanbanTopicPill extends Component {
  get memberships() {
    return this.args.topic?.kanban_memberships || [];
  }

  get single() {
    return this.memberships.length === 1 ? this.memberships[0] : null;
  }

  get multiple() {
    return this.memberships.length > 1;
  }

  get singleUrl() {
    return this.#cardUrl(this.single);
  }

  @action
  goToBoard(membership, closeMenu) {
    closeMenu();
    DiscourseURL.routeTo(this.#cardUrl(membership));
  }

  #cardUrl(membership) {
    const boardUrl = kanbanBoardUrl({
      slug: membership.board_slug,
      id: membership.board_id,
    });
    return `${boardUrl}?card=${membership.card_id}`;
  }

  <template>
    {{#if this.single}}
      <a
        class="kanban-topic-pill"
        href={{this.singleUrl}}
        title={{i18n
          "discourse_kanban.topic_pill.title"
          board=this.single.board_name
          column=this.single.column_title
        }}
      >
        {{icon "table-columns"}}
        <span class="kanban-topic-pill__label">{{this.single.board_name}}</span>
      </a>
    {{else if this.multiple}}
      <DMenu
        @identifier="kanban-topic-pill"
        @icon="table-columns"
        @label={{i18n
          "discourse_kanban.topic_pill.multiple"
          count=this.memberships.length
        }}
        @title={{i18n "discourse_kanban.topic_pill.multiple_title"}}
        @triggerClass="btn-flat kanban-topic-pill kanban-topic-pill--multiple"
      >
        <:content as |args|>
          <DropdownMenu as |dropdown|>
            {{#each this.memberships as |membership|}}
              <dropdown.item>
                <DButton
                  @action={{fn this.goToBoard membership args.close}}
                  class="btn-transparent kanban-topic-pill__menu-item --with-description"
                >
                  <div class="kanban-topic-pill__menu-item-texts">
                    <span
                      class="kanban-topic-pill__menu-item-label"
                    >{{membership.board_name}}</span>
                    <span class="kanban-topic-pill__menu-item-description">
                      {{#if membership.board_created_by}}
                        <span class="kanban-topic-pill__fact">
                          {{i18n "discourse_kanban.topic_pill.created_by"}}
                          {{dBoundAvatarTemplate
                            membership.board_created_by.avatar_template
                            "tiny"
                          }}
                        </span>
                      {{/if}}
                      <span class="kanban-topic-pill__fact">
                        {{i18n
                          "discourse_kanban.topic_pill.column_count"
                          count=membership.board_column_count
                        }}
                      </span>
                    </span>
                    <span
                      class="kanban-topic-pill__column"
                      style={{columnColorVariable membership.column_color}}
                    >
                      {{#if membership.column_icon}}
                        {{icon membership.column_icon}}
                      {{/if}}
                      {{membership.column_title}}
                    </span>
                  </div>
                </DButton>
              </dropdown.item>
            {{/each}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
