class Blog < ActiveRecord::Migration
  def self.up
  	create_table :blog
  	add_column :blog, :blog_id, :text, :null => false, :default => ''
	add_index  :blog, :blog_id, :unique => true
	add_column :blog, :user_id, :integer, :null => false, :default => 0
	add_column :blog, :notebook, :text
	add_column :blog, :title, :text
	add_column :blog, :subtitle, :text
	add_column :blog, :author, :text
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
