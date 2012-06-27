# -*- coding: utf-8 -*-

module Emark
  def connection
    db = SQLite3::Database.new ActiveRecord::Base.configurations[config.environment]["database"]
    db.results_as_hash = true
    db.busy_handler do |resouce, retries|
      fb = Fiber.current
      EM.add_timer do
        logger.info "busy"
        fb.resume true
      end
      Fiber.yield
    end

    def db.session
      @session ||= Table.new(:session)
    end

    def db.blog
      @blog ||= Table.new(:blog)
    end

    def db.blog_q
      @blog_q ||= Table.new(:blog_q)
    end

    def db.sync
      @sync ||= Table.new(:sync)
    end

    db
  end

  def sleep wait
    fb = Fiber.current
    logger.debug "sleep wait:#{wait}"
    EM.add_timer wait do
      fb.resume
    end
    Fiber.yield
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

