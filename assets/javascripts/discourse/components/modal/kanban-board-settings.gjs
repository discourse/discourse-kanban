import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const CARD_STYLE_OPTIONS = [
  { id: "detailed", name: "discourse_kanban.manage.card_style_detailed" },
  { id: "simple", name: "discourse_kanban.manage.card_style_simple" },
];

export default class KanbanBoardSettings extends Component {
  @service site;

  @tracked editName;
  @tracked editSlug;
  @tracked editBaseFilterQuery;
  @tracked editCardStyle;
  @tracked editShowTags;
  @tracked editShowTopicThumbnail;
  @tracked editShowActivityIndicators;
  @tracked editRequireConfirmation;
  @tracked editAllowReadGroupIds;
  @tracked editAllowWriteGroupIds;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    const board = this.args.model.board;
    if (board) {
      this.editName = board.name || "";
      this.editSlug = board.slug || "";
      this.editBaseFilterQuery = board.base_filter_query || "";
      this.editCardStyle = board.card_style || "detailed";
      this.editShowTags = board.show_tags ?? false;
      this.editShowTopicThumbnail = board.show_topic_thumbnail ?? false;
      this.editShowActivityIndicators = board.show_activity_indicators ?? false;
      this.editRequireConfirmation = board.require_confirmation ?? true;
      this.editAllowReadGroupIds = board.allow_read_group_ids || [];
      this.editAllowWriteGroupIds = board.allow_write_group_ids || [];
    } else {
      this.editName = "";
      this.editSlug = "";
      this.editBaseFilterQuery = "";
      this.editCardStyle = "detailed";
      this.editShowTags = false;
      this.editShowTopicThumbnail = false;
      this.editShowActivityIndicators = false;
      this.editRequireConfirmation = true;
      this.editAllowReadGroupIds = [];
      this.editAllowWriteGroupIds = [];
    }
  }

  get isNew() {
    return this.args.model.isNew;
  }

  get modalTitle() {
    return this.isNew
      ? i18n("discourse_kanban.board.new_board")
      : i18n("discourse_kanban.board.board_settings");
  }

  get cardStyleOptions() {
    return CARD_STYLE_OPTIONS.map((opt) => ({
      id: opt.id,
      name: i18n(opt.name),
    }));
  }

  @action
  onNameInput(event) {
    this.editName = event.target.value;
  }

  @action
  onSlugInput(event) {
    this.editSlug = event.target.value;
  }

  @action
  onBaseFilterQueryInput(event) {
    this.editBaseFilterQuery = event.target.value;
  }

  @action
  onCardStyleChange(event) {
    this.editCardStyle = event.target.value;
  }

  @action
  onShowTagsChange(event) {
    this.editShowTags = event.target.checked;
  }

  @action
  onShowTopicThumbnailChange(event) {
    this.editShowTopicThumbnail = event.target.checked;
  }

  @action
  onShowActivityIndicatorsChange(event) {
    this.editShowActivityIndicators = event.target.checked;
  }

  @action
  onRequireConfirmationChange(event) {
    this.editRequireConfirmation = event.target.checked;
  }

  @action
  onReadGroupsChange(groupIds) {
    this.editAllowReadGroupIds = groupIds || [];
  }

  @action
  onWriteGroupsChange(groupIds) {
    this.editAllowWriteGroupIds = groupIds || [];
  }

  @action
  async save() {
    if (this.saving) {
      return;
    }
    this.saving = true;
    const boardData = {
      name: this.editName,
      slug: this.editSlug,
      base_filter_query: this.editBaseFilterQuery,
      card_style: this.editCardStyle,
      show_tags: this.editShowTags,
      show_topic_thumbnail: this.editShowTopicThumbnail,
      show_activity_indicators: this.editShowActivityIndicators,
      require_confirmation: this.editRequireConfirmation,
      allow_read_group_ids: this.editAllowReadGroupIds,
      allow_write_group_ids: this.editAllowWriteGroupIds,
    };
    try {
      await this.args.model.onSave(boardData);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  onDelete() {
    this.args.model.onDelete();
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.modalTitle}}
      class="kanban-board-settings-modal"
    >
      <:body>
        <div class="kanban-board-settings__field">
          <label>{{i18n "discourse_kanban.manage.name"}}</label>
          <input
            type="text"
            value={{this.editName}}
            {{on "input" this.onNameInput}}
          />
        </div>

        <div class="kanban-board-settings__field">
          <label>{{i18n "discourse_kanban.manage.slug"}}</label>
          <input
            type="text"
            value={{this.editSlug}}
            {{on "input" this.onSlugInput}}
          />
        </div>

        <div class="kanban-board-settings__field">
          <label>{{i18n "discourse_kanban.manage.base_filter_query"}}</label>
          <input
            type="text"
            value={{this.editBaseFilterQuery}}
            {{on "input" this.onBaseFilterQueryInput}}
          />
        </div>

        <div class="kanban-board-settings__field">
          <label>{{i18n "discourse_kanban.manage.card_style"}}</label>
          <select {{on "change" this.onCardStyleChange}}>
            {{#each this.cardStyleOptions as |styleOption|}}
              <option
                value={{styleOption.id}}
                selected={{if (eq styleOption.id this.editCardStyle) true}}
              >{{styleOption.name}}</option>
            {{/each}}
          </select>
        </div>

        <div
          class="kanban-board-settings__field kanban-board-settings__field--checkbox"
        >
          <label>
            <input
              type="checkbox"
              checked={{this.editShowTags}}
              {{on "change" this.onShowTagsChange}}
            />
            {{i18n "discourse_kanban.manage.show_tags"}}
          </label>
        </div>

        <div
          class="kanban-board-settings__field kanban-board-settings__field--checkbox"
        >
          <label>
            <input
              type="checkbox"
              checked={{this.editShowTopicThumbnail}}
              {{on "change" this.onShowTopicThumbnailChange}}
            />
            {{i18n "discourse_kanban.manage.show_topic_thumbnail"}}
          </label>
        </div>

        <div
          class="kanban-board-settings__field kanban-board-settings__field--checkbox"
        >
          <label>
            <input
              type="checkbox"
              checked={{this.editShowActivityIndicators}}
              {{on "change" this.onShowActivityIndicatorsChange}}
            />
            {{i18n "discourse_kanban.manage.show_activity_indicators"}}
          </label>
        </div>

        <div
          class="kanban-board-settings__field kanban-board-settings__field--checkbox"
        >
          <label>
            <input
              type="checkbox"
              checked={{this.editRequireConfirmation}}
              {{on "change" this.onRequireConfirmationChange}}
            />
            {{i18n "discourse_kanban.manage.require_confirmation"}}
          </label>
        </div>

        <div class="kanban-board-settings__field">
          <label>{{i18n "discourse_kanban.manage.allow_read_groups"}}</label>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{this.editAllowReadGroupIds}}
            @onChange={{this.onReadGroupsChange}}
          />
        </div>

        <div class="kanban-board-settings__field">
          <label>{{i18n "discourse_kanban.manage.allow_write_groups"}}</label>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{this.editAllowWriteGroupIds}}
            @onChange={{this.onWriteGroupsChange}}
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
        {{#unless this.isNew}}
          <DButton
            class="btn-danger"
            @action={{this.onDelete}}
            @label="discourse_kanban.board.delete_board"
          />
        {{/unless}}
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
