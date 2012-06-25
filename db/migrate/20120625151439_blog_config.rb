class BlogConfig < ActiveRecord::Migration
  def self.up
    add_column :blog, :paginate,            :integer, :null => false, :default => 10
    add_column :blog, :recent_posts,        :integer, :null => false, :default => 5
    add_column :blog, :excerpt_count,       :integer, :null => false, :default => 3
    add_column :blog, :disqus_short_name,   :text
    add_column :blog, :twitter_user,        :text
    add_column :blog, :twitter_tweet_count, :integer, :default => 4
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
