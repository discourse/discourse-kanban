import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import {
  ASSIGNED_OPTIONS,
  assignedMode,
  assignedUserValue,
  STATUS_OPTIONS,
  tagToArray,
} from "../../lib/kanban-column-helpers";

export default class KanbanColumnSettings extends Component {
  @service dialog;

  @tracked editTitle;
  @tracked editIcon;
  @tracked editMode;
  @tracked editFilterQuery;
  @tracked editMoveToTag;
  @tracked editMoveToCategoryId;
  @tracked editMoveToAssigned;
  @tracked editMoveToStatus;
  @tracked startedInAdvanced = false;
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
      this.editMode = this.#persistedColumnUsesAdvancedMode(column)
        ? "advanced"
        : "simple";
      this.startedInAdvanced = this.editMode === "advanced";
    } else {
      this.editTitle = "";
      this.editIcon = null;
      this.editMode = "simple";
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

  get hasBoardBaseFilterQuery() {
    return Boolean(this.args.model.board?.base_filter_query?.trim());
  }

  get isSimpleMode() {
    return this.editMode === "simple";
  }

  get isAdvancedMode() {
    return this.editMode === "advanced";
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

  get hasAdvancedOnlyValues() {
    if (this.editMoveToCategoryId) {
      return true;
    }

    if (this.editMoveToAssigned) {
      return true;
    }

    if (this.editMoveToStatus) {
      return true;
    }

    return (
      this.#normalizedFilterQuery(this.editFilterQuery) !==
      this.#simpleFilterQueryForTag(this.editMoveToTag)
    );
  }

  #normalizedTag(tag) {
    return typeof tag === "string" ? tag.trim() : "";
  }

  #normalizedFilterQuery(query) {
    return typeof query === "string" ? query.trim() : "";
  }

  #simpleFilterQueryForTag(tag) {
    const normalizedTag = this.#normalizedTag(tag);
    if (!this.hasBoardBaseFilterQuery || !normalizedTag) {
      return "";
    }

    return `tags:${normalizedTag}`;
  }

  #persistedColumnUsesAdvancedMode(column) {
    if (
      column.move_to_category_id ||
      column.move_to_assigned ||
      column.move_to_status
    ) {
      return true;
    }

    const persistedFilter = this.#normalizedFilterQuery(column.filter_query);
    if (!persistedFilter) {
      return false;
    }

    return (
      persistedFilter !== this.#simpleFilterQueryForTag(column.move_to_tag)
    );
  }

  #applySimpleModeDefaults() {
    this.editMoveToTag = this.#normalizedTag(this.editMoveToTag);
    this.editFilterQuery = this.#simpleFilterQueryForTag(this.editMoveToTag);
    this.editMoveToCategoryId = null;
    this.editMoveToAssigned = "";
    this.editMoveToStatus = "";
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
    this.editMoveToTag = this.#normalizedTag(
      typeof tag === "object" ? tag.name : tag || ""
    );

    if (this.isSimpleMode) {
      this.editFilterQuery = this.#simpleFilterQueryForTag(this.editMoveToTag);
    }
  }

  @action
  onCategoryChange(value) {
    this.editMoveToCategoryId = value;
  }

  @action
  toggleAdvanced() {
    if (this.isAdvancedMode && this.hasAdvancedOnlyValues) {
      this.dialog.confirm({
        message: i18n(
          "discourse_kanban.manage.columns.switch_to_simple_confirm"
        ),
        didConfirm: () => {
          this.#applySimpleModeDefaults();
          this.editMode = "simple";
        },
      });
      return;
    }

    if (this.isAdvancedMode) {
      this.#applySimpleModeDefaults();
      this.editMode = "simple";
      return;
    }

    this.editMode = "advanced";
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

    if (this.isSimpleMode) {
      this.#applySimpleModeDefaults();
    }

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

        {{#if (and this.isAdvancedMode this.startedInAdvanced)}}
          <div class="kanban-column-settings__field">
            <p class="kanban-column-settings__help">
              {{i18n "discourse_kanban.manage.columns.mode_advanced_notice"}}
            </p>
          </div>
        {{/if}}

        {{#if this.isSimpleMode}}
          <div class="kanban-column-settings__field">
            <label>{{i18n
                "discourse_kanban.manage.columns.simple_tag_lane"
              }}</label>
            <MiniTagChooser
              @value={{this.currentTagArray}}
              @onChange={{this.onTagChange}}
              @options={{hash maximum=1 allowCreate=false}}
            />
            <p class="kanban-column-settings__help">
              {{#if this.hasBoardBaseFilterQuery}}
                {{i18n "discourse_kanban.manage.columns.simple_tag_help_auto"}}
              {{else}}
                {{i18n
                  "discourse_kanban.manage.columns.simple_tag_help_no_base"
                }}
              {{/if}}
            </p>
          </div>
        {{else}}
          {{#unless this.hasBoardBaseFilterQuery}}
            <div class="kanban-column-settings__field">
              <p
                class="kanban-column-settings__help kanban-column-settings__help--warning"
              >
                {{i18n
                  "discourse_kanban.manage.columns.advanced_filter_no_base_warning"
                }}
              </p>
            </div>
          {{/unless}}

          <div class="kanban-column-settings__field">
            <label>{{i18n
                "discourse_kanban.manage.columns.filter_query"
              }}</label>
            <input
              data-identifier="kanban-column-filter-query"
              type="text"
              value={{this.editFilterQuery}}
              {{on "input" this.onFilterQueryInput}}
            />
          </div>

          <div class="kanban-column-settings__field">
            <label>{{i18n
                "discourse_kanban.manage.columns.move_to_tag"
              }}</label>
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

        {{/if}}

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
        <DButton
          @action={{this.toggleAdvanced}}
          @icon="gear"
          @label={{if
            this.isAdvancedMode
            "discourse_kanban.manage.columns.hide_advanced"
            "discourse_kanban.manage.columns.show_advanced"
          }}
          @title={{if
            this.isAdvancedMode
            "discourse_kanban.manage.columns.hide_advanced"
            "discourse_kanban.manage.columns.show_advanced"
          }}
          class="btn-default show-advanced"
        />
      </:footer>
    </DModal>
  </template>
}
