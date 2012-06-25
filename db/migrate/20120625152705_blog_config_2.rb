class BlogConfig2 < ActiveRecord::Migration
  def self.up
    add_column :blog, :about_me, :text
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
