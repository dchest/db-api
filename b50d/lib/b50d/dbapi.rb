require 'pg'
require 'json'

class DbAPI
	attr_accessor :error, :message

	def initialize(server='live')
		dbname = (server == 'test') ? 'd50b_test' : 'd50b'
		@db =  PG::Connection.new(host: '127.0.0.1', port: 6543, dbname: dbname, user: 'd50b')
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
