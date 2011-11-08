# From ruby-git
# Add the directory containing this file to the start of the load path if it
# # isn't there already.
$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cgi'
require 'yaml'
require 'fileutils'

require 'rest_client'
require 'json'
require 'git'
require 'zipruby'

require 'bob_the_builder/bob'
require 'bob_the_builder/git_hub_uploader'

require 'orderedhash' if RUBY_VERSION < '1.9'

module BobTheBuilder
end
