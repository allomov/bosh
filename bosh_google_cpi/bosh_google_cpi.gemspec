# -*- encoding: utf-8 -*-

version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = 'bosh_google_cpi'
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'BOSH Google Engine CPI'
  s.description  = "BOSH Google Engine CPI\n#{`git rev-parse HEAD`[0, 6]}"
  s.author       = 'Altoros'
  s.homepage     = 'https://github.com/Altoros/bosh'
  s.license      = 'Apache 2.0'
  s.email        = 'altoros-cf@googlegroups.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = `git ls-files -- bin/* lib/* scripts/*`.split("\n") + %w(README.md)
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables  = %w()

  s.add_dependency 'google-api-client', '~>0.6.4'
  s.add_dependency 'fog', '1.14.0'

  s.add_dependency 'bosh_common', "~>#{version}"
  s.add_dependency 'bosh_cpi', "~>#{version}"
  s.add_dependency 'bosh-registry', "~>#{version}"
  s.add_dependency 'httpclient', '=2.2.4'
  s.add_dependency 'yajl-ruby', '>=0.8.2'
end
