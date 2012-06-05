class RenameBid < ActiveRecord::Migration
  def self.up
    rename_column :session, :user_id, :uid
    remove_column :session, :notebook_id
    remove_column :session, :notestore_url
    rename_column :blog, :user_id, :uid
    rename_column :blog, :blog_id, :bid
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
