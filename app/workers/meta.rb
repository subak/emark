# -*- coding: utf-8; -*-

module Emark
  module Publish
    class Meta
      class Empty < Exception; end
      class Left < Exception; end

      module Helper
        def sitemap entries
          haml = <<'HAML'
!!! XML
%urlset{xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9"}
- entries.each do |entry|
  %url
    %loc=     "http://#{entry[:bid]}/#{entry[:eid]}"
    %lastmod= entry[:created]
HAML

          Haml::Engine.new(haml).render(self, entries: entries)
        end

        def atom entries, blog
          haml = <<'HAML'
!!! XML
%feed{xmlns: "http://www.w3.org/2005/Atom"}
  %title
    :cdata
      #{blog[:title]}
  %subtitle
    :cdata
      #{blog[:subtitle]}
  %link{href: "http://#{blog[:bid]}/atom.xml", rel: "self"}
  %link{href: "http://#{blog[:bid]}/"}
  %updated= Time.now.utc.iso8601
  %id= "http://#{blog[:bid]}/"
  %author
    %name
      :cdata
        #{blog[:author]}
  %generator{uri: "http://emark.jp/", version: 0.1} Emark
  - entries.each do |entry|
    - uri = "http://#{entry[:bid]}/#{entry[:eid]}"
    %entry
      %title
        :cdata
          #{entry[:title]}
      %link{href: uri}
      %updated= entry[:updated]
      %id= uri
HAML

          Haml::Engine.new(haml).
            render(self,
            entries: entries,
            blog:    blog)
        end

        def index_html entries, blog
          haml = <<'HAML'
!!!
%html
  %head
    %meta{charset: "utf-8"}
    %meta{name: "description", content: blog[:subtitle]}
    %meta{name: "author",      content: blog[:author]}
    %title{title:  blog[:title]}
  %body
    %header
      %hgroup
        %h1= blog[:title]
        %h2= blog[:subtitle]
    - entries.each do |entry|
      %article
        %h1= entry[:title]
HAML

          Haml::Engine.new(haml, :format => :html5).
            render(self, entries: entries, blog: blog)
        end
      end
      include Helper

      def step_1
        bid = nil

        catch :left do
          db.transaction do
            select = db.meta_q.project(db.meta_q[:id], db.meta_q[:bid])
            select.where(db.meta_q[:queued].not_eq nil)
            select.order db.meta_q[:queued].asc
            select.take 1
            meta = db.get_first_row select.to_sql
            raise Empty if meta.!

            select = db.entry_q.project(db.entry_q[:id])
            select.where(db.entry_q[:bid].eq meta[:bid])
            select.take 1
            sql = select.to_sql; logger.debug sql
            if db.get_first_value(sql)

              # キュー時刻を更新
              update = UpdateManager.new Table.engine
              update.table db.meta_q
              update.set([
                           [db.meta_q[:queued], Time.now.to_f]
                         ])
              update.where(db.meta_q[:bid].eq meta[:bid])
              sql = update.to_sql; logger.debug sql

              db.execute sql
              raise Fatal if db.changes != 1

              throw :left
            end

            update = UpdateManager.new Table.engine
            update.table db.meta_q
            update.set([
                         [db.meta_q[:queued], Time.now.to_f]
                       ])
            update.where(db.meta_q[:bid].eq meta[:bid])
            sql = update.to_sql; logger.debug sql

            db.execute sql
            raise Fatal if db.changes != 1

            # delete = DeleteManager.new Table.engine
            # delete.from db.meta_q
            # delete.where(db.meta_q[:id].eq meta[:id])
            # db.execute delete.to_sql
            # raise Fatal if db.changes != 1

            bid = meta[:bid]
          end
        end
        raise Left if bid.!

        bid
      end

      def step_2 bid
        select = db.blog.project(SqlLiteral.new "*")
        select.where(db.blog[:bid].eq bid)
        blog = db.get_first_row select.to_sql
        raise Fatal if blog.!

        blog
      end

      def step_3 bid
        select = db.sync.project(SqlLiteral.new "*")
        select.where(db.sync[:bid].eq bid)
        select.where(db.sync[:deleted].eq 0)
        select.order db.sync[:created].desc
        entries = []

        db.execute select.to_sql do |row|
          entries << {
            guid:    row[:guid],
            title:   row[:title],
            created: Time.at(row[:created/1000]).utc.iso8601,
            updated: Time.at(row[:updated/1000]).utc.iso8601,
            eid:     row[:eid],
            bid:     row[:bid]
          }
        end

        entries
      end

      ##
      # sitemap.xml
      def step_4 entries
        haml = <<'HAML'
!!! XML
%urlset{xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9"}
- entries.each do |entry|
  %url
    %loc=     "http://#{entry[:bid]}/#{entry[:eid]}"
    %lastmod= entry[:created]
HAML

        Haml::Engine.new(haml).render(self, entries: entries)
      end

      ##
      # atom
      def step_5 entries, blog
        haml = <<'HAML'
!!! XML
%feed{xmlns: "http://www.w3.org/2005/Atom"}
  %title
    :cdata
      #{blog[:title]}
  %subtitle
    :cdata
      #{blog[:subtitle]}
  %link{href: "http://#{blog[:bid]}/atom.xml", rel: "self"}
  %link{href: "http://#{blog[:bid]}/"}
  %updated= Time.now.utc.iso8601
  %id= "http://#{blog[:bid]}/"
  %author
    %name
      :cdata
        #{blog[:author]}
  %generator{uri: "http://emark.jp/", version: 0.1} Emark
  - entries.each do |entry|
    - uri = "http://#{entry[:bid]}/#{entry[:eid]}"
    %entry
      %title
        :cdata
          #{entry[:title]}
      %link{href: uri}
      %updated= entry[:updated]
      %id= uri
HAML

        Haml::Engine.new(haml).
          render(self,
          entries: entries,
          blog:    blog)
      end

      ##
      # meta.json
      def step_6 blog
        blog.to_json
      end

      ##
      # index.json
      def step_7 entries
        entries.to_json
      end

      ##
      # index.html
      def step_8 entries, blog
        haml = <<'HAML'
!!!
%html
  %head
    %meta{charset: "utf-8"}
    %meta{name: "description", content: blog[:subtitle]}
    %meta{name: "author",      content: blog[:author]}
    %title{title:  blog[:title]}
  %body
    %header
      %hgroup
        %h1= blog[:title]
        %h2= blog[:subtitle]
    - entries.each do |entry|
      %article
        %h1= entry[:title]
HAML

        Haml::Engine.new(haml, :format => :html5).
          render(self, entries: entries, blog: blog)
      end

      def step_9

      end

    end
  end
end
