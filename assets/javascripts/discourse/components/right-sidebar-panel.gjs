import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
// import { block } from "discourse/blocks";
import DockedComposer from "discourse/components/docked-composer";
import PostStream from "discourse/components/post-stream";
import TopicCategory from "discourse/components/topic-category";
import Post from "discourse/models/post";
import DButton from "discourse/ui-kit/d-button";
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
        <h2 class="kanban-right-sidebar-panel__title">
          {{this.panelTitle}}

        </h2>

        <TopicCategory @topic={{this.topic}} class="topic-category" />

        <div class="kanban-right-sidebar-panel__nav">
          <DHorizontalOverflowNav class="main-nav nav user-nav">
            <DNavigationItem @route="kanbanBoardCard">
              {{dIcon "reply"}}
              <span>Discussion</span>
            </DNavigationItem>

            <DNavigationItem
              @route="kanbanBoardCard"
              class="user-nav__activity"
            >
              {{dIcon "far-rectangle-list"}}
              <span>Details</span>
            </DNavigationItem>

            <DNavigationItem
              @route="kanbanBoardCard"
              class="user-nav__activity"
            >
              {{dIcon "bars-staggered"}}
              <span>{{i18n "user.activity_stream"}}</span>
            </DNavigationItem>
          </DHorizontalOverflowNav>
        </div>
      </div>
      <div class="kanban-right-sidebar-panel__content">
        {{#if this.topic}}
          <div class="kanban-right-sidebar-panel__topic">
            <DButton
              @action={{this.close}}
              @icon="xmark"
              @title="close"
              class="btn-flat topic-sidebar-block__close"
            />
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
