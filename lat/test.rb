require '../test_tools.rb'

class LatTest < Minitest::Test
	include JDB

	def test_get_concepts
		qry("lat.get_concepts()")
		r = [{id:1, created_at:'2015-03-19', title:'roses', concept:'roses are red'},
			{id:2, created_at:'2015-03-19', title:'violats', concept:'violets are blue'},
			{id:3, created_at:'2015-03-19', title:'sugar', concept:'sugar is sweet'}]
		assert_equal r, @j
	end

	def test_get_concept
		qry("lat.get_concept(1)")
		r = {id:1, created_at:'2015-03-19', title:'roses', concept:'roses are red',
			urls:[
				{id:1, url:'http://www.rosesarered.co.nz/', notes:nil},
				{id:2, url:'http://en.wikipedia.org/wiki/Roses_are_red', notes:nil}],
			tags:[
				{id:1, tag:'flower'},
				{id:2, tag:'color'}]}
		assert_equal r, @j
		qry("lat.get_concept(999)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_get_concepts  # PRIVATE. Not in public API.
		qry("lat.get_concepts(array[3, 1])")
		assert_instance_of Array, @j
		assert_equal 2, @j.size
		assert_equal 1, @j[0][:id]
		assert_equal 'roses are red', @j[0][:concept]
		assert_equal 'http://www.rosesarered.co.nz/', @j[0][:urls][0][:url]
		assert_equal 3, @j[1][:id]
		assert_equal 'sugar is sweet', @j[1][:concept]
		assert_equal 'flavor', @j[1][:tags][0][:tag]
		qry("lat.get_concepts(array[999, 123])")
		assert_equal [], @j
	end

	def test_create_concept
		qry("lat.create_concept(' river ', ' River running ')")
		assert_equal 5, @j[:id]
		assert_equal 'river', @j[:title]
		assert_equal 'River running', @j[:concept]
		assert_equal nil, @j[:urls]
		assert_equal nil, @j[:tags]
		qry("lat.create_concept('something', $1)", ["  \t \r \n hi \n\t \r  "])
		assert_equal 'hi', @j[:concept]
		qry("lat.create_concept($1, 'something')", ["  \t \r \n hi \n\t \r  "])
		assert_equal 'hi', @j[:title]
	end

	def test_create_concept_err
		qry("lat.create_concept(NULL, 'something')")
		assert @j[:title].include? 'not-null'
		qry("lat.create_concept('something', NULL)")
		assert @j[:title].include? 'not-null'
		qry("lat.create_concept('', 'something')")
		assert @j[:title].include? 'title_not_empty'
		qry("lat.create_concept('something', '')")
		assert @j[:title].include? 'concept_not_empty'
		qry("lat.create_concept('new roses', 'roses are red')")
		assert @j[:title].include? 'unique constraint'
		qry("lat.create_concept('roses', 'new roses are red')")
		assert @j[:title].include? 'unique constraint'
	end

	def test_update_concept
		qry("lat.update_concept(3, '  on sugar  ', 'sugar is sticky ')")
		assert_equal 'on sugar', @j[:title]
		assert_equal 'sugar is sticky', @j[:concept]
		assert_equal [{id:3, tag:'flavor'}], @j[:tags]
		qry("lat.update_concept(999, 'nope', 'should return 404')")
		assert_equal 'Not Found', @j[:title]
	end

	def test_update_concept_err
		qry("lat.update_concept(1, '', 'ok')")
		assert @j[:title].include? 'not_empty'
		qry("lat.update_concept(1, 'ok', '')")
		assert @j[:title].include? 'not_empty'
		qry("lat.update_concept(1, 'ok', NULL)")
		assert @j[:title].include? 'not-null'
		qry("lat.update_concept(1, NULL, 'ok')")
		assert @j[:title].include? 'not-null'
	end

	def test_delete_concept
		qry("lat.delete_concept(1)")
		assert_equal 'roses are red', @j[:concept]
		qry("lat.delete_concept(1)")
		assert_equal 'Not Found', @j[:title]
		qry("lat.delete_concept(999)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_tag_concept
		qry("lat.tag_concept(2, $1)", [" \t\r\n BaNG \n\t "])
		assert_equal 'bang', @j[:tags][2][:tag]
		qry("lat.tag_concept(3, '  JUICY ')")
		assert_equal [{id:3, tag:'flavor'},{id:5, tag:'juicy'}], @j[:tags]
		qry("lat.tag_concept(3, 'flavor')")
		assert_equal [{id:3, tag:'flavor'},{id:5, tag:'juicy'}], @j[:tags]
		qry("lat.tag_concept(3, '  FLOWER ')")
		assert_equal [{id:1, tag:'flower'},{id:3, tag:'flavor'},{id:5, tag:'juicy'}], @j[:tags]
		qry("lat.tag_concept(9999, 'nah')")
		assert_equal 'Not Found', @j[:title]
	end

	def test_untag_concept
		qry("lat.untag_concept(1, 1)")
		assert_equal [{id:2, tag:'color'}], @j[:tags]
		qry("lat.get_concept(2)")
		assert_equal [{id:1, tag:'flower'},{id:2, tag:'color'}], @j[:tags]
		qry("lat.untag_concept(9999, 1)")
		assert_equal 'Not Found', @j[:title]
		qry("lat.untag_concept(2, 9999)")
		assert_equal [{id:1, tag:'flower'},{id:2, tag:'color'}], @j[:tags]
	end

	def test_get_url  # PRIVATE. Not in public API.
		qry("lat.get_url(3)")
		assert_equal 3, @j[:id]
		assert_equal 'http://en.wikipedia.org/wiki/Violets_Are_Blue', @j[:url]
		assert_equal 'many refs here', @j[:notes]
	end

	def test_add_url
		qry("lat.add_url(3, $1, $2)", ["\r\thttp://some.url \t \n", " \t\r\n some notes \n\t "])
		assert_equal 'http://some.url', @j[:url]
		assert_equal 'some notes', @j[:notes]
	end

	def test_update_url
		qry("lat.update_url(1, $1, $2)", ["\r\thttp://some.url \t \n", " \t\r\n some notes \n\t "])
		assert_equal 1, @j[:id]
		assert_equal 'http://some.url', @j[:url]
		assert_equal 'some notes', @j[:notes]
	end

	def test_delete_url
		qry("lat.delete_url(3)")
		assert_equal 3, @j[:id]
		assert_equal 'http://en.wikipedia.org/wiki/Violets_Are_Blue', @j[:url]
		assert_equal 'many refs here', @j[:notes]
		qry("lat.delete_url(3)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_tags
		qry("lat.tags()")
		assert_instance_of Array, @j
		assert_equal 3, @j.size
		assert @j.include?({id: 1, tag: 'flower'})
		assert @j.include?({id: 2, tag: 'color'})
		assert @j.include?({id: 3, tag: 'flavor'})
	end

	def test_concepts_tagged
		qry("lat.concepts_tagged('flower')")
		assert_instance_of Array, @j
		assert_equal 2, @j.size
		assert_equal 1, @j[0][:id]
		assert_equal 2, @j[1][:id]
		qry("lat.concepts_tagged('boop')")
		assert_equal [], @j
	end

	def test_get_pairings
		qry("lat.get_pairings()")
		r = [{id:1, created_at:'2015-03-19', concept1:'roses', concept2:'violets'}]
		assert_equal r, @j
	end

	def test_get_pairing
		qry("lat.get_pairing(1)")
		r = {:id=>1, :created_at=>'2015-03-19', :thoughts=>'describing flowers',
			:concept1=>{:id=>1, :created_at=>'2015-03-19', :title=>'roses', :concept=>'roses are red',
				:urls=>[
					{:id=>1, :url=>'http://www.rosesarered.co.nz/', :notes=>nil},
					{:id=>2, :url=>'http://en.wikipedia.org/wiki/Roses_are_red', :notes=>nil}],
				:tags=>[
					{:id=>1, :tag=>'flower'}, {:id=>2, :tag=>'color'}]},
			:concept2=>{:id=>2, :created_at=>'2015-03-19', :title=>'violets', :concept=>'violets are blue',
				:urls=>[
					{:id=>3, :url=>'http://en.wikipedia.org/wiki/Violets_Are_Blue', :notes=>'many refs here'}],
				:tags=>[{:id=>1, :tag=>'flower'}, {:id=>2, :tag=>'color'}]}}
		assert_equal r, @j
	end

	def test_create_pairing
		qry("lat.create_pairing()")
		assert_equal 2, @j[:id]
		pair2 = [@j[:concept1][:id], @j[:concept2][:id]].sort
		refute_equal [1,2], pair2
		qry("lat.create_pairing()")
		assert_equal 3, @j[:id]
		pair3 = [@j[:concept1][:id], @j[:concept2][:id]].sort
		refute_equal [1,2], pair3
		refute_equal pair2, pair3
		qry("lat.create_pairing()")
		qry("lat.create_pairing()")
		qry("lat.create_pairing()")
		qry("lat.create_pairing()")
		assert @j[:title].include? 'no unpaired concepts'
	end

	def test_update_pairing
		qry("lat.update_pairing(1, ' \n new thoughts \t\r ')")
		assert_equal 'new thoughts', @j[:thoughts]
	end

	def test_delete_pairing
		qry("lat.delete_pairing(1)")
		assert_equal 'describing flowers', @j[:thoughts]
		qry("lat.delete_pairing(1)")
		assert_equal 'Not Found', @j[:title]
	end

	def test_tag_pairing
		qry("lat.tag_pairing(1, 'newtag')")
		assert_equal %w{flower color newtag}, @j[:concept1][:tags].map {|t| t[:tag]}
		assert_equal %w{flower color newtag}, @j[:concept2][:tags].map {|t| t[:tag]}
	end

end

