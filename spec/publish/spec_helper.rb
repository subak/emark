# -*- coding: utf-8; -*-

require "ruby-debug"
Debugger.start

module Helper
  class Common
    include Emark::Publish::Common

    def self.db
      @instance ||= self.new
      @instance.db
    end
  end

  def db
    Helper::Common.db
  end

  def logger
    @logger ||= Logger.new(STDOUT){@level = config.logger_level}
  end

  def sync &block
    EM.run do
      fb = Fiber.new do
        block.call
      end
      fb.resume

      EM.add_periodic_timer do
        EM.stop if fb.alive?.!
      end
    end
  end

  def get_session
    select = db.session.project(SqlLiteral.new "*")
    select.where(db.session[:uid].eq 25512727)
    @session = db.get_first_row select.to_sql
    raise "session error" if @session.!
    @http_cookie = "sid=#{@session[:sid]}"
  end

  def delete_blog
    pp db.closed?


    delete = DeleteManager.new Table.engine
    delete.from db.blog
    db.execute delete.to_sql
  end

  def delete_blog_q
    delete = DeleteManager.new Table.engine
    delete.from db.blog_q
    db.execute delete.to_sql
  end

  def delete_entry_q
    delete = DeleteManager.new Table.engine
    delete.from db.entry_q
    db.execute delete.to_sql
  end

  def delete_meta_q
    delete = DeleteManager.new Table.engine
    delete.from db.meta_q
    db.execute delete.to_sql
  end

  def delete_sync
    delete = DeleteManager.new Table.engine
    delete.from db.sync
    db.execute delete.to_sql
  end

  def get_real_guid authtoken, shard
    noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{shard}")
    noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
    noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    notes = noteStore.findNotes authtoken, filter, 0, 1
    notes.notes[0].guid
  end

  def notebook_guid authtoken, shard
    noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{shard}")
    noteStoreProtocol =  Thrift::BinaryProtocol.new(noteStoreTransport)
    noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    notebooks = noteStore.listNotebooks(authtoken)

    notebooks.first.guid
  end
end
