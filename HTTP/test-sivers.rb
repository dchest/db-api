require 'minitest/autorun'
require_relative 'testful.rb'

#Minitest.after_run do
	# delete '/reset'
#end

require_relative 'sivers.rb'
class TestCommentAPI < Minitest::Test
	include Testful
	Testful::BASE = 'http://127.0.0.1:10021'

	def setup
		@auth = ['a'*8, 'b'*8]
		delete '/reset'
		@new_comment = {uri: 'boo', name: 'Bob Dobalina', email: 'bob@dobali.na', html: 'þ <script>alert("poop")</script> <a href="http://bad.cc">yuck</a> :-)'}
	end

	def test_add
		get '/comments/6'
		assert_equal '', @res.body
		assert_equal 'application/problem+json', @res.headers['content-type']
		post '/comments', @new_comment
		get '/comments/6'
		assert_equal 9, @j['person_id']
		assert_includes @j['html'], 'þ'
		refute_includes @j['html'], '<script>'
		assert_includes @j['html'], '&quot;poop&quot;'
		refute_includes @j['html'], '<a href'
		assert_includes @j['html'], 'yuck'
		assert_includes @j['html'], 'smile.gif'
	end
	
	def test_comments_newest
		qry("sivers.new_comments()")
		assert_equal [5, 4, 3, 2, 1], @j.map {|x| x['id']}
	end

	def test_reply
		qry("sivers.reply_to_comment(1, 'Thanks')")
		assert_equal 'That is great.<br><span class="response">Thanks -- Derek</span>', @j['html']
		qry("sivers.reply_to_comment(2, ':-)')")
		assert_includes @j['html'], 'smile'
	end

	def test_delete
		qry("sivers.delete_comment(5)")
		assert_equal 'spam2', @j['html']
		qry("sivers.new_comments()")
		assert_equal [4, 3, 2, 1], @j.map {|x| x['id']}
		qry("peeps.get_person(5)")
		assert_equal 'Oompa Loompa', @j['name']
	end

	def test_spam
		qry("sivers.spam_comment(5)")
		assert_equal 'spam2', @j['html']
		qry("peeps.get_person(5)")
		assert_equal 'application/problem+json', @res.headers['content-type']
		qry("sivers.new_comments()")
		assert_equal [3, 2, 1], @j.map {|x| x['id']}
	end

	def test_update
		qry("sivers.update_comment(5, $1)", ['{"html":"new body", "name":"Opa!", "ignore":true}'])
		assert_equal 'Opa!', @j['name']
		assert_equal 'new body', @j['html']
		assert_equal 'oompa@loompa.mm', @j['email']
	end

end
