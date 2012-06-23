#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

dir = File.dirname File.expand_path(__FILE__)
require File.join dir, "publish"
require File.join dir, "blog"
require File.join dir, "entry"
require File.join dir, "meta"

# def run &block
#   Fiber.new do
#     begin
#       block.call
#     rescue Emark::Publish::Fatal => e
#       logger.warn "#{e}"
#     rescue Exception => e
#       logger.warn e
#     end
#   end.resume
# end

include Emark::Publish

def run &block
  df = EM::DefaultDeferrable.new
  df.callback do
    fb = Fiber.current
    EM.add_timer do
      fb.resume
    end
    Fiber.yield

    run &block
  end

  df.errback do
    puts "error"
  end

  Fiber.new do
    begin
      block.call df
    rescue Emark::Publish::Fatal => e
      logger.warn "#{e}"
    rescue Exception => e
      logger.warn e
    end
  end.resume
end


EM.run do
  3.times do
    run do |df|
      (Blog.new).run
      df.succeed
    end
  end
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
