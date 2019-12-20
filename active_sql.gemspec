# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path("../lib", __FILE__)

require "active_sql/version"

Gem::Specification.new do |s|
  s.name        = "active_sql"
  s.version     = ActiveSql::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Christian Eichhorn"]
  s.email       = ["c.eichhorn@webmasters.de"]
  s.homepage    = ""
  s.summary     = "Write sql in ruby syntax"
  s.description = "Write sql in ruby syntax"

  s.files         = Dir.glob(File.expand_path("../**/*", __FILE__)).select {|f| File.file?(f) }.collect {|f| f.gsub(File.expand_path("../", __FILE__) + '/', '') }
  s.test_files    = []
  s.executables   = []
  s.require_paths = ["lib"]
  
  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rails>, [">= 0"])
      s.add_runtime_dependency(%q<activerecord>, [">= 0"])
    else
      s.add_dependency(%q<rails>, [">= 0"])
      s.add_dependency(%q<activerecord>, [">= 0"])
    end
  else
    s.add_dependency(%q<rails>, [">= 0"])
    s.add_dependency(%q<activerecord>, [">= 0"])
  end
end
