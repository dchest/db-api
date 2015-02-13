require 'minitest/autorun'
require_relative 'testful.rb'

#Minitest.after_run do
	# delete '/reset'
#end

require_relative 'sivers-comments-public.rb'
class TestSiversCommentsPublicAPI < Minitest::Test
	include Testful
	Testful::BASE = 'http://127.0.0.1:10031'

	def setup
		delete '/reset'
	end

	def test_add
		@new_comment = {uri: 'boo', name: 'Bob Dobalina', email: 'bob@dobali.na', html: 'þ <script>alert("poop")</script> <a href="http://bad.cc">yuck</a> :-)'}
		post '/comments', @new_comment
		assert_equal 9, @j['person_id']
		assert_includes @j['html'], 'þ'
		refute_includes @j['html'], '<script>'
		assert_includes @j['html'], '&quot;poop&quot;'
		refute_includes @j['html'], '<a href'
		assert_includes @j['html'], 'yuck'
		assert_includes @j['html'], 'smile.gif'
	end

end
