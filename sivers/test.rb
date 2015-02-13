P_SCHEMA = File.read('../peeps/schema.sql')
P_FIXTURES = File.read('../peeps/fixtures.sql')
require '../test_tools.rb'

class TestComment < Minitest::Test
	include JDB

	def setup
		super
		@new_comment = {uri: 'boo', name: 'Bob Dobalina', email: 'bob@dobali.na', html: 'þ <script>alert("poop")</script> <a href="http://bad.cc">yuck</a> :-)'}
	end

	def test_add
		qry("peeps.get_person(9)")
		assert_equal 'application/problem+json', @res[0]['mime']
		qry("sivers.get_comment(6)")
		assert_equal 'application/problem+json', @res[0]['mime']
		qry("sivers.add_comment($1, $2, $3, $4)", [
			@new_comment[:uri],
			@new_comment[:name],
			@new_comment[:email],
			@new_comment[:html]])
		qry("peeps.get_person(9)")
		assert_equal 'Bob Dobalina', @j['name']
		qry("sivers.get_comment(6)")
		assert_equal 9, @j['person_id']
		assert_includes @j['html'], 'þ'
		refute_includes @j['html'], '<script>'
		assert_includes @j['html'], '&quot;poop&quot;'
		refute_includes @j['html'], '<a href'
		assert_includes @j['html'], 'yuck'
		assert_includes @j['html'], 'smile.gif'
	end
	
	def test_comments_found
		assert_instance_of Sivers::Comment, Sivers::Comment[1]
		assert_equal 'Willy Wonka', Sivers::Comment[1].name
	end

	def test_comments_newest
		assert_equal [5, 4, 3, 2, 1], Sivers::Comment.newest.map(&:id)
	end

	def test_comment_associations
		x = Sivers::Comment[2]
		p = x.person
		assert_equal Person[3], p
		cs = p.sivers_comments
		assert_instance_of Array, cs
		assert_equal [3, 2], cs.map(&:id)
		assert_instance_of Sivers::Comment, cs.pop
	end

	def test_reply
		x = Sivers::Comment[1]
		assert_equal 'That is great.', x.html
		x.add_reply('Thanks')
		assert_equal 'That is great.<br><span class="response">Thanks -- Derek</span>', x.html
		x = Sivers::Comment[2]
		x.add_reply(':-)')
		assert_includes x.html, 'smile'
	end

	def test_spam
		x = Sivers::Comment[5]
		x.spam!
		assert_equal [3, 2, 1], Sivers::Comment.newest.map(&:id)
		assert_nil Person[5]
	end

end
