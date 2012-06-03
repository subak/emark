# -*- coding: utf-8; -*-

require "pp"
require "fiber"
require "eventmachine"

module Helpers
  class RunLoop
    def initialize app
      @app = app
    end

    def call(env)
      # logger = Logger.new(STDOUT)
      # logger.level = Logger::DEBUG
      # env["rack.logger"] = logger
      EM.run do
        env["async.callback"] = proc do |result|
          @result = result
          EM.stop
        end
        catch :async do
          @app.call(env) do
            p "hugahoge"
          end
        end
      end
      @result
    end
  end
end
