import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import KanbanEditableTitle from "../kanban-editable-title";

export default class KanbanCardDetail extends Component {
  @service siteSettings;
  @service currentUser;

  get canWrite() {
    return this.args.model.canWrite;
  }

  get formData() {
    const card = this.args.model.card;
    const assignedTo = card.assigned_to;
    return {
      title: card.title || "",
      notes: card.notes || "",
      tags: [...(card.tags || [])],
      assigned_to: assignedTo ? [assignedTo.username || assignedTo.name] : [],
    };
  }

  get isNew() {
    return !!this.args.model.isNew;
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
      title: data.title.trim(),
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

  @action
  viewCard() {
    if (!this.currentUser) {
      return;
    }

    if (this.isNew) {
      return;
    }

    ajax(
      `/kanban/boards/${this.args.model.card.board_id}/cards/${this.args.model.card.id}/view`,
      { method: "POST" }
    ).catch(() => {
      // No error message should be shown if this fails,
      // it's purely for history logging.
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @submitOnEnter={{false}}
      @hideHeader={{true}}
      class="discourse-kanban-card-detail-modal"
      {{didInsert this.viewCard}}
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form data|>
          <KanbanEditableTitle
            @form={{form}}
            @name="title"
            @title={{i18n "discourse_kanban.board.title"}}
            @placeholder={{i18n "discourse_kanban.board.title_placeholder"}}
            @disabled={{not this.canWrite}}
            @showClose={{false}}
          />
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
              @disabled={{not this.canWrite}}
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
                @disabled={{not this.canWrite}}
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
          class="btn-flat discourse-kanban-card-detail-modal__close"
        />
      </:body>
    </DModal>
  </template>
}
