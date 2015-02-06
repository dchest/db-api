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

	def test_unopened_email_count
		get '/emails/unopened'
		assert_equal %w(derek@sivers we@woodegg), @j.keys
		assert_equal({'woodegg' => 1, 'not-derek' => 1}, @j['we@woodegg'])
		@auth = @emailer_4
		get '/emails/unopened'
		assert_equal %w(we@woodegg), @j.keys
		@auth = @emailer_3
		get '/emails/unopened'
		assert_equal({}, @j)
	end

	def test_unopened_emails
		res = DB.exec("SELECT * FROM unopened_emails(1, 'we@woodegg', 'woodegg')")
		j = JSON.parse(res[0]['js'])
		assert_instance_of Array, j
		assert_equal 1, j.size
		assert_equal 'I refuse to wait', j[0]['subject']
		assert_nil j[0]['body']
		res = DB.exec("SELECT * FROM unopened_emails(3, 'we@woodegg', 'woodegg')")
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_open_next_email
		res = DB.exec("SELECT * FROM open_next_email(1, 'we@woodegg', 'woodegg')")
		j = JSON.parse(res[0]['js'])
		assert_equal 8, j['id']
		assert_equal 1, j['openor']['id']
		assert_equal 'Derek Sivers', j['openor']['name']
		assert_match /^\d{4}-\d{2}-\d{2}/, j['opened_at']
		assert_equal 'I refuse to wait', j['subject']
		assert_equal 'I refuse to wait', j['body']
		res = DB.exec("SELECT * FROM open_next_email(1, 'we@woodegg', 'woodegg')")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_opened_emails
		res = DB.exec("SELECT * FROM opened_emails(1)")
		j = JSON.parse(res[0]['js'])
		assert_instance_of Array, j
		assert_equal 1, j.size
		assert_equal 'I want that Wood Egg book now', j[0]['subject']
		res = DB.exec("SELECT * FROM opened_emails(3)")
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_get_email
		res = DB.exec("SELECT * FROM get_email(1, 8)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'I refuse to wait', j['subject']
		assert_equal 'Derek Sivers', j['openor']['name']
		res = DB.exec("SELECT * FROM get_email(1, 6)")
		j = JSON.parse(res[0]['js'])
		assert_equal '2014-05-21', j['opened_at'][0,10]
		res = DB.exec("SELECT * FROM get_email(3, 6)")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'about:blank', j['type']
		assert_equal 'Not Found', j['title']
		assert_equal 404, j['status']
	end

	def test_update_email
		res = DB.exec_params("SELECT * FROM update_email(1, 8, $1)", ['{"subject":"boop", "ig":"nore"}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'boop', j['subject']
		res = DB.exec_params("SELECT * FROM update_email(3, 8, $1)", ['{"subject":"boop", "ig":"nore"}'])
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_update_email_errors
		res = DB.exec_params("SELECT * FROM update_email(1, 8, $1)", ['{"opened_by":"boop"}'])
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert j['type'].include? '22P02'
		assert j['title'].include? 'invalid input syntax for integer'
		assert j['detail'].include? 'jsonupdate'
	end

	def test_delete_email
		res = DB.exec("SELECT * FROM delete_email(1, 8)")
		assert_equal 'application/json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'I refuse to wait', j['subject']
		res = DB.exec("SELECT * FROM delete_email(1, 8)")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec("SELECT * FROM delete_email(3, 1)")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_close_email
		res = DB.exec("SELECT * FROM close_email(4, 6)")
		j = JSON.parse(res[0]['js'])
		assert_equal 4, j['closor']['id']
	end

	def test_unread_email
		res = DB.exec("SELECT * FROM unread_email(4, 6)")
		j = JSON.parse(res[0]['js'])
		assert_nil j['opened_at']
		assert_nil j['openor']
	end

	def test_not_my_email
		res = DB.exec("SELECT * FROM not_my_email(4, 6)")
		j = JSON.parse(res[0]['js'])
		assert_nil j['opened_at']
		assert_nil j['openor']
		assert_equal 'not-gong', j['category']
	end

	def test_reply_to_email
		res = DB.exec("SELECT * FROM reply_to_email(4, 8, 'Groovy, baby')")
		j = JSON.parse(res[0]['js'])
		assert_equal 11, j['id']
		assert_equal 3, j['person_id']
		assert_match /\A[0-9]{17}\.3@sivers.org\Z/, j['message_id']
		assert_equal j['message_id'][0,12], Time.now.strftime('%Y%m%d%H%M')
		assert j['body'].include? 'Groovy, baby'
		assert_match /\AHi Veruca -/, j['body']
		assert_match /^> I refuse to wait$/, j['body']
		assert_match %r{^Wood Egg  we@woodegg.com  http://woodegg.com\/$}, j['body']
		assert_equal nil, j['outgoing']
		assert_equal 're: I refuse to wait', j['subject']
		assert_match %r{^20}, j['created_at']
		assert_match %r{^20}, j['opened_at']
		assert_match %r{^20}, j['closed_at']
		assert_equal '巩俐', j['creator']['name']
		assert_equal '巩俐', j['openor']['name']
		assert_equal '巩俐', j['closor']['name']
		assert_equal 'Veruca Salt', j['their_name']
		assert_equal 'veruca@salt.com', j['their_email']
	end

	def test_count_unknowns
		res = DB.exec("SELECT * FROM count_unknowns(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal({'count' => 2}, j)
		res = DB.exec("SELECT * FROM count_unknowns(4)")
		j = JSON.parse(res[0]['js'])
		assert_equal({'count' => 0}, j)
	end

	def test_get_unknowns
		res = DB.exec("SELECT * FROM get_unknowns(1)")
		j = JSON.parse(res[0]['js'])
		assert_instance_of Array, j
		assert_equal 2, j.size
		assert_equal [5, 10], j.map{|x| x['id']}
		res = DB.exec("SELECT * FROM get_unknowns(4)")
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_get_next_unknown
		res = DB.exec("SELECT * FROM get_next_unknown(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'New Stranger', j['their_name']
		assert j['body'].include? 'I have a question'
		assert j['headers'].include? 'new@stranger.com'
		res = DB.exec("SELECT * FROM get_next_unknown(4)")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_set_unknown_person
		res = DB.exec("SELECT * FROM set_unknown_person(1, 5, 0)")
		j = JSON.parse(res[0]['js'])
		assert_equal 9, j['person_id']
		res = DB.exec("SELECT * FROM set_unknown_person(1, 10, 5)")
		j = JSON.parse(res[0]['js'])
		assert_equal 5, j['person_id']
		res = DB.exec("SELECT notes FROM people WHERE id = 5")
		assert_equal 'OLD EMAIL: oompa@loompa.mm', res[0]['notes'].strip
	end

	def test_set_unknown_person_fail
		res = DB.exec("SELECT * FROM set_unknown_person(1, 99, 5)")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec("SELECT * FROM set_unknown_person(1, 5, 99)")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_delete_unknown
		res = DB.exec("SELECT * FROM delete_unknown(1, 5)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'random question', j['subject']
		res = DB.exec("SELECT * FROM delete_unknown(1, 8)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec("SELECT * FROM delete_unknown(4, 10)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec("SELECT * FROM delete_unknown(3, 10)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'remember me?', j['subject']
	end

	def test_create_person
		res = DB.exec("SELECT * FROM create_person('  Bob Dobalina', 'MISTA@DOBALINA.COM')")
		j = JSON.parse(res[0]['js'])
		assert_equal 9, j['id']
		assert_equal 'Bob', j['address']
		assert_equal 'mista@dobalina.com', j['email']
		%w(stats urls emails).each do |k|
			assert j.keys.include? k
			assert_equal nil, j[k]
		end
	end

	def test_create_person_fail
		res = DB.exec("SELECT * FROM create_person('', 'a@b.c')")
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'no_name'
		res = DB.exec("SELECT * FROM create_person('Name', 'a@b')")
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'valid_email'
	end

	def test_get_person
		res = DB.exec("SELECT * FROM get_person(99)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec("SELECT * FROM get_person(2)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'http://www.wonka.com/', j['urls'][0]['url']
		assert_equal 'you coming by?', j['emails'][0]['subject']
		assert_equal 'musicthoughts', j['stats'][1]['name']
		assert_equal 'clicked', j['stats'][1]['value']
	end

	def test_update_person
		res = DB.exec_params("SELECT * FROM update_person(8, $1)", ['{"address":"Ms. Ono", "city": "NY", "ig":"nore"}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'Ms. Ono', j['address']
		assert_equal 'NY', j['city']
	end

	def test_update_person_fail
		res = DB.exec_params("SELECT * FROM update_person(99, $1)", ['{"country":"XXX"}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec_params("SELECT * FROM update_person(1, $1)", ['{"country":"XXX"}'])
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'value too long'
	end

	def test_delete_person
		res = DB.exec("SELECT * FROM delete_person(1)")
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'violates foreign key'
		res = DB.exec("SELECT * FROM delete_person(99)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec("SELECT * FROM delete_person(5)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Oompa Loompa', j['name']
	end

	def test_add_url
		res = DB.exec("SELECT * FROM add_url(5, 'bank.com')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'http://bank.com', j['urls'][1]['url']
		res = DB.exec("SELECT * FROM add_url(5, 'x')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'bad url', j['title']
		res = DB.exec("SELECT * FROM add_url(999, 'http://good.com')")
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'violates foreign key'
	end

	def test_add_stat
		res = DB.exec("SELECT * FROM add_stat(5, ' s OM e ', '  v alu e ')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'some', j['stats'][1]['name']
		assert_equal 'v alu e', j['stats'][1]['value']
		res = DB.exec("SELECT * FROM add_stat(5, '  ', 'val')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'stats.key must not be empty', j['title']
		res = DB.exec("SELECT * FROM add_stat(5, 'key', ' ')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'stats.value must not be empty', j['title']
		res = DB.exec("SELECT * FROM add_stat(99, 'a key', 'a val')")
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'violates foreign key'
	end

	def test_new_email
		res = DB.exec("SELECT * FROM new_email(4, 5, 'we@woodegg', 'a subject', 'a body')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'a subject', j['subject']
		assert_equal "Hi Oompa Loompa -\n\na body\n\n--\nWood Egg  we@woodegg.com  http://woodegg.com/", j['body']
		res = DB.exec("SELECT * FROM new_email(4, 99, 'we@woodegg', 'a subject', 'a body')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'person_id not found', j['title']
		res = DB.exec("SELECT * FROM new_email(4, 1, 'we@wo', 'a subject', 'a body')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'invalid profile', j['title']
		res = DB.exec("SELECT * FROM new_email(4, 1, 'we@woodegg', 'a subject', '  ')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'body must not be empty', j['title']
	end
	
	def test_get_person_emails
		res = DB.exec("SELECT * FROM get_person_emails(3)")
		j = JSON.parse(res[0]['js'])
		assert_equal 4, j.size
		assert_equal [6, 7, 8, 9], j.map {|x| x['id']}
		assert j[0]['body']
		assert j[1]['message_id']
		assert j[2]['headers']
		assert_equal false, j[3]['outgoing']
		res = DB.exec("SELECT * FROM get_person_emails(99)")
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_people_unemailed
		res = DB.exec("SELECT * FROM people_unemailed()")
		j = JSON.parse(res[0]['js'])
		assert_equal [8, 6, 5, 4, 1], j.map {|x| x['id']}
		DB.exec("SELECT * FROM new_email(4, 5, 'we@woodegg', 'subject', 'body')")
		res = DB.exec("SELECT * FROM people_unemailed()")
		j = JSON.parse(res[0]['js'])
		assert_equal [8, 6, 4, 1], j.map {|x| x['id']}
	end

	def test_people_search
		res = DB.exec("SELECT * FROM people_search('on')")
		j = JSON.parse(res[0]['js'])
		assert_instance_of Array, j
		assert_equal [7, 2, 8], j.map {|x| x['id']}
		res = DB.exec("SELECT * FROM people_search('x')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'search term too short', j['title']
	end

	def test_delete_stat
		res = DB.exec("SELECT * FROM delete_stat(8)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'interview', j['value']
		res = DB.exec("SELECT * FROM delete_stat(8)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_delete_url
		res = DB.exec("SELECT * FROM delete_url(8)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'http://oompa.loompa', j['url']
		res = DB.exec("SELECT * FROM delete_url(8)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_update_url
		res = DB.exec_params("SELECT * FROM update_url(8, $1)", ['{"url":"http://oompa.com", "main": true}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'http://oompa.com', j['url']
		assert_equal true, j['main']
		res = DB.exec_params("SELECT * FROM update_url(99, $1)", ['{"url":"http://oompa.com"}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
		res = DB.exec_params("SELECT * FROM update_url(8, $1)", ['{"main":"boop"}'])
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'invalid input syntax'
	end

	def test_get_formletters
		res = DB.exec("SELECT * FROM get_formletters()")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(five four one six three two), j.map {|x| x['title']} # alphabetized
	end

	def test_create_formletter
		res = DB.exec("SELECT * FROM create_formletter('new title')")
		j = JSON.parse(res[0]['js'])
		assert_equal 7, j['id']
		assert_equal nil, j['body']
		assert_equal nil, j['explanation']
		assert_equal 'new title', j['title']
	end

	def test_update_formletter
		res = DB.exec_params("SELECT * FROM update_formletter(6, $1)", ['{"title":"nu title", "body":"a body", "explanation":"weak", "ignore":"this"}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'nu title', j['title']
		assert_equal 'a body', j['body']
		assert_equal 'weak', j['explanation']
		res = DB.exec_params("SELECT * FROM update_formletter(6, $1)", ['{"title":"one"}'])
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert j['title'].include? 'unique constraint'
		res = DB.exec_params("SELECT * FROM update_formletter(99, $1)", ['{"title":"one"}'])
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_delete_formletter
		res = DB.exec("SELECT * FROM delete_formletter(6)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'meh', j['body']
		res = DB.exec("SELECT * FROM delete_formletter(6)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_parsed_formletter
		res = DB.exec("SELECT * FROM parsed_formletter(1, 1)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Your email is derek@sivers.org. Here is your URL: https://sivers.org/u/1/Dyh15IHs', j['body']
		res = DB.exec("SELECT * FROM parsed_formletter(99, 1)")
		j = JSON.parse(res[0]['js'])
		assert_nil j['body']
		res = DB.exec("SELECT * FROM parsed_formletter(1, 99)")
		j = JSON.parse(res[0]['js'])
		assert_nil j['body']
	end

	def test_country_count
		res = DB.exec("SELECT * FROM country_count()")
		j = JSON.parse(res[0]['js'])
		assert_equal 6, j.size
		assert_equal({'country'=>'US', 'count'=>3}, j[0])
		assert_equal({'country'=>'CN', 'count'=>1}, j[1])
	end

	def test_state_count
		res = DB.exec("SELECT * FROM state_count('US')")
		j = JSON.parse(res[0]['js'])
		assert_equal({'state'=>'PA', 'count'=>3}, j[0])
		res = DB.exec("SELECT * FROM state_count('IT')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_city_count
		res = DB.exec("SELECT * FROM city_count('GB')")
		j = JSON.parse(res[0]['js'])
		assert_equal({'city'=>'London', 'count'=>1}, j[0])
		res = DB.exec("SELECT * FROM city_count('US', 'PA')")
		j = JSON.parse(res[0]['js'])
		assert_equal({'city'=>'Hershey', 'count'=>3}, j[0])
		res = DB.exec("SELECT * FROM city_count('US', 'CA')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_people_from
		res = DB.exec("SELECT * FROM people_from_country('SG')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Derek Sivers', j[0]['name']
		res = DB.exec("SELECT * FROM people_from_state('GB', 'England')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Veruca Salt', j[0]['name']
		res = DB.exec("SELECT * FROM people_from_city('CN', 'Shanghai')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'gong@li.cn', j[0]['email']
		res = DB.exec("SELECT * FROM people_from_state_city('US', 'PA', 'Hershey')")
		j = JSON.parse(res[0]['js'])
		assert_equal 3, j.size
		assert_equal [2, 4, 5], j.map {|x| x['id']}
	end

	def test_get_stats
		res = DB.exec("SELECT * FROM get_stats('listype')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'some', j[0]['value']
		assert_equal 'Willy Wonka', j[0]['person']['name']
		res = DB.exec("SELECT * FROM get_stats('listype', 'all')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'all', j[0]['value']
		assert_equal 'Derek Sivers', j[0]['person']['name']
		res = DB.exec("SELECT * FROM get_stats('nothing')")
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_get_stat_count
		res = DB.exec("SELECT * FROM get_stat_value_count('listype')")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(all some), j.map {|x| x['value']}
		res = DB.exec("SELECT * FROM get_stat_name_count()")
		j = JSON.parse(res[0]['js'])
		assert_equal({'name' => 'listype', 'count' => 2}, j[1])
	end
end

