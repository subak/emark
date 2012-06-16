# -*- coding: utf-8 -*-

module Emark
  module Publish
    class Blog
      attr_accessor :db, :logger, :bid

      def initialize db, logger
        @db     = db
        @logger = logger
      end

      def run
        @bid  = step_1
        row   = step_2 @bid
        notes = thread do
          step_3 row[:authtoken], row[:shard], row[:notebook]
        end

        sync_notes = step_4 notes

        enqueues = step_5 sync_notes
        step_6 sync_notes


        @logger.info "Emark::Publish::Blog => #{enqueues} entries enqueued."

        @bid  = nil
        enqueues
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
        select = db.session.project(db.session[:authtoken], db.session[:shard], db.blog[:notebook])
        select.join(db.blog).on(db.session[:uid].eq db.blog[:uid])
        select.where(db.blog[:bid].eq bid)
        select.take 1

        row = db.get_first_row select.to_sql
        raise Fatal if row.!
        row
      end

      def step_3 authtoken, shard, notebook
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

      # 同期すべきnoteの検出
      def step_4 notesMetadataList
        notesA = {}
        select = db.sync.project(db.sync[:note_guid], db.sync[:updated])
        select.where(db.sync[:deleted].eq 0)
        select.where(db.sync[:bid].eq @bid)
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

      ##
      # キューを入れる
      def step_5 sync_notes
        result = 0
        return result if sync_notes.empty?

        # entryテーブルにキューを入れる
        db.transaction do
          sync_notes.each do |guid, updated|
            insert = db.entry_q.insert_manager
            insert.insert([
                            [db.entry_q[:note_guid], guid],
                            [db.entry_q[:updated],   updated],
                            [db.entry_q[:bid],       @bid],
                            [db.entry_q[:queued],    Time.now.to_f]
                          ])
            begin
              db.execute insert.to_sql
            rescue SQLite3::ConstraintException => e
              logger.warn "#{e.class}: #{e.message} #{__FILE__}:#{__LINE__}"
            else
              result += 1
            end
          end
        end

        result
      end

      def step_6 sync_notes
        result = false
        return result if sync_notes.empty?

        # metaテーブルにキューを入れる
        insert = db.meta_q.insert_manager
        insert.insert([
                        [db.meta_q[:bid],    @bid],
                        [db.meta_q[:queued], Time.now.to_f]
                      ])
        begin
          db.execute insert.to_sql
        rescue SQLite3::ConstraintException => e
          logger.warn "#{e.class}: #{e.message} #{__FILE__}:#{__LINE__}"
        else
          result = true
        end

        result
      end

    end
  end
end

