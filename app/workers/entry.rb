# -*- coding: utf-8 -*-

require File.join File.expand_path(__FILE__), "../publish"

module Emark
  module Publish
    module EntryHelper
      class Delete < Exception; end
      class Recover < Exception; end

      def file_dir dirname, guid
        File.join config.root, "files", dirname.to_s, guid.slice(0, 2)
      end

      def link_dir bid
        File.join config.public_blog, bid.slice(0, 2), bid
      end

      def save_link bid, eid, extension, file
        dir = link_dir(bid)
        FileUtils.mkdir_p dir
        link = File.join dir, "#{eid}.#{extension}"

        File.unlink link if File.symlink? link
        File.symlink file, link

        link
      end

      def save_file dirname, guid, extension, content
        dir  = file_dir dirname, guid
        FileUtils.mkdir_p dir
        file = File.join dir, "#{guid}.#{extension}"
        File.open file, "w" do |fp|
          fp.write content
        end

        file
      end

      def dequeue
        select = db.entry_q.project(SqlLiteral.new "*")
        select.where(db.entry_q[:lock].eq 0)
        select.order db.entry_q[:queued].asc
        select.take 1
        sql = select.to_sql; logger.debug sql
        entry = db.get_first_row sql
        return false if entry.!

        update = UpdateManager.new Table.engine
        update.table db.entry_q
        update.where(db.entry_q[:note_guid].eq entry[:note_guid])
        update.where(db.entry_q[:lock].eq 0)
        update.set([
                     [db.entry_q[:lock], 1]
                   ])
        logger.debug update.to_sql
        db.execute update.to_sql
        raise Fatal if db.changes != 1

        entry
      end

      def detect guid, updated
        raise Delete if updated.!

        select = db.sync.project(db.sync[:updated])
        select.where(db.sync[:note_guid].eq guid)
        logger.debug select.to_sql
        update_sync = db.get_first_value select.to_sql

        raise Recover if update_sync and update_sync == updated

        true
      end

      def note guid, authtoken, shard
        noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{shard}")
        noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
        noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

        noteStore.getNote(authtoken, guid, true, false, false, false)
      end

      def markdown note, shard
        title = note.title
        enml  = note.content
        resources = {}

        note.resources.each do |resource|
          # binary form の文字列を16進数の文字列に変換 http://d.hatena.ne.jp/toshifusa1423/20101028/1288244724
          body_hash = resource.data.bodyHash.unpack("H*")[0].to_sym
          resources[body_hash] = {
            :guid     => resource.guid,
            :fileName => resource.attributes.fileName,
          }
        end if note.respond_to?('resources') && note.resources.respond_to?('each')

        doc = Nokogiri::XML enml

        # 画像のみ抽出 するように変更する必要がある
        doc.css('en-media').each do |enMedia|
          bodyHash  = enMedia.attributes['hash'].value
          resource  = resources[bodyHash.to_sym]
          guid      = resource[:guid]

          fileName  = URI.encode(resource[:fileName] || "")

          mime = enMedia.attribute("type").content
          type = mime.sub %r{/[^/]+$}, ''

          case type
          when "image"
            url = "http://#{config.cache_host}/shard/#{shard}/res/#{guid}/#{fileName}"
            enMedia.add_previous_sibling Nokogiri::XML::Text.new("![](#{url})", doc)
          else
            url = "http://#{config.cache_host}/shard/#{shard}/res/#{guid}/#{fileName}"
            enMedia.add_previous_sibling Nokogiri::XML::Text.new("[#{fileName}](#{url})", doc)
          end
        end

        doc.text
      end

      ##
      # jsonを作成
      def entry_json guid, eid, markdown, title, created, updated
        json = {
          eid:      eid,
          title:    title,
          created:  Time.at(created/1000).utc.iso8601,
          updated:  Time.at(updated/1000).utc.iso8601,
          markdown: markdown
        }

        json.to_json
      end

      ##
      # 検索エンジン用のhtml
      def entry_html guid, markdown, title
        rDiscount = RDiscount.new markdown
        haml = <<HAML
!!!
%html
  %head
    %meta{charset: "utf-8"}
    %title= title
  %body
    %h1= title
    = html
