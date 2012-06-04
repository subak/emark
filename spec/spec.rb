# -*- coding: utf-8; -*-

require "simplecov"
SimpleCov.start do
  add_filter "vender/bundle/"
  add_filter "lib/Evernote/"
end

require "./spec/token_spec"
require "./spec/open_spec"
