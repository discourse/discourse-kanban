import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import Board from "discourse/plugins/discourse-kanban/discourse/models/board";
import KanbanAddFromTopicColumnMenu from "./kanban-add-from-topic-column-menu";

const SKELETON_ROWS = Array.from({ length: 3 });

const BoardSkeleton = <template>
  <div class="kanban-add-from-topic-menu__skeleton" aria-hidden="true">
    <div class="kanban-add-from-topic-menu__skeleton-label"></div>
    <div class="kanban-add-from-topic-menu__skeleton-icon"></div>
  </div>
</template>;

export default class KanbanAddFromTopicMenu extends Component {
  @service menu;

  @tracked boards = [];
  @tracked loading = true;

  skeletonRows = SKELETON_ROWS;
  #requestedBoards = false;

  @action
  loadBoards() {
    if (this.#requestedBoards) {
      return;
    }

    this.#requestedBoards = true;
    this.#fetchBoards();
  }

  async #fetchBoards() {
    try {
      const result = await ajax("/kanban/boards?edit_only=true");
      this.boards = result.boards
        .filter((board) => board.columns?.length)
        .map((board) => Board.create(board));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  openBoardSubmenu(board, event) {
    return this.menu.show(event.currentTarget, {
      identifier: "kanban-add-from-topic-column-menu",
      component: KanbanAddFromTopicColumnMenu,
      modalForMobile: true,
      placement: "right-start",
      offset: { mainAxis: 10, crossAxis: -5 },
      data: { board, topic: this.args.data?.topic },
    });
  }

  <template>
    <DDropdownMenu
      class="kanban-add-from-topic-menu"
      {{didInsert this.loadBoards}}
      as |dropdown|
    >
      {{#if this.loading}}
        {{#each this.skeletonRows}}
          <dropdown.item>
            <BoardSkeleton />
          </dropdown.item>
        {{/each}}
      {{else}}
        {{#each this.boards as |board|}}
          <dropdown.item
            class="kanban-add-from-topic-menu__board-item"
            {{on "mouseenter" (fn this.openBoardSubmenu board) passive=true}}
          >
            <DButton
              @actionParam={{board}}
              @action={{this.openBoardSubmenu}}
              @forwardEvent={{true}}
              @suffixIcon="angle-right"
              @translatedLabel={{board.fancyTitle}}
              class="btn-transparent kanban-add-from-topic-menu__board"
            />
          </dropdown.item>
        {{else}}
          <dropdown.item class="kanban-add-from-topic-menu__empty">
            {{i18n "discourse_kanban.topic_footer.no_boards"}}
          </dropdown.item>
        {{/each}}
      {{/if}}
    </DDropdownMenu>
  </template>
}
