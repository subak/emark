require "bundler"
Bundler.require :default

module Emark
  Config = Hashie::Mash.new
  def config
    Config
  end
end
