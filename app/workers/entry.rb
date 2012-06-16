# -*- coding: utf-8 -*-

module Emark
  module Publish
    class Entry
      class Delete < Exception; end
      class Recover < Exception; end

      attr_accessor :entry, :session

      def run
        @entry = nil
      end

      def step_1
        db.transaction do
          select = db.entry_q.project(SqlLiteral.new "*")
          select.where(db.entry_q[:queued].not_eq nil)
          select.order db.entry_q[:queued].asc
          select.take 1
          logger.debug select.to_sql
          @entry = db.get_first_row select.to_sql
          raise Empty if @entry.!

          update = UpdateManager.new Table.engine
          update.table db.entry_q
          update.where(db.entry_q[:note_guid].eq @entry[:note_guid])
          update.set([
                          [db.entry_q[:queued], nil]
                        ])
          logger.debug update.to_sql
          db.execute update.to_sql
          raise Fatal if db.changes != 1
        end

        @entry
      end

      def step_2
        raise Delete if @entry[:updated].!

        select = db.sync.project(db.sync[:updated])
        select.where(db.sync[:note_guid].eq @entry[:note_guid])
        logger.debug select.to_sql
        update_sync = db.get_first_value select.to_sql

        raise Recover if update_sync and update_sync == @entry[:updated]

        @entry[:bid]
      end

      def step_3
        select = db.session.project(db.session[:authtoken], db.session[:shard], db.blog[:notebook])
        select.join(db.blog).on(db.session[:uid].eq db.blog[:uid])
        select.where(db.blog[:bid].eq @entry[:bid])
        select.take 1

        logger.debug select.to_sql
        session = db.get_first_row select.to_sql
        raise Fatal if session.!
        session
      end

      def step_4 guid, authtoken, shard, notebook
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
    end
  end
end
