# frozen_string_literal: true
class KeepPublicKanbanBoardsPublic < ActiveRecord::Migration[8.0]
  def up
    # Boards previously treated an empty read-group list as "public". Visibility
    # is now a strict allowlist, so preserve that public visibility by granting
    # the anonymous (4 = logged-out visitors) and trust_level_0 (10 = all
    # logged-in members) auto-groups read access.
    execute <<~SQL
      UPDATE discourse_kanban_boards
      SET allow_read_group_ids = ARRAY[4, 10]::integer[]
      WHERE allow_read_group_ids IS NULL OR allow_read_group_ids = '{}'::integer[]
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
