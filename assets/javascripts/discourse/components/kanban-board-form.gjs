import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";
import KanbanColumnsEditor from "./kanban-columns-editor";

const CARD_STYLE_OPTIONS = [
  { id: "detailed", name: "discourse_kanban.manage.card_style_detailed" },
  { id: "simple", name: "discourse_kanban.manage.card_style_simple" },
];

export default class KanbanBoardForm extends Component {
  @service router;
  @service dialog;
  @service toasts;
  @service site;

  get isNew() {
    return !this.args.model.id;
  }

  get cardStyleOptions() {
    return CARD_STYLE_OPTIONS.map((opt) => ({
      id: opt.id,
      name: i18n(opt.name),
    }));
  }

  get formData() {
    const model = this.args.model;
    return {
      id: model.id,
      name: model.name,
      slug: model.slug,
      base_filter_query: model.base_filter_query,
      card_style: model.card_style || "detailed",
      show_tags: model.show_tags ?? false,
      show_topic_thumbnail: model.show_topic_thumbnail ?? false,
      show_activity_indicators: model.show_activity_indicators ?? false,
      require_confirmation: model.require_confirmation ?? true,
      allow_read_group_ids: model.allow_read_group_ids || [],
      allow_write_group_ids: model.allow_write_group_ids || [],
      columns: model.columns ? model.columns.map((c) => ({ ...c })) : [],
    };
  }

  @action
  async save(data) {
    const isNew = !data.id;
    const payload = {
      board: {
        name: data.name,
        slug: data.slug,
        base_filter_query: data.base_filter_query,
        card_style: data.card_style,
        show_tags: data.show_tags,
        show_topic_thumbnail: data.show_topic_thumbnail,
        show_activity_indicators: data.show_activity_indicators,
        require_confirmation: data.require_confirmation,
        allow_read_group_ids: data.allow_read_group_ids || [],
        allow_write_group_ids: data.allow_write_group_ids || [],
        columns: (data.columns || []).map((col) => ({
          id: col.id,
          title: col.title,
          icon: col.icon,
          filter_query: col.filter_query,
          move_to_tag: col.move_to_tag,
          move_to_category_id: col.move_to_category_id,
          move_to_assigned:
            col.move_to_assigned === "_user" ? "" : col.move_to_assigned,
          move_to_status: col.move_to_status,
        })),
      },
    };

    try {
      const result = await ajax(
        isNew ? "/kanban/boards" : `/kanban/boards/${data.id}`,
        {
          type: isNew ? "POST" : "PUT",
          contentType: "application/json",
          data: JSON.stringify(payload),
        }
      );

      this.toasts.success({
        data: { message: i18n("saved") },
        duration: "short",
      });

      const savedBoard = result.board;

      if (isNew) {
        this.router.transitionTo(
          "kanbanBoardConfigure",
          savedBoard.slug,
          savedBoard.id
        );
      } else {
        Object.assign(this.args.model, savedBoard);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  delete() {
    if (this.isNew) {
      this.router.transitionTo("kanbanBoards");
      return;
    }

    return this.dialog.confirm({
      message: i18n("discourse_kanban.manage.confirm_delete"),

      didConfirm: async () => {
        try {
          await ajax(`/kanban/boards/${this.args.model.id}`, {
            type: "DELETE",
          });
          this.router.transitionTo("kanbanBoards");
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="kanban-board-form"
      as |form|
    >
      <form.Field
        @name="name"
        @title={{i18n "discourse_kanban.manage.name"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="slug"
        @title={{i18n "discourse_kanban.manage.slug"}}
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="base_filter_query"
        @title={{i18n "discourse_kanban.manage.base_filter_query"}}
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="card_style"
        @title={{i18n "discourse_kanban.manage.card_style"}}
        as |field|
      >
        <field.Select as |select|>
          {{#each this.cardStyleOptions as |option|}}
            <select.Option @value={{option.id}}>{{option.name}}</select.Option>
          {{/each}}
        </field.Select>
      </form.Field>

      <form.Field
        @name="show_tags"
        @title={{i18n "discourse_kanban.manage.show_tags"}}
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="show_topic_thumbnail"
        @title={{i18n "discourse_kanban.manage.show_topic_thumbnail"}}
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="show_activity_indicators"
        @title={{i18n "discourse_kanban.manage.show_activity_indicators"}}
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="require_confirmation"
        @title={{i18n "discourse_kanban.manage.require_confirmation"}}
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="allow_read_group_ids"
        @title={{i18n "discourse_kanban.manage.allow_read_groups"}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="allow_write_group_ids"
        @title={{i18n "discourse_kanban.manage.allow_write_groups"}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="columns"
        @title={{i18n "discourse_kanban.manage.columns.title"}}
        @format="full"
        as |field|
      >
        <field.Custom>
          <KanbanColumnsEditor
            @columns={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Actions>
        <form.Submit @label="discourse_kanban.manage.save" />
        {{#unless this.isNew}}
          <form.Button
            @action={{this.delete}}
            @label="discourse_kanban.manage.delete"
            class="btn-danger"
          />
        {{/unless}}
      </form.Actions>
    </Form>
  </template>
}
