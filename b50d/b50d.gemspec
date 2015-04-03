Gem::Specification.new do |s|
  s.platform	= Gem::Platform::RUBY
  s.name        = 'b50d'
  s.version     = '1.9.6'
  s.date        = '2015-04-03'
  s.author      = 'Derek Sivers'
  s.email       = 'derek@sivers.org'
  s.license     = 'CC BY-NC'
  s.homepage    = 'https://github.com/50pop/db-api'
  s.summary     = 'PostgreSQL API clients for db-api'
  s.description = 'Ruby classes for my web apps to use, to access the PostgreSQL APIs.'
  s.files       =  Dir['lib/b50d/*'] + Dir['bin/*'] + ['b50d.gemspec','b50d-config.rb.sample']
  s.executables = ['impeema', 'woodegg-proofs']
end

