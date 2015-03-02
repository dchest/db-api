P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
require '../test_tools.rb'

class TestWoodEgg < Minitest::Test
	include JDB

	def test_something
		qry("woodegg.get_book(1)")
		assert_equal 'China 2013: How To', @j['title']
	end
end

