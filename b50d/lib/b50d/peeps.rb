require_relative 'dbapi.rb'

module B50D
	class Peeps
		def error ; @db.error ; end
		def message ; @db.message ; end

		def self.auth(server, email, password, api)
			db = DbAPI.new(server)
			db.js('peeps.auth_api($1, $2, $3)', [email, password, api])
		end

		def initialize(api_key, api_pass, server='live')
			@db = DbAPI.new(server)
			res = @db.qry("SELECT emailers.id FROM peeps.api_keys, peeps.emailers" +
				" WHERE akey=$1 AND apass=$2 AND $3=ANY(apis)" +
				" AND api_keys.person_id=emailers.person_id",
				[api_key, api_pass, 'Peep'])
			raise 'bad API auth' unless res.ntuples == 1
			@eid = res[0]['id']
		end

		def profiles
			['derek@sivers', 'we@woodegg']
		end

		def unopened_email_count
			@db.js('peeps.unopened_email_count($1)', [@eid])
		end

		def open_emails
			@db.js('peeps.opened_emails($1)', [@eid])
		end

		def unknowns
			@db.js('peeps.get_unknowns($1)', [@eid])
		end

		def unknowns_count
			@db.js('peeps.count_unknowns($1)', [@eid])
		end

		def next_unknown
			@db.js('peeps.get_next_unknown($1)', [@eid])
		end

		def unknown_is_person(email_id, person_id)
			@db.js('peeps.set_unknown_person($1, $2, $3)', [@eid, email_id, person_id.to_i])
		end

		def unknown_is_new_person(email_id)
			@db.js('peeps.set_unknown_person($1, $2, $3)', [@eid, email_id, 0])
		end

		def delete_unknown(email_id)
			@db.js('peeps.delete_unknown($1, $2)', [@eid, email_id])
		end

		def emails_unopened(profile, category)
			@db.js('peeps.unopened_emails($1, $2, $3)', [@eid, profile, category])
		end

		def next_unopened_email(profile, category)
			@db.js('peeps.open_next_email($1, $2, $3)', [@eid, profile, category])
		end

		def open_email(id)
			@db.js('peeps.get_email($1, $2)', [@eid, id])
		end

		def update_email(id, params)
			@db.js('peeps.update_email($1, $2, $3)', [@eid, id, params.to_json])
		end

		def delete_email(id)
			@db.js('peeps.delete_email($1, $2)', [@eid, id])
		end

		def close_email(id)
			@db.js('peeps.close_email($1, $2)', [@eid, id])
		end

		def unread_email(id)
			@db.js('peeps.unread_email($1, $2)', [@eid, id])
		end

		def not_my_email(id)
			@db.js('peeps.not_my_email($1, $2)', [@eid, id])
		end

		def reply_to_email(id, body)
			@db.js('peeps.reply_to_email($1, $2, $3)', [@eid, id, body])
		end

		def new_person(name, email)
			@db.js('peeps.create_person($1, $2)', [name, email])
		end

		def get_person(id)
			@db.js('peeps.get_person($1)', [id])
		end

		def emails_for_person(id)
			@db.js('peeps.get_person_emails($1)', [id])
		end

		def update_person(id, params)
			@db.js('peeps.update_person($1, $2)', [id, params.to_json])
		end

		def delete_person(id)
			@db.js('peeps.delete_person($1)', [id])
		end

		def add_url(person_id, url)
			@db.js('peeps.add_url($1, $2)', [person_id, url])
		end

		def add_stat(person_id, key, value)
			@db.js('peeps.add_stat($1, $2, $3)', [person_id, key, value])
		end

		def new_email_to(person_id, body, subject, profile)
			@db.js('peeps.new_email($1, $2, $3, $4, $5)',
				[@eid, person_id, profile, subject, body])
		end

		def merge_into_person(person_id, person_id_to_merge)
			@db.js('peeps.merge_person($1, $2)', [person_id, person_id_to_merge])
		end

		def unemailed_people
			@db.js('peeps.people_unemailed()')
		end

		def person_search(q)
			@db.js('peeps.people_search($1)', [q.strip])
		end

		def get_stat(id)
			@db.js('peeps.get_stat($1)', [id])
		end

		def delete_stat(id)
			@db.js('peeps.delete_stat($1)', [id])
		end

		def update_stat(id, params)
			@db.js('peeps.update_stat($1, $2)', [id, params.to_json])
		end

		def get_url(id)
			@db.js('peeps.get_url($1)', [id])
		end

		def delete_url(id)
			@db.js('peeps.delete_url($1)', [id])
		end

		def update_url(id, params)
			@db.js('peeps.update_url($1, $2)', [id, params.to_json])
		end

		def star_url(id)
			@db.js('peeps.update_url($1, $2)', [id, '{"main":true}'])
		end

		def unstar_url(id)
			@db.js('peeps.update_url($1, $2)', [id, '{"main":false}'])
		end

		def formletters
			@db.js('peeps.get_formletters()')
		end

		def add_formletter(title)
			@db.js('peeps.create_formletter($1)', [title])
		end

		def get_formletter(id)
			@db.js('peeps.get_formletter($1)', [id])
		end

		def update_formletter(id, params)
			@db.js('peeps.update_formletter($1, $2)', [id, params.to_json])
		end

		def delete_formletter(id)
			@db.js('peeps.delete_formletter($1)', [id])
		end

		def get_formletter_for_person(formletter_id, person_id)
			@db.js('peeps.parsed_formletter($1, $2)', [person_id, formletter_id])
		end

		def all_countries
			@db.js('peeps.all_countries()')
		end

		def country_names
			@db.js('peeps.country_names()')
		end

		def country_count
			@db.js('peeps.country_count()')
		end

		def state_count(country)
			@db.js('peeps.state_count($1)', [country])
		end

		def city_count(country, state=nil)
			if state
				@db.js('peeps.city_count($1, $2)', [country, state])
			else
				@db.js('peeps.city_count($1)', [country])
			end
		end

		def where(country, city=nil, state=nil)
			if state && city
				@db.js('peeps.people_from_state_city($1, $2, $3)', [country, state, city])
			elsif state
				@db.js('peeps.people_from_state($1, $2)', [country, state])
			elsif city
				@db.js('peeps.people_from_city($1, $2)', [country, city])
			else
				@db.js('peeps.people_from_country($1)', [country])
			end
		end

		def statkeys_count
			@db.js('peeps.get_stat_name_count()')
		end

		def statvalues_count(statkey)
			@db.js('peeps.get_stat_value_count($1)', [statkey])
		end

		def stats_with_key(statkey)
			@db.js('peeps.get_stats($1)', [statkey])
		end

		def stats_with_key_value(statkey, statvalue)
			@db.js('peeps.get_stats($1, $2)', [statkey, statvalue])
		end

		def import_email(hsh)
			@db.js('peeps.import_email($1)', [hsh.to_json])
		end
	end
end
