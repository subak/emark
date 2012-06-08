class Sync < ActiveRecord::Migration
  def self.up
    create_table :sync
    add_column :sync, :note_guid, :text
    add_index  :sync, :note_guid, :unique => true
    add_column :sync, :title,   :text
    add_column :sync, :created, :integer
    add_column :sync, :updated, :integer
    add_column :sync, :deleted, :integer, :null => false, :default => 0
    add_column :sync, :bid,     :textZ
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
