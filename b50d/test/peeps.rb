SCHEMA = File.read('../../peeps/schema.sql')
FIXTURES = File.read('../../peeps/fixtures.sql')
require '../../test_tools.rb'

require '../lib/b50d/peeps.rb'

class TestPeep < Minitest::Test

	def setup
		super
		@p = B50D::Peeps.new('aaaaaaaa', 'bbbbbbbb', 'test')
	end

	def test_auth
		x = B50D::Peeps.auth('test', 'derek@sivers.org', 'derek', 'Peep')
		assert_equal 1, x[:person_id]
		assert_equal 'aaaaaaaa', x[:akey]
		assert_equal 'bbbbbbbb', x[:apass]
		assert_equal %w(Peep SiversComments MuckworkManager), x[:apis]
		x = B50D::Peeps.auth('test', 'derek@sivers.net', 'wrong', 'Peep')
		assert_equal false, x
	end

	def test_unopened_email_count
		h = {:'derek@sivers'=>{:derek=>1}, :'we@woodegg'=>{:woodegg=>1, :'not-derek'=>1}}
		assert_equal h, @p.unopened_email_count
	end

	def test_open_emails
		y = @p.open_emails
		assert_instance_of Array, y
		assert_equal 1, y.size
		x = y.pop
		assert_equal 6, x[:id]
		assert_match /2014-05-20/, x[:created_at]
		assert_equal 'I want that Wood Egg book now', x[:subject]
		assert_equal 'Veruca Salt', x[:their_name]
	end

	def test_unknowns
		y = @p.unknowns
		assert_instance_of Array, y
		assert_equal 2, y.size
		x = y.shift
		assert_equal 'new@stranger.com', x[:their_email]
		x = y.shift
		assert_equal 'remember me?', x[:subject]
	end

	def test_unknowns_count
		assert_equal({:count => 2}, @p.unknowns_count)
	end

	def test_next_unknown
		x = @p.next_unknown
		assert_equal 'new@stranger.com', x[:their_email]
		assert_equal 5, x[:id]
	end

	def test_unknown_is_person
		email_id = 10 
		person_id = 5
		x = @p.unknown_is_person(email_id, person_id)
		assert_equal 5, x[:person][:id]
	end

	def test_unknown_is_new_person
		email_id = 5
		x = @p.unknown_is_new_person(email_id)
		assert x[:person][:id] > 8
	end

	def test_delete_unknown
		email_id = 5
		x = @p.delete_unknown(email_id)
		assert_equal 'random question', x[:subject]
	end

	def test_emails_unopened
		y = @p.emails_unopened('derek@sivers', 'derek')
		assert_instance_of Array, y
		assert_equal 1, y.size
		x = y.shift
		assert_equal 'getting personal', x[:subject]
		y = @p.emails_unopened('we@woodegg', 'not-derek')
		x = y.shift
		assert_equal 'Veruca Salt', x[:their_name]
	end

	def test_next_unopened_email
		x = @p.next_unopened_email('we@woodegg', 'woodegg')
		assert_equal 'I refuse to wait', x[:subject]
		assert_equal 'I refuse to wait', x[:body]
	end

	def test_open_email
		x = @p.open_email(9)
		assert_equal 'getting personal', x[:subject]
		assert_equal 'Wood Egg is not replying to my last three emails!', x[:body]
		assert_equal 'CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7D@mail.gmail.com', x[:message_id]
		assert x[:headers].include? x[:message_id]
		assert x[:headers].include? x[:subject]
		assert_match /^20/, x[:opened_at]
		aa = x[:attachments]
		assert_equal 2, aa.size
	end

	def test_update_email
		x = @p.update_email(6, {category: 'blah', body: 'boo'})
		assert_equal 'blah', x[:category]
		assert_equal 'boo', x[:body]
	end

	def test_delete_email
		x = @p.delete_email(9)
		assert_equal 'getting personal', x[:subject]
		refute @p.open_email(9)
		assert_equal 'Not Found', @p.error
	end

	def test_close_email
		x = @p.close_email(6)
		assert_match /^20/, x[:closed_at]
	end

	def test_unread_email
		x = @p.open_email(6)
		open1 = x[:opened_at]
		assert @p.unread_email(6)
		x = @p.open_email(6)
		assert x[:opened_at] > open1
	end

	def test_not_my_email
		x = @p.open_email(6)
		open1 = x[:opened_at]
		assert @p.not_my_email(6)
		x = @p.open_email(6)
		assert x[:opened_at] > open1
		assert_match /^not-/, x[:category]
	end

	def test_reply_to_email
		body = 'fantastic then'
		y = @p.reply_to_email(6, body)
		assert y[:id] > 10 
		assert_equal 6, y[:reference_id]
		assert y[:body].include? body
		x = @p.open_email(6)
		assert_equal y[:id], x[:answer_id]
	end

	def test_new_person
		name = 'ップ 値上げ続々'
		email = 'xo@sd.jp'
		x = @p.new_person(name, email)
		assert_equal 9, x[:id]
		assert_equal name, x[:name]
		assert_equal email, x[:email]
		assert_equal 'ップ', x[:address]
	end

	def test_get_person
		x = @p.get_person(2)
		assert_equal 2, x[:id]
		assert_equal 'Willy Wonka', x[:name]
		assert_equal 'Mr. Wonka', x[:address]
		assert_equal 'willy@wonka.com', x[:email]
		assert_equal 'Wonka Chocolate Inc', x[:company]
		assert_equal 'Hershey', x[:city]
		assert_equal 'PA', x[:state]
		assert_equal 'US', x[:country]
		assert_nil x[:notes]
		assert_equal '+1 215 555 1034', x[:phone]
		assert_equal 'some', x[:listype]
		assert_nil x[:categorize_as]
		assert_match /^2000-01-01/, x[:created_at]
		assert_instance_of Array, x[:stats]
		assert_equal 2, x[:stats].size
		y = x[:stats].shift
		assert_equal 3, y[:id]
		assert_equal 'listype', y[:name]
		assert_equal 'some', y[:value]
		assert_instance_of Array, x[:urls]
		assert_equal 3, x[:urls].size
		y = x[:urls].shift
		assert_equal 'http://www.wonka.com/', y[:url]
		assert_equal true, y[:main]
		assert_instance_of Array, x[:emails]
		assert_equal 2, x[:emails].size
		y = x[:emails].shift
		assert_equal 'you coming by?', y[:subject]
	end

	def test_get_person_lopass
		refute @p.get_person_lopass(2, 'abcd')
		x = @p.get_person_lopass(2, 'R5Gf')
		assert_equal 2, x[:id]
		assert_equal 'Wonka Chocolate Inc', x[:company]
	end

	def test_get_person_newpass
		refute @p.get_person_newpass(2, 'abcdefgh')
		x = @p.get_person_newpass(2, 'NvaGAkHK')
		assert_equal 2, x[:id]
		assert_equal 'Wonka Chocolate Inc', x[:company]
	end

	def test_get_person_password
		x = @p.get_person_password('derek@sivers.org', 'derek')
		assert_equal 'Derek Sivers', x[:name]
		x = @p.get_person_password(' Derek@Sivers.org  ', 'derek')
		assert_equal 'Derek Sivers', x[:name]
		refute @p.get_person_password('derek@sivers.org', 'deRek')
		refute @p.get_person_password('derek@sivers.org', '')
		refute @p.get_person_password('', 'derek')
		refute @p.get_person_password(nil, nil)
	end

	def test_get_person_cookie
		x = @p.get_person_cookie('2a9c0226c871c711a5e944bec5f6df5d:18e8b4f0a05db21eed590e96eb27be9c')
		assert_equal 'Derek Sivers', x[:name]
		refute @p.get_person_cookie('c776d5b6249a9fb45eec8d2af2fd7954:18e8b4f0a05db21eed590e96eb27be9f')
		refute @p.get_person_cookie('95fcacd3d2c6e3e006906cc4f4cdf908:18e8b4f0a05db21eed590e96eb27be9c')
	end

	def test_cookie_from_id
		x = @p.cookie_from_id(3, 'woodegg.com')
		assert_match /\A[a-f0-9]{32}:[a-zA-Z0-9]{32}\Z/, x[:cookie]
		x = @p.get_person_cookie(x[:cookie])
		assert_equal 'Veruca Salt', x[:name]
		refute @p.cookie_from_id(99, 'woodegg.com')
		refute @p.cookie_from_id(nil, 'woodegg.com')
		refute @p.cookie_from_id(4, nil)
	end

	def test_cookie_from_login
		x = @p.cookie_from_login('derek@sivers.org', 'derek', 'sivers.org')
		assert_match /\A[a-f0-9]{32}:[a-zA-Z0-9]{32}\Z/, x[:cookie]
		x = @p.cookie_from_login(' Derek@Sivers.org  ', 'derek', 'muckwork.com')
		assert_match /\A[a-f0-9]{32}:[a-zA-Z0-9]{32}\Z/, x[:cookie]
		refute @p.cookie_from_login('derek@sivers.org', 'deRek', 'sivers.org')
		refute @p.cookie_from_login('', 'derek', 'muckwork.com')
		refute @p.cookie_from_login(nil, nil, nil)
		x = @p.cookie_from_login('veruca@salt.com', 'veruca', 'muckwork.com')
		x = @p.get_person_cookie(x[:cookie])
		assert_equal 'Veruca Salt', x[:name]
	end

	def test_set_password
		nupass = 'þíŋø¥|ǫ©'
		x = @p.set_password(1, nupass)
		assert_equal 'Derek Sivers', x[:name]
		x = @p.get_person_password('derek@sivers.org', nupass)
		assert_equal 'Derek Sivers', x[:name]
		refute @p.set_password(1, 'x')
		assert_equal 'short_password', @p.error
		refute @p.set_password(1, nil)
		assert_equal 'short_password', @p.error
		refute @p.set_password(9999, 'anOKpass')
		assert_equal 'Not Found', @p.error
	end

	def test_emails_for_person
		y = @p.emails_for_person(2)
		assert_instance_of Array, y
		assert_equal 2, y.size
		x = y.pop
		assert x[:body]
		assert_equal 2, x[:person_id]
	end

	def test_update_person
		id = 5
		params = {address: 'doofus'}
		assert @p.update_person(id, params)
		x = @p.get_person(id)
		assert_equal params[:address], x[:address]
	end

	def test_delete_person
		x = @p.new_person('a name', 'a@email.com')
		assert @p.get_person(x[:id])
		assert @p.delete_person(x[:id])
		refute @p.get_person(x[:id])
	end

	def test_annihilate_person
		refute @p.annihilate_person(99)
		x = @p.annihilate_person(2)
		assert_equal 'Willy Wonka', x[:name]
		refute @p.get_person(2)
		refute @p.open_email(1)
		refute @p.get_url(3)
		# can't delete an emailer
		refute @p.annihilate_person(1)
		assert @p.error.include? 'foreign key constraint "emails_created_by_fkey"'
	end

	def test_add_url
		person_id = 4
		url = 'http://something.cc'
		assert @p.add_url(person_id, url)
		x = @p.get_person(4)
		y = x[:urls]
		assert_equal 1, y.size
		z = y.pop
		assert_equal url, z[:url]
		refute z[:main]
	end

	def test_add_stat
		person_id = 4
		key = 'akey'
		value = 'avalue'
		assert @p.add_stat(person_id, key, value)
		x = @p.get_person(4)
		y = x[:stats]
		assert_equal 1, y.size
		z = y.pop
		assert_equal key, z[:name]
		assert_equal value, z[:value]
	end

	def test_new_email_to
		person_id = 4
		body = 'Писать о творческом кризисе – это лучше, чем не писать вовсе.'
		subject = 'случайное высказывание'
		profile = 'derek@sivers'
		x = @p.new_email_to(person_id, body, subject, profile)
		assert_equal 11, x[:id]
		assert x[:body].include? body
		assert_equal subject, x[:subject]
		assert_equal profile, x[:profile]
		assert_equal 1, x[:creator][:id]
		assert_equal 1, x[:openor][:id]
		assert_equal 1, x[:closor][:id]
		assert_nil x[:outgoing]	# nil = queued to send
	end

	def test_merge_into_person
		old1 = @p.get_person(1)
		old_id = old1[:id]
		new1 = @p.new_person('Derek3', 'derek3@sivers.org')
		person_id = new1[:id]
		assert @p.merge_into_person(person_id, old_id)
		x = @p.get_person(person_id)
		assert_equal old1[:city], x[:city]
		assert_equal old1[:phone], x[:phone]
		refute_equal old1[:email], x[:email]
	end

	def test_unemailed_people
		y = @p.unemailed_people
		assert_equal [8,6,5,4,1], y.map {|x| x[:id]}
	end

	def test_person_search
		y = @p.person_search('on')
		assert_equal [2, 7, 8], y.map {|x| x[:id]}.sort
		y = @p.person_search('chocolate')
		assert_equal [2], y.map {|x| x[:id]}
		y = @p.person_search('DEREK')
		assert_equal [1], y.map {|x| x[:id]}
	end

	def test_delete_stat
		a = @p.get_person(6)
		assert_equal [6, 7], a[:stats].map {|x| x[:id]}.sort
		assert @p.delete_stat(7)
		a = @p.get_person(6)
		assert_equal [6], a[:stats].map {|x| x[:id]}.sort
		refute @p.get_stat(7)
	end

	def test_delete_url
		a = @p.get_person(3)
		assert_equal [6, 7], a[:urls].map {|x| x[:id]}.sort
		assert @p.delete_url(7)
		a = @p.get_person(3)
		assert_equal [6], a[:urls].map {|x| x[:id]}.sort
		refute @p.get_url(7)
	end

	def test_update_url
		id = 6
		nu = 'http://salt.biz/'
		u = @p.get_url(id)
		assert_equal 'http://salt.com/', u[:url]
		@p.update_url(id, {url: nu})
		u = @p.get_url(id)
		assert_equal nu, u[:url]
	end

	def test_star_url
		id = 6
		u = @p.get_url(id)
		refute u[:main]
		assert @p.star_url(id)
		u = @p.get_url(id)
		assert u[:main]
	end

	def test_unstar_url
		id = 3
		u = @p.get_url(id)
		assert u[:main]
		assert @p.unstar_url(id)
		u = @p.get_url(id)
		refute u[:main]
	end

	def test_formletters
		y = @p.formletters
		# sorted by title now
		assert_equal ['five', 'four', 'one', 'six', 'three', 'two'], y.map {|x| x[:title]}
		x = y.shift
		refute x[:body]
	end

	def test_add_formletter
		refute @p.add_formletter('one')	# title must be unique
		n = 'new title here'
		x = @p.add_formletter(n)
		assert_equal x[:title], n
	end

	def test_formletter
		x = @p.get_formletter(1)
		assert_equal "Your email is {email}. Here is your URL: https://sivers.org/u/{id}/{newpass}", x[:body]
	end

	def test_formletter_for_person
		x = @p.get_formletter_for_person(1, 3)
		assert_includes x[:body], "Your email is veruca@salt.com. Here is your URL: https://sivers.org/u/3/"
	end

	def test_update_formletter
		assert @p.update_formletter(5, {title: 'boo'})
		x = @p.get_formletter(5)
		assert_equal 'boo', x[:title]
	end

	def test_delete_formletter
		assert @p.delete_formletter(5)
		refute @p.get_formletter(5)
	end

	def test_all_countries
		x = @p.all_countries
		assert_equal 242, x.size
		assert_equal({code: 'AF', name: 'Afghanistan'}, x[0])
		assert_equal({code: 'ZW', name: 'Zimbabwe'}, x[241])
	end

	def test_country_names
		x = @p.country_names
		assert_equal 242, x.size
		assert_equal 'Singapore', x[:SG]
		assert_equal 'New Zealand', x[:NZ]
	end

	def test_country_count
		xpct = [{country: 'US', count: 3},
					{country: 'CN', count: 1},
					{country: 'DE', count: 1},
					{country: 'GB', count: 1},
					{country: 'JP', count: 1},
					{country: 'SG', count: 1}]
		assert_equal(xpct, @p.country_count)
	end

	def test_state_count
		assert_equal @p.state_count('US'), [{state: 'PA', count: 3}]
		refute @p.state_count('XX')
	end

	def test_city_count
		assert_equal @p.city_count('US', 'PA'), [{city: 'Hershey', count: 3}]
		assert_equal @p.city_count('SG'), [{city: 'Singapore', count: 1}]
		refute @p.city_count('ZZ')
	end

	def test_where
		assert_equal 3, @p.where('US', 'Hershey', 'PA').count
		refute @p.where('ID')
	end

	def test_statkeys_count
		xpct = [{name:'ayw',count:1},
			{name:'listype',count:2},
			{name:'media',count:1},
			{name:'musicthoughts',count:1},
			{name:'twitter',count:1},
			{name:'woodegg-bio',count:1},
			{name:'woodegg-mn',count:1}]
		assert_equal xpct, @p.statkeys_count
	end

	def test_stats_key
		xpct = [{id:3,created_at:'2011-03-15',name:'listype',value:'some',
					 		person:{id:2,name:'Willy Wonka',email:'willy@wonka.com'}},
						{id:1,created_at:'2008-01-01',name:'listype',value:'all',
							person:{id:1,name:'Derek Sivers',email:'derek@sivers.org'}}]
		assert_equal xpct, @p.stats_with_key('listype')
		assert_equal [], @p.stats_with_key('x')
	end

	def test_stats_key_value
		xpct = [{id:3,created_at:'2011-03-15',name:'listype',value:'some',
					 		person:{id:2,name:'Willy Wonka',email:'willy@wonka.com'}}]
		assert_equal xpct, @p.stats_with_key_value('listype', 'some')
		assert_equal [], @p.stats_with_key_value('listype', 'x')
	end

	def test_import_email
		nu = {profile: 'derek@sivers', category: 'derek@sivers', message_id: 'abcdefghijk@yep',
			their_email: 'Charlie@BUCKET.ORG', their_name: 'Charles Buckets', subject: 'yip',
			headers: 'To: Derek Sivers <derek@sivers.org>', body: 'hi Derek',
			references: [], attachments: []}
		x = @p.import_email(nu)
		assert_equal 11, x[:id]
		assert_equal 'charlie@bucket.org', x[:their_email]
		assert_equal 2, x[:creator][:id]
		assert_equal 4, x[:person][:id]
		assert_equal 'derek@sivers', x[:category]
		assert_nil x[:reference_id]
		assert_nil x[:attachments]
	end

	def test_import_email_references
		nu = {profile: 'derek@sivers', category: 'derek@sivers', message_id: 'abcdefghijk@yep',
			their_email: 'wonka@gmail.com', their_name: 'W Wonka', subject: 're: you coming by?',
			headers: 'To: Derek Sivers <derek@sivers.org>', body: 'kthxbai',
			references: ['not@thisone', '20130719234701.2@sivers.org'], attachments: []}
		x = @p.import_email(nu)
		assert_equal 11, x[:id]
		assert_equal 2, x[:person][:id]
		assert_equal 3, x[:reference_id]
		assert_equal 'derek@sivers', x[:category]
		x = @p.open_email(3)
		assert_equal 11, x[:answer_id]
	end

	def test_import_email_attachments
		atch = []
		atch << {mime_type: 'image/gif', filename: 'cute.gif', bytes: 1234}
		atch << {mime_type: 'audio/mp3', filename: 'fun.mp3', bytes: 123456}
		nu = {profile: 'derek@sivers', category: 'derek@sivers', message_id: 'abcdefghijk@yep',
			their_email: 'Charlie@BUCKET.ORG', their_name: 'Charles Buckets', subject: 'yip',
			headers: 'To: Derek Sivers <derek@sivers.org>', body: 'hi Derek',
			references: [], attachments: atch}
		x = @p.import_email(nu)
		assert_equal 11, x[:id]
		assert_equal [{id:3,filename:'cute.gif'},{id:4,filename:'fun.mp3'}], x[:attachments]
	end

	def test_list_updates
		x = @p.list_update('Willy Wonka', 'willy@wonka.com', 'none')
		assert_equal({list: 'none'}, x)
		x = @p.get_person(2)
		assert_equal 'none', x[:listype]
		assert_equal 'none', x[:stats][2][:value]
	end

	def test_list_update_create
		@p.list_update('New Person', 'new@pers.on', 'all?')
		x = @p.get_person(9)
		assert_equal 'new@pers.on', x[:email]
		assert_equal 'all', x[:listype]
		assert_equal 'all', x[:stats][0][:value]
	end

	def test_list_update_err
		refute @p.list_update('New Person', 'new@pers.on', 'more-than-4-chars')
		assert @p.error.include? 'value too long'
	end

	def test_queued_emails
		x = @p.queued_emails
		assert_instance_of Array, x
		assert_equal 1, x.size
		assert_equal 4, x[0][:id]
		assert_equal 're: translations almost done', x[0][:subject]
		assert_equal 'CABk7SeW6+FaqxOUwHNdiaR2AdxQBTY1275uC0hdkA0kLPpKPVg@mail.li.cn', x[0][:referencing]
	end

	def test_email_is_sent
		x = @p.email_is_sent(4)
		assert_equal({sent: 4}, x)
		x = @p.queued_emails
		assert_equal [], x
		refute @p.email_is_sent(99)
	end

	def test_sent_emails
		x = @p.sent_emails(20)
		assert_instance_of Array, x
		assert_equal 1, x.size  # only 1 outgoing in fixtures
		h = {id: 3, 
			subject: 're: you coming by?',
			created_at: '2013-07-20T03:47:01',
			their_name: 'Will Wonka',
			their_email: 'willy@wonka.com'}
		assert_equal(h, x[0])
	end

	def test_twitter_unfollowed
		x = @p.twitter_unfollowed
		assert_equal([{person_id: 2, twitter: 'wonka'}], x)
		@p.add_stat(2, 'twitter', '12325 = wonka')
		x = @p.twitter_unfollowed
		assert_equal [], x
	end

	def test_dead_email
		x = @p.dead_email(1)
		assert_equal({ok: 1}, x)
		x = @p.get_person(1)
		assert_equal "DEAD EMAIL: derek@sivers.org\nThis is me.", x[:notes]
		refute @p.dead_email(99)
		x = @p.dead_email(4)
		assert_equal({ok: 4}, x)
		x = @p.get_person(4)
		assert_equal "DEAD EMAIL: charlie@bucket.org\n", x[:notes]
	end

	def test_tables_with_person
		x = @p.tables_with_person(1)
		assert_equal ['peeps.emailers','peeps.userstats','peeps.urls','peeps.logins','peeps.api_keys'].sort, x.sort
	end
end

