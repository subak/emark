class RenameTables < ActiveRecord::Migration
  def self.up
    rename_table :entry, :entry_q
    rename_table :meta,  :meta_q
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
