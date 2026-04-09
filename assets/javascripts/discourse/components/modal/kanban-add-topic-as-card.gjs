import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import TopicStatus from "discourse/components/topic-status";
import categoryLink from "discourse/helpers/category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import loadingSpinner from "discourse/helpers/loading-spinner";
import replaceEmoji from "discourse/helpers/replace-emoji";
import discourseDebounce from "discourse/lib/debounce";
import { searchForTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class KanbanAddTopicAsCard extends Component {
  @tracked selectedRow = -1;
  @tracked searchResults = [];
  @tracked searchLoading = false;
  #debounced;
  #activeSearch;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#debounced);
  }

  @cached
  get data() {
    return { topicSearch: "" };
  }

  highlightRow(e, direction) {
    const index =
      direction === "down" ? this.selectedRow + 1 : this.selectedRow - 1;

    if (index > -1 && index < this.searchResults.length) {
      document
        .querySelectorAll(".internal-link-results .search-link")
        [index]?.focus();
      this.selectedRow = index;
    } else {
      this.selectedRow = -1;
      document.querySelector("input.topic-search-input")?.focus();
    }

    e.preventDefault();
  }

  selectTopic(el) {
    const topicId = parseInt(el.dataset.topicId, 10);
    const title = el.dataset.title;
    if (topicId) {
      this.searchResults = [];
      this.args.model.onAddTopicAsCard({ topicId, title });
      this.args.closeModal();
    }
  }

  async triggerSearch(value) {
    if (!value || value.length < 4 || value.startsWith("http")) {
      this.abortSearch();
      return;
    }

    this.searchLoading = true;
    this.#activeSearch = searchForTerm(value, { typeFilter: "topic" });

    try {
      const results = await this.#activeSearch;
      this.searchResults = results?.topics || [];
    } finally {
      this.searchLoading = false;
      this.#activeSearch = null;
    }
  }

  abortSearch() {
    this.#activeSearch?.abort();
    this.searchResults = [];
    this.searchLoading = false;
  }

  @action
  keyDown(event) {
    switch (event.key) {
      case "ArrowDown":
        this.highlightRow(event, "down");
        break;
      case "ArrowUp":
        this.highlightRow(event, "up");
        break;
      case "Enter":
        if (this.selectedRow > -1) {
          const selected = document.querySelectorAll(
            ".internal-link-results .search-link"
          )[this.selectedRow];
          if (selected) {
            this.selectTopic(selected);
          }
          event.preventDefault();
          event.stopPropagation();
        }
        break;
      case "Escape":
        if (this.searchResults.length) {
          this.searchResults = [];
          event.preventDefault();
          event.stopPropagation();
        }
        break;
    }
  }

  @action
  mouseDown(event) {
    if (!event.target.closest(".inputs")) {
      this.searchResults = [];
    }
  }

  @action
  topicClick(event) {
    if (!event.metaKey && !event.ctrlKey) {
      event.preventDefault();
      event.stopPropagation();
      this.selectTopic(event.target.closest(".search-link"));
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  search(value) {
    this.formApi.set("topicSearch", value);
    this.#debounced = discourseDebounce(this, this.triggerSearch, value, 400);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <DModal
      {{on "keydown" this.keyDown}}
      {{on "mousedown" this.mouseDown}}
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_kanban.board.add_topic_as_card_title"}}
      @bodyClass="insert-link"
      class="kanban-add-topic-as-card-modal"
    >
      <:body>
        <div class="inputs">
          <Form
            @data={{this.data}}
            @onRegisterApi={{this.registerApi}}
            as |form|
          >
            <form.Field
              @name="topicSearch"
              @type="input"
              @title={{i18n "discourse_kanban.board.topic_search_placeholder"}}
              @format="full"
              @onSet={{this.search}}
              as |field|
            >
              <field.Control
                placeholder={{i18n
                  "discourse_kanban.board.topic_search_placeholder"
                }}
                class="topic-search-input"
                autofocus="autofocus"
              />
            </form.Field>

            {{#if this.searchLoading}}
              {{loadingSpinner}}
            {{/if}}

            {{#if this.searchResults}}
              <div class="internal-link-results">
                {{#each this.searchResults as |result|}}
                  <a
                    {{on "click" this.topicClick}}
                    href={{result.url}}
                    data-topic-id={{result.id}}
                    data-title={{result.fancy_title}}
                    class="search-link"
                  >
                    <TopicStatus @topic={{result}} @disableActions={{true}} />
                    {{replaceEmoji result.title}}
                    <div class="search-category">
                      {{#if result.category.parentCategory}}
                        {{categoryLink result.category.parentCategory}}
                      {{/if}}
                      {{categoryLink result.category hideParent=true}}
                      {{discourseTags result}}
                    </div>
                  </a>
                {{/each}}
              </div>
            {{/if}}
          </Form>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{@closeModal}}
          @label="cancel"
          class="btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
