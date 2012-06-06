class QueueTables < ActiveRecord::Migration
  def self.up
    create_table :entry
    add_column :entry, :note_guid, :text
    add_index  :entry, :note_guid, :unique => true
    add_column :entry, :updated,   :integer
    add_column :entry, :bid,       :text
    add_column :entry, :queued,    :float

    create_table :meta
    add_column :meta, :bid,    :text
    add_index  :meta, :bid,    :unique => true
    add_column :meta, :queued, :float
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
