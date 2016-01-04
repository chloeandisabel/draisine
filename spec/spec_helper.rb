require "bundler/setup"

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "rspec/collection_matchers"
require "draisine"
require "salesforce_stubs"
