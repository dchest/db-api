SCHEMA = File.read('../../woodegg/schema.sql')
FIXTURES = File.read('../../woodegg/fixtures.sql')
P_SCHEMA = File.read('../../peeps/schema.sql')
P_FIXTURES = File.read('../../peeps/fixtures.sql')
require '../../test_tools.rb'

require '../lib/b50d/woodegg.rb'

class TestWoodEgg < Minitest::Test

	def setup
		super
		@we = B50D::WoodEgg.new('test')
	end

	def test_login
		x = @we.login('augustus@gloop.de', 'augustus')
		assert x[:cookie]
		assert_match /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/, x[:cookie]
		refute @we.login('derek@sivers.org', 'derek')
		refute @we.login('derek@sivers.org', '')
		refute @we.login('derek@sivers.org', nil)
	end

	def test_customer
		x = @we.login('augustus@gloop.de', 'augustus')
		x = @we.customer_from_cookie(x[:cookie])
		assert_equal 1, x[:id]
		assert_equal 'Augustus Gloop', x[:name]
		z = '95a1aa2d50a38ec052179065329bdb0d:iXFyoXL6AJGs1p9F66L2M8oI9uGO4vmZ'
		refute @we.customer_from_cookie(z)
	end

	def test_register
		x = @we.register({
			name: 'Dude Abides',
			email: 'DUDE@abid.ES',
			password: 'TheDude',
			proof: 'some proof'})
		assert_equal 9, x[:id]
		assert_equal 'Dude Abides', x[:name]
		assert_equal 'dude@abid.es', x[:email]
		assert_equal 'Dude', x[:address]
	end

	def test_forgot
		x = @we.forgot('augustus@gloop.de')
		assert_equal 6, x[:id]
		assert_equal 'Augustus Gloop', x[:name]
		assert_equal 'augustus@gloop.de', x[:email]
		assert_equal 'Master Gloop', x[:address]
		refute @we.forgot('derek@sivers.org')
		refute @we.forgot('x')
		refute @we.forgot('')
		refute @we.forgot(nil)
	end

	def test_get_customer_reset
		x = @we.customer_from_reset('8LLRaMwm')
		assert_equal 1, x[:customer_id]
		assert_equal 6, x[:person_id]
		assert_equal '8LLRaMwm', x[:reset]
	end

	def test_set_customer_password
		refute @we.set_customer_password('8LLRaMwm', 'x')
		nu = 'þø¿€ñ'
		x = @we.set_customer_password('8LLRaMwm', nu)
		assert_equal 6, x[:id]
		assert_equal 'Augustus Gloop', x[:name]
		assert_equal 'augustus@gloop.de', x[:email]
		assert_equal 'Master Gloop', x[:address]
		x = @we.login('augustus@gloop.de', nu)
		assert_match /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/, x[:cookie]
		refute @we.set_customer_password('8LLRaMwm', nu)
	end

	def test_researcher
		x = @we.researcher(1)
		assert_equal '巩俐', x[:name]
		assert_equal 'This is Gong Li', x[:bio]
		refute @we.researcher(99)
	end

	def test_writer
		x = @we.writer(1)
		assert_equal 'Veruca Salt', x[:name]
		assert_equal 'This is Veruca Salt', x[:bio]
		refute @we.writer(99)
	end

	def test_editor
		x = @we.editor(1)
		assert_equal 'Derek Sivers', x[:name]
		assert_equal 'This is Derek', x[:bio]
		refute @we.editor(99)
	end

	def test_country
		x = @we.country('CN')
		assert_instance_of Array, x
		assert_equal 2, x.size
		assert_equal 'Country', x[0][:topic]
		assert_instance_of Array, x[0][:subtopics]
		assert_equal 2, x[0][:subtopics].size
		assert_equal 'how big', x[0][:subtopics][0][:subtopic]
		assert_equal 'how old', x[0][:subtopics][1][:subtopic]
		assert_instance_of Array, x[0][:subtopics][0][:questions]
		assert_equal 'how big is China?', x[0][:subtopics][0][:questions][0][:question]
		assert_equal 'Culture', x[1][:topic]
		assert_instance_of Array, x[1][:subtopics]
		assert_equal 2, x[1][:subtopics].size
		refute @we.country('XXX')
		refute @we.country('KH')
	end

	def test_country2
		x = @we.country('CN')
		j = [  # another way of looking at it:
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
		assert_equal j, x
	end

	def test_question
		x = @we.question(1)
		assert_equal 'CN', x[:country]
		assert_equal 1, x[:template_id]
		assert_equal 'how big is China?', x[:question]
		assert_instance_of Array, x[:answers]
		assert_instance_of Array, x[:essays]
		assert_equal '2013-06-28', x[:answers][0][:date]
		assert_equal 'China whatever1', x[:answers][0][:answer]
		assert_equal 'none', x[:answers][0][:sources]
		assert_equal '巩俐', x[:answers][0][:researcher][:name]
		assert_equal '2013-06-28', x[:essays][0][:date]
		assert_equal 'China whatever1!', x[:essays][0][:essay]
		assert_equal 'Veruca Salt', x[:essays][0][:writer][:name]
		assert_equal '/images/200/writers-1.jpg', x[:essays][0][:writer][:image]
		assert_equal 'Derek Sivers', x[:essays][0][:editor][:name]
		assert_equal '/images/200/editors-1.jpg', x[:essays][0][:editor][:image]
		refute @we.question(99)
	end

	def test_book
		x = @we.book(1)
		assert_equal 'CN', x[:country]
		assert_equal 'China 2013: How To', x[:title]
		assert_equal '9789810766320', x[:isbn]
		assert_equal 'B00D1HOJII', x[:asin]
		assert_equal 'ChinaStartupGuide2013', x[:leanpub]
		assert_equal 'THIS IS FOR SALE NOW', x[:salescopy]
		assert_instance_of Array, x[:researchers]
		assert_instance_of Array, x[:writers]
		assert_instance_of Array, x[:editors]
		assert_equal '巩俐', x[:researchers][0][:name]
		assert_equal 'Veruca Salt', x[:writers][0][:name]
		assert_equal 'Derek Sivers', x[:editors][0][:name]
		assert_equal '/images/200/editors-1.jpg', x[:editors][0][:image]
		refute @we.book(99)
	end

	def test_templates
		x = @we.templates()
		j = [
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
		assert_equal j, x
	end

	def test_template
		x = @we.template(1)
		j = {:id=>1, :question=>'how big is {COUNTRY}?', :countries=>[
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
		assert_equal(j, x)
		refute @we.template(99)
	end

	def test_uploads
		x = @we.uploads('CN')
		assert_instance_of Array, x
		j = {id:1,
			country:'CN',
			date:'2013-08-07',
			filename:'r003-20130807-someinterview.mp3',
			notes:'This is me interviewing someone.'}
		assert_equal(j, x[0])
		refute @we.uploads('XX')
		refute @we.uploads('KH')
	end

	def test_upload
		x = @we.upload(1)
		j = {id:1,
			country:'CN',
			date:'2013-08-07',
			filename:'r003-20130807-someinterview.mp3',
			notes:'This is me interviewing someone.',
		  mime_type:'audio/mp3',
			bytes:1234567,
			transcription:'This has a transcription.'}
		assert_equal(j, x)
		refute @we.upload(99)
	end

end

