require 'nestful'
# This patch prevents Nestful from raising errors due to response code
module Nestful
	class Connection
		def handle_response(response)
			case response.code.to_i
				when 401
					raise UnauthorizedAccess.new(response)
				when 301,302
					raise Redirection.new(response)
				else
					response
			end
		end
	end
end

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

module Testful
	def prox(meth, url, args={})
		opts = {method: meth}
		if @auth
			opts.merge!(auth_type: :basic, user: @auth[0], password: @auth[1])
		end
		if args.size > 0
			opts.merge!(params: args)
		end
		@res = Nestful::Request.new(BASE + url, opts).execute
		@j = (String(@res.body) == '') ? nil : JSON.parse(@res.body)
	end
	def get(url)
		prox(:get, url)
	end
	def put(url, args={})
		prox(:put, url, args)
	end
	def post(url, args={})
		prox(:post, url, args)
	end
	def delete(url)
		prox(:delete, url)
	end
end

