# test musicthoughts schema
require 'pg'
require 'minitest/autorun'
require 'json'

DB = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')
P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
SCHEMA = File.read('schema.sql')
FIXTURES = File.read('fixtures.sql')

class Minitest::Test
	def setup
		DB.exec(P_SCHEMA)
		DB.exec(SCHEMA)
		DB.exec(P_FIXTURES)
		DB.exec(FIXTURES)
	end
end

Minitest.after_run do
	DB.exec(P_SCHEMA)
	DB.exec(SCHEMA)
	DB.exec(P_FIXTURES)
	DB.exec(FIXTURES)
end

class TestMusicthoughtsClient < Minitest::Test

	def test_languages
		res = DB.exec("SELECT * FROM languages()")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(en es fr de it pt ja zh ar ru), j
	end

	def test_categories
		res = DB.exec("SELECT * FROM all_categories()")
		j = JSON.parse(res[0]['js'])
		assert_equal 12, j.size
		assert_equal 2, j[1]['id']
		assert_equal 2, j[1]['howmany']
	end

	def test_category
		res = DB.exec("SELECT * FROM category(5)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Schreiberblock', j['de']
		assert_equal 'колонка авторов', j['ru']
		res = DB.exec("SELECT * FROM category(7)")
		j = JSON.parse(res[0]['js'])
		assert_equal [3, 1], j['thoughts'].map {|x| x['id']}
		res = DB.exec("SELECT * FROM category(55)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_top_authors
		res = DB.exec("SELECT * FROM top_authors(2)")
		j = JSON.parse(res[0]['js'])
		assert_equal 2, j.size
		assert_equal 'Miles Davis', j[0]['name']
		assert_equal 2, j[0]['howmany']
		assert_equal 'Maya Angelou', j[1]['name']
		assert_equal 1, j[1]['howmany']
		res = DB.exec("SELECT * FROM top_authors(NULL)")
		j = JSON.parse(res[0]['js'])
		assert_equal 3, j.size
	end

	def test_get_author
		res = DB.exec("SELECT * FROM get_author(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Miles Davis', j['name']
		assert_instance_of Array, j['thoughts']
		assert_equal 'Non aver paura degli errori. Non ce ne sono.', j['thoughts'][0]['it']
		assert_equal 'Suona quello che non conosci.', j['thoughts'][1]['it']
		res = DB.exec("SELECT * FROM get_author(55)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_top_contributors
		res = DB.exec("SELECT * FROM top_contributors(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal 1, j.size
		assert_equal 'Derek Sivers', j[0]['name']
		assert_equal 3, j[0]['howmany']
		res = DB.exec("SELECT * FROM top_contributors(NULL)")
		j = JSON.parse(res[0]['js'])
		assert_equal 2, j.size
	end

	def test_get_contributor
		res = DB.exec("SELECT * FROM get_contributor(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Derek Sivers', j['name']
		assert_instance_of Array, j['thoughts']
		assert_equal [4, 3, 1], j['thoughts'].map {|x| x['id']}
		res = DB.exec("SELECT * FROM get_contributor(2)")
		j = JSON.parse(res[0]['js'])
		assert_nil j['thoughts']
		res = DB.exec("SELECT * FROM get_contributor(55)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_random_thought
		res = DB.exec("SELECT * FROM random_thought()")
		j = JSON.parse(res[0]['js'])
		assert [1, 4].include? j['id']
		res = DB.exec("SELECT * FROM random_thought()")
		j = JSON.parse(res[0]['js'])
		assert [1, 4].include? j['id']
	end

	def test_get_thought
		res = DB.exec("SELECT * FROM get_thought(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'http://www.milesdavis.com/', j['source_url']
		assert_equal '知らないものを弾け。', j['ja']
		assert_equal 'Miles Davis', j['author']['name']
		assert_equal 'Derek Sivers', j['contributor']['name']
		assert_equal %w(experiments performing practicing), j['categories'].map {|x| x['en']}.sort
		res = DB.exec("SELECT * FROM get_thought(99)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_new_thoughts
		res = DB.exec("SELECT * FROM new_thoughts(1)")
		j = JSON.parse(res[0]['js'])
		assert_instance_of Array, j
		assert_equal 1, j.size
		assert_equal 5, j[0]['id']
		res = DB.exec("SELECT * FROM new_thoughts(NULL)")
		j = JSON.parse(res[0]['js'])
		assert_equal [5, 4, 3, 1], j.map {|x| x['id']}
	end

	def test_search
		res = DB.exec("SELECT * FROM search('中')")
		j = JSON.parse(res[0]['js'])
		assert_equal 'search term too short', j['title']
		res = DB.exec("SELECT * FROM search('出中')")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(authors categories contributors thoughts), j.keys.sort
		assert_nil j['authors']
		assert_nil j['contributors']
		assert_nil j['thoughts']
		assert_equal '演出中', j['categories'][0]['zh']
		res = DB.exec("SELECT * FROM search('Miles')")
		j = JSON.parse(res[0]['js'])
		assert_nil j['contributors']
		assert_nil j['categories']
		assert_nil j['thoughts']
		assert_equal 'Miles Davis', j['authors'][0]['name']
		res = DB.exec("SELECT * FROM search('Salt')")
		j = JSON.parse(res[0]['js'])
		assert_nil j['authors']
		assert_nil j['categories']
		assert_nil j['thoughts']
		assert_equal 'Veruca Salt', j['contributors'][0]['name']
		res = DB.exec("SELECT * FROM search('dimenticherá')")
		j = JSON.parse(res[0]['js'])
		assert_nil j['authors']
		assert_nil j['categories']
		assert_nil j['contributors']
		assert_equal 5, j['thoughts'][0]['id']
	end

	def test_add
		res = DB.exec("SELECT * FROM add_thought('de', 'wow', 'me', 'me@me.nz', 'http://me.nz/', 'NZ', 'god', 'http://god.com/', ARRAY[1, 3, 5])")
		j = JSON.parse(res[0]['js'])
		assert_equal({'thought'=>7,'contributor'=>4,'author'=>5}, j)
	end
end

