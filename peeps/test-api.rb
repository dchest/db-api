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

	def test_unopened_emails
		res = DB.exec("SELECT * FROM unopened_emails(1, 'we@woodegg', 'woodegg')")
		j = JSON.parse(res[0]['js'])
		assert_instance_of Array, j
		assert_equal 1, j.size
		assert_equal 'I refuse to wait', j[0]['subject']
		assert_nil j[0]['body']
		res = DB.exec("SELECT * FROM unopened_emails(3, 'we@woodegg', 'woodegg')")
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_open_next_email
		res = DB.exec("SELECT * FROM open_next_email(1, 'we@woodegg', 'woodegg')")
		j = JSON.parse(res[0]['js'])
		assert_equal 8, j['id']
		assert_equal 1, j['openor']['id']
		assert_match /^\d{4}-\d{2}-\d{2}/, j['opened_at']
		assert_equal 'I refuse to wait', j['subject']
		assert_equal 'I refuse to wait', j['body']
		res = DB.exec("SELECT * FROM open_next_email(1, 'we@woodegg', 'woodegg')")
		assert_equal 'application/problem+json', res[0]['mime']
		j = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', j['title']
	end
end

