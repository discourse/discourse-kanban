# frozen_string_literal: true

class DropLabelsFromKanbanCards < ActiveRecord::Migration[7.2]
  def up
    execute "DROP TRIGGER IF EXISTS kanban_labels_to_tags_trigger ON discourse_kanban_cards"
    execute "DROP FUNCTION IF EXISTS mirror_kanban_labels_to_tags()"

    Migration::ColumnDropper.execute_drop(:discourse_kanban_cards, %i[labels])
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
