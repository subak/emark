class Lock < ActiveRecord::Migration
  def self.up
  	add_column :meta_q, :lock, :integer, :default => 0, :null => false
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
