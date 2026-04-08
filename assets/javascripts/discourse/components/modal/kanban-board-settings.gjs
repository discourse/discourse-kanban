import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import CategorySelector from "discourse/select-kit/components/category-selector";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

const CARD_STYLE_OPTIONS = [
  {
    id: "detailed",
    name: i18n("discourse_kanban.manage.card_style_detailed"),
  },
  { id: "simple", name: i18n("discourse_kanban.manage.card_style_simple") },
];

export default class KanbanBoardSettings extends Component {
  @service dialog;
  @service site;

  @tracked isEditingName = !this.args.model.board?.name;
  @tracked editingName = this.args.model.board?.name || "";
  constraintWarning = null;

  focusNameInput = modifier((element) => {
    element.focus();
    element.select();
  });

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._constraintCheckTimer);
  }

  @cached
  get formData() {
    const board = this.args.model.board;
    if (board) {
      return {
        name: board.name || "",
        slug: board.slug || "",
        category_ids: board.category_ids || [],
        tag_names: board.tag_names || [],
        card_style: board.card_style || "detailed",
        show_tags: board.show_tags ?? false,
        show_topic_thumbnail: board.show_topic_thumbnail ?? false,
        show_activity_indicators: board.show_activity_indicators ?? false,
        require_confirmation: board.require_confirmation ?? true,
        allow_read_group_ids: board.allow_read_group_ids || [],
        allow_write_group_ids: board.allow_write_group_ids || [],
      };
    }
    return {
      name: "",
      slug: "",
      category_ids: [],
      tag_names: [],
      card_style: "detailed",
      show_tags: false,
      show_topic_thumbnail: false,
      show_activity_indicators: false,
      require_confirmation: true,
      allow_read_group_ids: [],
      allow_write_group_ids: [],
    };
  }

  get isNew() {
    return this.args.model.isNew;
  }

  get hasName() {
    return !!(this.editingName || this.args.model.board?.name);
  }

  get displayName() {
    return (
      this.editingName ||
      this.args.model.board?.name ||
      i18n("discourse_kanban.manage.name_placeholder")
    );
  }

  @action
  startEditingName() {
    this.editingName =
      this.formApi?.get("name") || this.args.model.board?.name || "";
    this.isEditingName = true;
  }

  @action
  updateName(event) {
    this.editingName = event.target.value;
  }

  @action
  finishEditingName() {
    this.isEditingName = false;
    const trimmed = this.editingName.trim();
    this.editingName = trimmed;
    this.formApi?.set("name", trimmed);
  }

  @action
  handleNameKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    } else if (event.key === "Escape") {
      this.editingName =
        this.formApi?.get("name") || this.args.model.board?.name || "";
      this.isEditingName = false;
    }
  }

  @action
  selectedCategories(categoryIds) {
    return (categoryIds || [])
      .map((id) => this.site.categories?.find((c) => c.id === id))
      .filter(Boolean);
  }

  @action
  onCategoriesChange(field, categories) {
    const ids = categories?.map((c) => c.id) || [];
    field.set(ids);
    this._checkConstraints(ids, null);
  }

  @action
  onTagsChange(tags, { set }) {
    const names = tags.map((t) => (typeof t === "string" ? t : t.name));
    set("tag_names", names);
    this._checkConstraints(null, names);
  }

  @action
  setGroupIds(field, groupIds) {
    field.set(groupIds || []);
  }

  _checkConstraints(categoryIds, tagNames) {
    if (this.isNew) {
      return;
    }
    cancel(this._constraintCheckTimer);
    this._constraintCheckTimer = discourseDebounce(
      this,
      this._fetchConstraintPreview,
      categoryIds,
      tagNames,
      500
    );
  }

  async _fetchConstraintPreview(categoryIds, tagNames) {
    const boardId = this.args.model.board?.id;
    if (!boardId) {
      return;
    }

    try {
      const result = await ajax(
        `/kanban/boards/${boardId}/constraint-preview`,
        {
          type: "POST",
          data: {
            category_ids: categoryIds ?? this.formApi?.get("category_ids"),
            tag_names: tagNames ?? this.formApi?.get("tag_names"),
          },
        }
      );
      this.constraintWarning =
        result.cards_to_remove > 0
          ? i18n("discourse_kanban.manage.constraint_warning", {
              count: result.cards_to_remove,
            })
          : null;
    } catch {
      this.constraintWarning = null;
    }
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  @action
  async save(data) {
    if (this.constraintWarning) {
      this.dialog.confirm({
        message: this.constraintWarning,
        didConfirm: () => this._performSave(data),
      });
      return;
    }

    await this._performSave(data);
  }

  async _performSave(data) {
    try {
      await this.args.model.onSave(data);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
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
      @hideHeader={{true}}
      class="kanban-board-settings-modal"
    >
      <:body>
        <div class="kanban-board-settings-modal__header">
          {{#if this.isEditingName}}
            <input
              type="text"
              value={{this.editingName}}
              placeholder={{i18n "discourse_kanban.manage.name_placeholder"}}
              class="kanban-board-settings-modal__name-input"
              {{this.focusNameInput}}
              {{on "input" this.updateName}}
              {{on "blur" this.finishEditingName}}
              {{on "keydown" this.handleNameKeydown}}
            />
          {{else}}
            {{! template-lint-disable no-invalid-interactive }}
            <div
              class={{concatClass
                "kanban-board-settings-modal__name"
                (unless this.hasName "--empty")
              }}
              {{on "click" this.startEditingName}}
            >{{this.displayName}}</div>
          {{/if}}
          <DButton
            @action={{@closeModal}}
            @icon="xmark"
            class="btn-flat kanban-board-settings-modal__close"
          />
        </div>
        <div class="kanban-board-settings-modal__container">
          <Form
            @data={{this.formData}}
            @onSubmit={{this.save}}
            @onRegisterApi={{this.onRegisterApi}}
            as |form data|
          >
            <form.Section>

              <form.Field
                @name="slug"
                @title={{i18n "discourse_kanban.manage.slug"}}
                @format="max"
                @type="input"
                as |field|
              >
                <field.Control />
              </form.Field>

              <form.Field
                @name="category_ids"
                @title={{i18n "discourse_kanban.manage.board_categories"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <CategorySelector
                    @categories={{this.selectedCategories data.category_ids}}
                    @onChange={{fn this.onCategoriesChange field}}
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @name="tag_names"
                @title={{i18n "discourse_kanban.manage.board_tags"}}
                @format="max"
                @type="tag-chooser"
                @onSet={{this.onTagsChange}}
                as |field|
              >
                <field.Control
                  @showAllTags={{true}}
                  @excludeSynonyms={{true}}
                  @allowCreate={{true}}
                />
              </form.Field>

              {{#if this.constraintWarning}}
                <form.Alert @type="warning">
                  {{this.constraintWarning}}
                </form.Alert>
              {{/if}}
            </form.Section>
            <form.Section>
              <form.Field
                @name="card_style"
                @title={{i18n "discourse_kanban.manage.card_style"}}
                @format="max"
                @type="select"
                as |field|
              >
                <field.Control as |select|>
                  {{#each CARD_STYLE_OPTIONS as |option|}}
                    <select.Option
                      @value={{option.id}}
                    >{{option.name}}</select.Option>
                  {{/each}}
                </field.Control>
              </form.Field>
              <form.Field
                @name="show_tags"
                @title={{i18n "discourse_kanban.manage.show_tags"}}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>

              <form.Field
                @name="show_topic_thumbnail"
                @title={{i18n "discourse_kanban.manage.show_topic_thumbnail"}}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>

              <form.Field
                @name="show_activity_indicators"
                @title={{i18n
                  "discourse_kanban.manage.show_activity_indicators"
                }}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>

              <form.Field
                @name="require_confirmation"
                @title={{i18n "discourse_kanban.manage.require_confirmation"}}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>
            </form.Section>
            <form.Section>
              <form.Field
                @name="allow_read_group_ids"
                @title={{i18n "discourse_kanban.manage.allow_read_groups"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <GroupChooser
                    @content={{this.site.groups}}
                    @value={{data.allow_read_group_ids}}
                    @onChange={{fn this.setGroupIds field}}
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @name="allow_write_group_ids"
                @title={{i18n "discourse_kanban.manage.allow_write_groups"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <GroupChooser
                    @content={{this.site.groups}}
                    @value={{data.allow_write_group_ids}}
                    @onChange={{fn this.setGroupIds field}}
                  />
                </field.Control>
              </form.Field>
            </form.Section>

            <form.Actions>
              <form.Submit />
              {{#unless this.isNew}}
                <form.Button
                  class="btn-danger"
                  @action={{this.onDelete}}
                  @label="discourse_kanban.board.delete_board"
                />
              {{/unless}}
            </form.Actions>
          </Form>
        </div>
      </:body>
    </DModal>
  </template>
}
