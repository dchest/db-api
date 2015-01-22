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

	def test_unopened_email_count
		res = DB.exec("SELECT * FROM unopened_email_count(1)")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(derek@sivers we@woodegg), j.keys
		assert_equal({'woodegg' => 1, 'not-derek' => 1}, j['we@woodegg'])
		res = DB.exec("SELECT * FROM unopened_email_count(4)")
		j = JSON.parse(res[0]['js'])
		assert_equal %w(we@woodegg), j.keys
		res = DB.exec("SELECT * FROM unopened_email_count(3)")
		j = JSON.parse(res[0]['js'])
		assert_equal({}, j)
	end

end