HAML

        content = rDiscount.to_html
        content = content.encode("UTF-8", "UTF-8",
                          invalid: :replace,
                          undef: :replace,
                          replace: '.')

        Haml::Engine.new(haml, format: :html5).
          to_html(self,
             title: title,
             html:  content)
      end


      ##
      # syncテーブルを更新
      def update_sync guid, eid, bid, title, created, updated
        data = [
          [db.sync[:note_guid], guid],
          [db.sync[:eid],       eid],
          [db.sync[:bid],       bid],
          [db.sync[:title],     title],
          [db.sync[:created],   created],
          [db.sync[:updated],   updated],
          [db.sync[:deleted],   0]
        ]

        catch :insert do
          begin
            insert = db.sync.insert_manager
            insert.insert data
            db.execute insert.to_sql
          rescue SQLite3::ConstraintException => e
            logger.debug "#{e}"
          else
            throw :insert
          end

          update = UpdateManager.new Table.engine
          update.table db.sync
          update.set data
          db.execute update.to_sql
        end

        true
      end

      ##
      # entry_q を削除
      def delete_queue guid
        delete = DeleteManager.new Table.engine
        delete.from db.entry_q
        delete.where(db.entry_q[:note_guid].eq guid)
        delete.where(db.entry_q[:lock].eq 1)

        db.transaction do
          db.execute delete.to_sql
          raise Fatal if 1 != db.changes
        end

        true
      end

      ##
      # delete
      def delete guid, eid, bid
        file = File.join config.public_blog, bid.slice(0, 2), bid, eid
        json = file + ".json"
        html = file + ".html"

        # errorの可能性
        File.unlink json if File.symlink? json
        File.unlink html if File.symlink? html

        update = UpdateManager.new Table.engine
        update.table db.sync
        update.set([
                     [db.sync[:deleted], 1]
                   ])
        update.where(db.sync[:note_guid].eq guid)
        db.transaction do
          db.execute update.to_sql
          raise Fatal if 1 != db.changes
        end

        true
      end

      ##
      # recover
      def recover guid, eid, bid
        file_dir  = file_dir(:entry, guid)
        json_file = File.join file_dir, "#{guid}.json"
        html_file = File.join file_dir, "#{guid}.html"

        link_dir = link_dir(bid)
        FileUtils.mkdir_p link_dir

        json_link = File.join link_dir, "#{eid}.json"
        html_link = File.join link_dir, "#{eid}.html"

        # errorの可能性
        File.symlink json_file, json_link
        File.symlink html_file, html_link

        update = UpdateManager.new Table.engine
        update.table db.sync
        update.set([
                     [db.sync[:deleted], 0],
                     [db.sync[:bid],     bid]
                   ])
        update.where(db.sync[:note_guid].eq guid)
        db.transaction do
          db.execute update.to_sql
          raise Fatal if 1 != db.changes
        end

        true
      end
    end

    class Entry
      include EntryHelper
      include Common

      def run
        entry = dequeue
        if entry.!
          logger.debug "Entry:empty"
          return false
        end
        guid    = entry[:note_guid]
        bid     = entry[:bid]
        updated = entry[:updated]
        eid     = Subak::Utility.shorten_hash(guid.gsub("-", "")).slice(0, 4)

        begin
          detect guid, updated
        rescue Delete
          delete guid, eid, bid
          delete_queue guid
          logger.info "Entry.delete bid:#{bid}, eid:#{eid}, guid:#{guid}"
          return :delete
        rescue Recover
          logger.info "recover"
          recover guid, eid, bid
          delete_queue guid
          logger.info "Entry.recover bid:#{bid}, eid:#{eid}, guid:#{guid}"
          return :recover
        end

        session   = session(bid)
        authtoken = session[:authtoken]
        shard     = session[:shard]

        note    = thread { note guid, authtoken, shard }
        title   = note.title.force_encoding("UTF-8")
        created = note.created
        updated = note.updated

        markdown = markdown(note, shard)
        json     = entry_json(guid, eid, markdown, title, created, updated)
        html     = entry_html(guid, markdown, title)

        thread do
          save_file :markdown, guid, :markdown, markdown
          json_path = save_file :entry, guid, :json, json
          html_path = save_file :entry, guid, :html, html
          save_link bid, eid, :json, json_path
          save_link bid, eid, :html, html_path
        end

        update_sync guid, eid, bid, title, created, updated
        delete_queue guid

        logger.info "Entry.run bid:#{bid}, eid:#{eid}, guid:#{guid}"

        true
      end
    end
  end
end
