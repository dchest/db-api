require 'pg'
require 'minitest/autorun'
require 'json'

DB = PG::Connection.new(dbname: 'sivers', user: 'sivers')
SQL = File.read('sql.sql')

class Minitest::Test
	def setup
		DB.exec(SQL)
	end
end
Minitest.after_run do
	DB.exec(SQL)
end

class SqlTest < Minitest::Test
	def test_not_null
		assert_raises PG::NotNullViolation do
			DB.exec("INSERT INTO concepts (concept) VALUES (NULL)")
		end
	end

	def test_not_empty
		err = assert_raises PG::CheckViolation do
			DB.exec("INSERT INTO concepts (concept) VALUES ('')")
		end
		assert err.message.include? 'not_empty'
	end

	def test_clean_concept
		res = DB.exec_params("INSERT INTO concepts (concept) VALUES ($1) RETURNING *", ["  \t \r \n hi \n\t \r  "])
		assert_equal 'hi', res[0]['concept']
	end

	def test_clean_tag
		res = DB.exec_params("INSERT INTO tags (concept_id, tag) VALUES ($1, $2) RETURNING *", [2, " \t\r\n BaNG \n\t "])
		assert_equal 'bang', res[0]['tag']
	end

	def test_new_pairing
		res = DB.exec("SELECT * FROM new_pairing()")
		assert_equal '2', res[0]['id']
		pair2 = [res[0]['concept1_id'], res[0]['concept2_id']].sort
		refute_equal %w(1 2), pair2
		res = DB.exec("SELECT * FROM new_pairing()")
		assert_equal '3', res[0]['id']
		pair3 = [res[0]['concept1_id'], res[0]['concept2_id']].sort
		refute_equal %w(1 2), pair3
		refute_equal pair2, pair3
		err = assert_raises PG::RaiseException do
			DB.exec("SELECT * FROM new_pairing()")
		end
		assert err.message.include? 'no unpaired concepts'
	end

	def test_get_concept
		res = DB.exec("SELECT mime, js FROM get_concept(1)")
		js = JSON.parse(res[0]['js'])
		assert_equal 'application/json', res[0]['mime']
		assert_equal %w(id created_at concept tags), js.keys
		assert_equal %w(color flower), js['tags'].sort
		assert_equal 'roses are red', js['concept']
	end

	def test_get_concept_404
		res = DB.exec("SELECT mime, js FROM get_concept(999)")
		js = JSON.parse(res[0]['js'])
		assert_equal 'application/problem+json', res[0]['mime']
		assert_equal 'about:blank', js['type']
		assert_equal 'Not Found', js['title']
		assert_equal 404, js['status']
	end

	def test_create_concept
		res = DB.exec("SELECT mime, js FROM create_concept(' River running ')")
		assert_equal 'application/json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 4, js['id']
		assert_equal 'River running', js['concept']
		assert_equal [], js['tags']
	end

	def test_update_concept
		res = DB.exec("SELECT mime, js FROM update_concept(3, 'sugar is sticky ')")
		assert_equal 'application/json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 3, js['id']
		assert_equal 'sugar is sticky', js['concept']
		assert_equal %w(flavor), js['tags']
		res = DB.exec("SELECT mime, js FROM update_concept(999, 'should return 404')")
		assert_equal 'application/problem+json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', js['title']
	end

	def test_delete_concept
		res = DB.exec("SELECT mime, js FROM delete_concept(1)")
		assert_equal 'application/json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 'roses are red', js['concept']
		res = DB.exec("SELECT mime, js FROM delete_concept(1)")
		assert_equal 'application/problem+json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', js['title']
	end

	def test_update_err
		res = DB.exec("SELECT mime, js FROM update_concept(1, '')")
		assert_equal 'application/problem+json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_match /23514$/, js['type']
		assert_match /not_empty/, js['title']
		assert_match /^Failing row/, js['detail']
		res = DB.exec("SELECT mime, js FROM update_concept(1, NULL)")
		js = JSON.parse(res[0]['js'])
		assert_match /23502$/, js['type']
		assert_match /not-null/, js['title']
		assert_match /^Failing row/, js['detail']
	end

	def test_create_err
		res = DB.exec("SELECT mime, js FROM create_concept('roses are red')")
		js = JSON.parse(res[0]['js'])
		assert_match /23505$/, js['type']
		assert_match /unique constraint/, js['title']
		res = DB.exec("SELECT mime, js FROM create_concept(NULL)")
		js = JSON.parse(res[0]['js'])
		assert_match /23502$/, js['type']
		assert_match /not-null/, js['title']
		assert_match /^Failing row/, js['detail']
	end

	def test_tag_concept
		res = DB.exec("SELECT mime, js FROM tag_concept(3, ' JUICY ')")
		js = JSON.parse(res[0]['js'])
		assert_equal 'sugar is sweet', js['concept']
		assert_equal %w(flavor juicy), js['tags'].sort
	end

	def test_get_concepts
		res = DB.exec("SELECT * FROM get_concepts(array[3, 1])")
		js = JSON.parse(res[0]['js'])
		assert_instance_of Array, js
		assert_equal 2, js.size
		assert_equal 1, js[0]['id']
		assert_equal 3, js[1]['id']
		assert_equal %w{color flower}, js[0]['tags'].sort
		assert_equal %w{flavor}, js[1]['tags']
		res = DB.exec("SELECT * FROM get_concepts(array[99, 123])")
		assert_equal 'application/json', res[0]['mime']
		assert_equal [], JSON.parse(res[0]['js'])
	end

	def test_concepts_tagged
		res = DB.exec("SELECT * FROM concepts_tagged('flower')")
		js = JSON.parse(res[0]['js'])
		assert_instance_of Array, js
		assert_equal 2, js.size
		assert_equal 1, js[0]['id']
		assert_equal 2, js[1]['id']
		assert_equal %w{color flower}, js[0]['tags'].sort
		assert_equal %w{color flower}, js[1]['tags'].sort
	end

	def test_get_pairing
		res = DB.exec("SELECT * FROM get_pairing(1)")
		assert_equal 'application/json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 1, js['id']
		assert_match /201[0-9]-[0-9]{2}-[0-9]{2}/, js['created_at']
		assert_equal 'describing flowers', js['thoughts']
		assert_instance_of Array, js['concepts']
		assert_equal 2, js['concepts'].size
		c = js['concepts'][0]
		assert_equal 1, c['id']
		assert_equal 'roses are red', c['concept']
		assert_equal %w(color flower), c['tags'].sort
		c = js['concepts'][1]
		assert_equal 2, c['id']
		assert_equal 'violets are blue', c['concept']
		assert_equal %w(color flower), c['tags'].sort
	end

	def test_create_pairing
		res = DB.exec("SELECT * FROM create_pairing()")
		js = JSON.parse(res[0]['js'])
		assert_equal 2, js['id']
		assert_match /201[0-9]-[0-9]{2}-[0-9]{2}/, js['created_at']
		assert_nil js['thoughts']
		assert_instance_of Array, js['concepts']
		assert_equal 2, js['concepts'].size
	end

	def test_update_pairing
		res = DB.exec("SELECT * FROM update_pairing(1, 'new thoughts')")
		js = JSON.parse(res[0]['js'])
		assert_equal 'new thoughts', js['thoughts']
	end

	def test_delete_pairing
		res = DB.exec("SELECT * FROM delete_pairing(1)")
		js = JSON.parse(res[0]['js'])
		assert_equal 'describing flowers', js['thoughts']
		res = DB.exec("SELECT * FROM delete_pairing(1)")
		assert_equal 'application/problem+json', res[0]['mime']
		js = JSON.parse(res[0]['js'])
		assert_equal 'Not Found', js['title']
	end

	def test_tag_pairing
		res = DB.exec("SELECT * FROM tag_pairing(1, 'newtag')")
		js = JSON.parse(res[0]['js'])
		assert_equal %w{color flower newtag}, js['concepts'][0]['tags'].sort
		assert_equal %w{color flower newtag}, js['concepts'][1]['tags'].sort
	end

end

