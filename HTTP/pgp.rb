require 'pg'

# PG Pool of connections. Simple as can be. Bypassed if test database.
# NOTE: duplicated in db-api/HTTP/
class PGP
	@@pool = []
	@@counter = 0
	class << self
		def get(live_or_test='live')
			if 'test' == live_or_test
				return PG::Connection.new(dbname: 'd50b_test', user: 'd50b')
			end
			my_id = @@counter
			@@counter += 1
			@@counter = 0 if 80 == @@counter
			@@pool[my_id] ||= PG::Connection.new(dbname: 'd50b', user: 'd50b')
		end
	end
end
