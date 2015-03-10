P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
require '../test_tools.rb'

class TestWoodEgg < Minitest::Test
	include JDB

	def test_login
		qry("woodegg.login($1, $2)", ['augustus@gloop.de', 'augustus'])
		assert @j[:cookie]
		assert_match /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/, @j[:cookie]
		qry("woodegg.login($1, $2)", ['derek@sivers.org', 'derek'])
		assert_equal 'Not Found', @j[:title]
	end

	def test_customer
		qry("woodegg.login($1, $2)", ['augustus@gloop.de', 'augustus'])
		qry("woodegg.get_customer($1)", [@j[:cookie]])
		assert_equal 1, @j[:id]
		assert_equal 'Augustus Gloop', @j[:name]
		qry("woodegg.get_customer($1)", ['a bad cookie value here'])
		assert_equal 'Not Found', @j[:title]
	end

	def test_register
		qry("woodegg.register($1, $2, $3, $4)",
			['Dude Abides', 'DUDE@abid.ES', 'TheDude', 'some proof'])
		assert_equal 9, @j[:id]
		assert_equal 'Dude Abides', @j[:name]
		assert_equal 'dude@abid.es', @j[:email]
		assert_equal 'Dude', @j[:address]
		res = DB.exec("SELECT * FROM peeps.userstats WHERE person_id=9")
		assert_equal 'proof-we14asia', res[0]['statkey']
		assert_equal 'some proof', res[0]['statvalue']
	end

	def test_forgot
		qry("woodegg.forgot($1)", ['augustus@gloop.de'])
		assert_equal 6, @j[:id]
		assert_equal 'Augustus Gloop', @j[:name]
		assert_equal 'augustus@gloop.de', @j[:email]
		assert_equal 'Master Gloop', @j[:address]
		res = DB.exec("SELECT * FROM peeps.emails WHERE id=11")
		assert_equal '6', res[0]['person_id']
		assert_equal 'augustus@gloop.de', res[0]['their_email']
		assert_equal 'your Wood Egg password reset link', res[0]['subject']
		assert_nil res[0]['outgoing']
		assert res[0]['body'].include? 'https://woodegg.com/reset/8LLRaMwm'
		assert res[0]['body'].include? 'Hi Master Gloop'
		assert res[0]['body'].include? 'we@woodegg.com'
		qry("woodegg.forgot($1)", ['derek@sivers.org'])
		assert_equal 'Not Found', @j[:title]
		qry("woodegg.forgot($1)", ['x'])
		assert_equal 'Not Found', @j[:title]
		qry("woodegg.forgot($1)", [''])
		assert_equal 'Not Found', @j[:title]
		qry("woodegg.forgot(NULL)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_forgot_sets_newpass
		DB.exec("UPDATE peeps.people SET newpass=NULL WHERE id=6")
		qry("woodegg.forgot($1)", ['augustus@gloop.de'])
		newpass = DB.exec("SELECT newpass FROM peeps.people WHERE id=6")[0]['newpass']
		assert_match /[a-zA-Z0-9]{8}/, newpass
		res = DB.exec("SELECT * FROM peeps.emails WHERE id=11")
		assert res[0]['body'].include? "https://woodegg.com/reset/#{newpass}"
	end

	def test_researcher
		qry("woodegg.get_researcher(1)")
		assert_equal '巩俐', @j[:name]
		assert_equal 'This is Gong Li', @j[:bio]
		qry("woodegg.get_researcher(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_writer
		qry("woodegg.get_writer(1)")
		assert_equal 'Veruca Salt', @j[:name]
		assert_equal 'This is Veruca Salt', @j[:bio]
		qry("woodegg.get_writer(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_editor
		qry("woodegg.get_editor(1)")
		assert_equal 'Derek Sivers', @j[:name]
		assert_equal 'This is Derek', @j[:bio]
		qry("woodegg.get_editor(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_country
		qry("woodegg.get_country('CN')")
		assert_instance_of Array, @j
		assert_equal 2, @j.size
		assert_equal 'Country', @j[0][:topic]
		assert_instance_of Array, @j[0][:subtopics]
		assert_equal 2, @j[0][:subtopics].size
		assert_equal 'how big', @j[0][:subtopics][0][:subtopic]
		assert_equal 'how old', @j[0][:subtopics][1][:subtopic]
		assert_instance_of Array, @j[0][:subtopics][0][:questions]
		assert_equal 'how big is China?', @j[0][:subtopics][0][:questions][0][:question]
		assert_equal 'Culture', @j[1][:topic]
		assert_instance_of Array, @j[1][:subtopics]
		assert_equal 2, @j[1][:subtopics].size
		qry("woodegg.get_country('XXX')")
		assert_equal 'Not Found', @j[:title]
	end

	def test_country2
		qry("woodegg.get_country('CN')")
		x = [  # another way of looking at it:
			{:id=>1, :topic=>'Country', :subtopics=>[
				{:id=>1, :subtopic=>'how big', :questions=>[
					{:id=>1, :question=>'how big is China?'}]},
				{:id=>2, :subtopic=>'how old', :questions=>[
					{:id=>2, :question=>'how old is China?'}]}]},
			{:id=>2, :topic=>'Culture', :subtopics=>[
				{:id=>3, :subtopic=>'is it fun?', :questions=>[
					{:id=>3, :question=>'what is fun in China?'},
					{:id=>4, :question=>'do they laugh in China?'}]},
				{:id=>4, :subtopic=>'what language?', :questions=>[
					{:id=>5, :question=>'what language in China?'}]}]}]
		assert_equal x, @j
	end

	def test_question
		qry("woodegg.get_question(1)")
		assert_equal 'CN', @j[:country]
		assert_equal 1, @j[:template_id]
		assert_equal 'how big is China?', @j[:question]
		assert_instance_of Array, @j[:answers]
		assert_instance_of Array, @j[:essays]
		assert_equal '2013-06-28', @j[:answers][0][:date]
		assert_equal 'China whatever1', @j[:answers][0][:answer]
		assert_equal 'none', @j[:answers][0][:sources]
		assert_equal '巩俐', @j[:answers][0][:researcher][:name]
		assert_equal '2013-06-28', @j[:essays][0][:date]
		assert_equal 'China whatever1!', @j[:essays][0][:essay]
		assert_equal 'Veruca Salt', @j[:essays][0][:writer][:name]
		assert_equal '/images/200/writers-1.jpg', @j[:essays][0][:writer][:image]
		assert_equal 'Derek Sivers', @j[:essays][0][:editor][:name]
		assert_equal '/images/200/editors-1.jpg', @j[:essays][0][:editor][:image]
		qry("woodegg.get_question(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_book
		qry("woodegg.get_book(1)")
		assert_equal 'CN', @j[:country]
		assert_equal 'China 2013: How To', @j[:title]
		assert_equal '9789810766320', @j[:isbn]
		assert_equal 'B00D1HOJII', @j[:asin]
		assert_equal 'ChinaStartupGuide2013', @j[:leanpub]
		assert_equal 'THIS IS FOR SALE NOW', @j[:salescopy]
		assert_instance_of Array, @j[:researchers]
		assert_instance_of Array, @j[:writers]
		assert_instance_of Array, @j[:editors]
		assert_equal '巩俐', @j[:researchers][0][:name]
		assert_equal 'Veruca Salt', @j[:writers][0][:name]
		assert_equal 'Derek Sivers', @j[:editors][0][:name]
		assert_equal '/images/200/editors-1.jpg', @j[:editors][0][:image]
		qry("woodegg.get_book(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_templates
		qry("woodegg.get_templates()")
		x = [
			{:id=>1, :topic=>'Country', :subtopics=>[
					{:id=>1, :subtopic=>'how big', :questions=>[
						{:id=>1, :question=>'how big is {COUNTRY}?'}]},
					{:id=>2, :subtopic=>'how old', :questions=>[
						{:id=>2, :question=>'how old is {COUNTRY}?'}]}]},
			{:id=>2, :topic=>'Culture', :subtopics=>[
				{:id=>3, :subtopic=>'is it fun?', :questions=>[
					{:id=>3, :question=>'what is fun in {COUNTRY}?'},
					{:id=>4, :question=>'do they laugh in {COUNTRY}?'}]},
				{:id=>4, :subtopic=>'what language?', :questions=>[
					{:id=>5, :question=>'what language in {COUNTRY}?'}]}]}]
		assert_equal x, @j
	end

	def test_template
		qry("woodegg.get_template(1)")
		x = {:id=>1, :question=>'how big is {COUNTRY}?', :countries=>[
			{:id=>1, :country=>'CN', :question=>'how big is China?',
				:answers=>[
					{:id=>1, :date=>'2013-06-28', :answer=>'China whatever1', :sources=>'none',
		 				:researcher=>{:id=>1, :name=>'巩俐', :image=>'/images/200/researchers-1.jpg'}}],
				:essays=>[
					{:id=>1, :date=>'2013-06-28', :essay=>'China whatever1!',
						:writer=>{:id=>1, :name=>'Veruca Salt', :image=>'/images/200/writers-1.jpg'},
						:editor=>{:id=>1, :name=>'Derek Sivers', :image=>'/images/200/editors-1.jpg'}}]},
			{:id=>6, :country=>'JP', :question=>'how big is Japan?',
				:answers=>[
					{:id=>6, :date=>'2013-06-28', :answer=>'Japan it depends 6', :sources=>'mind',
						:researcher=>{:id=>2, :name=>'Yoko Ono', :image=>'/images/200/researchers-2.jpg'}}],
				:essays=>[
					{:id=>6, :date=>'2013-07-08', :essay=>'Japan. Whatever. One.',
						:writer=>{:id=>2, :name=>'Charlie Buckets', :image=>'/images/200/writers-2.jpg'},
						:editor=>{:id=>2, :name=>'Willy Wonka', :image=>'/images/200/editors-2.jpg'}}]}]}
		assert_equal x, @j
		qry("woodegg.get_template(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_uploads
		qry("woodegg.get_uploads('CN')")
		assert_instance_of Array, @j
		x = {id:1,
			country:'CN',
			date:'2013-08-07',
			filename:'r003-20130807-someinterview.mp3',
			notes:'This is me interviewing someone.'}
		assert_equal(x, @j[0])
		qry("woodegg.get_uploads('XX')")
		assert_equal 'Not Found', @j[:title]
	end

	def test_upload
		qry("woodegg.get_upload(1)")
		x = {id:1,
			country:'CN',
			date:'2013-08-07',
			filename:'r003-20130807-someinterview.mp3',
			notes:'This is me interviewing someone.',
		  mime_type:'audio/mp3',
			bytes:1234567,
			transcription:'This has a transcription.'}
		assert_equal(x, @j)
		qry("woodegg.get_upload(99)")
		assert_equal 'Not Found', @j[:title]
	end

end

