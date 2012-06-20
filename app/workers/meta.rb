# -*- coding: utf-8; -*-

module Emark
  module Publish
    module Meta

      private

      def file_dir bid
        File.join config.root, "files/index", bid.slice(0, 2), bid
      end

      def sym_dir bid
        File.join config.public_blog, bid.slice(0, 2), bid
      end

      def save_file bid, filename, content
        file = File.join file_dir(bid), filename
        sym  = File.join sym_dir(bid), filename

        File.open file, "w" do |fp|
          fp.write content
        end

        File.unlink sym if File.symlink? sym
        File.symlink file, sym

        true
      end

      def dequeue
        select = db.meta_q.project(db.meta_q[:bid])
        select.where(db.meta_q[:lock].eq 0)
        select.order db.meta_q[:queued].asc
        select.take 1
        bid = db.get_first_value select.to_sql
        return :empty => true if bid.!

        select = db.entry_q.project(db.entry_q[:id].count)
        select.where(db.entry_q[:bid].eq bid)
        sql = select.to_sql; logger.debug sql
        count = db.get_first_value(sql)
        if 1 <= count

          # キュー時刻を更新
          update = UpdateManager.new Table.engine
          update.table db.meta_q
          update.set([
                       [db.meta_q[:queued], Time.now.to_f]
                     ])
          update.where(db.meta_q[:bid].eq bid)
          sql = update.to_sql; logger.debug sql

          db.execute sql
          raise Fatal if db.changes != 1

          return :left => true, :bid => bid, :count => count
        end

        update = UpdateManager.new Table.engine
        update.table db.meta_q
        update.set([
                     [db.meta_q[:lock], 1]
                   ])
        update.where(db.meta_q[:bid].eq bid)
        update.where(db.meta_q[:lock].eq 0)
        sql = update.to_sql; logger.debug sql

        db.execute sql
        raise Fatal if db.changes != 1

        return :bid => bid
      end

      def find_blog bid
        select = db.blog.project(SqlLiteral.new "*")
        select.where(db.blog[:bid].eq bid)
        blog = db.get_first_row select.to_sql
        raise Fatal if blog.!

        blog
      end

      def find_entries bid
        select = db.sync.project(SqlLiteral.new "*")
        select.where(db.sync[:bid].eq bid)
        select.where(db.sync[:deleted].eq 0)
        select.order db.sync[:created].desc
        entries = []

        db.execute select.to_sql do |row|
          entries << {
            guid:    row[:guid],
            title:   row[:title],
            created: Time.at(row[:created]/1000).utc.iso8601,
            updated: Time.at(row[:updated]/1000).utc.iso8601,
            eid:     row[:eid],
            bid:     row[:bid]
          }
        end

        entries
      end

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

      def delete_queue bid
        delete = DeleteManager.new Table.engine
        delete.from db.meta_q
        delete.where(db.meta_q[:bid].eq bid)
        delete.where(db.meta_q[:lock].eq 1)
        db.execute delete.to_sql
        raise Fatal if db.changes != 1
        true
      end

      class << self
        include Emark::Publish::Meta

        def run
          res = dequeue
          case
          when res[:empty]
            logger.debug "Emark::Publish::Meta#empty"
            return :empty
          when res[:left]
            logger.info "Emark::Publish::Meta#left bid:#{res[:bid]}, count:#{res[:count]}"
            return :left
          end
          bid = res[:bid]

          blog    = find_blog bid
          entries = find_entries bid

          thread do
            FileUtils.mkdir_p file_dir(bid)
            FileUtils.mkdir_p sym_dir(bid)

            save_file bid, "sitemap.xml", sitemap(entries)
            save_file bid, "atom.xml",    atom(entries, blog)
            save_file bid, "index.html",  index_html(entries, blog)
            save_file bid, "meta.json",   blog.to_json
            save_file bid, "index.json",  entries.to_json

            ##
            # templateファイル
            tpl = File.join config.public, 'emark.jp/octopress/index.html'
            sym = File.join sym_dir(bid),  "template.html"
            File.unlink sym if File.symlink? sym
            File.symlink tpl, sym
          end

          delete_queue bid
        end
      end
    end
  end
end
