# -*- coding: utf-8 -*-

require "fiber"
require "pp"
require "logger"
require "yaml"
require "digest"
require "bundler"
Bundler.require :default, :publish

require "./config/environment"

include Emark
$: << "./lib/Evernote/EDAM"
require 'note_store'
require 'limits_constants'
require "user_store"
require "user_store_constants.rb"
require "errors_types.rb"

require "subak/utility"

require "./lib/override/sqlite3"


module Emark
  module Publish
    private
    def session bid
      select = db.session.project(SqlLiteral.new "*")
      select.join(db.blog).on(db.session[:uid].eq db.blog[:uid])
      select.where(db.blog[:bid].eq bid)
      select.take 1

      sql = select.to_sql; logger.debug sql
      session = db.get_first_row sql
      raise Fatal if session.!
      session
    end
  end
end
