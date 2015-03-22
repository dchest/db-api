SCHEMA = File.read('../../lat/schema.sql')
FIXTURES = File.read('../../lat/fixtures.sql')
require '../../test_tools.rb'

require '../lib/b50d/lat.rb'

class LatTest < Minitest::Test

	def setup
		super
		@l = B50D::Lat.new('test')
	end

	def test_get_concepts
		x = @l.get_concepts
		r = [{id:1, created_at:'2015-03-19', title:'roses', concept:'roses are red'},
			{id:2, created_at:'2015-03-19', title:'violets', concept:'violets are blue'},
			{id:3, created_at:'2015-03-19', title:'sugar', concept:'sugar is sweet'}]
		assert_equal r, x
	end

	def test_get_concept
		x = @l.get_concept(1)
		r = {id:1, created_at:'2015-03-19', title:'roses', concept:'roses are red',
			urls:[
				{id:1, url:'http://www.rosesarered.co.nz/', notes:nil},
				{id:2, url:'http://en.wikipedia.org/wiki/Roses_are_red', notes:nil}],
			tags:[
				{id:1, tag:'flower'},
				{id:2, tag:'color'}]}
		assert_equal r, x
		refute @l.get_concept(999)
		assert_equal 'Not Found', @l.error
	end

	def test_create_concept
		x = @l.create_concept(' river ', ' River running ')
		assert_equal 4, x[:id]
		assert_equal 'river', x[:title]
		assert_equal 'River running', x[:concept]
		assert_equal nil, x[:urls]
		assert_equal nil, x[:tags]
		x = @l.create_concept('something', "  \t \r \n hi \n\t \r  ")
		assert_equal 'hi', x[:concept]
		x = @l.create_concept("  \t \r \n hi \n\t \r  ", 'something')
		assert_equal 'hi', x[:title]
	end

	def test_create_concept_err
		refute @l.create_concept(nil, 'something')
		assert @l.error.include? 'not-null'
		refute @l.create_concept('something', nil)
		assert @l.error.include? 'not-null'
		refute @l.create_concept('', 'something')
		assert @l.error.include? 'title_not_empty'
		refute @l.create_concept('something', '')
		assert @l.error.include? 'concept_not_empty'
		refute @l.create_concept('new roses', 'roses are red')
		assert @l.error.include? 'unique constraint'
		refute @l.create_concept('roses', 'new roses are red')
		assert @l.error.include? 'unique constraint'
	end

	def test_update_concept
		x = @l.update_concept(3, '  on sugar  ', 'sugar is sticky ')
		assert_equal 'on sugar', x[:title]
		assert_equal 'sugar is sticky', x[:concept]
		assert_equal [{id:3, tag:'flavor'}], x[:tags]
		refute @l.update_concept(999, 'nope', 'should return 404')
		assert_equal 'Not Found', @l.error
	end

	def test_update_concept_err
		refute @l.update_concept(1, '', 'ok')
		assert @l.error.include? 'not_empty'
		refute @l.update_concept(1, 'ok', '')
		assert @l.error.include? 'not_empty'
		refute @l.update_concept(1, 'ok', nil)
		assert @l.error.include? 'not-null'
		refute @l.update_concept(1, nil, 'ok')
		assert @l.error.include? 'not-null'
	end

	def test_delete_concept
		x = @l.delete_concept(1)
		assert_equal 'roses are red', x[:concept]
		refute @l.delete_concept(1)
		assert_equal 'Not Found', @l.error
		refute @l.delete_concept(999)
		assert_equal 'Not Found', @l.error
	end

	def test_tag_concept
		x = @l.tag_concept(2, " \t\r\n BaNG \n\t ")
		assert_equal 'bang', x[:tags][2][:tag]
		x = @l.tag_concept(3, '  JUICY ')
		assert_equal [{id:3, tag:'flavor'},{id:5, tag:'juicy'}], x[:tags]
		x = @l.tag_concept(3, 'flavor')
		assert_equal [{id:3, tag:'flavor'},{id:5, tag:'juicy'}], x[:tags]
		x = @l.tag_concept(3, '  FLOWER ')
		assert_equal [{id:1, tag:'flower'},{id:3, tag:'flavor'},{id:5, tag:'juicy'}], x[:tags]
		refute @l.tag_concept(9999, 'nah')
		assert_equal 'Not Found', @l.error
	end

	def test_untag_concept
		x = @l.untag_concept(1, 1)
		assert_equal [{id:2, tag:'color'}], x[:tags]
		x = @l.get_concept(2)
		assert_equal [{id:1, tag:'flower'},{id:2, tag:'color'}], x[:tags]
		refute @l.untag_concept(9999, 1)
		assert_equal 'Not Found', @l.error
		x = @l.untag_concept(2, 9999)
		assert_equal [{id:1, tag:'flower'},{id:2, tag:'color'}], x[:tags]
	end

	def test_add_url
		x = @l.add_url(3, "\r\thttp://some.url \t \n", " \t\r\n some notes \n\t ")
		assert_equal 'http://some.url', x[:url]
		assert_equal 'some notes', x[:notes]
	end

	def test_update_url
		x = @l.update_url(1, "\r\thttp://some.url \t \n", " \t\r\n some notes \n\t ")
		assert_equal 1, x[:id]
		assert_equal 'http://some.url', x[:url]
		assert_equal 'some notes', x[:notes]
	end

	def test_delete_url
		x = @l.delete_url(3)
		assert_equal 3, x[:id]
		assert_equal 'http://en.wikipedia.org/wiki/Violets_Are_Blue', x[:url]
		assert_equal 'many refs here', x[:notes]
		refute @l.delete_url(3)
		assert_equal 'Not Found', @l.error
	end

	def test_tags
		x = @l.tags
		assert_instance_of Array, x
		assert_equal 3, x.size
		assert x.include?({id: 1, tag: 'flower'})
		assert x.include?({id: 2, tag: 'color'})
		assert x.include?({id: 3, tag: 'flavor'})
	end

	def test_concepts_tagged
		x = @l.concepts_tagged('flower')
		assert_instance_of Array, x
		assert_equal 2, x.size
		assert_equal 1, x[0][:id]
		assert_equal 2, x[1][:id]
		x = @l.concepts_tagged('boop')
		assert_equal [], x
	end

	def test_get_pairings
		x = @l.get_pairings
		r = [{id:1, created_at:'2015-03-19', concept1:'roses', concept2:'violets'}]
		assert_equal r, x
	end

	def test_get_pairing
		x = @l.get_pairing(1)
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
		assert_equal r, x
	end

	def test_create_pairing
		x = @l.create_pairing
		assert_equal 2, x[:id]
		pair2 = [x[:concept1][:id], x[:concept2][:id]].sort
		refute_equal [1,2], pair2
		x = @l.create_pairing
		assert_equal 3, x[:id]
		pair3 = [x[:concept1][:id], x[:concept2][:id]].sort
		refute_equal [1,2], pair3
		refute_equal pair2, pair3
		refute @l.create_pairing
		assert @l.error.include? 'no unpaired concepts'
	end

	def test_update_pairing
		x = @l.update_pairing(1, " \n new thoughts \t\r ")
		assert_equal 'new thoughts', x[:thoughts]
	end

	def test_delete_pairing
		x = @l.delete_pairing(1)
		assert_equal 'describing flowers', x[:thoughts]
		refute @l.delete_pairing(1)
		assert_equal 'Not Found', @l.error
	end

	def test_tag_pairing
		x = @l.tag_pairing(1, 'newtag')
		assert_equal %w{flower color newtag}, x[:concept1][:tags].map {|t| t[:tag]}
		assert_equal %w{flower color newtag}, x[:concept2][:tags].map {|t| t[:tag]}
	end

end

