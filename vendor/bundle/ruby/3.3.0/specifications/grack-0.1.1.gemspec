# -*- encoding: utf-8 -*-
# stub: grack 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "grack".freeze
  s.version = "0.1.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Scott Chacon".freeze, "Dawa Ometto".freeze, "Jeremy Bopp".freeze]
  s.date = "2020-03-14"
  s.description = "This project aims to replace the builtin git-http-backend CGI handler\ndistributed with C Git with a Rack application. By default, Grack uses calls to\ngit on the system to implement Smart HTTP. Since the git-http-backend is really\njust a simple wrapper for the upload-pack and receive-pack processes with the\n'--stateless-rpc' option, this does not actually re-implement very much.\nHowever, it is possible to use a different backend by specifying a different\nAdapter.\n".freeze
  s.email = ["schacon@gmail.com".freeze, "d.ometto@gmail.com".freeze, "jeremy@bopp.net".freeze]
  s.homepage = "https://github.com/grackorg/grack".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "This project aims to replace the builtin git-http-backend CGI handler distributed with C Git with a Rack application.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<rack>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 12.3.3".freeze, "~> 12.3.3".freeze])
  s.add_development_dependency(%q<rack-test>.freeze, ["~> 0.6".freeze, ">= 0.6.3".freeze])
  s.add_development_dependency(%q<minitest>.freeze, [">= 5.8.0".freeze, "~> 5.8".freeze])
  s.add_development_dependency(%q<mocha>.freeze, [">= 1.1.0".freeze, "~> 1.1".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0.10.0".freeze, "~> 0.10".freeze])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9.24".freeze])
  s.add_development_dependency(%q<redcarpet>.freeze, [">= 3.1.0".freeze, "~> 3.1".freeze])
  s.add_development_dependency(%q<github-markup>.freeze, ["~> 1.0".freeze, ">= 1.0.2".freeze])
  s.add_development_dependency(%q<pry>.freeze, ["~> 0".freeze])
end
