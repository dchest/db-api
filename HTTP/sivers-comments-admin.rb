require 'pg'
require 'sinatra/base'

class SiversCommentsAdmin < Sinatra::Base
	@db = PG::Connection.new(dbname: 'd50b', user: 'd50b')
	class << self
		attr_accessor :db
	end

	helpers do
		def authorized?
			@auth ||= Rack::Auth::Basic::Request.new(request.env)
			if @auth.provided? && @auth.basic? && @auth.credentials
				akey, apass = @auth.credentials
				sql = "SELECT * FROM peeps.api_keys WHERE akey=$1 AND apass=$2 AND $3=ANY(apis)"
				res = self.class.db.exec_params(sql, [akey, apass, 'SiversComments'])
				return true if res.ntuples == 1
			end
			false
		end
	end

	before do
		pass if request.path_info == '/auth'
		unless authorized?
			headers['WWW-Authenticate'] = 'Basic realm="SiversComments API keys"'
			halt 401, "Not authorized\n"
		end
	end

	def qry(sql, params=[])
		@res = self.class.db.exec_params('select mime, js from sivers.' + sql, params)
	end

	after do
		halt 200 unless @res # for testing delete '/reset', below
		content_type @res[0]['mime']
		body @res[0]['js']
		if @res[0]['mime'].include? 'problem'
			if @res[0]['js'].include? '"Not Found"'
				status 404
			else
				status 400
			end
		end
	end

	get '/comments' do
		qry('new_comments()')
	end

	get %r{^/comments/([0-9]+)$} do |id|
		qry('get_comment($1)', [id])
	end

	# PARAMS: json 
	put %r{^/comments/([0-9]+)$} do |id|
		qry('update_comment($1, $2)', [id, params[:json]])
	end

	# PARAMS: reply
	post %r{^/comments/([0-9]+)/reply$} do |id|
		qry('reply_to_comment($1, $2)', [id, params[:reply]])
	end

	delete %r{^/comments/([0-9]+)$} do |id|
		qry('delete_comment($1)', [id])
	end

	delete %r{^/comments/([0-9]+)/spam$} do |id|
		qry('spam_comment($1)', [id])
	end

end


P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
SCHEMA = File.read('../sivers/schema.sql')
FIXTURES = File.read('../sivers/fixtures.sql')

class SiversCommentsAdminTest < SiversCommentsAdmin
	@db = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')

	delete '/reset' do
		self.class.db.exec(P_SCHEMA)
		self.class.db.exec(SCHEMA)
		self.class.db.exec(P_FIXTURES)
		self.class.db.exec(FIXTURES)
		status 200
	end

end

