# frozen_string_literal: true

class AddTagsToKanbanCards < ActiveRecord::Migration[7.2]
  def up
    add_column :discourse_kanban_cards, :tags, :text, array: true, null: false, default: []

    execute <<~SQL
      UPDATE discourse_kanban_cards SET tags = labels
    SQL

    # Mirror future writes from labels → tags so pre-deploy code doesn't lose data.
    # Only fires when labels is explicitly changed (old code path), not on
    # every update — otherwise writes to tags get overwritten.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION mirror_kanban_labels_to_tags() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'INSERT' OR NEW.labels IS DISTINCT FROM OLD.labels THEN
          NEW.tags := NEW.labels;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER kanban_labels_to_tags_trigger
        BEFORE INSERT OR UPDATE ON discourse_kanban_cards
        FOR EACH ROW
        EXECUTE FUNCTION mirror_kanban_labels_to_tags();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS kanban_labels_to_tags_trigger ON discourse_kanban_cards"
    execute "DROP FUNCTION IF EXISTS mirror_kanban_labels_to_tags()"
    remove_column :discourse_kanban_cards, :tags
  end
end
