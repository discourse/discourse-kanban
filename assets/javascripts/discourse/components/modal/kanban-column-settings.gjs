import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import {
  ASSIGNED_OPTIONS,
  assignedMode,
  assignedUserValue,
  STATUS_OPTIONS,
  tagToArray,
} from "../../lib/kanban-column-helpers";
import KanbanEditableTitle from "../kanban-editable-title";

export default class KanbanColumnSettings extends Component {
  @tracked editTitle;
  @tracked showAdvanced = false;

  constructor() {
    super(...arguments);
    this.editTitle = this.args.model.column?.title || "";
  }

  get isNew() {
    return !this.args.model.column;
  }

  @cached
  get formData() {
    const column = this.args.model.column;
    if (column) {
      return {
        icon: column.icon || null,
        tag_name: column.tag_name || "",
        move_to_category_id: column.move_to_category_id || null,
        move_to_assigned: column.move_to_assigned || "",
        move_to_status: column.move_to_status || "",
      };
    }
    return {
      icon: null,
      tag_name: "",
      move_to_category_id: null,
      move_to_assigned: "",
      move_to_status: "",
    };
  }

  get statusOptions() {
    return STATUS_OPTIONS;
  }

  get assignedOptions() {
    return ASSIGNED_OPTIONS;
  }

  @action
  onTitleInput(value) {
    this.editTitle = value;
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  @action
  onTagChange(field, tags) {
    const tag = tags?.[0];
    field.set(typeof tag === "object" ? tag.name : tag || "");
  }

  @action
  onCategoryChange(field, value) {
    field.set(value);
  }

  @action
  onAssignedModeChange(field, value) {
    field.set(value || "");
  }

  @action
  onAssignedUserChange(field, users) {
    field.set(users?.[0] || "_user");
  }

  @action
  onStatusChange(field, value) {
    field.set(value);
  }

  @action
  toggleAdvanced() {
    this.showAdvanced = !this.showAdvanced;
  }

  @action
  async save(data) {
    const columnData = {
      title: this.editTitle.trim(),
      icon: data.icon,
      tag_name: data.tag_name || null,
      move_to_category_id: data.move_to_category_id,
      move_to_assigned: data.move_to_assigned,
      move_to_status: data.move_to_status,
    };
    try {
      await this.args.model.onSave(columnData);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @hideHeader={{true}}
      class="kanban-column-settings-modal"
    >
      <:body>
        <KanbanEditableTitle
          @value={{this.editTitle}}
          @placeholder={{i18n
            "discourse_kanban.manage.columns.column_title_placeholder"
          }}
          @onInput={{this.onTitleInput}}
          @onClose={{@closeModal}}
        />

        <Form
          @data={{this.formData}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.onRegisterApi}}
          as |form data|
        >
          <div class="kanban-column-settings-modal__wrapper">
            <form.Section>
              <form.Field
                @name="icon"
                @title={{i18n "discourse_kanban.manage.columns.icon"}}
                @format="max"
                @type="icon"
                as |field|
              >
                <field.Control/>
              </form.Field>

              <form.Field
                @name="tag_name"
                @title={{i18n "discourse_kanban.manage.columns.tag"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <MiniTagChooser
                    @value={{tagToArray data.tag_name}}
                    @onChange={{fn this.onTagChange field}}
                    @options={{hash maximum=1 allowCreate=false}}
                  />
                  <p class="kanban-column-settings__help">
                    {{i18n "discourse_kanban.manage.columns.tag_help"}}
                  </p>
                </field.Control>
              </form.Field>

              {{#if this.showAdvanced}}
                <form.Field
                  @name="move_to_category_id"
                  @title={{i18n
                    "discourse_kanban.manage.columns.move_to_category"
                  }}
                  @format="max"
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <CategoryChooser
                      @value={{data.move_to_category_id}}
                      @onChange={{fn this.onCategoryChange field}}
                      @options={{hash clearable=true}}
                    />
                  </field.Control>
                </form.Field>

                <form.Field
                  @name="move_to_assigned"
                  @title={{i18n
                    "discourse_kanban.manage.columns.move_to_assigned"
                  }}
                  @format="max"
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <ComboBox
                      @value={{assignedMode data.move_to_assigned}}
                      @content={{this.assignedOptions}}
                      @onChange={{fn this.onAssignedModeChange field}}
                      @options={{hash
                        clearable=true
                        none="discourse_kanban.manage.columns.move_to_assigned_none"
                      }}
                    />
                    {{#if (eq (assignedMode data.move_to_assigned) "_user")}}
                      <EmailGroupUserChooser
                        @value={{assignedUserValue data.move_to_assigned}}
                        @onChange={{fn this.onAssignedUserChange field}}
                        @options={{hash maximum=1}}
                      />
                    {{/if}}
                  </field.Control>
                </form.Field>

                <form.Field
                  @name="move_to_status"
                  @title={{i18n
                    "discourse_kanban.manage.columns.move_to_status"
                  }}
                  @format="max"
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <ComboBox
                      @value={{data.move_to_status}}
                      @content={{this.statusOptions}}
                      @onChange={{fn this.onStatusChange field}}
                      @options={{hash
                        clearable=true
                        none="discourse_kanban.manage.columns.move_to_status_none"
                      }}
                    />
                  </field.Control>
                </form.Field>
              {{/if}}
            </form.Section>
          </div>

          <form.Actions>
            <form.Submit />
            <form.Button
              class="btn-flat d-modal-cancel"
              @action={{@closeModal}}
              @label="cancel"
            />
            <DButton
              @action={{this.toggleAdvanced}}
              @icon="gear"
              @title={{if
                this.showAdvanced
                "discourse_kanban.manage.columns.hide_advanced"
                "discourse_kanban.manage.columns.show_advanced"
              }}
              class="btn-default show-advanced"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
