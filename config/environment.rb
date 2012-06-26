require "logger"
require File.expand_path "../application.rb", __FILE__

include Emark

dir = File.expand_path "."
config.root   =        dir
config.public =        File.join dir, "public"
config.public_blog =   File.join(config.public, "_")
config.cache_host =    "en.cdn-cache.com"
config.evernote_host = "www.evernote.com" # "sandbox.evernote.com"
config.evernote_site = "https://#{config.evernote_host}"
config.evernote_oauth_consumer_key =    "tk84-1998"
config.evernote_oauth_consumer_secret = "df5c4560b5604a97"
config.evernote_user_notes_max =        500

config.environment =      ENV["RACK_ENV"]
case config.environment
when "production"
  config.site_protocol =  "http"
  config.site_host =      "emark.jp"
  config.site_port =      80
  config.admin_protocol = "https"
  config.admin_host =     "emark.jp"
  config.admin_port =     443
  config.cdn_host =       "emark.cdn-cache.com"
  config.cdn_port =       80
  config.nginx_conf =     "/home/www/nginx/conf/include/emark.conf"
  config.logger_level =   Logger::WARN
  config.thread_abort =   false
  config.cpu_core =       3
else
  config.site_protocol =  "http"
  config.site_host =      "localhost"
  config.site_port =      8080
  config.admin_protocol = "https"
  config.admin_host =     "localhost"
  config.admin_port =     4430
  config.cdn_host =       "emark.cdn.localhost"
  config.cdn_port =       8080
  config.nginx_conf =     "/Volumes/Data/Users/hiro/Dev/nginx/conf/include/emark.conf"
  config.logger_level =   Logger::INFO
  config.thread_abort =   true
  config.cpu_core =       1
end

config.site_hostname =  "#{config.site_host}" + case (p = config.site_port) when 443,80,nil then "" else ":#{p}" end
config.site_href =      "#{config.site_protocol}://#{config.site_hostname}"
config.admin_hostname = "#{config.admin_host}" + case (p = config.admin_port) when 443,80,nil then "" else ":#{p}" end
config.admin_href =     "#{config.admin_protocol}://#{config.admin_hostname}"
config.cdn_hostname =   "#{config.cdn_host}" + case (p = config.cdn_port) when 443,80,nil then "" else ":#{p}" end
config.cdn_href =       "http://#{config.cdn_hostname}/#{Time.now.strftime("%Y%m%d%H%M%S")}"
