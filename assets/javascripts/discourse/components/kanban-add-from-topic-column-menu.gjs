import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import KanbanConstraintFix from "./modal/kanban-constraint-fix";

export default class KanbanAddFromTopicColumnMenu extends Component {
  @service messageBus;
  @service modal;

  @action
  async addToColumn(column) {
    const response = await this.#checkConstraints(column);

    if (response?.constraints_need_fixing) {
      return this.#onConstraintMismatch(column, response);
    }

    await this.#completeAddToColumn(column);

    // if MOVING TO OTHER COLUMN
    // if this.board.require_confirmation (require confirmation on moves)
    // show move confirm
    //
    //
    // _confirmMove(card, toColumn) {
    //   return new Promise((resolve) => {
    //     const cardTitle = card.fancyTitle || "";
    //     this.dialog.yesNoConfirm({
    //       message: i18n("discourse_kanban.board.move_confirm", {
    //         topic_title: cardTitle,
    //         column_title: toColumn.fancyTitle,
    //       }),
    //       didConfirm: () => resolve(true),
    //       didCancel: () => resolve(false),
    //     });
    //   });
    // }
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
    // TODO (martin) Not sure if we need this...since we aren't technically
    // moving.
    // if (this.args.board.require_confirmation) {
    // }
    //
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
      return await ajax(`/kanban/boards/${this.args.data.board.id}/cards`, {
        type: "POST",
        data,
      });
    } catch (error) {
      popupAjaxError(error);
      return;
    }
  }

  <template>
    <DDropdownMenu class="kanban-add-from-topic-column-menu" as |dropdown|>
      {{#each @data.board.columns as |column|}}
        <dropdown.item>
          <DButton
            @action={{fn this.addToColumn column}}
            @icon={{column.icon}}
            @translatedLabel={{column.fancyTitle}}
            class="btn-transparent kanban-add-from-topic-column-menu__column"
          />
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
