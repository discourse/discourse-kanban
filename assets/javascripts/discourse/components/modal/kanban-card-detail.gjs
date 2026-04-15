import Component from "@glimmer/component";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import KanbanEditableTitle from "../kanban-editable-title";

export default class KanbanCardDetail extends Component {
  @service siteSettings;

  @tracked editTitle;

  constructor() {
    super(...arguments);
    this.editTitle = this.args.model.card.title || "";
  }

  get canWrite() {
    return this.args.model.canWrite;
  }

  get formData() {
    const card = this.args.model.card;
    const assignedTo = card.assigned_to;
    return {
      notes: card.notes || "",
      tags: [...(card.tags || [])],
      assigned_to: assignedTo ? [assignedTo.username || assignedTo.name] : [],
    };
  }

  get isNew() {
    return !!this.args.model.isNew;
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
  onAssignedChanged(field, value) {
    field.set(value || []);
  }

  @action
  async save(data) {
    const tagIds = [];
    const tagNames = [];
    for (const tag of data.tags || []) {
      if (Number.isInteger(tag.id) && tag.id > 0) {
        tagIds.push(tag.id);
      } else if (typeof tag.id === "string" && tag.id.length > 0) {
        tagNames.push(tag.id);
      }
    }

    const updates = {
      title: this.editTitle.trim(),
      notes: data.notes,
      tag_ids:
        !this.isNew && !tagIds.length && !tagNames.length ? [""] : tagIds,
      tag_names: tagNames,
      assigned_to_name: data.assigned_to[0] || null,
    };
    try {
      if (this.isNew) {
        await this.args.model.onCreateCard(updates);
      } else {
        await this.args.model.onUpdateCard(this.args.model.card.id, updates);
      }
      this.args.closeModal();
    } catch {
      // modal stays open — popupAjaxError already handles the error
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @submitOnEnter={{false}}
      @hideHeader={{true}}
      class="kanban-card-detail-modal"
    >
      <:body>
        <KanbanEditableTitle
          @value={{this.editTitle}}
          @placeholder={{i18n "discourse_kanban.board.title_placeholder"}}
          @onInput={{this.onTitleInput}}
          @showClose={{false}}
          @disabled={{not this.canWrite}}
        />

        <Form
          @data={{this.formData}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.onRegisterApi}}
          as |form data|
        >
          <form.Section>
            <form.Field
              @name="notes"
              @title={{i18n "discourse_kanban.board.notes"}}
              @format="max"
              @type="composer"
              @disabled={{not this.canWrite}}
              as |field|
            >
              <field.Control
                @height={{300}}
                @forceEditorMode={{USER_OPTION_COMPOSITION_MODES.rich}}
              />
            </form.Field>
            <form.Field
              @name="tags"
              @title={{i18n "discourse_kanban.board.tags"}}
              @format="max"
              @type="tag-chooser"
              as |field|
            >
              <field.Control @allowCreate={{true}} />
            </form.Field>

            {{#if this.siteSettings.assign_enabled}}
              <form.Field
                @name="assigned_to"
                @title={{i18n "discourse_kanban.board.assigned_to"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <EmailGroupUserChooser
                    @value={{data.assigned_to}}
                    @onChange={{fn this.onAssignedChanged field}}
                    @options={{hash maximum=1 excludeCurrentUser=false}}
                    @disabled={{not this.canWrite}}
                  />
                </field.Control>
              </form.Field>
            {{/if}}
          </form.Section>

          <form.Actions>
            {{#if this.canWrite}}
              <form.Submit />
            {{/if}}
            <form.Button
              class="btn-flat d-modal-cancel"
              @action={{@closeModal}}
              @label="cancel"
            />
          </form.Actions>
        </Form>

        <DButton
          @action={{@closeModal}}
          @icon="xmark"
          @ariaLabel="modal.close"
          @title="modal.close"
          class="btn-flat kanban-card-detail-modal__close"
        />
      </:body>
    </DModal>
  </template>
}
