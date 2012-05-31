# -*- coding: utf-8; -*-

require "./spec/helpers/helper"
require "./app/sinatra"

RSpec.configure do |c|
  c.include Helpers
end

describe 'get("/")は' do
  pp Sinatra::Application.new

  it "helloを返す" do
    result = task do
      catch :async do
        Rack::MockRequest.new(Helpers::MyMiddle.new(Sinatra::Application)).get("/")
      end
    end
    result[2][0].should == "hoge"
  end
end
