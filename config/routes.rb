# frozen_string_literal: true

DiscourseKanban::Engine.routes.draw do
  # Client-side Ember routes (serve app shell on page reload)
  get "/" => "boards#respond"
  get "/boards/new" => "boards#respond"
  get "/boards/:slug/:id/configure" => "boards#respond"
  get "/boards/:id/configure" => "boards#respond"

  get "/boards/:slug/:id/card/:card_id" => "boards#respond"
  get "/boards/:slug/:id" => "boards#respond"

  # API routes
  get "/boards" => "boards#index"
  get "/boards/:id" => "boards#show"
  post "/boards" => "boards#create"
  put "/boards/:id" => "boards#update"
  delete "/boards/:id" => "boards#destroy"
  post "/boards/:id/move-column" => "boards#move_column"
  post "/boards/:id/constraint-preview" => "boards#constraint_preview"

  post "/boards/:board_id/columns" => "columns#create"
  put "/boards/:board_id/columns/:id" => "columns#update"
  delete "/boards/:board_id/columns/:id" => "columns#destroy"
  post "/boards/:board_id/cards" => "cards#create"
  put "/boards/:board_id/cards/:id" => "cards#update"
  post "/boards/:board_id/cards/:id/view" => "cards#view"
  delete "/boards/:board_id/cards/:id" => "cards#destroy"
  delete "/boards/:board_id/columns/:column_id/cards" => "cards#clear"

  post "/boards/:board_id/topic-moves" => "topic_moves#create"
end

Discourse::Application.routes.draw { mount ::DiscourseKanban::Engine, at: "/kanban" }
