require_relative 'dbapi.rb'

# USAGE:
# require '/srv/public/db-api/b50d/woodegg.rb'
# @we = B50D::WoodEgg.new('test')
# unless @writer = @we.writer(123)
#   puts @we.error
#   puts @we.message
# end

module B50D
	class WoodEgg
		def error ; @db.error ; end
		def message ; @db.message ; end

		def initialize(server='live')
			@db = DbAPI.new(server)
			@ccs = %w(CN HK ID IN JP KH KR LK MM MN MY PH SG TH TW VN)
		end

		def login(email, password)
			@db.js('woodegg.login($1, $2)', [email, password])
		end

		def customer_from_cookie(cookie)
			return false unless /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/ === cookie
			@db.js('woodegg.get_customer($1)', [cookie])
		end

		# PARAMS KEYS: name, email, password, proof
		def register(params)
			@db.js('woodegg.register($1, $2, $3, $4)',
				[params[:name], params[:email], params[:password], params[:proof]])
		end

		def forgot(email)
			@db.js('woodegg.forgot($1)', [email])
		end

		def customer_from_reset(reset)
			@db.js('woodegg.get_customer_reset($1)', [reset])
		end

		def set_customer_password(reset, password)
			@db.js('woodegg.set_customer_password($1, $2)', [reset, password])
		end

		def researcher(id)
			@db.js('woodegg.get_researcher($1)', [id])
		end

		def writer(id)
			@db.js('woodegg.get_writer($1)', [id])
		end

		def editor(id)
			@db.js('woodegg.get_editor($1)', [id])
		end

		def country(cc)
			return false unless @ccs.include? cc
			@db.js('woodegg.get_country($1)', [cc])
		end

		def question(id)
			@db.js('woodegg.get_question($1)', [id])
		end

		def book(id)
			@db.js('woodegg.get_book($1)', [id])
		end

		def templates
			@db.js('woodegg.get_templates()')
		end

		def template(id)
			@db.js('woodegg.get_template($1)', [id])
		end

		def topic(id)
			@db.js('woodegg.get_topic($1)', [id])
		end

		def upload(id)
			@db.js('woodegg.get_upload($1)', [id])
		end

		def uploads(cc)
			return false unless @ccs.include? cc
			@db.js('woodegg.get_uploads($1)', [cc])
		end

	end
end
