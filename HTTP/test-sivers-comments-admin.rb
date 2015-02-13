require 'minitest/autorun'
require_relative 'testful.rb'

#Minitest.after_run do
	# delete '/reset'
#end

require_relative 'sivers-comments-admin.rb'
class TestSiversCommentsAdminAPI < Minitest::Test
	include Testful
	Testful::BASE = 'http://127.0.0.1:10021'

	def setup
		@auth = ['a'*8, 'b'*8]
		delete '/reset'
	end

	def test_comments_newest
		get '/comments'
		assert_equal [5, 4, 3, 2, 1], @j.map {|x| x['id']}
	end

	def test_reply
		post '/comments/1/reply', {reply: 'Thanks'}
		assert_equal 'That is great.<br><span class="response">Thanks -- Derek</span>', @j['html']
		post '/comments/2/reply', {reply: ':-)'}
		assert_includes @j['html'], 'smile'
	end

	def test_delete
		delete '/comments/5'
		assert_equal 'spam2', @j['html']
		get '/comments'
		assert_equal [4, 3, 2, 1], @j.map {|x| x['id']}
	end

	def test_spam
		delete '/comments/5/spam'
		assert_equal 'spam2', @j['html']
		get '/comments'
		assert_equal [3, 2, 1], @j.map {|x| x['id']}
	end

	def test_update
		put '/comments/5', {json: '{"html":"new body", "name":"Opa!", "ignore":true}'}
		assert_equal 'Opa!', @j['name']
		assert_equal 'new body', @j['html']
		assert_equal 'oompa@loompa.mm', @j['email']
	end

end
