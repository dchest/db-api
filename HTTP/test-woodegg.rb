require 'minitest/autorun'
require_relative 'testful.rb'

require_relative 'woodegg.rb'
class TestWoodEgg < Minitest::Test
	include Testful
	Testful::BASE = 'http://127.0.0.1:10031'

	def setup
		delete '/reset'
	end

	def test_researcher
		get '/researchers/1'
		assert_equal '巩俐', @j[:name]
		assert_equal 'This is Gong Li', @j[:bio]
		get '/researchers/99'
		assert_equal 'Not Found', @j[:title]
	end

	def test_writer
		get '/writers/1'
		assert_equal 'Veruca Salt', @j[:name]
		assert_equal 'This is Veruca Salt', @j[:bio]
		get '/writers/99'
		assert_equal 'Not Found', @j[:title]
	end

	def test_editor
		get '/editors/1'
		assert_equal 'Derek Sivers', @j[:name]
		assert_equal 'This is Derek', @j[:bio]
		get '/editors/99'
		assert_equal 'Not Found', @j[:title]
	end

	def test_country
		get '/country/CN'
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
		get '/country/KH'
		assert_equal 'Not Found', @j[:title]
	end

	def test_country2
		get '/country/CN'
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
		get '/questions/1'
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
		get '/questions/99'
		assert_equal 'Not Found', @j[:title]
	end

	def test_book
		get '/books/1'
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
		get '/books/99'
		assert_equal 'Not Found', @j[:title]
	end

	def test_templates
		get '/templates'
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
		get '/templates/1'
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
		get '/templates/99'
		assert_equal 'Not Found', @j[:title]
	end

	def test_uploads
		get '/uploads/CN'
		assert_instance_of Array, @j
		x = {id:1,
			country:'CN',
			date:'2013-08-07',
			filename:'r003-20130807-someinterview.mp3',
			notes:'This is me interviewing someone.'}
		assert_equal(x, @j[0])
		get '/uploads/KH'
		assert_equal 'Not Found', @j[:title]
	end

	def test_upload
		get '/uploads/1'
		x = {id:1,
			country:'CN',
			date:'2013-08-07',
			filename:'r003-20130807-someinterview.mp3',
			notes:'This is me interviewing someone.',
		  mime_type:'audio/mp3',
			bytes:1234567,
			transcription:'This has a transcription.'}
		assert_equal(x, @j)
		get '/uploads/99'
		assert_equal 'Not Found', @j[:title]
	end

end

