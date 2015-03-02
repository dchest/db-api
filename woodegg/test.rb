P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
require '../test_tools.rb'

class TestWoodEgg < Minitest::Test
	include JDB

	def test_researcher
		qry("woodegg.get_researcher(1)")
		assert_equal({id: 1, name: '巩俐', bio: 'This is Gong Li'}, @j)
		qry("woodegg.get_researcher(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_writer
		qry("woodegg.get_writer(1)")
		assert_equal({id: 1, name: 'Veruca Salt', bio: 'This is Veruca Salt'}, @j)
		qry("woodegg.get_writer(99)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_editor
		qry("woodegg.get_editor(1)")
		assert_equal({id: 1, name: 'Derek Sivers', bio: 'This is Derek'}, @j)
		qry("woodegg.get_editor(99)")
		assert_equal 'Not Found', @j[:title]
	end
end

