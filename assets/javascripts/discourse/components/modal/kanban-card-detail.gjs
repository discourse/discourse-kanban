import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import icon from "discourse/helpers/d-icon";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import KanbanEditableTitle from "../kanban-editable-title";

export default class KanbanCardDetail extends Component {
  @tracked editTitle;
  @tracked newLabelText = "";

  constructor() {
    super(...arguments);
    this.editTitle = this.args.model.card.title || "";
  }

  get canWrite() {
    return this.args.model.canWrite;
  }

  @cached
  get formData() {
    const card = this.args.model.card;
    const assignedTo = card.assigned_to;
    return {
      notes: card.notes || "",
      labels: [...(card.labels || [])],
      assigned_to: assignedTo ? [assignedTo.username || assignedTo.name] : [],
    };
  }

  get canAddLabel() {
    const labelsFromInput = this.parseLabelsInput(this.newLabelText);
    if (!labelsFromInput.length) {
      return false;
    }

    const currentLabels = this.formApi?.get("labels") || [];
    const existingLabels = new Set(
      currentLabels.map((label) => label.toLowerCase())
    );
    return labelsFromInput.some(
      (label) => !existingLabels.has(label.toLowerCase())
    );
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
  onLabelInput(event) {
    this.newLabelText = event.target.value;
  }

  @action
  onLabelKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      this.addLabel();
    }
  }

  @action
  addLabel() {
    const labelsFromInput = this.parseLabelsInput(this.newLabelText);
    if (!labelsFromInput.length) {
      return;
    }

    const currentLabels = this.formApi?.get("labels") || [];
    const existingLabels = new Set(
      currentLabels.map((label) => label.toLowerCase())
    );
    const nextLabels = [...currentLabels];

    for (const label of labelsFromInput) {
      const normalizedLabel = label.toLowerCase();
      if (existingLabels.has(normalizedLabel)) {
        continue;
      }

      existingLabels.add(normalizedLabel);
      nextLabels.push(label);
    }

    if (nextLabels.length !== currentLabels.length) {
      this.formApi?.set("labels", nextLabels);
      this.newLabelText = "";
    }
  }

  @action
  removeLabel(labelsField, label) {
    const currentLabels = this.formApi?.get("labels") || [];
    labelsField.set(currentLabels.filter((l) => l !== label));
  }

  @action
  onAssignedChanged(field, value) {
    field.set(value || []);
  }

  get isNew() {
    return !!this.args.model.isNew;
  }

  @action
  async save(data) {
    this.addLabel();

    const labels = this.formApi?.get("labels") || data.labels;
    const updates = {
      title: this.editTitle.trim(),
      notes: data.notes,
      labels,
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

  parseLabelsInput(value) {
    return value
      .split(",")
      .map((label) => label.trim())
      .filter(Boolean);
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
          @onClose={{@closeModal}}
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
              @type="textarea"
              @disabled={{not this.canWrite}}
              as |field|
            >
              <field.Control
                @placeholder={{i18n "discourse_kanban.board.notes_placeholder"}}
              />
            </form.Field>
            <form.Field
              @name="labels"
              @title={{i18n "discourse_kanban.board.labels"}}
              @format="max"
              @type="custom"
              as |field|
            >
              <field.Control>
                {{#if data.labels.length}}
                  <div class="kanban-card-detail__labels">
                    {{#each data.labels key="@identity" as |label|}}
                      <span class="kanban-card-detail__label-chip">
                        {{label}}
                        {{#if this.canWrite}}
                          <button
                            type="button"
                            class="btn-remove-label"
                            title={{i18n "discourse_kanban.board.remove_label"}}
                            {{on "click" (fn this.removeLabel field label)}}
                          >{{icon "xmark"}}</button>
                        {{/if}}
                      </span>
                    {{/each}}
                  </div>
                {{/if}}
                {{#if this.canWrite}}
                  <div class="kanban-card-detail__label-composer">
                    <input
                      type="text"
                      class="kanban-card-detail__label-input"
                      value={{this.newLabelText}}
                      placeholder={{i18n
                        "discourse_kanban.board.labels_placeholder"
                      }}
                      {{on "input" this.onLabelInput}}
                      {{on "keydown" this.onLabelKeydown}}
                    />
                    <DButton
                      @action={{this.addLabel}}
                      @label="discourse_kanban.board.add_label"
                      @icon="plus"
                      @disabled={{not this.canAddLabel}}
                      class="btn-default kanban-card-detail__add-label"
                    />
                  </div>
                  <div class="kanban-card-detail__label-help">
                    {{i18n "discourse_kanban.board.labels_help"}}
                  </div>
                {{/if}}
              </field.Control>
            </form.Field>

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
      </:body>
    </DModal>
  </template>
}
