require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + "/factories")
require File.expand_path(File.dirname(__FILE__) + "/shoulda_macros")
require File.expand_path(File.dirname(__FILE__) + "/test_tables")

Dir.glob(File.expand_path(File.dirname(__FILE__) + "/models/*.rb")).sort.each do |file|
  require file.gsub(".rb", "")
end

module ActiveSqlTestCase

  def self.included(base)
    base.class_eval do
      extend ShouldaMacros
      extend TestTables

      create_tables
    end
  end
end

class ActiveSupport::TestCase
  include ActiveSqlTestCase
end
