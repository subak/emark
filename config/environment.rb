require "logger"
require File.expand_path "../application.rb", __FILE__

include Emark

dir = File.expand_path "."
config.root   = dir
config.public = File.join dir, "public"
config.public_blog   = File.join(config.public, "_")
#config.evernote_host = "sandbox.evernote.com"
config.evernote_host = "www.evernote.com"
config.evernote_site = "https://#{config.evernote_host}"
config.evernote_oauth_consumer_key =    "tk84-1998"
config.evernote_oauth_consumer_secret = "df5c4560b5604a97"
config.evernote_user_notes_max =        500
config.cache_host = "everblog.cdn-cache.com"

config.environment = ENV["RACK_ENV"]

case config.environment
when "production"
  config.site_protocol =  "http"
  config.site_host =      "everblog.subak.jp"
  config.site_port =      80
  config.admin_protocol = "https"
  config.admin_host =     "everblog.subak.jp"
  config.admin_port =     443
  config.nginx_conf =     "/home/www/nginx/conf/include/everblog.conf"
  config.logger_level =   Logger::WARN
  config.thread_abort =   false
else
  config.site_protocol =  "http"
  config.site_host =      "localhost"
  config.site_port =      8080
  config.admin_protocol = "https"
  config.admin_host =     "localhost"
  config.admin_port =     4430
  config.nginx_conf =     "/home/www/nginx/conf/include/everblog.conf"
  config.logger_level =   Logger::DEBUG
  config.thread_abort =   true
end

config.site_hostname =  "#{config.site_host}" + case (p = config.site_port) when 443,80,nil then "" else ":#{p}" end
config.site_href =      "#{config.site_protocol}://#{config.site_hostname}"
config.admin_hostname = "#{config.admin_host}" + case (p = config.admin_port) when 443,80,nil then "" else ":#{p}" end
config.admin_href =     "#{config.admin_protocol}://#{config.admin_hostname}"


