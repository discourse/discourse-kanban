import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
// import { block } from "discourse/blocks";
import { modifier } from "ember-modifier";
import DockedComposer from "discourse/components/docked-composer";
import PostStream from "discourse/components/post-stream";
import TopicCategory from "discourse/components/topic-category";
import Post from "discourse/models/post";
import DButton from "discourse/ui-kit/d-button";
import { withSidebarViewTransition } from "../lib/sidebar-transition";

export default class RightSidebarPanel extends Component {
  @service topicSidebar;

  trackHeaderHeight = modifier((element) => {
    const root = document.documentElement;
    const update = () => {
      root.style.setProperty(
        "--right-sidebar-header-height",
        `${element.offsetHeight}px`
      );
    };
    update();
    const observer = new ResizeObserver(update);
    observer.observe(element);
    return () => {
      observer.disconnect();
      root.style.removeProperty("--right-sidebar-header-height");
    };
  });

  get topic() {
    return this.topicSidebar.selectedTopicId ? this.topicSidebar.topic : null;
  }

  get panelTitle() {
    return this.topic ? this.topic.fancyTitle : "";
  }

  @action
  close() {
    withSidebarViewTransition(() => {
      this.topicSidebar.clearSelectedTopic();
    });
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
    {{#if this.topic}}
      <div class="kanban-right-sidebar-panel">
        <div
          class="kanban-right-sidebar-panel__header"
          {{this.trackHeaderHeight}}
        >

          <div class="kanban-right-sidebar-panel__header-content">

            <div class="kanban-right-sidebar-panel__title-content">
              <h2 class="kanban-right-sidebar-panel__title">
                {{this.panelTitle}}
              </h2>
              <div class="kanban-right-sidebar-panel__category">
                <TopicCategory @topic={{this.topic}} class="topic-category" />
              </div>
            </div>
            <DButton
              @action={{this.close}}
              @icon="angles-right"
              @title="close"
              class="btn-transparent kanban-right-sidebar-panel__close"
            />
          </div>

        </div>
        <div class="kanban-right-sidebar-panel__content">
          <div class="kanban-right-sidebar-panel__topic">

            <PostStream
              @postStream={{this.topic.postStream}}
              @topic={{this.topic}}
            />

            <DockedComposer
              @topicId={{this.topic.id}}
              @onSubmit={{this.onComposerSubmit}}
            />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
