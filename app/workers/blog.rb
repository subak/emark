# -*- coding: utf-8 -*-

module Emark
  module Publish
    class Empty < Exception; end
    class Fatal < Exception; end

    class Blog
      attr_accessor :db, :logger

      def initialize db, logger
        @db     = db
        @logger = logger
      end

      def run

      end

      def step_1
        bid = nil
        db.transaction do
          select = db.blog_q.project(db.blog_q[:bid])
          select.order db.blog_q[:queued].asc
          select.take 1
          bid = db.get_first_value select.to_sql
          raise Empty if bid.!

          delete = DeleteManager.new Table.engine
          delete.from db.blog_q
          delete.where(db.blog_q[:bid].eq bid)
          db.execute delete.to_sql
          raise Fatal if (db.changes >= 1).!
        end
        bid
      end

      def step_2 bid
        select = db.session.project(db.session[:authtoken], db.blog[:notebook])
        select.join(db.blog).on(db.session[:user_id].eq db.blog[:user_id])
        select.where(db.blog[:blog_id].eq bid)
        select.take 1

        row = db.get_first_row select.to_sql
        raise Fatal if row.!
        row
      end

    end
  end
end

