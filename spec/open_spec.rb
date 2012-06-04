# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::DEBUG
require "./spec/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

describe "ノートブック公開" do
  it "Cookieにsidがないときは403" do
    get admin_url("/open")
    last_response.forbidden?.should be_true
  end

  describe "Cookieにsidをセット" do
    before:all do
      select = db.session.project(SqlLiteral.new "*")
      select.where(db.session[:user_id].eq 25512727)
      @session = db.get_first_row select.to_sql
      raise "session error" if @session.!
    end

    it "ノートブックのリストを取得" do
      get(admin_url("/open"), {}, {
            "HTTP_COOKIE" => "sid=#{@session[:sid]}"
          })

      json = JSON.parse(last_response.body)
      json["notebooks"].should be_true

      logger.debug last_response.body
    end

    describe "ノートブックの制限" do
      before:all do
        noteStoreTransport = Thrift::HTTPClientTransport.new("#{config.evernote_site}/edam/note/#{@session[:shard]}")
        noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
        @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

        # ノートブックの共有をやめる
        @guids = []
        notebooks = @noteStore.listNotebooks(@session[:authtoken])
        notebooks.each do |notebook|
          @guids << notebook.guid
          logger.debug notebook
          begin
            publishing = Evernote::EDAM::Type::Publishing.
              new(:uri => "hugahoge")
            newbook = Evernote::EDAM::Type::Notebook.
              new(
              :guid       => notebook.guid,
              :name       => notebook.name,
              :publishing => publishing,
              :published  => false)
            @noteStore.updateNotebook @session[:authtoken], newbook
          rescue Exception => e
            pp e
          end
        end

        # 公開ブログを削除
        delete = DeleteManager.new Table.engine
        delete.from db.blog
        delete.where(db.blog[:user_id].eq @session[:user_id])
        db.execute delete.to_sql
      end

      it "共有されないノートは選択できない" do
        get(admin_url("/open"), {}, {
              "HTTP_COOKIE" => "sid=#{@session[:sid]}"
            })
        json = JSON.parse(last_response.body)

        availables = json["notebooks"].select do |notebook|
          notebook["available"]
        end
        availables.size.should == 0
      end

      describe "共有ノート" do
        before:all do
          @guids.each do |guid|
            begin
              newbook = Evernote::EDAM::Type::Notebook.
                new(
                :guid      => guid,
                :name      => Digest::MD5.new.update(Time.now.to_f.to_s).to_s,
                :published => true)
              @noteStore.updateNotebook @session[:authtoken], newbook
            rescue Exception => e
              pp e
            end
          end

          get(admin_url("/open"), {}, {
                "HTTP_COOKIE" => "sid=#{@session[:sid]}"
              })
        end

        it "利用可能" do
          json = JSON.parse(last_response.body)
          availables = json["notebooks"].select do |notebook|
            notebook["available"]
          end
          availables.size.should >= 1
        end

        it "セッションにノートブックを持つ" do
          session = Rack::Session::Cookie::Base64::Marshal.new.decode rack_mock_session.cookie_jar["rack.session"]
          notebooks = session["notebooks"]
          notebooks.each do |key, value|
            @guids.include?(key).should be_true
          end
        end
      end

      describe "すでに公開されているブログ" do
        before:all do
          @guids.each do |guid|
            insert = db.blog.insert_manager
            insert.insert [
                   [db.blog[:user_id], @session[:user_id]],
                   [db.blog[:blog_id], Digest::MD5.new.update(Time.now.to_f.to_s).to_s],
                   [db.blog[:notebook], guid]]
            db.execute insert.to_sql
          end

          get(admin_url("/open"), {}, {
                "HTTP_COOKIE" => "sid=#{@session[:sid]}"
              })
        end

        it "選択できない" do
          json = JSON.parse(last_response.body)

          availables = json["notebooks"].select do |notebook|
            notebook["available"]
          end

          availables.size.should == 0
        end
      end

    end
  end
end

