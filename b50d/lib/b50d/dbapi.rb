require 'pg'
require 'json'

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

class DbAPI
	attr_accessor :error, :message

	def initialize(server='live')
		@db = PGP.get(server)
	end

	def js(func, params=[])
		res = @db.exec_params("SELECT mime, js FROM #{func}", params)
		j = JSON.parse(res[0]['js'], symbolize_names: true)
		if res[0]['mime'].include? 'problem'
			@error = j[:title]
			@message = j[:detail]
			return false
		else
			@error = @message = nil
			return j
		end
	end

	def qry(sql, params)
		@db.exec_params(sql, params)
	end
end
