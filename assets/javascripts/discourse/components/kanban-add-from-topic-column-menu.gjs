import Component from "@glimmer/component";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

export default class KanbanAddFromTopicColumnMenu extends Component {
  addToColumn() {}

  <template>
    <DDropdownMenu class="kanban-add-from-topic-column-menu" as |dropdown|>
      {{#each @data.board.columns as |column|}}
        <dropdown.item>
          <DButton
            @action={{this.addToColumn}}
            @icon={{column.icon}}
            @translatedLabel={{column.fancyTitle}}
            class="btn-transparent kanban-add-from-topic-column-menu__column"
          />
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
