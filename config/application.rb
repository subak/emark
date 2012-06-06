require "bundler"
Bundler.require :default

module Emark
  Config = Hashie::Mash.new
  def config
    Config
  end

  def thread &block
    fb = Fiber.current
    EM.
      defer(
      EM.Callback do
              begin
                block.call
              rescue Exception => e
                e
              end
            end,
      EM.Callback { |e| fb.resume e })
    e = Fiber.yield
    raise e if e.kind_of? Exception
    e
  end
end
