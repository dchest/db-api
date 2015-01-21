# test peeps schema
require 'pg'
require 'minitest/autorun'
require 'json'

DB = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')
SCHEMA = File.read('schema.sql')
FIXTURES = File.read('fixtures.sql')

class Minitest::Test
	def setup
		DB.exec(SCHEMA)
		DB.exec(FIXTURES)
	end
end

Minitest.after_run do
	DB.exec(SCHEMA)
	DB.exec(FIXTURES)
end

class TestPeepsAPI < Minitest::Test

	def test_emailer_profiles
		res = DB.exec("SELECT * FROM get_profiles(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(derek@sivers we@woodegg), j
	end

end

