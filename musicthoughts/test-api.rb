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

	def test_category
		res = DB.exec("SELECT * FROM category(5)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Schreiberblock', j['de']
		assert_equal 'колонка авторов', j['ru']
		res = DB.exec("SELECT * FROM category(55)")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end

	def test_top_authors
		res = DB.exec("SELECT * FROM top_authors()")
		j = JSON.parse(res[0]['js'])
		assert_equal 'Miles Davis', j[0]['name']
		assert_equal 2, j[0]['howmany']
		assert_equal 'Maya Angelou', j[1]['name']
		assert_equal 1, j[1]['howmany']
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
end
