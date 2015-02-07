require '../test_tools.rb'

class TestPeepsAPI < Minitest::Test
	include JDB

	def test_unopened_email_count
		qry("unopened_email_count(1)")
		assert_equal %w(derek@sivers we@woodegg), @j.keys
		assert_equal({'woodegg' => 1, 'not-derek' => 1}, @j['we@woodegg'])
		qry("unopened_email_count(4)")
		assert_equal %w(we@woodegg), @j.keys
		qry("unopened_email_count(3)")
		assert_equal({}, @j)
	end

	def test_unopened_emails
		qry("unopened_emails(1, 'we@woodegg', 'woodegg')")
		assert_instance_of Array, @j
		assert_equal 1, @j.size
		assert_equal 'I refuse to wait', @j[0]['subject']
		assert_nil @j[0]['body']
		qry("unopened_emails(3, 'we@woodegg', 'woodegg')")
		assert_equal [], @j
	end

	def test_open_next_email
		qry("open_next_email(1, 'we@woodegg', 'woodegg')")
		assert_equal 8, @j['id']
		assert_equal 1, @j['openor']['id']
		assert_equal 'Derek Sivers', @j['openor']['name']
		assert_match /^\d{4}-\d{2}-\d{2}/, @j['opened_at']
		assert_equal 'I refuse to wait', @j['subject']
		assert_equal 'I refuse to wait', @j['body']
		qry("open_next_email(1, 'we@woodegg', 'woodegg')")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
	end

	def test_opened_emails
		qry("opened_emails(1)")
		assert_instance_of Array, @j
		assert_equal 1, @j.size
		assert_equal 'I want that Wood Egg book now', @j[0]['subject']
		qry("opened_emails(3)")
		assert_equal [], @j
	end

	def test_get_email
		qry("get_email(1, 2)")
		assert_equal 4, @j['answer_id']
		qry("get_email(1, 4)")
		assert_equal 2, @j['reference_id']
		qry("get_email(1, 8)")
		assert_equal 'I refuse to wait', @j['subject']
		assert_equal 'Derek Sivers', @j['openor']['name']
		qry("get_email(1, 6)")
		assert_equal '2014-05-21', @j['opened_at'][0,10]
		qry("get_email(3, 6)")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'about:blank', @j['type']
		assert_equal 'Not Found', @j['title']
		assert_equal 404, @j['status']
	end

	def test_update_email
		qry("update_email(1, 8, $1)", ['{"subject":"boop", "ig":"nore"}'])
		assert_equal 'boop', @j['subject']
		qry("update_email(3, 8, $1)", ['{"subject":"boop", "ig":"nore"}'])
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
	end

	def test_update_email_errors
		qry("update_email(1, 8, $1)", ['{"opened_by":"boop"}'])
		assert_equal 'application/problem+json', @res[0]['mime']
		assert @j['type'].include? '22P02'
		assert @j['title'].include? 'invalid input syntax for integer'
		assert @j['detail'].include? 'jsonupdate'
	end

	def test_delete_email
		qry("delete_email(1, 8)")
		assert_equal 'application/json', @res[0]['mime']
		assert_equal 'I refuse to wait', @j['subject']
		qry("delete_email(1, 8)")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
		qry("delete_email(3, 1)")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
	end

	def test_close_email
		qry("close_email(4, 6)")
		assert_equal 4, @j['closor']['id']
	end

	def test_unread_email
		qry("unread_email(4, 6)")
		assert_nil @j['opened_at']
		assert_nil @j['openor']
	end

	def test_not_my_email
		qry("not_my_email(4, 6)")
		assert_nil @j['opened_at']
		assert_nil @j['openor']
		assert_equal 'not-gong', @j['category']
	end

	def test_reply_to_email
		qry("reply_to_email(4, 8, 'Groovy, baby')")
		assert_equal 11, @j['id']
		assert_equal 3, @j['person_id']
		assert_match /\A[0-9]{17}\.3@sivers.org\Z/, @j['message_id']
		assert_equal @j['message_id'][0,12], Time.now.strftime('%Y%m%d%H%M')
		assert @j['body'].include? 'Groovy, baby'
		assert_match /\AHi Veruca -/, @j['body']
		assert_match /^> I refuse to wait$/, @j['body']
		assert_match %r{^Wood Egg  we@woodegg.com  http://woodegg.com\/$}, @j['body']
		assert_equal nil, @j['outgoing']
		assert_equal 're: I refuse to wait', @j['subject']
		assert_match %r{^20}, @j['created_at']
		assert_match %r{^20}, @j['opened_at']
		assert_match %r{^20}, @j['closed_at']
		assert_equal '巩俐', @j['creator']['name']
		assert_equal '巩俐', @j['openor']['name']
		assert_equal '巩俐', @j['closor']['name']
		assert_equal 'Veruca Salt', @j['their_name']
		assert_equal 'veruca@salt.com', @j['their_email']
	end

	def test_count_unknowns
		qry("count_unknowns(1)")
		assert_equal({'count' => 2}, @j)
		qry("count_unknowns(4)")
		assert_equal({'count' => 0}, @j)
	end

	def test_get_unknowns
		qry("get_unknowns(1)")
		assert_instance_of Array, @j
		assert_equal 2, @j.size
		assert_equal [5, 10], @j.map{|x| x['id']}
		qry("get_unknowns(4)")
		assert_equal [], @j
	end

	def test_get_next_unknown
		qry("get_next_unknown(1)")
		assert_equal 'New Stranger', @j['their_name']
		assert @j['body'].include? 'I have a question'
		assert @j['headers'].include? 'new@stranger.com'
		qry("get_next_unknown(4)")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
	end

	def test_set_unknown_person
		qry("set_unknown_person(1, 5, 0)")
		assert_equal 9, @j['person_id']
		qry("set_unknown_person(1, 10, 5)")
		assert_equal 5, @j['person_id']
		qry("get_person(5)")
		assert_equal 'OLD EMAIL: oompa@loompa.mm', @j['notes'].strip
	end

	def test_set_unknown_person_fail
		qry("set_unknown_person(1, 99, 5)")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
		qry("set_unknown_person(1, 5, 99)")
		assert_equal 'application/problem+json', @res[0]['mime']
		assert_equal 'Not Found', @j['title']
	end

	def test_delete_unknown
		qry("delete_unknown(1, 5)")
		assert_equal 'random question', @j['subject']
		qry("delete_unknown(1, 8)")
		assert_equal 'Not Found', @j['title']
		qry("delete_unknown(4, 10)")
		assert_equal 'Not Found', @j['title']
		qry("delete_unknown(3, 10)")
		assert_equal 'remember me?', @j['subject']
	end

	def test_create_person
		qry("create_person('  Bob Dobalina', 'MISTA@DOBALINA.COM')")
		assert_equal 9, @j['id']
		assert_equal 'Bob', @j['address']
		assert_equal 'mista@dobalina.com', @j['email']
		%w(stats urls emails).each do |k|
			assert @j.keys.include? k
			assert_equal nil, @j[k]
		end
	end

	def test_create_person_fail
		qry("create_person('', 'a@b.c')")
		assert @j['title'].include? 'no_name'
		qry("create_person('Name', 'a@b')")
		assert @j['title'].include? 'valid_email'
	end

	def test_get_person
		qry("get_person(99)")
		assert_equal 'Not Found', @j['title']
		qry("get_person(2)")
		assert_equal 'http://www.wonka.com/', @j['urls'][0]['url']
		assert_equal 'you coming by?', @j['emails'][0]['subject']
		assert_equal 'musicthoughts', @j['stats'][1]['name']
		assert_equal 'clicked', @j['stats'][1]['value']
	end

	def test_update_person
		qry("update_person(8, $1)", ['{"address":"Ms. Ono", "city": "NY", "ig":"nore"}'])
		assert_equal 'Ms. Ono', @j['address']
		assert_equal 'NY', @j['city']
	end

	def test_update_person_fail
		qry("update_person(99, $1)", ['{"country":"XXX"}'])
		assert_equal 'Not Found', @j['title']
		qry("update_person(1, $1)", ['{"country":"XXX"}'])
		assert @j['title'].include? 'value too long'
	end

	def test_delete_person
		qry("delete_person(1)")
		assert @j['title'].include? 'violates foreign key'
		qry("delete_person(99)")
		assert_equal 'Not Found', @j['title']
		qry("delete_person(5)")
		assert_equal 'Oompa Loompa', @j['name']
	end

	def test_add_url
		qry("add_url(5, 'bank.com')")
		assert_equal 'http://bank.com', @j['urls'][1]['url']
		qry("add_url(5, 'x')")
		assert_equal 'bad url', @j['title']
		qry("add_url(999, 'http://good.com')")
		assert @j['title'].include? 'violates foreign key'
	end

	def test_add_stat
		qry("add_stat(5, ' s OM e ', '  v alu e ')")
		assert_equal 'some', @j['stats'][1]['name']
		assert_equal 'v alu e', @j['stats'][1]['value']
		qry("add_stat(5, '  ', 'val')")
		assert_equal 'stats.key must not be empty', @j['title']
		qry("add_stat(5, 'key', ' ')")
		assert_equal 'stats.value must not be empty', @j['title']
		qry("add_stat(99, 'a key', 'a val')")
		assert @j['title'].include? 'violates foreign key'
	end

	def test_new_email
		qry("new_email(4, 5, 'we@woodegg', 'a subject', 'a body')")
		assert_equal 'a subject', @j['subject']
		assert_equal "Hi Oompa Loompa -\n\na body\n\n--\nWood Egg  we@woodegg.com  http://woodegg.com/", @j['body']
		qry("new_email(4, 99, 'we@woodegg', 'a subject', 'a body')")
		assert_equal 'person_id not found', @j['title']
		qry("new_email(4, 1, 'we@wo', 'a subject', 'a body')")
		assert_equal 'invalid profile', @j['title']
		qry("new_email(4, 1, 'we@woodegg', 'a subject', '  ')")
		assert_equal 'body must not be empty', @j['title']
	end
	
	def test_get_person_emails
		qry("get_person_emails(3)")
		assert_equal 4, @j.size
		assert_equal [6, 7, 8, 9], @j.map {|x| x['id']}
		assert @j[0]['body']
		assert @j[1]['message_id']
		assert @j[2]['headers']
		assert_equal false, @j[3]['outgoing']
		qry("get_person_emails(99)")
		assert_equal [], @j
	end

	def test_people_unemailed
		qry("people_unemailed()")
		assert_equal [8, 6, 5, 4, 1], @j.map {|x| x['id']}
		qry("new_email(4, 5, 'we@woodegg', 'subject', 'body')")
		qry("people_unemailed()")
		assert_equal [8, 6, 4, 1], @j.map {|x| x['id']}
	end

	def test_people_search
		qry("people_search('on')")
		assert_instance_of Array, @j
		assert_equal [7, 2, 8], @j.map {|x| x['id']}
		qry("people_search('x')")
		assert_equal 'search term too short', @j['title']
	end

	def test_delete_stat
		qry("delete_stat(8)")
		assert_equal 'interview', @j['value']
		qry("delete_stat(8)")
		assert_equal 'Not Found', @j['title']
	end

	def test_delete_url
		qry("delete_url(8)")
		assert_equal 'http://oompa.loompa', @j['url']
		qry("delete_url(8)")
		assert_equal 'Not Found', @j['title']
	end

	def test_update_url
		qry("update_url(8, $1)", ['{"url":"http://oompa.com", "main": true}'])
		assert_equal 'http://oompa.com', @j['url']
		assert_equal true, @j['main']
		qry("update_url(99, $1)", ['{"url":"http://oompa.com"}'])
		assert_equal 'Not Found', @j['title']
		qry("update_url(8, $1)", ['{"main":"boop"}'])
		assert @j['title'].include? 'invalid input syntax'
	end

	def test_get_formletters
		qry("get_formletters()")
		assert_equal %w(five four one six three two), @j.map {|x| x['title']} # alphabetized
	end

	def test_create_formletter
		qry("create_formletter('new title')")
		assert_equal 7, @j['id']
		assert_equal nil, @j['body']
		assert_equal nil, @j['explanation']
		assert_equal 'new title', @j['title']
	end

	def test_update_formletter
		qry("update_formletter(6, $1)", ['{"title":"nu title", "body":"a body", "explanation":"weak", "ignore":"this"}'])
		assert_equal 'nu title', @j['title']
		assert_equal 'a body', @j['body']
		assert_equal 'weak', @j['explanation']
		qry("update_formletter(6, $1)", ['{"title":"one"}'])
		assert_equal 'application/problem+json', @res[0]['mime']
		assert @j['title'].include? 'unique constraint'
		qry("update_formletter(99, $1)", ['{"title":"one"}'])
		assert_equal 'Not Found', @j['title']
	end

	def test_delete_formletter
		qry("delete_formletter(6)")
		assert_equal 'meh', @j['body']
		qry("delete_formletter(6)")
		assert_equal 'Not Found', @j['title']
	end

	def test_parsed_formletter
		qry("parsed_formletter(1, 1)")
		assert_equal 'Your email is derek@sivers.org. Here is your URL: https://sivers.org/u/1/Dyh15IHs', @j['body']
		qry("parsed_formletter(99, 1)")
		assert_nil @j['body']
		qry("parsed_formletter(1, 99)")
		assert_nil @j['body']
	end

	def test_country_count
		qry("country_count()")
		assert_equal 6, @j.size
		assert_equal({'country'=>'US', 'count'=>3}, @j[0])
		assert_equal({'country'=>'CN', 'count'=>1}, @j[1])
	end

	def test_state_count
		qry("state_count('US')")
		assert_equal({'state'=>'PA', 'count'=>3}, @j[0])
		qry("state_count('IT')")
		assert_equal 'Not Found', @j['title']
	end

	def test_city_count
		qry("city_count('GB')")
		assert_equal({'city'=>'London', 'count'=>1}, @j[0])
		qry("city_count('US', 'PA')")
		assert_equal({'city'=>'Hershey', 'count'=>3}, @j[0])
		qry("city_count('US', 'CA')")
		assert_equal 'Not Found', @j['title']
	end

	def test_people_from
		qry("people_from_country('SG')")
		assert_equal 'Derek Sivers', @j[0]['name']
		qry("people_from_state('GB', 'England')")
		assert_equal 'Veruca Salt', @j[0]['name']
		qry("people_from_city('CN', 'Shanghai')")
		assert_equal 'gong@li.cn', @j[0]['email']
		qry("people_from_state_city('US', 'PA', 'Hershey')")
		assert_equal 3, @j.size
		assert_equal [2, 4, 5], @j.map {|x| x['id']}
	end

	def test_get_stats
		qry("get_stats('listype')")
		assert_equal 'some', @j[0]['value']
		assert_equal 'Willy Wonka', @j[0]['person']['name']
		qry("get_stats('listype', 'all')")
		assert_equal 'all', @j[0]['value']
		assert_equal 'Derek Sivers', @j[0]['person']['name']
		qry("get_stats('nothing')")
		assert_equal [], @j
	end

	def test_get_stat_count
		qry("get_stat_value_count('listype')")
		assert_equal %w(all some), @j.map {|x| x['value']}
		qry("get_stat_name_count()")
		assert_equal({'name' => 'listype', 'count' => 2}, @j[1])
	end
end

