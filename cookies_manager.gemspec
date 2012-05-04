# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cookies_manager/version"

Gem::Specification.new do |s|
  s.name        = "cookies_manager"
  s.version     = CookiesManager::VERSION
  s.authors     = ["Christophe Levand"]
  s.email       = ["levand@free.fr"]
  s.homepage    = ""
  s.summary     = %q{Simple cookies management tool for Rails}
  s.description = %q{Simple cookies management tool for Rails that provides a convenient way to manage any kind of data in the cookies (strings, arrays, hashes, etc.)}

  s.rubyforge_project = "cookies_manager"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'actionpack', '~> 3.2.3'
  s.add_dependency 'activesupport', '~> 3.2.3'
  s.add_development_dependency 'rspec', '~> 2.9.0'
  s.add_development_dependency 'rr', '~> 1.0.4'  
end
