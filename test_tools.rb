require 'pg'
require 'minitest/autorun'
require 'json'

DB = PG::Connection.new(dbname: 'd50b_test', user: 'd50b')
SCHEMA = File.read('schema.sql')
FIXTURES = File.read('fixtures.sql')

class Minitest::Test
	def setup
		DB.exec(P_SCHEMA) if Module::const_defined?('P_SCHEMA')
		DB.exec(SCHEMA)
		DB.exec(P_FIXTURES) if Module::const_defined?('P_FIXTURES')
		DB.exec(FIXTURES)
	end
end

Minitest.after_run do
	DB.exec(P_SCHEMA) if Module::const_defined?('P_SCHEMA')
	DB.exec(SCHEMA)
	DB.exec(P_FIXTURES) if Module::const_defined?('P_FIXTURES')
	DB.exec(FIXTURES)
end

module JDB
	def qry(sql, params=[])
		@res = DB.exec_params("SELECT * FROM #{sql}", params)
		@j = JSON.parse(@res[0]['js'])
	end
end

