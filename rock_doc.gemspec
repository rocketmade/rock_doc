$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "rock_doc/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "rock_doc"
  s.version     = RockDoc::VERSION
  s.authors     = ["Daniel Evans"]
  s.email       = ["evans.daniel.n@gmail.com"]
  s.homepage    = "https://github.com/rocketmade/rock_doc"
  s.summary     = "An automatic api doc generator."
  s.description = <<DESC
Automatically generates docs by inspecting controllers in api namespaces and has_scope scopes.
For resourceful controllers it further interrogates the model and active model serializers, if available.
DESC
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 4.2.0.rc2"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "active_model_serializers", '~> 0.8.0'
  s.add_development_dependency "rspec-rails"
end
