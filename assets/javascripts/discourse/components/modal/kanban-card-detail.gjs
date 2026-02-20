import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DateInput from "discourse/components/date-input";
import icon from "discourse/helpers/d-icon";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class KanbanCardDetail extends Component {
  @tracked editTitle;
  @tracked editNotes;
  @tracked editLabels;
  @tracked editDueAt;
  @tracked newLabelText = "";

  constructor() {
    super(...arguments);
    const card = this.args.model.card;
    this.editTitle = card.title || "";
    this.editNotes = card.notes || "";
    this.editLabels = [...(card.labels || [])];
    this.editDueAt = card.due_at ? moment(card.due_at) : null;
  }

  get canWrite() {
    return this.args.model.canWrite;
  }

  @action
  onTitleInput(event) {
    this.editTitle = event.target.value;
  }

  @action
  onNotesInput(event) {
    this.editNotes = event.target.value;
  }

  @action
  onLabelInput(event) {
    this.newLabelText = event.target.value;
  }

  @action
  onLabelKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.addLabel();
    }
  }

  @action
  addLabel() {
    const label = this.newLabelText.trim();
    if (label && !this.editLabels.includes(label)) {
      this.editLabels = [...this.editLabels, label];
    }
    this.newLabelText = "";
  }

  @action
  removeLabel(label) {
    this.editLabels = this.editLabels.filter((l) => l !== label);
  }

  @action
  onDueDateChanged(date) {
    this.editDueAt = date || null;
  }

  @action
  async save() {
    const card = this.args.model.card;
    const updates = {
      title: this.editTitle.trim(),
      notes: this.editNotes,
      labels: this.editLabels,
      due_at: this.editDueAt ? this.editDueAt.toISOString() : null,
    };
    try {
      await this.args.model.onUpdateCard(card.id, updates);
      this.args.closeModal();
    } catch {
      // modal stays open — popupAjaxError already handles the error in onUpdateCard
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_kanban.board.card_detail"}}
      class="kanban-card-detail-modal"
    >
      <:body>
        <div class="kanban-card-detail__field">
          <label>{{i18n "discourse_kanban.board.title"}}</label>
          <input
            type="text"
            value={{this.editTitle}}
            disabled={{not this.canWrite}}
            {{on "input" this.onTitleInput}}
          />
        </div>

        <div class="kanban-card-detail__field">
          <label>{{i18n "discourse_kanban.board.notes"}}</label>
          <textarea
            disabled={{not this.canWrite}}
            placeholder={{i18n "discourse_kanban.board.notes_placeholder"}}
            {{on "input" this.onNotesInput}}
          >{{this.editNotes}}</textarea>
        </div>

        <div class="kanban-card-detail__field">
          <label>{{i18n "discourse_kanban.board.labels"}}</label>
          {{#if this.editLabels.length}}
            <div class="kanban-card-detail__labels">
              {{#each this.editLabels as |label|}}
                <span class="kanban-card-detail__label-chip">
                  {{label}}
                  {{#if this.canWrite}}
                    <button
                      type="button"
                      class="btn-remove-label"
                      title={{i18n "discourse_kanban.board.remove_label"}}
                      {{on "click" (fn this.removeLabel label)}}
                    >{{icon "xmark"}}</button>
                  {{/if}}
                </span>
              {{/each}}
            </div>
          {{/if}}
          {{#if this.canWrite}}
            <input
              type="text"
              value={{this.newLabelText}}
              placeholder={{i18n "discourse_kanban.board.labels_placeholder"}}
              {{on "input" this.onLabelInput}}
              {{on "keydown" this.onLabelKeydown}}
            />
          {{/if}}
        </div>

        <div class="kanban-card-detail__field">
          <label>{{i18n "discourse_kanban.board.due_date"}}</label>
          <DateInput
            @date={{this.editDueAt}}
            @onChange={{this.onDueDateChanged}}
            disabled={{not this.canWrite}}
          />
        </div>
      </:body>
      <:footer>
        {{#if this.canWrite}}
          <DButton class="btn-primary" @action={{this.save}} @label="save" />
        {{/if}}
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
