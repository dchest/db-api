SCHEMA = File.read('../../sivers/schema.sql')
FIXTURES = File.read('../../sivers/fixtures.sql')
P_SCHEMA = File.read('../../peeps/schema.sql')
P_FIXTURES = File.read('../../peeps/fixtures.sql')
require '../../test_tools.rb'

require '../lib/b50d/sivers-comments.rb'

class TestSiversComments < Minitest::Test

	def setup
		super
		@sc = B50D::SiversComments.new('aaaaaaaa', 'bbbbbbbb', 'test')
		@nu = 'þíŋ'
	end

	def test_api_auth
		assert_raises RuntimeError do
			B50D::SiversComments.new('bad', 'wrong', 'test')
		end
	end

	def test_get_comments
		cc = @sc.get_comments
		assert_instance_of Array, cc
		assert_equal 5, cc.size
		assert_equal [5, 4, 3, 2, 1], cc.map {|x| x[:id]}
		c = cc.pop
		assert c[:id] > 0
		assert c[:name].length > 2
	end

	def test_get_comment
		c = @sc.get_comment(1)
		assert_instance_of Array, c[:person][:stats]
		assert_equal 'Willy Wonka', c[:name]
		assert_equal 'That is great.', c[:html]
		assert_equal '2000-01-01', c[:person][:created_at]
	end

	def test_update_comment
		assert @sc.update_comment(1, {html: @nu})
		c = @sc.get_comment(1)
		assert_equal @nu, c[:html]
	end

	def test_reply_to_comment
		assert @sc.reply_to_comment(2, @nu)
		c = @sc.get_comment(2)
		assert c[:html].include? @nu
		assert c[:html].include? '<span class="response">'
	end

	def test_delete_comment
		assert @sc.delete_comment(5)
		refute @sc.get_comment(5)
		assert @sc.get_comment(4)
	end

	def test_spam_comment
		assert @sc.spam_comment(5)
		refute @sc.get_comment(5)
		refute @sc.get_comment(4)
	end
end
