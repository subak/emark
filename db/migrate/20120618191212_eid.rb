class Eid < ActiveRecord::Migration
  def self.up
    add_column :sync, :eid, :text
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
