require 'minitest/autorun'
require_relative 'testful.rb'

#Minitest.after_run do
	# delete '/reset'
#end

require_relative 'peeps.rb'
class TestPeepsAPI < Minitest::Test
	include Testful
	Testful::BASE = 'http://127.0.0.1:10001'

	def setup
		# api_keys for different emailers:
		@emailer_1 = ['a'*8, 'b'*8]
		@emailer_2 = ['g'*8, 'h'*8]
		@emailer_3 = ['k'*8, 'l'*8]
		@emailer_4 = ['m'*8, 'n'*8]
		# Testful looks for @auth
		@auth = @emailer_1
		delete '/reset'
	end

	def test_auth
		@auth = ['x', 'x']
		post '/auth', {email: 'derek@sivers.org', password: 'derek', api: 'Peep'}
		assert_equal 1, @j[:person_id]
		assert_equal 'aaaaaaaa', @j[:akey]
		assert_equal 'bbbbbbbb', @j[:apass]
		assert_equal %w(Peep SiversComments MuckworkManager), @j[:apis]
		post '/auth', {email: 'derek@sivers.org', password: 'derek', api: 'POP'}
		assert_equal 'application/problem+json', @res.headers['content-type']
		post '/auth', {email: 'derek@sivers.org', password: 'doggy', api: 'Peep'}
		assert_equal 'application/problem+json', @res.headers['content-type']
		post '/auth', {email: 'derek@sivers.org', password: 'x', api: 'Peep'}
		assert_equal 'application/problem+json', @res.headers['content-type']
		post '/auth', {email: 'derek@sivers', password: 'derek', api: 'Peep'}
		assert_equal 'application/problem+json', @res.headers['content-type']
	end

	def test_unopened_email_count
		get '/emails/unopened'
		assert_equal %i(derek@sivers we@woodegg), @j.keys
		assert_equal({:woodegg => 1, :'not-derek' => 1}, @j[:'we@woodegg'])
		@auth = @emailer_4
		get '/emails/unopened'
		assert_equal %i(we@woodegg), @j.keys
		@auth = @emailer_3
		get '/emails/unopened'
		assert_equal({}, @j)
	end

	def test_unopened_emails
		get '/emails/unopened/we@woodegg/woodegg'
		assert_instance_of Array, @j
		assert_equal 1, @j.size
		assert_equal 'I refuse to wait', @j[0][:subject]
		assert_nil @j[0][:body]
		@auth = @emailer_3
		get '/emails/unopened/we@woodegg/woodegg'
		assert_equal [], @j
	end

	def test_open_next_email
		post '/request/we@woodegg/woodegg'
		assert_equal 8, @j[:id]
		assert_equal 1, @j[:openor][:id]
		assert_equal 'Derek Sivers', @j[:openor][:name]
		assert_match /^\d{4}-\d{2}-\d{2}/, @j[:opened_at]
		assert_equal 'I refuse to wait', @j[:subject]
		assert_equal 'I refuse to wait', @j[:body]
		post '/request/we@woodegg/woodegg'
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
	end

	def test_opened_emails
		get '/emails/open'
		assert_instance_of Array, @j
		assert_equal 1, @j.size
		assert_equal 'I want that Wood Egg book now', @j[0][:subject]
		@auth = @emailer_3
		get '/emails/open'
		assert_equal [], @j
	end

	def test_get_email
		get '/emails/2'
		assert_equal 4, @j[:answer_id]
		get '/emails/4'
		assert_equal 2, @j[:reference_id]
		get '/emails/8'
		assert_equal 'I refuse to wait', @j[:subject]
		assert_equal 'Derek Sivers', @j[:openor][:name]
		get '/emails/6'
		assert_equal '2014-05-21', @j[:opened_at][0,10]
		@auth = @emailer_3
		get '/emails/6'
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'about:blank', @j[:type]
		assert_equal 'Not Found', @j[:title]
		assert_equal 404, @j[:status]
	end

	def test_update_email
		put '/emails/8', {json: '{"subject":"boop", "ig":"nore"}'}
		assert_equal 'boop', @j[:subject]
		@auth = @emailer_3
		put '/emails/8', {json: '{"subject":"boop", "ig":"nore"}'}
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
	end

	def test_update_email_errors
		put '/emails/8', {json: '{"opened_by":"boop"}'}
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert @j[:type].include? '22P02'
		assert @j[:title].include? 'invalid input syntax for integer'
		assert @j[:detail].include? 'jsonupdate'
	end

	def test_delete_email
		delete '/emails/8'
		assert_equal 'application/json', @res.headers['content-type']
		assert_equal 'I refuse to wait', @j[:subject]
		delete '/emails/8'
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
		@auth = @emailer_3
		delete '/emails/1'
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
	end

	def test_close_email
		@auth = @emailer_4
		put '/emails/6/close'
		assert_equal 4, @j[:closor][:id]
	end

	def test_unread_email
		@auth = @emailer_4
		put '/emails/6/unread'
		assert_nil @j[:opened_at]
		assert_nil @j[:openor]
	end

	def test_not_my_email
		@auth = @emailer_4
		put '/emails/6/notme'
		assert_nil @j[:opened_at]
		assert_nil @j[:openor]
		assert_equal 'not-gong', @j[:category]
	end

	def test_reply_to_email
		@auth = @emailer_4
		post '/emails/8/reply', {body: 'Groovy, baby'}
		assert_equal 11, @j[:id]
		assert_equal 3, @j[:person][:id]
		assert_match /\A[0-9]{17}\.3@sivers.org\Z/, @j[:message_id]
		assert_equal @j[:message_id][0,12], Time.now.strftime('%Y%m%d%H%M')
		assert @j[:body].include? 'Groovy, baby'
		assert_match /\AHi Veruca -/, @j[:body]
		assert_match /^> I refuse to wait$/, @j[:body]
		assert_match %r{^Wood Egg  we@woodegg.com  http://woodegg.com\/$}, @j[:body]
		assert_equal nil, @j[:outgoing]
		assert_equal 're: I refuse to wait', @j[:subject]
		assert_match %r{^20}, @j[:created_at]
		assert_match %r{^20}, @j[:opened_at]
		assert_match %r{^20}, @j[:closed_at]
		assert_equal '巩俐', @j[:creator][:name]
		assert_equal '巩俐', @j[:openor][:name]
		assert_equal '巩俐', @j[:closor][:name]
		assert_equal 'Veruca Salt', @j[:their_name]
		assert_equal 'veruca@salt.com', @j[:their_email]
	end

	def test_count_unknowns
		get '/unknowns/count'
		assert_equal({count: 2}, @j)
		@auth = @emailer_4
		get '/unknowns/count'
		assert_equal({count: 0}, @j)
	end

	def test_get_unknowns
		get '/unknowns'
		assert_instance_of Array, @j
		assert_equal 2, @j.size
		assert_equal [5, 10], @j.map{|x| x[:id]}
		@auth = @emailer_4
		get '/unknowns'
		assert_equal [], @j
	end

	def test_get_next_unknown
		get '/unknowns/next'
		assert_equal 'New Stranger', @j[:their_name]
		assert @j[:body].include? 'I have a question'
		assert @j[:headers].include? 'new@stranger.com'
		@auth = @emailer_4
		get '/unknowns/next'
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
	end

	def test_set_unknown_person
		post '/unknowns/5', {person_id: 0}
		assert_equal 9, @j[:person][:id]
		post '/unknowns/10', {person_id: 5}
		assert_equal 5, @j[:person][:id]
		get '/people/5'
		assert_equal 'OLD EMAIL: oompa@loompa.mm', @j[:notes].strip
	end

	def test_set_unknown_person_fail
		post '/unknowns/99', {person_id: 5}
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
		post '/unknowns/5', {person_id: 99}
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert_equal 'Not Found', @j[:title]
	end

	def test_delete_unknown
		delete '/unknowns/5'
		assert_equal 'random question', @j[:subject]
		delete '/unknowns/8'
		assert_equal 'Not Found', @j[:title]
		@auth = @emailer_4
		delete '/unknowns/10'
		assert_equal 'Not Found', @j[:title]
		@auth = @emailer_3
		delete '/unknowns/10'
		assert_equal 'remember me?', @j[:subject]
	end

	def test_create_person
		post '/people', {name: '  Bob Dobalina', email: 'MISTA@DOBALINA.COM'}
		assert_equal 9, @j[:id]
		assert_equal 'Bob', @j[:address]
		assert_equal 'mista@dobalina.com', @j[:email]
		%i(stats urls emails).each do |k|
			assert @j.keys.include? k
			assert_equal nil, @j[k]
		end
	end

	def test_create_person_fail
		post '/people', {name: '', email: 'a@b.c'}
		assert @j[:title].include? 'no_name'
		post '/people', {name: 'Name', email: 'a@b'}
		assert @j[:title].include? 'valid_email'
	end

	def test_get_person
		get '/people/99'
		assert_equal 'Not Found', @j[:title]
		get '/people/2'
		assert_equal 'http://www.wonka.com/', @j[:urls][0][:url]
		assert_equal 'you coming by?', @j[:emails][0][:subject]
		assert_equal 'musicthoughts', @j[:stats][1][:name]
		assert_equal 'clicked', @j[:stats][1][:value]
	end

	def test_update_person
		put '/people/8', {json: '{"address":"Ms. Ono", "city": "NY", "ig":"nore"}'}
		assert_equal 'Ms. Ono', @j[:address]
		assert_equal 'NY', @j[:city]
	end

	def test_update_person_fail
		put '/people/99', {json: '{"country":"XXX"}'}
		assert_equal 'Not Found', @j[:title]
		put '/people/1', {json: '{"country":"XXX"}'}
		assert @j[:title].include? 'value too long'
	end

	def test_delete_person
		delete '/people/1'
		assert @j[:title].include? 'violates foreign key'
		delete '/people/99'
		assert_equal 'Not Found', @j[:title]
		delete '/people/5'
		assert_equal 'Oompa Loompa', @j[:name]
	end

	def test_add_url
		post '/people/5/urls', {url: 'bank.com'}
		assert_equal 'http://bank.com', @j[:urls][1][:url]
		post '/people/5/urls', {url: 'x'}
		assert_equal 'bad url', @j[:title]
		post '/people/999/urls', {url: 'http://good.com'}
		assert @j[:title].include? 'violates foreign key'
	end

	def test_add_stat
		post '/people/5/stats', {statkey: ' s OM e ', statvalue: '  v alu e '}
		assert_equal 'some', @j[:stats][1][:name]
		assert_equal 'v alu e', @j[:stats][1][:value]
		post '/people/5/stats', {statkey: '  ', statvalue: 'val'}
		assert_equal 'stats.key must not be empty', @j[:title]
		post '/people/5/stats', {statkey: 'key', statvalue: ' '}
		assert_equal 'stats.value must not be empty', @j[:title]
		post '/people/99/stats', {statkey: 'key', statvalue: 'value'}
		assert @j[:title].include? 'violates foreign key'
	end

	def test_new_email
		@auth = @emailer_4
		post '/people/5/emails', {profile: 'we@woodegg', subject: 'a subject', body: 'a body'}
		assert_equal 'a subject', @j[:subject]
		assert_equal "Hi Oompa Loompa -\n\na body\n\n--\nWood Egg  we@woodegg.com  http://woodegg.com/", @j[:body]
		post '/people/99/emails', {profile: 'we@woodegg', subject: 'a subject', body: 'a body'}
		assert_equal 'person_id not found', @j[:title]
		post '/people/1/emails', {profile: 'we@wo', subject: 'a subject', body: 'a body'}
		assert_equal 'invalid profile', @j[:title]
		post '/people/1/emails', {profile: 'we@woodegg', subject: 'a subject', body: ' '}
		assert_equal 'body must not be empty', @j[:title]
	end
	
	def test_get_person_emails
		get '/people/3/emails'
		assert_equal 4, @j.size
		assert_equal [6, 7, 8, 9], @j.map {|x| x[:id]}
		assert @j[0][:body]
		assert @j[1][:message_id]
		assert @j[2][:headers]
		assert_equal false, @j[3][:outgoing]
		get '/people/99/emails'
		assert_equal [], @j
	end

	def test_people_unemailed
		get '/people/unemailed'
		assert_equal [8, 6, 5, 4, 1], @j.map {|x| x[:id]}
		@auth = @emailer_4
		post '/people/5/emails', {profile: 'we@woodegg', subject: 'a subject', body: 'a body'}
		get '/people/unemailed'
		assert_equal [8, 6, 4, 1], @j.map {|x| x[:id]}
	end

	def test_people_search
		get '/search?q=on'
		assert_instance_of Array, @j
		assert_equal [7, 2, 8], @j.map {|x| x[:id]}
		get '/search?q=x'
		assert_equal 'search term too short', @j[:title]
	end

	def test_get_stat
		get '/stats/8'
		assert_equal 'media', @j[:name]
		assert_equal 'interview', @j[:value]
		assert_equal 5, @j[:person][:id]
		assert_equal 'oompa@loompa.mm', @j[:person][:email]
		assert_equal 'Oompa Loompa', @j[:person][:name]
	end

	def test_delete_stat
		delete '/stats/8'
		assert_equal 'interview', @j[:value]
		delete '/stats/8'
		assert_equal 'Not Found', @j[:title]
	end

	# note for now it's statkey & statvalue, not name & value
	def test_update_stat
		put '/stats/8', {json: '{"statkey":"m", "statvalue": "i"}'}
		assert_equal 'm', @j[:name]
		assert_equal 'i', @j[:value]
		put '/stats/99', {json: '{"statkey":"m"}'}
		assert_equal 'Not Found', @j[:title]
		put '/stats/8', {json: '{"person_id":"boop"}'}
		assert @j[:title].include? 'invalid input syntax'
	end

	def test_get_url
		get '/urls/2'
		assert_equal 1, @j[:person_id]
		assert_equal 'http://sivers.org/', @j[:url]
		assert_equal true, @j[:main]
	end

	def test_delete_url
		delete '/urls/8'
		assert_equal 'http://oompa.loompa', @j[:url]
		delete '/urls/8'
		assert_equal 'Not Found', @j[:title]
	end

	def test_update_url
		put '/urls/8', {json: '{"url":"http://oompa.com", "main": true}'}
		assert_equal 'http://oompa.com', @j[:url]
		assert_equal true, @j[:main]
		put '/urls/99', {json: '{"url":"http://oompa.com"}'}
		assert_equal 'Not Found', @j[:title]
		put '/urls/8', {json: '{"main":"boop"}'}
		assert @j[:title].include? 'invalid input syntax'
	end

	def test_get_formletters
		get '/formletters'
		assert_equal %w(five four one six three two), @j.map {|x| x[:title]} # alphabetized
	end

	def test_create_formletter
		post '/formletters', {title: 'new title'}
		assert_equal 7, @j[:id]
		assert_equal nil, @j[:body]
		assert_equal nil, @j[:explanation]
		assert_equal 'new title', @j[:title]
	end

	def test_update_formletter
		put '/formletters/6', {json: '{"title":"nu title", "body":"a body", "explanation":"weak", "ignore":"this"}'}
		assert_equal 'nu title', @j[:title]
		assert_equal 'a body', @j[:body]
		assert_equal 'weak', @j[:explanation]
		put '/formletters/6', {json: '{"title":"one"}'}
		assert_equal 'application/problem+json', @res.headers['content-type']
		assert @j[:title].include? 'unique constraint'
		put '/formletters/99', {json: '{"title":"one"}'}
		assert_equal 'Not Found', @j[:title]
	end

	def test_delete_formletter
		delete '/formletters/6'
		assert_equal 'meh', @j[:body]
		delete '/formletters/6'
		assert_equal 'Not Found', @j[:title]
	end

	def test_parsed_formletter
		get '/people/1/formletters/1'
		assert_equal 'Your email is derek@sivers.org. Here is your URL: https://sivers.org/u/1/Dyh15IHs', @j[:body]
		get '/people/99/formletters/1'
		assert_nil @j[:body]
		get '/people/1/formletters/99'
		assert_nil @j[:body]
	end

	def test_all_countries
		get '/locations'
		assert_equal 242, @j.size
		assert_equal({code: 'AF', name: 'Afghanistan'}, @j[0])
		assert_equal({code: 'ZW', name: 'Zimbabwe'}, @j[241])
	end

	def test_country_names
		get '/country_names'
		assert_equal 242, @j.size
		assert_equal 'New Zealand', @j[:NZ]
		assert_equal 'Singapore', @j[:SG]
	end

	def test_country_count
		get '/countries'
		assert_equal 6, @j.size
		assert_equal({country: 'US', count: 3}, @j[0])
		assert_equal({country: 'CN', count: 1}, @j[1])
	end

	def test_state_count
		get '/states/US'
		assert_equal({state: 'PA', count: 3}, @j[0])
		get '/states/IT'
		assert_equal 'Not Found', @j[:title]
	end

	def test_city_count
		get '/cities/GB'
		assert_equal({city: 'London', count: 1}, @j[0])
		get '/cities/US/PA'
		assert_equal({city: 'Hershey', count: 3}, @j[0])
		get '/cities/US/CA'
		assert_equal 'Not Found', @j[:title]
	end

	def test_people_from
		get '/where/SG'
		assert_equal 'Derek Sivers', @j[0][:name]
		get '/where/GB?state=England'
		assert_equal 'Veruca Salt', @j[0][:name]
		get '/where/CN?city=Shanghai'
		assert_equal 'gong@li.cn', @j[0][:email]
		get '/where/US?state=PA&city=Hershey'
		assert_equal 3, @j.size
		assert_equal [2, 4, 5], @j.map {|x| x[:id]}
	end

	def test_get_stats
		get '/stats/listype'
		assert_equal 'some', @j[0][:value]
		assert_equal 'Willy Wonka', @j[0][:person][:name]
		get '/stats/listype/all'
		assert_equal 'all', @j[0][:value]
		assert_equal 'Derek Sivers', @j[0][:person][:name]
		get '/stats/nothing'
		assert_equal [], @j
	end

	def test_get_stat_count
		get '/statcount/listype'
		assert_equal %w(all some), @j.map {|x| x[:value]}
		get '/statcount'
		assert_equal({name: 'listype', count: 2}, @j[1])
	end
end
