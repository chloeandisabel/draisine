# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'draisine/version'

Gem::Specification.new do |spec|
  spec.name          = "draisine"
  spec.version       = Draisine::VERSION
  spec.authors       = ["Mark Abramov"]
  spec.email         = ["markizko@gmail.com"]

  spec.summary       = %q{Synchronization machinery for salesforce}
  spec.description   = %q{Bidirectional synchronization for salesforce / activerecord}
  spec.homepage      = "https://github.com/markiz/draisine"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "sqlite3"
  spec.add_runtime_dependency 'actionpack-xml_parser'
  spec.add_runtime_dependency "rails", ">= 4.2"
  spec.add_runtime_dependency "databasedotcom", "~> 1.3"
end
