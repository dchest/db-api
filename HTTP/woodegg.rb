require 'pg'
require 'sinatra/base'

class WoodEgg < Sinatra::Base
	@db = PG::Connection.new(host: '127.0.0.1', port: 6543, dbname: 'd50b', user: 'd50b')
	class << self
		attr_accessor :db
	end

	def qry(sql, params=[])
		@res = self.class.db.exec_params('select mime, js from woodegg.' + sql, params)
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

	post '/login' do
		qry('login($1, $2)', [params[:email], params[:password]])
	end

	get %r{^/customer/([a-zA-Z0-9]{32}:[a-zA-Z0-9]{32})$} do |cookie|
		qry('get_customer($1)', [cookie])
	end

	post '/register' do
		qry('register($1, $2, $3, $4)',
			[params[:name], params[:email], params[:password], params[:proof]])
	end

	post '/forgot' do
		qry('forgot($1)', [params[:email]])
	end

	get %r{^/customer/([a-zA-Z0-9]{8})$} do |newpass|
		qry('get_customer_reset($1)', [newpass])
	end

	post %r{^/customer/([a-zA-Z0-9]{8})$} do |newpass|
		qry('set_customer_password($1, $2)', [newpass, params[:password]])
	end

	get %r{^/researchers/([0-9]+)$} do |id|
		qry('get_researcher($1)', [id])
	end

	get %r{^/writers/([0-9]+)$} do |id|
		qry('get_writer($1)', [id])
	end

	get %r{^/editors/([0-9]+)$} do |id|
		qry('get_editor($1)', [id])
	end

	get %r{^/country/(CN|HK|ID|IN|JP|KH|KR|LK|MM|MN|MY|PH|SG|TH|TW|VN)$} do |cc|
		qry('get_country($1)', [cc])
	end

	get %r{^/questions/([0-9]+)$} do |id|
		qry('get_question($1)', [id])
	end

	get %r{^/books/([0-9]+)$} do |id|
		qry('get_book($1)', [id])
	end

	get '/templates' do
		qry('get_templates()')
	end

	get %r{^/templates/([0-9]+)$} do |id|
		qry('get_template($1)', [id])
	end

	get %r{^/topics/([0-9]+)$} do |id|
		qry('get_topic($1)', [id])
	end

	get %r{^/uploads/([0-9]+)$} do |id|
		qry('get_upload($1)', [id])
	end

	get %r{^/uploads/(CN|HK|ID|IN|JP|KH|KR|LK|MM|MN|MY|PH|SG|TH|TW|VN)$} do |cc|
		qry('get_uploads($1)', [cc])
	end
end


P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
SCHEMA = File.read('../woodegg/schema.sql')
FIXTURES = File.read('../woodegg/fixtures.sql')

class WoodEggTest < WoodEgg
	@db = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')

	delete '/reset' do
		self.class.db.exec(P_SCHEMA)
		self.class.db.exec(SCHEMA)
		self.class.db.exec(P_FIXTURES)
		self.class.db.exec(FIXTURES)
		status 200
	end

end

