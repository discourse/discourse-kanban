import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import KanbanConstraintFix from "./modal/kanban-constraint-fix";

export default class KanbanAddFromTopicColumnSubmenu extends Component {
  @service messageBus;
  @service modal;
  @service toasts;

  @action
  async addToColumn(column) {
    const response = await this.#checkConstraints(column);

    if (response?.constraints_need_fixing) {
      return this.#onConstraintMismatch(column, response);
    }

    await this.#completeAddToColumn(column);
  }

  async #checkConstraints(column) {
    try {
      const response = await ajax(
        `/kanban/boards/${this.args.data.board.id}/check-constraint-mismatches`,
        {
          method: "PUT",
          data: {
            topic_id: this.args.data.topic.id,
            target_column_id: column.id,
          },
        }
      );
      return response;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #onConstraintMismatch(column, response) {
    const mismatches = {
      needsTags: response.tags_needed.length > 0,
      needsCategory: response.categories_needed.length > 0,
      boardTagNames: response.tags_needed,
      boardCategoryIds: response.categories_needed,
    };

    this.modal.show(KanbanConstraintFix, {
      model: {
        topic: this.args.data.topic,
        board: this.args.data.board,
        column,
        mismatches,
        onConfirm: (result) => this.#completeAddToColumn(column, result),
      },
    });
  }

  async #completeAddToColumn(column, constraintFixResult = null) {
    const data = {
      client_id: this.messageBus.clientId,
      card: {
        column_id: column.id,
        topic_id: this.args.data.topic.id,
      },
    };

    if (constraintFixResult) {
      data.constraint_fix = constraintFixResult;
    }

    try {
      await ajax(`/kanban/boards/${this.args.data.board.id}/cards`, {
        type: "POST",
        data,
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("discourse_kanban.board.added_topic_to_board", {
            boardName: this.args.data.board.unicode_name,
            columnName: column.unicode_title,
          }),
        },
      });

      this.args.close();
    } catch (error) {
      popupAjaxError(error);
      return;
    }
  }

  columnIcon(column) {
    if (column.topic_is_member) {
      return "circle";
    }

    return null;
  }

  columnStyle(column) {
    if (!isValidHex(column.color)) {
      return null;
    }

    if (column.color) {
      return `--kanban-column-suffix-color: #${normalizeHex(column.color)};`;
    }

    return null;
  }

  <template>
    <DDropdownMenu class="kanban-add-from-topic-column-menu" as |dropdown|>
      {{#each @data.board.columns as |column|}}
        <dropdown.item>
          <DButton
            @action={{fn this.addToColumn column}}
            @icon={{this.columnIcon column}}
            @suffixIcon={{column.icon}}
            @translatedLabel={{column.fancyTitle}}
            style={{this.columnStyle column}}
            class="btn-transparent kanban-add-from-topic-column-menu__column"
          />
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
