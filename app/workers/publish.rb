# -*- coding: utf-8 -*-

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
