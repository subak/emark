# -*- coding: utf-8; -*-

require "./app/sinatra"
config.environment  = :spec
config.logger_level = Logger::INFO
require "./spec/spec_helper.rb"

RSpec.configure do
  include Helpers
  include Rack::Test::Methods
end

describe "sync" do
  before:all do
    sync do
      delete_blog
    end
  end

  it "hoge" do
    sync do
      put "/config/test.example.com"
      last_response.forbidden?.should be_true
    end
  end
end
