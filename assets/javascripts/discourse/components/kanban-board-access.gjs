import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The anonymous (4) and trust_level_0 (10) auto-groups let a board be made
// public or member-visible. anonymous is not present in site.groups nor in the
// JS AUTO_GROUPS constant, so it is defined explicitly here.
const ANONYMOUS_GROUP_ID = 4;
const TRUST_LEVEL_0_GROUP_ID = 10;
const SPECIAL_GROUP_IDS = new Set([ANONYMOUS_GROUP_ID, TRUST_LEVEL_0_GROUP_ID]);

const DEFAULT_LEVEL = "editor";
const LEVELS = ["editor", "viewer"];

export default class KanbanBoardAccess extends Component {
  @service site;

  get value() {
    return this.args.value || [];
  }

  get levelOptions() {
    return LEVELS.map((level) => ({
      id: level,
      name: this.#levelLabel(level),
    }));
  }

  get chooserContent() {
    const special = [
      {
        id: ANONYMOUS_GROUP_ID,
        name: i18n("discourse_kanban.manage.access_anonymous"),
      },
      {
        id: TRUST_LEVEL_0_GROUP_ID,
        name: i18n("discourse_kanban.manage.access_members"),
      },
    ];

    return [
      ...special,
      ...(this.args.groups || []).filter((g) => !SPECIAL_GROUP_IDS.has(g.id)),
    ];
  }

  get selectedGroupIds() {
    return this.value.map((entry) => entry.group_id);
  }

  get rows() {
    return this.value.map((entry) => ({
      groupId: entry.group_id,
      level: entry.level,
      levelLabel: this.#levelLabel(entry.level),
      name: this.#nameFor(entry.group_id),
    }));
  }

  #levelLabel(level) {
    return i18n(`discourse_kanban.manage.access_level_${level}`);
  }

  #nameFor(groupId) {
    if (groupId === ANONYMOUS_GROUP_ID) {
      return i18n("discourse_kanban.manage.access_anonymous");
    }
    if (groupId === TRUST_LEVEL_0_GROUP_ID) {
      return i18n("discourse_kanban.manage.access_members");
    }
    return this.site.groupsById[groupId]?.name ?? `#${groupId}`;
  }

  // GroupChooser emits a fresh array of integer ids. Preserve the level of
  // groups that are still selected; new groups default to editor (anonymous to
  // viewer, since anonymous users can never be editors). Always hand a brand
  // new array of objects to onChange — FormKit freezes the draft state.
  @action
  onGroupsChange(groupIds) {
    const byId = new Map(this.value.map((entry) => [entry.group_id, entry]));

    const next = (groupIds || []).map(
      (id) =>
        byId.get(id) ?? {
          group_id: id,
          level: id === ANONYMOUS_GROUP_ID ? "viewer" : DEFAULT_LEVEL,
        }
    );

    this.args.onChange(next);
  }

  @action
  onLevelChange(groupId, level, menu) {
    const next = this.value.map((entry) =>
      entry.group_id === groupId ? { group_id: entry.group_id, level } : entry
    );

    this.args.onChange(next);
    menu?.close();
  }

  <template>
    <div class="kanban-board-access">
      <GroupChooser
        class="kanban-board-access__chooser"
        @content={{this.chooserContent}}
        @value={{this.selectedGroupIds}}
        @onChange={{this.onGroupsChange}}
      />

      {{#if this.rows.length}}
        <div class="kanban-board-access__rows">
          {{#each this.rows key="groupId" as |row|}}
            <div class="kanban-board-access__row" data-group-id={{row.groupId}}>
              <span class="kanban-board-access__group-name">{{row.name}}</span>
              <DMenu
                @identifier="kanban-board-access-level"
                @triggerClass="kanban-board-access__level btn-transparent"
                @label={{row.levelLabel}}
                @icon="angle-down"
              >
                <:content as |menu|>
                  <DDropdownMenu as |dropdown|>
                    {{#each this.levelOptions as |option|}}
                      <dropdown.item
                        class={{if (eq option.id row.level) "--selected"}}
                      >
                        <DButton
                          class="kanban-board-access__level-{{option.id}}"
                          @translatedLabel={{option.name}}
                          @action={{fn
                            this.onLevelChange
                            row.groupId
                            option.id
                            menu
                          }}
                        />
                      </dropdown.item>
                    {{/each}}
                  </DDropdownMenu>
                </:content>
              </DMenu>
            </div>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
