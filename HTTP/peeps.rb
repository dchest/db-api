require 'pg'
require 'sinatra/base'

class Peep < Sinatra::Base
	@db = PG::Connection.new(dbname: 'd50b', user: 'd50b')
	class << self
		attr_accessor :db
	end

	helpers do
		def authorized?
			@eid = nil
			@auth ||= Rack::Auth::Basic::Request.new(request.env)
			if @auth.provided? && @auth.basic? && @auth.credentials
				akey, apass = @auth.credentials
				sql = "SELECT emailers.id FROM api_keys, emailers" +
				" WHERE akey=$1 AND apass=$2 AND $3=ANY(apis)" +
				" AND api_keys.person_id=emailers.person_id"
				res = self.class.db.exec_params(sql, [akey, apass, 'Peep'])
				if res.ntuples == 1
					@eid = res[0]['id']
				end
			end
			@eid
		end
	end

	before do
		unless authorized?
			headers['WWW-Authenticate'] = 'Basic realm="Peeps API keys"'
			halt 401, "Not authorized\n"
		end
	end

	def qry(sql, params=[])
		@res = self.class.db.exec_params('select mime, js from peeps.' + sql, params)
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

	get '/emails/unopened' do
		qry('unopened_email_count($1)', [@eid])
	end

	get '/emails/open' do
		qry('opened_emails($1)', [@eid])
	end

	get '/unknowns/count' do
		qry('count_unknowns($1)', [@eid])
	end

	get '/unknowns' do
		qry('get_unknowns($1)', [@eid])
	end

	get '/unknowns/next' do
		qry('get_next_unknown($1)', [@eid])
	end

	# PARAMS: person_id if known, or 0 to create a new person from this email
	post %r{^/unknowns/([0-9]+)$} do |email_id|
		qry('set_unknown_person($1, $2, $3)', [@eid, email_id, params[:person_id]])
	end

	delete %r{^/unknowns/([0-9]+)$} do |email_id|
		qry('delete_unknown($1, $2)', [@eid, email_id])
	end

	get '/emails/unopened/:profile/:category' do |p, c|
		qry('unopened_emails($1, $2, $3)', [@eid, p, c])
	end

	post '/request/:profile/:category' do |p, c|
		qry('open_next_email($1, $2, $3)', [@eid, p, c])
	end

	get %r{^/emails/([0-9]+)$} do |id|
		qry('get_email($1, $2)', [@eid, id])
	end

	# PARAMS: json : key=>val of new values
	# TODO: or just use params.to_json?
	put %r{^/emails/([0-9]+)$} do |id|
		qry('update_email($1, $2, $3)', [@eid, id, params[:json]])
	end

	delete %r{^/emails/([0-9]+)$} do |id|
		qry('delete_email($1, $2)', [@eid, id])
	end

	put %r{^/emails/([0-9]+)/close$} do |id|
		qry('close_email($1, $2)', [@eid, id])
	end

	put %r{^/emails/([0-9]+)/unread$} do |id|
		qry('unread_email($1, $2)', [@eid, id])
	end

	put %r{^/emails/([0-9]+)/notme$} do |id|
		qry('not_my_email($1, $2)', [@eid, id])
	end

	# PARAMS: body
	post %r{^/emails/([0-9]+)/reply$} do |id|
		qry('reply_to_email($1, $2, $3)', [@eid, id, params[:body]])
	end

	# PARAMS: name, email
	post '/people' do
		qry('create_person($1, $2)', [params[:name], params[:email]])
	end

	get %r{^/people/([0-9]+)$} do |id|
		qry('get_person($1)', [id])
	end

	# PARAMS: json : key=>val of new values
	# TODO: or just use params.to_json?
	put %r{^/people/([0-9]+)$} do |id|
		qry('update_person($1, $2)', [id, params[:json]])
	end

	delete %r{^/people/([0-9]+)$} do |id|
		qry('delete_person($1)', [id])
	end

	# PARAMS: url
	post %r{^/people/([0-9]+)/urls$} do |id|
		qry('add_url($1, $2)', [id, params[:url]])
	end

	# PARAMS: statkey, statvalue
	post %r{^/people/([0-9]+)/stats$} do |id|
		qry('add_stat($1, $2, $3)', [id, params[:statkey], params[:statvalue]])
	end

	get %r{^/people/([0-9]+)/emails$} do |id|
		qry('get_person_emails($1)', [id])
	end

	# PARAMS: profile, subject, body
	post %r{^/people/([0-9]+)/emails$} do |id|
		qry('new_email($1, $2, $3, $4, $5)',
				[@eid, id, params[:profile], params[:subject], params[:body]])
	end

	# PARAMS: id = person.id to merge INTO the one in the URL
	post %r{^/people/([0-9]+)/merge$} do |id|
		qry('merge_person($1, $2)', [id, params[:id]])
	end

	get '/people/unemailed' do
		qry('people_unemailed()')
	end

	# PARAMS: q = search term
	get '/search' do
		qry('people_search($1)', [params[:q]])
	end

	delete %r{^/stats/([0-9]+)$} do |id|
		qry('delete_stat($1)', [id])
	end

	delete %r{^/urls/([0-9]+)$} do |id|
		qry('delete_url($1)', [id])
	end

	# PARAMS: json with person_id, url, main(boolean)
	# TODO: or just use params.to_json?
	put %r{^/urls/([0-9]+)$} do |id|
		qry('update_url($1, $2)', [id, params[:json]])
	end

	get '/formletters' do
		qry('get_formletters()')
	end

	# PARAMS: title
	post '/formletters' do
		qry('create_formletter($1)', [params[:title]])
	end

	get %r{^/formletters/([0-9]+)$} do |id|
		qry('get_formletter($1)', [id])
	end

	# PARAMS: json with title, explanation, body
	# TODO: or just use params.to_json?
	put %r{^/formletters/([0-9]+)$} do |id|
		qry('update_formletter($1, $2)', [id, params[:json]])
	end

	delete %r{^/formletters/([0-9]+)$} do |id|
		qry('delete_formletter($1)', [id])
	end

	# returns just {body: "parsed body for this person here"}
	get %r{^/people/([0-9]+)/formletters/([0-9]+)$} do |p_id, f_id|
		qry('parsed_formletter($1, $2)', [p_id, f_id])
	end

	get '/countries' do
		qry('country_count()')
	end

	get %r{^/states/([A-Z][A-Z])$} do |country_code|
		qry('state_count($1)', [country_code])
	end

	get %r{^/cities/([A-Z][A-Z])/(\S+)$} do |country_code, state|
		qry('city_count($1, $2)', [country_code, state])
	end

	get %r{^/cities/([A-Z][A-Z])$} do |country_code|
		qry('city_count($1)', [country_code])
	end

	# optional params: city, state
	get %r{^/where/([A-Z][A-Z])} do |country_code|
		if params[:state] && params[:city]
			qry('people_from_state_city($1, $2, $3)', [country_code, params[:state], params[:city]])
		elsif params[:state]
			qry('people_from_state($1, $2)', [country_code, params[:state]])
		elsif params[:city]
			qry('people_from_city($1, $2)', [country_code, params[:city]])
		else
			qry('people_from_country($1)', [country_code])
		end
	end

	get %r{^/stats/(\S+)/(\S+)$} do |statkey, statvalue|
		qry('get_stats($1, $2)', [statkey, statvalue])
	end

	get %r{^/stats/(\S+)$} do |statkey|
		qry('get_stats($1)', [statkey])
	end

	get %r{^/statcount/(\S+)$} do |statkey|
		qry('get_stat_value_count($1)', [statkey])
	end

	get '/statcount' do
		qry('get_stat_name_count()')
	end

end


P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')

class PeepTest < Peep
	@db = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')

	delete '/reset' do
		self.class.db.exec(P_SCHEMA)
		self.class.db.exec(P_FIXTURES)
		status 200
	end

end

