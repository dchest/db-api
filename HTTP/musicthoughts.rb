require_relative 'pgp.rb'
require 'sinatra/base'

class MusicThoughtsPublic < Sinatra::Base
	@db = PGP.get
	class << self
		attr_accessor :db
	end

	def qry(sql, params=[])
		@res = self.class.db.exec_params('select mime, js from musicthoughts.' + sql, params)
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

	get '/languages' do
		qry('languages()')
	end

	get '/categories' do
		qry('all_categories()')
	end

	get %r{^/categories/([0-9]+)$} do |id|
		qry('category($1)', [id])
	end

	get '/authors' do
		qry('top_authors(NULL)')
	end

	get '/authors/top' do
		qry('top_authors($1)', [20])
	end

	get %r{^/authors/([0-9]+)$} do |id|
		qry('get_author($1)', [id])
	end

	get '/contributors' do
		qry('top_contributors(NULL)')
	end

	get '/contributors/top' do
		qry('top_contributors($1)', [20])
	end

	get %r{^/contributors/([0-9]+)$} do |id|
		qry('get_contributor($1)', [id])
	end

	get '/thoughts/random' do
		qry('random_thought()')
	end

	get %r{^/thoughts/([0-9]+)$} do |id|
		qry('get_thought($1)', [id])
	end

	get '/thoughts' do
		qry('new_thoughts(NULL)')
	end

	get '/thoughts/new' do
		qry('new_thoughts($1)', [20])
	end

	get '/search' do
		qry('search($1)', [params[:q]])
	end

	# PARAMS:
	# $1 = lang_code
	# $2 = thought
	# $3 = contributor_name
	# $4 = contributor_email
	# $5 = contributor_url
	# $6 = contributor_place
	# $7 = author_name
	# $8 = source_url
	# $9 = category_ids (array)
	post '/thoughts' do
		qry('add_thought($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
				params[:lang_code],
				params[:thought],
				params[:contributor_name],
				params[:contributor_email],
				params[:contributor_url],
				params[:contributor_place],
				params[:author_name],
				params[:source_url],
				params[:category_ids]])
	end

end


P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
SCHEMA = File.read('../musicthoughts/schema.sql')
FIXTURES = File.read('../musicthoughts/fixtures.sql')

class MusicThoughtsPublicTest < MusicThoughtsPublic
	@db = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')

	delete '/reset' do
		self.class.db.exec(P_SCHEMA)
		self.class.db.exec(SCHEMA)
		self.class.db.exec(P_FIXTURES)
		self.class.db.exec(FIXTURES)
		status 200
	end

end

