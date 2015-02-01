require 'minitest/autorun'
require_relative 'testful.rb'

#Minitest.after_run do
	# delete '/reset'
#end

require_relative 'musicthoughts.rb'
class TestMusicthoughtsPublic < Minitest::Test
	include Testful
	Testful::BASE = 'http://127.0.0.1:10011'

	def setup
		delete '/reset'
	end

	def test_languages
		get '/languages'
		assert_equal %w(en es fr de it pt ja zh ar ru), @j
	end

	def test_categories
		get '/categories'
		assert_equal 12, @j.size
		assert_equal 2, @j[1]['id']
		assert_equal 2, @j[1]['howmany']
	end

	def test_category
		get '/categories/5'
		assert_equal 'Schreiberblock', @j['de']
		assert_equal 'колонка авторов', @j['ru']
		get '/categories/55'
		assert_equal 'Not Found', @j['title']
	end

	def test_top_authors
		get '/authors/top'
		assert_equal 3, @j.size
		assert_equal 'Miles Davis', @j[0]['name']
		assert_equal 2, @j[0]['howmany']
		assert_equal 'Maya Angelou', @j[1]['name']
		assert_equal 1, @j[1]['howmany']
		get '/authors'
		assert_equal 3, @j.size
	end

	def test_get_author
		get '/authors/1'
		assert_equal 'Miles Davis', @j['name']
		assert_instance_of Array, @j['thoughts']
		assert_equal 'Non aver paura degli errori. Non ce ne sono.', @j['thoughts'][0]['it']
		assert_equal 'Suona quello che non conosci.', @j['thoughts'][1]['it']
		get '/authors/55'
		assert_equal 'Not Found', @j['title']
	end

	def test_top_contributors
		get '/contributors/top'
		assert_equal 2, @j.size
		assert_equal 'Derek Sivers', @j[0]['name']
		assert_equal 3, @j[0]['howmany']
		get '/contributors'
		assert_equal 2, @j.size
	end

	def test_get_contributor
		get '/contributors/1'
		assert_equal 'Derek Sivers', @j['name']
		assert_instance_of Array, @j['thoughts']
		assert_equal [4, 3, 1], @j['thoughts'].map {|x| x['id']}
		get '/contributors/2'
		assert_nil @j['thoughts']
		get '/contributors/55'
		assert_equal 'Not Found', @j['title']
	end

	def test_random_thought
		get '/thoughts/random'
		assert [1, 4].include? @j['id']
		get '/thoughts/random'
		assert [1, 4].include? @j['id']
	end

	def test_get_thought
		get '/thoughts/1'
		assert_equal 'http://www.milesdavis.com/', @j['source_url']
		assert_equal '知らないものを弾け。', @j['ja']
		assert_equal 'Miles Davis', @j['author']['name']
		assert_equal 'Derek Sivers', @j['contributor']['name']
		assert_equal %w(experiments performing practicing), @j['categories'].map {|x| x['en']}.sort
		get '/thoughts/99'
		assert_equal 'Not Found', @j['title']
	end

	def test_new_thoughts
		get '/thoughts/new'
		assert_instance_of Array, @j
		assert_equal 5, @j[0]['id']
		get '/thoughts'
		assert_equal [5, 4, 3, 1], @j.map {|x| x['id']}
	end

	def test_search
		get '/search?q=%E4%B8%AD'	# 中
		assert_equal 'search term too short', @j['title']
		get '/search?q=%E5%87%BA%E4%B8%AD'	# 出中
		assert_equal %w(authors categories contributors thoughts), @j.keys.sort
		assert_nil @j['authors']
		assert_nil @j['contributors']
		assert_nil @j['thoughts']
		assert_equal '演出中', @j['categories'][0]['zh']
		get '/search?q=Miles'
		assert_nil @j['contributors']
		assert_nil @j['categories']
		assert_nil @j['thoughts']
		assert_equal 'Miles Davis', @j['authors'][0]['name']
		get '/search?q=Salt'
		assert_nil @j['authors']
		assert_nil @j['categories']
		assert_nil @j['thoughts']
		assert_equal 'Veruca Salt', @j['contributors'][0]['name']
		get '/search?q=dimenticher%C3%A1' # á
		assert_nil @j['authors']
		assert_nil @j['categories']
		assert_nil @j['contributors']
		assert_equal 5, @j['thoughts'][0]['id']
	end

	def test_add
		post('/thoughts', {lang_code: 'de',
			thought: 'wow',
			contributor_name: 'me',
			contributor_email: 'me@me.nz',
			contributor_url: 'http://me.nz/',
			contributor_place: 'NZ',
			author_name: 'god',
			source_url: 'http://god.com/'})
		assert_equal({'thought'=>7,'contributor'=>4,'author'=>5}, @j)
	end
end

