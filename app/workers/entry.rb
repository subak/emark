# -*- coding: utf-8 -*-

module Emark
  module Publish
    class Entry
      class Delete < Exception; end
      class Recover < Exception; end

      module Helper
        def alias_path bid, eid, extension
          file = File.join(config.public_blog, bid.slice(0, 2), bid, eid)
          "#{file}.#{extension}"
        end

        def save_file_path dirname, note_guid, extension
          dirname   = dirname.to_s
          extension = extension.to_s
          dir  = File.join config.root, "files", dirname, note_guid.slice(0,2)
          file_name = note_guid + "." + extension

          File.join(dir, file_name)
        end

        def save_file dirname, note_guid, extension, content
          file = save_file_path dirname, note_guid, extension
          FileUtils.mkdir_p File.dirname(file)
          File.open file, "w" do |fp|
            fp.write content
          end
          content
        end
      end
      include Helper

      def run
        # step_1
        entry =
          begin
            step_1
          rescue Empty
            logger.debug "Emark::Publish::Entry Empty"
            return :empty
          end
        guid    = entry[:note_guid]
        bid     = entry[:bid]
        updated = entry[:updated]

        # step_2
        begin
          step_2 guid, updated
        rescue Delete
          step_2_1 guid, eid, bid
          logger.info "Emark::Publish::Entry#delete bid:#{bid}, eid:#{eid}, guid:#{guid}"
          return :delete
        rescue Recover
          step_2_2 guid, eid, bid
          logger.info "Emark::Publish::Entry#recover bid:#{bid}, eid:#{eid}, guid:#{guid}"
          return :recover
        end

        # step_3
        session   = step_3(bid)
        authtoken = session[:authtoken]
        shard     = session[:shard]

        # step_4
        note = step_4 guid, authtoken, shard
        title   = note.title
        created = note.created
        updated = note.updated

        # step_5
        markdown = step_5 note, shard

        # step_6
        step_6 guid, markdown

        # step_7
        eid = Subak::Utility.shorten_hash guid.gsub("-", "").slice(0, 4)
        step_7 guid, eid, markdown, title, created, updated

        # step_8
        step_8 guid, markdown, title

        # step_9
        step_9 guid, eid, bid

        # step_10
        step_10 guid, eid, bid, title, created, updated

        # step_11
        step_11 guid

        logger.info "Emark::Publish::Entry#run bid:#{bid}, eid:#{eid}, guid:#{guid}"
        true
      end

      def step_1
        entry = nil

        db.transaction do
          select = db.entry_q.project(SqlLiteral.new "*")
          select.where(db.entry_q[:queued].not_eq nil)
          select.order db.entry_q[:queued].asc
          select.take 1
          logger.debug select.to_sql
          entry = db.get_first_row select.to_sql
          raise Empty if entry.!

          update = UpdateManager.new Table.engine
          update.table db.entry_q
          update.where(db.entry_q[:note_guid].eq entry[:note_guid])
          update.set([
                          [db.entry_q[:queued], nil]
                        ])
          logger.debug update.to_sql
          db.execute update.to_sql
          raise Fatal if db.changes != 1
        end

        entry
      end

      def step_2 guid, updated
        raise Delete if updated.!

        select = db.sync.project(db.sync[:updated])
        select.where(db.sync[:note_guid].eq guid)
        logger.debug select.to_sql
        update_sync = db.get_first_value select.to_sql

        raise Recover if update_sync and update_sync == updated

        true
      end

      # delete
      def step_2_1 guid, eid, bid
        file = File.join config.public_blog, bid.slice(0, 2), bid, eid
        json = file + ".json"
        html = file + ".html"

        # errorの可能性
        File.unlink json
        File.unlink html

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

      # recover
      def step_2_2 guid, eid, bid
        org_json = save_file_path :entry, guid, :json
        org_html = save_file_path :entry, guid, :html

        ali_json = alias_path bid, eid, :json
        ali_html = alias_path bid, eid, :html

        FileUtils.mkdir_p File.dirname(ali_json)

        # errorの可能性
        File.symlink org_json, ali_json
        File.symlink org_html, ali_html

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

      def step_3 bid
        select = db.session.project(db.session[:authtoken], db.session[:shard])
        select.join(db.blog).on(db.session[:uid].eq db.blog[:uid])
        select.where(db.blog[:bid].eq bid)
        select.take 1

        logger.debug select.to_sql
        session = db.get_first_row select.to_sql
        raise Fatal if session.!
        session
      end

      def step_4 guid, authtoken, shard
        noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{shard}")
        noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
        noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

        noteStore.getNote(authtoken, guid, true, false, false, false)
      end

      def step_5 note, shard
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
      # markdownをディスクへ書き出し
      def step_6 guid, markdown
        save_file :markdown, guid, :markdown, markdown
      end

      ##
      # jsonを作成
      def step_7 guid, eid, markdown, title, created, updated
        json = {
          eid:      eid,
          title:    title,
          created:  Time.at(created/1000).utc.iso8601,
          updated:  Time.at(updated/1000).utc.iso8601,
          markdown: markdown
        }

        save_file :entry, guid, :json, json.to_json
      end

      ##
      # 検索エンジン用のhtml
      def step_8 guid, markdown, title
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

        html = Haml::Engine.new(haml, format: :html5).
          to_html(self,
             title: title,
             html:  rDiscount.to_html)
        save_file(:entry, guid, :html, html)
      end

      ##
      # エイリアスの作成
      def step_9 guid, eid, bid
        old = File.dirname save_file_path(:entry, guid, :dummy)
        new = File.join config.public_blog, bid.slice(0, 2), bid, eid
        FileUtils.mkdir_p File.dirname(new)
        File.symlink "#{old}.json", "#{new}.json" if File.symlink?("#{new}.json").!
        File.symlink "#{old}.html", "#{new}.html" if File.symlink?("#{new}.html").!
        true
      end

      # step 10
      # syncテーブルを更新
      def step_10 guid, eid, bid, title, created, updated
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
          rescue SQLite3::ConstraintException
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

      # step 11
      # entry_q を削除
      def step_11 guid
        delete = DeleteManager.new Table.engine
        delete.from db.entry_q
        delete.where(db.entry_q[:note_guid].eq guid)
        delete.where(db.entry_q[:queued].eq    nil)

        db.transaction do
          db.execute delete.to_sql
          raise Fatal if 1 != db.changes
        end

        true
      end
    end
  end
end
