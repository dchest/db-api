require_relative 'dbapi.rb'

module B50D
	class SiversComments
		def error ; @db.error ; end
		def message ; @db.message ; end

		def initialize(api_key, api_pass, server='live')
			@db = DbAPI.new(server)
			res = @db.qry("SELECT person_id FROM peeps.api_keys" +
			" WHERE akey=$1 AND apass=$2 AND $3=ANY(apis)",
				[api_key, api_pass, 'SiversComments'])
			raise 'bad API auth' unless res.ntuples == 1
		end

		def get_comments
			@db.js('sivers.new_comments()')
		end

		def get_comment(id)
			@db.js('sivers.get_comment($1)', [id])
		end

		# hash keys: uri, person_id, name, email, html
		def update_comment(id, hash_of_new_values)
			@db.js('sivers.update_comment($1, $2)', [id, hash_of_new_values.to_json])
		end

		def reply_to_comment(id, reply)
			@db.js('sivers.reply_to_comment($1, $2)', [id, reply])
		end

		def delete_comment(id)
			@db.js('sivers.delete_comment($1)', [id])
		end

		def spam_comment(id)
			@db.js('sivers.spam_comment($1)', [id])
		end

		def add_comment(uri, name, email, html)
			@db.js('sivers.add_comment($1, $2, $3, $4)', [uri, name, email, html])
		end
	end
end

