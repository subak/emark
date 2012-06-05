class Publish < ActiveRecord::Migration
  def self.up
  	create_table :blog_q
  	add_column :blog_q, :bid, :text
  	add_index  :blog_q, :bid, :unique => true
  	add_column :blog_q, :queued, :float
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
