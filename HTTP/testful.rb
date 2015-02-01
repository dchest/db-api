# This module does 4 things:
# 1. Create get post put delete methods which...
# 2. Add Testful::BASE url to calls
# 3. Save response in @res
# 4. Save decoded body in @j
# 
# USAGE:
# class TestSomething < Minitest::Test
#   include Testful
#   Testful::BASE = 'http://127.0.0.1:1234'
#
#   def test_something
#     post '/someurl', {some: 'values'}
#     assert_equal 200, @res.status
#     assert_equal 'application/json', @res.headers['content-type']
#     assert_equal 'some', @j['thing']
#   end

require 'nestful'
module Testful
	def prox(meth, url, args)
		@res = Nestful.send(meth, BASE + url, args)
		@j = @res.decoded
	end
	def get(url, *args)
		prox(:get, url, args)
	end
	def put(url, *args)
		prox(:put, url, args)
	end
	def post(url, *args)
		prox(:post, url, args)
	end
	def delete(url, *args)
		prox(:delete, url, args)
	end
end

