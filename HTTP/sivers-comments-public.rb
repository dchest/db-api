require 'pg'
require 'sinatra/base'

class SiversCommentsPublic < Sinatra::Base
	@db = PG::Connection.new(dbname: 'd50b', user: 'd50b')
	class << self
		attr_accessor :db
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

	# PARAMS: uri, name, email, html
	post '/comments' do
		qry('add_comment($1, $2, $3, $4)', [
			params[:uri],
			params[:name],
			params[:email],
			params[:html]])
	end

end


P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
SCHEMA = File.read('../sivers/schema.sql')
FIXTURES = File.read('../sivers/fixtures.sql')

class SiversCommentsPublicTest < SiversCommentsPublic
	@db = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')

	delete '/reset' do
		self.class.db.exec(P_SCHEMA)
		self.class.db.exec(SCHEMA)
		self.class.db.exec(P_FIXTURES)
		self.class.db.exec(FIXTURES)
		status 200
	end

end

