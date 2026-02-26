import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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

export default class KanbanColumnSettings extends Component {
  @tracked editTitle;
  @tracked editIcon;
  @tracked editFilterQuery;
  @tracked editMoveToTag;
  @tracked editMoveToCategoryId;
  @tracked editMoveToAssigned;
  @tracked editMoveToStatus;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    const column = this.args.model.column;
    if (column) {
      this.editTitle = column.title || "";
      this.editIcon = column.icon || null;
      this.editFilterQuery = column.filter_query || "";
      this.editMoveToTag = column.move_to_tag || "";
      this.editMoveToCategoryId = column.move_to_category_id || null;
      this.editMoveToAssigned = column.move_to_assigned || "";
      this.editMoveToStatus = column.move_to_status || "";
    } else {
      this.editTitle = "";
      this.editIcon = null;
      this.editFilterQuery = "";
      this.editMoveToTag = "";
      this.editMoveToCategoryId = null;
      this.editMoveToAssigned = "";
      this.editMoveToStatus = "";
    }
  }

  get isNew() {
    return !this.args.model.column;
  }

  get modalTitle() {
    return this.isNew
      ? i18n("discourse_kanban.board.new_column_title")
      : i18n("discourse_kanban.board.column_settings_title");
  }

  get statusOptions() {
    return STATUS_OPTIONS;
  }

  get assignedOptions() {
    return ASSIGNED_OPTIONS;
  }

  get currentAssignedMode() {
    return assignedMode(this.editMoveToAssigned);
  }

  get currentAssignedUserValue() {
    return assignedUserValue(this.editMoveToAssigned);
  }

  get currentTagArray() {
    return tagToArray(this.editMoveToTag);
  }

  @action
  onTitleInput(event) {
    this.editTitle = event.target.value;
  }

  @action
  onFilterQueryInput(event) {
    this.editFilterQuery = event.target.value;
  }

  @action
  onIconChange(value) {
    this.editIcon = value;
  }

  @action
  onTagChange(tags) {
    const tag = tags?.[0];
    this.editMoveToTag = typeof tag === "object" ? tag.name : tag || "";
  }

  @action
  onCategoryChange(value) {
    this.editMoveToCategoryId = value;
  }

  @action
  onAssignedModeChange(value) {
    this.editMoveToAssigned = value || "";
  }

  @action
  onAssignedUserChange(users) {
    this.editMoveToAssigned = users?.[0] || "_user";
  }

  @action
  onStatusChange(value) {
    this.editMoveToStatus = value;
  }

  @action
  async save() {
    if (this.saving) {
      return;
    }
    this.saving = true;
    const columnData = {
      title: this.editTitle,
      icon: this.editIcon,
      filter_query: this.editFilterQuery,
      move_to_tag: this.editMoveToTag,
      move_to_category_id: this.editMoveToCategoryId,
      move_to_assigned: this.editMoveToAssigned,
      move_to_status: this.editMoveToStatus,
    };
    try {
      await this.args.model.onSave(columnData);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.modalTitle}}
      class="kanban-column-settings-modal"
    >
      <:body>
        <div class="kanban-column-settings__field">
          <label>{{i18n "discourse_kanban.manage.columns.column_title"}}</label>
          <input
            type="text"
            value={{this.editTitle}}
            {{on "input" this.onTitleInput}}
          />
        </div>

        <div class="kanban-column-settings__field">
          <label>{{i18n "discourse_kanban.manage.columns.icon"}}</label>
          <IconPicker
            @value={{this.editIcon}}
            @onChange={{this.onIconChange}}
            @options={{hash maximum=1 icons=this.editIcon}}
          />
        </div>

        <div class="kanban-column-settings__field">
          <label>{{i18n "discourse_kanban.manage.columns.filter_query"}}</label>
          <input
            type="text"
            value={{this.editFilterQuery}}
            {{on "input" this.onFilterQueryInput}}
          />
        </div>

        <div class="kanban-column-settings__field">
          <label>{{i18n "discourse_kanban.manage.columns.move_to_tag"}}</label>
          <MiniTagChooser
            @value={{this.currentTagArray}}
            @onChange={{this.onTagChange}}
            @options={{hash maximum=1 allowCreate=false}}
          />
        </div>

        <div class="kanban-column-settings__field">
          <label>{{i18n
              "discourse_kanban.manage.columns.move_to_category"
            }}</label>
          <CategoryChooser
            @value={{this.editMoveToCategoryId}}
            @onChange={{this.onCategoryChange}}
            @options={{hash clearable=true}}
          />
        </div>

        <div class="kanban-column-settings__field">
          <label>{{i18n
              "discourse_kanban.manage.columns.move_to_assigned"
            }}</label>
          <ComboBox
            @value={{this.currentAssignedMode}}
            @content={{this.assignedOptions}}
            @onChange={{this.onAssignedModeChange}}
            @options={{hash
              clearable=true
              none="discourse_kanban.manage.columns.move_to_assigned_none"
            }}
          />
          {{#if (eq this.currentAssignedMode "_user")}}
            <EmailGroupUserChooser
              @value={{this.currentAssignedUserValue}}
              @onChange={{this.onAssignedUserChange}}
              @options={{hash maximum=1}}
            />
          {{/if}}
        </div>

        <div class="kanban-column-settings__field">
          <label>{{i18n
              "discourse_kanban.manage.columns.move_to_status"
            }}</label>
          <ComboBox
            @value={{this.editMoveToStatus}}
            @content={{this.statusOptions}}
            @onChange={{this.onStatusChange}}
            @options={{hash
              clearable=true
              none="discourse_kanban.manage.columns.move_to_status_none"
            }}
          />
        </div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.save}}
          @label="save"
          @isLoading={{this.saving}}
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
