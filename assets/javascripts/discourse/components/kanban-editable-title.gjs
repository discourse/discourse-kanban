import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class KanbanEditableTitle extends Component {
  @tracked isEditing = !this.args.value;

  focusInput = modifier((element) => {
    element.focus();
    element.select();
  });

  get hasValue() {
    return !!this.args.value;
  }

  get displayText() {
    return this.args.value || this.args.placeholder;
  }

  @action
  startEditing() {
    if (this.args.disabled) {
      return;
    }
    this.isEditing = true;
  }

  @action
  onInput(event) {
    this.args.onInput?.(event.target.value);
  }

  @action
  finishEditing() {
    this.isEditing = false;
    this.args.onInput?.(this.args.value?.trim() ?? "");
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
    <div class="kanban-editable-title">
      {{#if this.isEditing}}
        <input
          type="text"
          value={{@value}}
          placeholder={{@placeholder}}
          class="kanban-editable-title__input"
          {{this.focusInput}}
          {{on "input" this.onInput}}
          {{on "blur" this.finishEditing}}
          {{on "keydown" this.handleKeydown}}
        />
      {{else}}
        {{! template-lint-disable no-invalid-interactive }}
        <div
          class={{concatClass
            "kanban-editable-title__text"
            (unless this.hasValue "--empty")
          }}
          {{on "click" this.startEditing}}
        >{{this.displayText}}</div>
      {{/if}}
      <DButton
        @action={{@onClose}}
        @icon="xmark"
        class="btn-flat kanban-editable-title__close"
      />
    </div>
  </template>
}
