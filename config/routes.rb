# frozen_string_literal: true

DiscourseKanban::Engine.routes.draw do
  # Client-side Ember routes (serve app shell on page reload)
  get "/" => "boards#respond"
  get "/boards/new" => "boards#respond"
  get "/boards/:slug/:id/configure" => "boards#respond"
  get "/boards/:id/configure" => "boards#respond"

  get "/boards/:slug/:id" => "boards#respond"

  # API routes
  get "/boards" => "boards#index"
  get "/boards/:id" => "boards#show"
  post "/boards" => "boards#create"
  put "/boards/:id" => "boards#update"
  delete "/boards/:id" => "boards#destroy"

  post "/boards/:board_id/cards" => "cards#create"
  put "/boards/:board_id/cards/:id" => "cards#update"
  delete "/boards/:board_id/cards/:id" => "cards#destroy"

  post "/boards/:board_id/topic-moves" => "topic_moves#create"
end

Discourse::Application.routes.draw { mount ::DiscourseKanban::Engine, at: "/kanban" }
