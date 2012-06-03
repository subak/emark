class Initialize < ActiveRecord::Migration
  def self.up
    create_table :session
    add_column :session, :user_id,   :integer, :null => false, :default => 0
    add_index  :session, :user_id,   :unique => true
    add_column :session, :notebook_id, :text
    add_column :session, :shard, :text
    add_column :session, :notestore_url, :text
    add_column :session, :authtoken, :text
    add_column :session, :expires, :integer
    add_column :session, :sid, :text
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
