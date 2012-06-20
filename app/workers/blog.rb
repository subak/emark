# -*- coding: utf-8 -*-

require File.join File.expand_path(__FILE__), "../publish"

module Emark
  module Publish
    module Blog

      private

      def dequeue
        select = db.blog_q.project(db.blog_q[:bid])
        select.where(db.blog_q[:lock].eq 0)
        select.order db.blog_q[:queued].asc
        select.take 1
        bid = db.get_first_value select.to_sql
        return nil if bid.!

        update = UpdateManager.new Table.engine
        update.table db.blog_q
        update.set([
                     [db.blog_q[:lock], 1]
                   ])
        update.where(db.blog_q[:bid].eq bid)
        update.where(db.blog_q[:lock].eq 0)
        db.execute update.to_sql
        raise Fatal if db.changes != 1

        bid
      end

      def find_notes authtoken, shard, notebook
        noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{shard}")
        noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
        noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

        # 特定のnotebookのnoteのみ取得
        # 作成日時が新しい順に取得する
        # ノート数の制限が超えた場合古いノートは削除される
        filter = Evernote::EDAM::NoteStore::NoteFilter.new()
        filter.notebookGuid = notebook
        filter.ascending    = false
        filter.order = Evernote::EDAM::Type::NoteSortOrder::CREATED

        # ノートの更新時刻を取得
        resultSpec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new()
        resultSpec.includeTitle   = true
        resultSpec.includeCreated = true
        resultSpec.includeUpdated = true

        noteStore.findNotesMetadata(authtoken, filter, 0, config.evernote_user_notes_max, resultSpec)
      end

      def detect notesMetadataList, bid
        notesA = {}
        select = db.sync.project(db.sync[:note_guid], db.sync[:updated])
        select.where(db.sync[:deleted].eq 0)
        select.where(db.sync[:bid].eq bid)
        db.execute select.to_sql do |row|
          notesA[row[:note_guid]] = row[:updated]
        end

        notesB = {}
        notesMetadataList.notes.each do |note|
          notesB[note.guid] = note.updated
        end

        checkNotesA = []
        notesA.each do |guid, updated|
          checkNotesA << "#{updated} #{guid}"
        end

        checkNotesB = []
        notesB.each do |guid, updated|
          checkNotesB << "#{updated} #{guid}"
        end

        ##
        # Insert or Update が必要なentry
        syncNotes = {}
        (checkNotesB - (checkNotesA & checkNotesB)).each do |check|
          if check =~ /([\d]+) (.*)/
            updated = Regexp.last_match[1]
            guid    = Regexp.last_match[2]
            syncNotes[guid] = updated
          end
        end

        ##
        # 削除スべきnoteをmix
        (notesA.keys - notesB.keys).each do |guid|
          syncNotes[guid] = nil
        end

        syncNotes
      end

      def enqueue_entry bid, sync_notes
        result = 0
        return result if sync_notes.empty?

        # entryテーブルにキューを入れる
        db.transaction do
          sync_notes.each do |guid, updated|
            insert = db.entry_q.insert_manager
            insert.insert([
                            [db.entry_q[:note_guid], guid],
                            [db.entry_q[:updated],   updated],
                            [db.entry_q[:bid],       bid],
                            [db.entry_q[:queued],    Time.now.to_f]
                          ])
            begin
              db.execute insert.to_sql
            rescue SQLite3::ConstraintException => e
              logger.warn "Emark::Publish::Blog.enqueue_entry #{e.class}: #{e.message} #{__FILE__}:#{__LINE__}"
            else
              result += 1
            end
          end
        end

        result
      end

      def enqueue_meta bid, sync_notes
        result = false
        return result if sync_notes.empty?

        # metaテーブルにキューを入れる
        insert = db.meta_q.insert_manager
        insert.insert([
                        [db.meta_q[:bid],    bid],
                        [db.meta_q[:queued], Time.now.to_f]
                      ])
        begin
          db.execute insert.to_sql
        rescue SQLite3::ConstraintException => e
          logger.warn "Emark::Publish::Blog.enqueue_meta #{e.class}: #{e.message} #{__FILE__}:#{__LINE__}"
        else
          result = true
        end

        result
      end

      def delete_queue bid
        delete = DeleteManager.new Table.engine
        delete.from db.blog_q
        delete.where(db.blog_q[:bid].eq  bid)
        delete.where(db.blog_q[:lock].eq 1)
        db.execute delete.to_sql
        raise Fatal if db.changes != 1

        true
      end

      class << self
        include Emark::Publish
        include Emark::Publish::Blog

        def run
          bid = dequeue
          if bid.!
            logger.debug "Blog.run:empty"
            return :empty
          end

          session = session bid

          notes = thread do
            find_notes session[:authtoken], session[:shard], session[:notebook]
          end

          sync_notes = detect notes, bid

          count = enqueue_entry bid, sync_notes
          enqueue_meta  bid, sync_notes

          delete_queue bid

          logger.info "Blog.run bid:#{bid}, count:#{count}"

          true
        end
      end
    end
  end
end
