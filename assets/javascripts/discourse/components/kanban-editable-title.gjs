import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import autoFocus from "discourse/modifiers/auto-focus";

class KanbanEditableTitleUi extends Component {
  @tracked isEditing = isEmpty(this.args.field.value);

  get hasValue() {
    return !isEmpty(this.args.field.value);
  }

  get displayText() {
    return trustHTML(
      emojiUnescape(
        escapeExpression(this.args.field.value || this.args.placeholder)
      )
    );
  }

  @action
  startEditing() {
    if (this.args.field.disabled) {
      return;
    }
    this.isEditing = true;
  }

  @action
  onInput(event) {
    this.args.field.set(event.target.value);
  }

  @action
  finishEditing() {
    const value = this.args.field.value?.trim() ?? "";
    this.args.field.set(value);
    this.isEditing = false;
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    } else if (event.key === "Escape") {
      this.isEditing = false;
    }
  }

  <template>
    {{#if this.isEditing}}
      <input
        type="text"
        value={{@field.value}}
        placeholder={{@placeholder}}
        class="discourse-kanban-editable-title__input"
        id={{@field.id}}
        name={{@field.name}}
        disabled={{@field.disabled}}
        aria-invalid={{if @field.error "true"}}
        aria-describedby={{if @field.error @field.errorId}}
        {{autoFocus selectText=true}}
        {{on "input" this.onInput}}
        {{on "blur" this.finishEditing}}
        {{on "keydown" this.handleKeydown}}
      />
    {{else}}
      {{! template-lint-disable no-invalid-interactive }}
      <div
        class={{concatClass
          "discourse-kanban-editable-title__text"
          (unless this.hasValue "--empty")
        }}
        {{on "click" this.startEditing}}
      >{{this.displayText}}</div>
    {{/if}}
    {{#if @showClose}}
      <DButton
        @action={{@onClose}}
        @icon="xmark"
        @ariaLabel="modal.close"
        @title="modal.close"
        class="btn-flat discourse-kanban-editable-title__close"
      />
    {{/if}}
  </template>
}

export default class KanbanEditableTitle extends Component {
  get validation() {
    if (this.args.validate) {
      return null;
    }

    return this.args.validation || "required:trim";
  }

  <template>
    <div class="discourse-kanban-editable-title">
      <@form.Field
        @name={{@name}}
        @title={{@title}}
        @type="custom"
        @validation={{this.validation}}
        @showTitle={{false}}
        @disabled={{@disabled}}
        @validate={{@validate}}
        @format="full"
        as |field|
      >
        <field.Control>
          <KanbanEditableTitleUi
            @field={{field}}
            @placeholder={{@placeholder}}
            @showClose={{@showClose}}
            @onClose={{@onClose}}
          />
        </field.Control>
      </@form.Field>
    </div>
  </template>
}
