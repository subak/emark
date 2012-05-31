# -*- coding: utf-8; -*-

require "pp"
require "fiber"
require "eventmachine"

module Helpers
  class MyMiddle
    class << self
      attr_accessor :fb, :result, :block
    end

    def initialize app
      @app = app
    end

    def call(env)
      env["async.callback"] = proc do |result|
        MyMiddle.fb.resume result
      end
      @app.call(env)
    end
  end

  def task &block
    MyMiddle.block = block

    EM.run do
      Fiber.new do
        MyMiddle.fb = Fiber.current

        EM.next_tick do
          MyMiddle.block.call
        end

        MyMiddle.result = Fiber.yield
        EM.stop
      end.resume
    end

    MyMiddle.result
  end
end
