import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const STATUS_OPTIONS = [
  {
    id: "open",
    name: i18n("discourse_kanban.manage.columns.move_to_status_open"),
  },
  {
    id: "closed",
    name: i18n("discourse_kanban.manage.columns.move_to_status_closed"),
  },
];

const ASSIGNED_OPTIONS = [
  {
    id: "nobody",
    name: i18n("discourse_kanban.manage.columns.move_to_assigned_unassign"),
  },
  {
    id: "_user",
    name: i18n("discourse_kanban.manage.columns.move_to_assigned_user"),
  },
];

function tagToArray(tag) {
  return tag ? [tag] : [];
}

function assignedMode(value) {
  if (!value) {
    return "";
  }
  if (value === "nobody") {
    return "nobody";
  }
  return "_user";
}

function assignedUserValue(value) {
  if (!value || value === "nobody" || value === "_user") {
    return [];
  }
  return [value];
}

export default class KanbanColumnsEditor extends Component {
  @action
  addColumn() {
    const columns = [...(this.args.columns || [])];
    columns.push({
      title: "",
      icon: "",
      filter_query: "",
      move_to_tag: "",
      move_to_category_id: null,
      move_to_assigned: "",
      move_to_status: "",
    });
    this.args.onChange(columns);
  }

  @action
  removeColumn(index) {
    const columns = [...this.args.columns];
    columns.splice(index, 1);
    this.args.onChange(columns);
  }

  @action
  moveColumn(index, direction) {
    const columns = [...this.args.columns];
    const newIndex = index + direction;
    if (newIndex < 0 || newIndex >= columns.length) {
      return;
    }
    [columns[index], columns[newIndex]] = [columns[newIndex], columns[index]];
    this.args.onChange(columns);
  }

  get statusOptions() {
    return STATUS_OPTIONS;
  }

  get assignedOptions() {
    return ASSIGNED_OPTIONS;
  }

  get lastIndex() {
    return (this.args.columns?.length || 0) - 1;
  }

  @action
  updateColumnField(index, field, valueOrEvent) {
    const columns = [...this.args.columns];
    const value =
      valueOrEvent?.target !== undefined
        ? valueOrEvent.target.value
        : valueOrEvent;
    columns[index] = { ...columns[index], [field]: value };
    this.args.onChange(columns);
  }

  @action
  updateColumnAssignedMode(index, value) {
    const columns = [...this.args.columns];
    columns[index] = {
      ...columns[index],
      move_to_assigned: value || "",
    };
    this.args.onChange(columns);
  }

  @action
  updateColumnAssignedUser(index, users) {
    const columns = [...this.args.columns];
    columns[index] = {
      ...columns[index],
      move_to_assigned: users?.[0] || "_user",
    };
    this.args.onChange(columns);
  }

  @action
  updateColumnTag(index, tags) {
    const columns = [...this.args.columns];
    const tag = tags?.[0];
    columns[index] = {
      ...columns[index],
      move_to_tag: typeof tag === "object" ? tag.name : tag || "",
    };
    this.args.onChange(columns);
  }

  <template>
    <div class="kanban-columns-editor">
      {{#each @columns key="@index" as |column index|}}
        <div class="kanban-columns-editor__column">
          <div class="kanban-columns-editor__column-header">
            <span class="kanban-columns-editor__column-number">{{i18n
                "discourse_kanban.manage.columns.column_number"
                number=index
              }}</span>
            <div class="kanban-columns-editor__column-actions">
              <DButton
                @action={{fn this.moveColumn index -1}}
                @icon="arrow-up"
                @disabled={{eq index 0}}
                class="btn-small btn-flat"
              />
              <DButton
                @action={{fn this.moveColumn index 1}}
                @icon="arrow-down"
                @disabled={{eq index this.lastIndex}}
                class="btn-small btn-flat"
              />
              <DButton
                @action={{fn this.removeColumn index}}
                @icon="trash-can"
                class="btn-small btn-danger btn-flat"
              />
            </div>
          </div>

          <div class="kanban-columns-editor__column-fields">
            <label>
              {{i18n "discourse_kanban.manage.columns.column_title"}}
              <input
                type="text"
                value={{column.title}}
                {{on "input" (fn this.updateColumnField index "title")}}
              />
            </label>

            <label>
              {{i18n "discourse_kanban.manage.columns.icon"}}
              <IconPicker
                @value={{column.icon}}
                @onChange={{fn this.updateColumnField index "icon"}}
                @options={{hash maximum=1}}
              />
            </label>

            <label>
              {{i18n "discourse_kanban.manage.columns.filter_query"}}
              <input
                type="text"
                value={{column.filter_query}}
                {{on "input" (fn this.updateColumnField index "filter_query")}}
              />
            </label>

            <label>
              {{i18n "discourse_kanban.manage.columns.move_to_tag"}}
              <MiniTagChooser
                @value={{tagToArray column.move_to_tag}}
                @onChange={{fn this.updateColumnTag index}}
                @options={{hash maximum=1 allowCreate=false}}
              />
            </label>

            <label>
              {{i18n "discourse_kanban.manage.columns.move_to_category"}}
              <CategoryChooser
                @value={{column.move_to_category_id}}
                @onChange={{fn
                  this.updateColumnField
                  index
                  "move_to_category_id"
                }}
                @options={{hash clearable=true}}
              />
            </label>

            <label>
              {{i18n "discourse_kanban.manage.columns.move_to_assigned"}}
              <ComboBox
                @value={{assignedMode column.move_to_assigned}}
                @content={{this.assignedOptions}}
                @onChange={{fn this.updateColumnAssignedMode index}}
                @options={{hash
                  clearable=true
                  none="discourse_kanban.manage.columns.move_to_assigned_none"
                }}
              />
              {{#if (eq (assignedMode column.move_to_assigned) "_user")}}
                <EmailGroupUserChooser
                  @value={{assignedUserValue column.move_to_assigned}}
                  @onChange={{fn this.updateColumnAssignedUser index}}
                  @options={{hash maximum=1}}
                />
              {{/if}}
            </label>

            <label>
              {{i18n "discourse_kanban.manage.columns.move_to_status"}}
              <ComboBox
                @value={{column.move_to_status}}
                @content={{this.statusOptions}}
                @onChange={{fn this.updateColumnField index "move_to_status"}}
                @options={{hash
                  clearable=true
                  none="discourse_kanban.manage.columns.move_to_status_none"
                }}
              />
            </label>
          </div>
        </div>
      {{/each}}

      <DButton
        @action={{this.addColumn}}
        @icon="plus"
        @label="discourse_kanban.manage.columns.add"
        class="btn-default kanban-columns-editor__add-btn"
      />
    </div>
  </template>
}
