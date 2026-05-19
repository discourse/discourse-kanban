import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
// import { block } from "discourse/blocks";
import DockedComposer from "discourse/components/docked-composer";
import PostStream from "discourse/components/post-stream";
import TopicCategory from "discourse/components/topic-category";
import DMenu from "discourse/float-kit/components/d-menu";
import Post from "discourse/models/post";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RightSidebarPanel extends Component {
  @service topicSidebar;

  get topic() {
    return this.topicSidebar.selectedTopicId ? this.topicSidebar.topic : null;
  }

  get panelTitle() {
    return this.topic ? this.topic.fancyTitle : "";
  }

  @action
  close() {
    this.topicSidebar.clearSelectedTopic();
  }

  @action
  async onComposerSubmit({ raw }) {
    const topic = this.topic;
    if (!topic || !raw?.trim()) {
      return;
    }
    const post = Post.create({ raw, topic_id: topic.id });
    await post.save();
    await topic.postStream.refresh();
  }

  <template>
    <div class="kanban-right-sidebar-panel">
      <div class="kanban-right-sidebar-panel__header">

        <div class="kanban-right-sidebar-panel__header-content">

          <DButton
            @action={{this.close}}
            @icon="angles-left"
            @title="close"
            class="btn-flat topic-sidebar-block__close"
          />
          <h2 class="kanban-right-sidebar-panel__title">
            {{this.panelTitle}}
          </h2>
          <DMenu
            @identifier="kanban-right-sidebar-panel__nav-menu"
            @title="Menu"
            @class="btn-default"
          >
            <:trigger>
              Title
              {{dIcon "angle-down"}}
            </:trigger>
            <:content>
              <DDropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @icon="reply"
                    @title="Discussion"
                    @label="Discussion"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @icon="far-rectangle-list"
                    @title="Details"
                    @label="Details"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @icon="bars-staggered"
                    @title="Activity"
                    @label="Activity"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>

        <TopicCategory @topic={{this.topic}} class="topic-category" />

      </div>
      <div class="kanban-right-sidebar-panel__content">
        {{#if this.topic}}
          <div class="kanban-right-sidebar-panel__topic">

            <div class="topic-sidebar-block__scroll">

              <PostStream
                @postStream={{this.topic.postStream}}
                @topic={{this.topic}}
              />
            </div>

            <DockedComposer
              @topicId={{this.topic.id}}
              @onSubmit={{this.onComposerSubmit}}
            />
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
