# frozen_string_literal: true

RSpec.describe DiscourseKanban::CardsController do
  fab!(:admin)
  fab!(:writer, :user)
  fab!(:reader, :user)
  fab!(:outsider, :user)
  fab!(:write_group, :group)
  fab!(:read_group, :group)
  fab!(:category) { Fabricate(:category, name: "Todo") }
  fab!(:topic) { Fabricate(:topic, category: category, user: writer) }

  fab!(:board) do
    DiscourseKanban::Board.create!(
      name: "Test Board",
      slug: "test-board",
      allow_write_group_ids: [write_group.id],
      allow_read_group_ids: [read_group.id],
      created_by_id: admin.id,
    )
  end
  fab!(:col_todo) { board.columns.create!(title: "To Do", position: 0) }
  fab!(:col_done) { board.columns.create!(title: "Done", position: 1, move_to_tag: "done") }

  before do
    enable_current_plugin
    SiteSetting.discourse_kanban_enabled = true
    write_group.add(writer)
    read_group.add(reader)
  end

  describe "POST /kanban/boards/:board_id/cards" do
    it "creates a floater card" do
      sign_in(writer)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "New task",
             },
           }

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["card_type"]).to eq("floater")
      expect(card["title"]).to eq("New task")
      expect(card["column_id"]).to eq(col_todo.id)
    end

    it "creates a topic card" do
      sign_in(writer)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: topic.id,
             },
           }

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["card_type"]).to eq("topic")
      expect(card["topic_id"]).to eq(topic.id)
      expect(card["topic"]["title"]).to eq(topic.title)
    end

    it "allows topic cards in different columns when another insert races" do
      inserted_competitor = false
      allow(DiscourseKanban::CardOrdering).to receive(
        :append_to_column!,
      ).and_wrap_original do |original, card, column|
        unless inserted_competitor
          board.cards.create!(
            card_type: :topic,
            membership_mode: :auto,
            topic_id: topic.id,
            column_id: col_done.id,
            position: 0,
            created_by_id: admin.id,
          )
          inserted_competitor = true
        end

        original.call(card, column)
      end

      sign_in(admin)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: topic.id,
             },
           }

      expect(response.status).to eq(201)
      expect(board.cards.where(topic_id: topic.id).count).to eq(2)

      created_card = board.cards.find_by(topic_id: topic.id, column_id: col_todo.id)
      expect(created_card).to be_present
      expect(created_card.membership_mode).to eq("manual_in")
    end

    it "returns 404 when topic does not exist" do
      sign_in(writer)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: -1,
             },
           }

      expect(response.status).to eq(404)
    end

    it "returns 404 when user cannot see the topic" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)

      sign_in(writer)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: private_topic.id,
             },
           }

      expect(response.status).to eq(404)
    end

    it "rejects requests from users without write access" do
      sign_in(reader)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Sneaky card",
             },
           }

      expect(response.status).to eq(403)
    end

    it "rejects anonymous requests" do
      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Anon card",
             },
           }

      expect(response.status).to eq(403)
    end

    it "includes all_assigned_users in the response when assignments exist" do
      skip("requires discourse-assign") unless defined?(Assignment)

      assignee_1 = Fabricate(:user)
      assignee_2 = Fabricate(:user)
      post_in_topic = Fabricate(:post, topic: topic)
      Assignment.create!(
        target: topic,
        topic_id: topic.id,
        assigned_to: assignee_1,
        assigned_by_user: admin,
        active: true,
      )
      Assignment.create!(
        target: post_in_topic,
        topic_id: topic.id,
        assigned_to: assignee_2,
        assigned_by_user: admin,
        active: true,
      )

      sign_in(admin)

      post "/kanban/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: topic.id,
             },
           }

      expect(response.status).to eq(201)
      all_assigned = response.parsed_body.dig("card", "topic", "all_assigned_users")
      expect(all_assigned).to be_present
      usernames = all_assigned.map { |u| u["username"] }
      expect(usernames).to include(assignee_1.username, assignee_2.username)
    end
  end

  describe "PUT /kanban/boards/:board_id/cards/:id" do
    it "moves a floater card between columns" do
      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Move me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_done.id)
    end

    it "updates a floater card title" do
      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Old title",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              title: "New title",
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.title).to eq("New title")
      expect(response.parsed_body["card"]["title"]).to eq("New title")
    end

    it "preserves notes and due date when omitted from floater updates" do
      due_at = 2.days.from_now.change(usec: 0)
      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Keep details",
          notes: "Keep this note",
          due_at: due_at,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              title: "Updated title only",
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.notes).to eq("Keep this note")
      expect(card.due_at.to_i).to eq(due_at.to_i)
    end

    it "applies topic mutations when moving a topic card to a new column" do
      SiteSetting.tagging_enabled = true
      Fabricate(:tag, name: "done")
      col_done.update!(move_to_tag: "done")

      card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_done.id)
      expect(topic.reload.tags.map(&:name)).to include("done")
    end

    it "reorders within the same column" do
      card1 =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "First",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      card2 =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Second",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/kanban/boards/#{board.id}/cards/#{card1.id}.json",
          params: {
            card: {
              column_id: col_todo.id,
              after_card_id: card2.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card2.reload.position).to be < card1.reload.position
    end

    it "promotes a floater card to a topic card" do
      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          notes: "Some notes",
          labels: %w[urgent],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      result = response.parsed_body["card"]
      expect(result["card_type"]).to eq("topic")
      expect(result["topic_id"]).to eq(topic.id)
      expect(result["title"]).to be_nil
      expect(result["notes"]).to be_nil
      expect(result["labels"]).to eq([])

      card.reload
      expect(card.topic_id).to eq(topic.id)
      expect(card).to be_topic
      expect(card.title).to be_nil
      expect(card.notes).to be_nil
      expect(card.labels).to eq([])
    end

    it "adopts the existing topic card when promotion races with topic sync insertion" do
      floater =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      inserted_competitor = false
      allow(DiscourseKanban::TopicMutator).to receive(
        :apply!,
      ).and_wrap_original do |original, **kwargs|
        unless inserted_competitor
          board.cards.create!(
            card_type: :topic,
            membership_mode: :auto,
            topic_id: topic.id,
            column_id: col_todo.id,
            position: 1,
            created_by_id: admin.id,
          )
          inserted_competitor = true
        end

        original.call(**kwargs)
      end

      sign_in(admin)

      put "/kanban/boards/#{board.id}/cards/#{floater.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      expect(board.cards.where(topic_id: topic.id).count).to eq(1)
      expect(DiscourseKanban::Card.find_by(id: floater.id)).to be_nil
      expect(response.parsed_body.dig("card", "topic_id")).to eq(topic.id)
    end

    it "promotes a floater reactivating an existing manual_out topic card" do
      existing_topic_card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_out,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )

      floater =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/kanban/boards/#{board.id}/cards/#{floater.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      result = response.parsed_body["card"]
      expect(result["card_type"]).to eq("topic")
      expect(result["topic_id"]).to eq(topic.id)
      expect(result["column_id"]).to eq(col_todo.id)

      existing_topic_card.reload
      expect(existing_topic_card).to be_manual_in
      expect(existing_topic_card.column_id).to eq(col_todo.id)

      expect(DiscourseKanban::Card.find_by(id: floater.id)).to be_nil
    end

    it "includes adopted_floater_id in response when adopting an existing topic card" do
      existing_topic_card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_out,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )

      floater =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/kanban/boards/#{board.id}/cards/#{floater.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["adopted_floater_id"]).to eq(floater.id)
      expect(body["card"]["topic_id"]).to eq(topic.id)
    end

    it "publishes card_deleted + card_created events for adoption" do
      existing_topic_card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_out,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )

      floater =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(admin)

      messages =
        MessageBus.track_publish("/kanban/boards/#{board.id}") do
          put "/kanban/boards/#{board.id}/cards/#{floater.id}.json",
              params: {
                card: {
                  topic_id: topic.id,
                },
              }
        end

      expect(response.status).to eq(200)
      types = messages.map { |m| m.data[:type] }
      expect(types).to contain_exactly("card_deleted", "card_created")
    end

    it "rejects promoting a floater to a topic the user cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)

      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              topic_id: private_topic.id,
            },
          }

      expect(response.status).to eq(403)
      expect(card.reload).to be_floater
    end

    it "includes all_assigned_users in the response after a topic card move" do
      skip("requires discourse-assign") unless defined?(Assignment)

      assignee = Fabricate(:user)
      Assignment.create!(
        target: topic,
        topic_id: topic.id,
        assigned_to: assignee,
        assigned_by_user: admin,
        active: true,
      )

      card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
          }

      expect(response.status).to eq(200)
      all_assigned = response.parsed_body.dig("card", "topic", "all_assigned_users")
      expect(all_assigned).to be_present
      expect(all_assigned.first["username"]).to eq(assignee.username)
    end

    it "rejects requests from users without write access" do
      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Protected",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(reader)

      put "/kanban/boards/#{board.id}/cards/#{card.id}.json", params: { card: { title: "Hacked" } }

      expect(response.status).to eq(403)
    end
  end

  describe "DELETE /kanban/boards/:board_id/cards/:id" do
    it "destroys a floater card" do
      card =
        board.cards.create!(
          card_type: :floater,
          membership_mode: :manual_in,
          title: "Delete me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      expect { delete "/kanban/boards/#{board.id}/cards/#{card.id}.json" }.to change {
        DiscourseKanban::Card.count
      }.by(-1)

      expect(response.status).to eq(204)
    end

    it "soft-deletes a topic card by marking it manual_out" do
      board.update!(base_filter_query: "category:#{category.slug}")

      card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      expect { delete "/kanban/boards/#{board.id}/cards/#{card.id}.json" }.not_to change {
        DiscourseKanban::Card.count
      }

      expect(response.status).to eq(204)
      expect(card.reload.membership_mode).to eq("manual_out")
    end

    it "excludes soft-deleted topic cards from board display" do
      card =
        board.cards.create!(
          card_type: :topic,
          membership_mode: :manual_in,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)
      delete "/kanban/boards/#{board.id}/cards/#{card.id}.json"

      expect(board.cards.with_column.where(id: card.id)).to be_empty
    end
  end
end
