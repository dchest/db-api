P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
require '../test_tools.rb'

class TestWoodEgg < Minitest::Test
	include JDB

	def test_researcher
		qry("woodegg.get_researcher(1)")
		assert_equal '巩俐', @j[:name]
		assert_equal 'This is Gong Li', @j[:bio]
		qry("woodegg.get_researcher(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_writer
		qry("woodegg.get_writer(1)")
		assert_equal 'Veruca Salt', @j[:name]
		assert_equal 'This is Veruca Salt', @j[:bio]
		qry("woodegg.get_writer(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_editor
		qry("woodegg.get_editor(1)")
		assert_equal 'Derek Sivers', @j[:name]
		assert_equal 'This is Derek', @j[:bio]
		qry("woodegg.get_editor(99)")
		assert_equal 'Not Found', @j[:title]
	end
end

