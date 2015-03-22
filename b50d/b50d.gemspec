Gem::Specification.new do |s|
  s.platform	= Gem::Platform::RUBY
  s.name        = 'b50d'
  s.version     = '1.1.2'
  s.date        = '2015-03-22'
  s.author      = 'Derek Sivers'
  s.email       = 'derek@sivers.org'
  s.license     = 'CC BY-NC'
  s.homepage    = 'https://github.com/50pop/db-api'
  s.summary     = 'PostgreSQL API clients for db-api'
  s.description = 'Ruby classes for my web apps to use, to access the PostgreSQL APIs.'
  s.files       =  Dir['lib/b50d/*'] + ['b50d.gemspec']
end


