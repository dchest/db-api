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

end
