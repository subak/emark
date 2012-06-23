#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

dir = File.dirname File.expand_path(__FILE__)
require File.join dir, "publish"
require File.join dir, "blog"
require File.join dir, "entry"
require File.join dir, "meta"

include Emark::Publish

def xrun obj, &block
  df = EM::DefaultDeferrable.new
  df.callback do
    fb = Fiber.current
    EM.add_timer do
      fb.resume
    end
    Fiber.yield

    run obj, &block
  end

  df.errback do
    puts "error"
  end

  Fiber.new do
    begin
      block.call obj, df
    rescue Emark::Publish::Fatal => e
      logger.warn "#{e}"
    rescue Exception => e
      logger.warn e
    end
  end.resume
end

def sleep time=0
  fb = Fiber.current
  EM.add_timer time do
    fb.resume
  end
  Fiber.yield
end

def run q, interval, &block
  q.pop do |obj|
    df = EM::DefaultDeferrable.new
    df.callback do |obj|
      fb = Fiber.current
      EM.add_timer do
        fb.resume
      end
      Fiber.yield

      q.push obj
      2.times do
        run q, interval, &block
      end
    end

    Fiber.new do
      begin
        block.call obj, df
      rescue Emark::Publish::Fatal => e
        logger.warn "#{e}"
      rescue Exception => e
        logger.warn e
      end
    end.resume
  end
end

def queue klass, size, interval=0
  q = EM::Queue.new
  size.times { q.push klass.new }
  block = proc do |obj, df|
    df.errback do |obj|
      sleep 1
      q.push obj
      if size == q.size
        run q, interval, &block
      end
    end
    obj.run.! ? df.fail(obj) : df.succeed(obj)
  end
  run q, interval, &block
end

EM.run do
  # blog_q = EM::Queue.new
  # 1.times do
  #   blog_q.push Blog.new
  # end
  # run blog_q, 0.5 do |obj, df|
  #   obj.run.! ? df.fail(obj) : df.succeed(obj)
  # end

  queue Blog, 1
  queue Entry, 100


  # entry_q = EM::Queue.new
  # 20.times { entry_q.push Entry.new }
  # run entry_q, 0 do |obj, df|
  #   obj.run.! ? df.fail(obj) : df.succeed(obj)
  # end

  # 3.times do
  #   run Blog.new do |obj, df|
  #     obj.run
  #     df.succeed obj
  #   end
  # end
  # run do |df|
  #   fb = Fiber.current
  #   EM.add_timer 0.5 do
  #     puts "in a fiber"
  #     fb.resume
  #   end

  #   Fiber.yield
  #   puts "run stop"

  #   (0 != rand(10)) ? df.succeed : df.fail
  # end


  # 2.times do
  #   puts "start queue"
  #   q.pop do |status|
  #     run q do
  #       fb = Fiber.current
  #       EM.add_timer 0.5 do
  #         puts "in a fiber"
  #         fb.resume
  #       end

  #       Fiber.yield
  #       puts "run stop"
  #     end
  #   end
  #   puts "end queue"
  # end

#  while status = q.pop
    # run q do
    #   puts "run start"
    #   fb = Fiber.current
    #   EM.add_timer 0.5 do
    #     p Thread.current

    #     puts "in a fiber"
    #     fb.resume
    #   end

    #   Fiber.yield
    #   puts "run stop"
    # end

#    p status
#  end

end


__END__

EM.run do
  Fiber.new do
    loop do
      fb = Fiber.current

      EM.add_timer do
        puts "in fiber"
        fb.resume
      end

      puts "in loop"
      Fiber.yield

      puts "end loop"
    end
  end.resume

  p "end"
end


__END__

# config.cpu_core.times do
#   Thread.new do
#     scope
#     EM.run do
#       EM.add_periodic_timer 0.1 do
#         run do
#           Emark::Publish::Blog.run
#         end
#       end

#       EM.add_periodic_timer 0.1 do
#         run do
#           Emark::Publish::Entry.run
#         end
#       end

#       EM.add_periodic_timer 1 do
#         run do
#           Emark::Publish::Meta.run
#         end
#       end
#     end
#   end
# end

EM.run do
  scope
  run do
    delete_expired_queue_blog  0
    delete_expired_queue_entry 0
    delete_expired_queue_meta  0
  end
  EM.add_periodic_timer 300 do
    run do
      delete_expired_queue_blog  300
      delete_expired_queue_entry 300
      delete_expired_queue_meta  300
    end
  end


  # EM.add_periodic_timer 0.1 do
  #   run do
  #     Emark::Publish::Blog.run
  #   end
  # end

  loop do
    run do
      Emark::Publish::Entry.run
    end
  end

  # EM.add_periodic_timer 1 do
  #   run do
  #     Emark::Publish::Meta.run
  #   end
  # end
end
