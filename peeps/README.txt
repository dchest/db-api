TODO:

Using existing peeps API, convert to functions:

get '/profiles'
emailer_profile_names(emailer_id integer)

get '/emails/unopened'
emailer_unopened_count(emailer_id integer)

get '/emails/open'
emailer_unopened_count(emailer_id integer)

get '/unknowns'
emailer_emails_unknown(emailer_id integer)

get '/unknowns/next'
emailer_next_email_unknown(emailer_id integer)

post %r{^/unknowns/([0-9]+)$} do |id|
emailer_unknown_set_person(emailer_id integer, unknown_id integer, person_id integer)

delete %r{^/unknowns/([0-9]+)$} do |id|
emailer_delete_unknown(emailer_id integer, unknown_id integer)

get '/emails/unopened/:profile/:category' do |p, c|
emailer_list_unopened_email_in(emailer_id integer, profile text, category text)

post '/request/:profile/:category' do |p, c|
emailer_next_unopened_email_in(emailer_id integer, profile text, category text)

get %r{^/emails/([0-9]+)$} do |id|
emailer_open_email(emailer_id integer, email_id integer) 

put %r{^/emails/([0-9]+)$} do |id|
emailer_update_email(emailer_id integer, email_id integer, newvalues json) 

delete %r{^/emails/([0-9]+)$} do |id|
emailer_delete_email(emailer_id integer, email_id integer)

put %r{^/emails/([0-9]+)/close$} do |id|
emailer_close_email(emailer_id integer, email_id integer)

put %r{^/emails/([0-9]+)/unread$} do |id|
emailer_unread_email(emailer_id integer, email_id integer)

put %r{^/emails/([0-9]+)/notme$} do |id|
emailer_not_my_email(emailer_id integer, email_id integer)

post %r{^/emails/([0-9]+)/reply$} do |id|
emailer_reply_to_email(emailer_id integer, email_id integer, body text)

post '/people'
emailer_create_person(emailer_id integer, name text, email text)

get %r{^/people/([0-9]+)$} do |id|
emailer_get_person(emailer_id integer, person_id integer)

put %r{^/people/([0-9]+)$} do |id|
emailer_update_person(emailer_id integer, person_id integer, newvalues json)

delete %r{^/people/([0-9]+)$} do |id|
emailer_delete_person(emailer_id integer, person_id integer)

post %r{^/people/([0-9]+)/urls$} do |id|
add_url(person_id integer, url text)

post %r{^/people/([0-9]+)/stats$} do |id|
add_stat(person_id integer, statkey text, statvalue text)

get %r{^/people/([0-9]+)/emails$} do |id|
emailer_get_person_emails(emailer_id integer, person_id integer)

post %r{^/people/([0-9]+)/emails$} do |id|
emailer_new_email_to(emailer_id integer, person_id integer, profile text, subject text, body text)

post %r{^/people/([0-9]+)/merge$} do |id|
merge_people(person_id integer, other_id integer)

get '/people/unemailed'
unemailed_people()

get '/search'
person_search(q text)

delete %r{^/stats/([0-9]+)$} do |id|
delete_stat(stat_id integer)

delete %r{^/urls/([0-9]+)$} do |id|
delete_url(url_id integer)

put %r{^/urls/([0-9]+)$} do |id|
update_url(uri_id integer, newvalues json)

get '/formletters'
get_formletters()

post '/formletters'
create_formletter(title text)

get %r{^/formletters/([0-9]+)$} do |id|
get_formletter(formletter_id integer)

put %r{^/formletters/([0-9]+)$} do |id|
update_formletter(formletter_id integer, newvalues json)

delete %r{^/formletters/([0-9]+)$} do |id|
delete_formletter(formletter_id integer)

get %r{^/people/([0-9]+)/formletters/([0-9]+)$} do |p_id, f_id|
get_parsed_formletter_for(formletter_id integer, person_id integer)

get '/countries'
get_countries()

get %r{^/states/([A-Z][A-Z])$} do |country_code|
get_country_states(country_code text)

get %r{^/cities/([A-Z][A-Z])/(\S+)$} do |country_code, state|
get_country_state_cities(country_code text, state text)

get %r{^/cities/([A-Z][A-Z])$} do |country_code|
get_country_cities(country_code text)

# optional params: city, state
get %r{^/where/([A-Z][A-Z])} do |country_code|
get_people_from(country_code text, state text, city text)

get %r{^/stats/(\S+)/(\S+)$} do |statkey, statvalue|
get_stats_with(statkey text, statvalue text)

get %r{^/stats/(\S+)$} do |statkey|
get_stats_with(statkey text)

get %r{^/statcount/(\S+)$} do |statkey|
get_stats_count_with(statkey text)

get '/statcount'
get_stats_count()

