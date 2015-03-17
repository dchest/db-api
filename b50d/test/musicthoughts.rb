SCHEMA = File.read('../../musicthoughts/schema.sql')
FIXTURES = File.read('../../musicthoughts/fixtures.sql')
P_SCHEMA = File.read('../../peeps/schema.sql')
P_FIXTURES = File.read('../../peeps/fixtures.sql')
require '../../test_tools.rb'

require '../lib/b50d/musicthoughts.rb'

class TestMusicThoughts < Minitest::Test

	def setup
		super
		@mt = B50D::MusicThoughts.new('test')
		@authornames = ['Maya Angelou', 'Miles Davis', '老崔']
		@nu = {author_name: 'Oscar', contributor_name: 'Kid', contributor_email: 'kid@kid.net', lang: 'fr', thought: 'Ça va'}
	end

	def test_languages
		assert_equal ['ar', 'de', 'en', 'es', 'fr', 'it', 'ja', 'pt', 'ru', 'zh'], @mt.languages.sort
	end

	def test_categories
		cc = @mt.categories
		assert_instance_of Array, cc
		assert_equal 12, cc.size
		c = cc.pop
		assert c[:id] > 0
		assert c[:category].length > 2
	end

	def test_category
		c = @mt.category(2)
		assert_equal 'writing lyrics', c[:category]
		assert_equal [4,5], c[:thoughts].map {|t| t[:id]}.sort
	end

	def test_authors
		aa = @mt.authors
		assert_equal @authornames, aa.map {|a| a[:name]}.sort
	end

	def test_authors_top
		aa = @mt.authors_top
		assert_equal @authornames, aa.map {|a| a[:name]}.sort
		a = aa.pop
		assert a[:howmany] > 0
	end

	def test_author
		a = @mt.author(1)
		assert_equal 'Miles Davis', a[:name]
		assert_equal [1,4], a[:thoughts].map {|x| x[:id]}.sort
		a = @mt.author(3)
		assert_equal 1, a[:thoughts].count
	end

	def test_author_bad
		assert_nil @mt.author(9876)
	end

	def test_contributors
		cc = @mt.contributors
		assert_equal ['Derek Sivers', 'Veruca Salt'], cc.map {|c| c[:name]}.sort
	end

	def test_contributors_top
		cc = @mt.contributors_top
		assert_equal ['Derek Sivers', 'Veruca Salt'], cc.map {|c| c[:name]}.sort
		c = cc.pop
		assert c[:howmany] > 0
	end

	def test_contributor
		c = @mt.contributor(1)
		assert_equal 'Derek Sivers', c[:name]
		#assert_equal 'Singapore, Singapore', c[:place]
		assert_equal [1,3,4], c[:thoughts].map {|x| x[:id]}.sort
		c = @mt.contributor(2)
		#assert_equal 'http://www.wonka.com/', c[:url]
		#assert_equal 'the magic chocolate factory', c[:place]
		c = @mt.contributor(3)
		assert_equal 'Veruca Salt', c[:name]
		#assert_equal 'salt.com or verucaenterprises.co.uk', c[:url]
		#assert_equal 'London, England, United Kingdom', c[:place]
		assert_equal 5, c[:thoughts][0][:id]
	end

	def test_contributor_bad
		assert_nil @mt.contributor(9876)
	end

	def test_all_thoughts
		tt = @mt.thoughts_all
		assert_equal [1, 3, 4, 5], tt.map {|t| t[:id]}.sort
		t1 = tt.find {|x| x[:id] == 1}
		assert_equal "Play what you don't know.", t1[:en]
	end

	def test_new_thoughts
		tt = @mt.thoughts_new
		assert_equal [5, 4, 3, 1], tt.map {|t| t[:id]}
	end

	def test_random_thought
		t = @mt.thought_random
		assert [1, 4].include? t[:id]
		t = @mt.thought_random
		assert [1, 4].include? t[:id]
	end

	def test_one_thought
		t = @mt.thought(1)
		assert_equal 'http://www.milesdavis.com/', t[:source_url]
		assert_equal [4, 6, 7], t[:categories].map {|c| c[:id]}.sort
	end

	def test_bad_thought
		assert_nil @mt.thought(98765)
		assert_nil @mt.thought('')
		assert_nil @mt.thought('"')
	end

	def test_search
		r = @mt.search('experiment')
		assert_nil r[:contributors]
		assert_nil r[:authors]
		assert_nil r[:thoughts]
		assert_equal 1, r[:categories].size
		assert_equal 4, r[:categories].pop[:id]
		r = @mt.search('miles')
		assert_nil r[:contributors]
		assert_nil r[:categories]
		assert_nil r[:thoughts]
		assert_equal 1, r[:authors].size
		assert_equal 'Miles Davis', r[:authors].pop[:name]
		r = @mt.search('veruca')
		assert_nil r[:authors]
		assert_nil r[:categories]
		assert_nil r[:thoughts]
		assert_equal 1, r[:contributors].size
		assert_equal 'Veruca Salt', r[:contributors].pop[:name]
		r = @mt.search('you')
		assert_nil r[:authors]
		assert_nil r[:categories]
		assert_nil r[:contributors]
		assert_equal 2, r[:thoughts].size
		assert_equal [1, 5], r[:thoughts].map {|x| x[:id]}.sort
	end

	def test_lang_category
		@mt.set_lang('ru')
		c = @mt.category(1)
		assert_equal 'сочинение музыки', c[:category]
		@mt.set_lang('ar')
		c = @mt.category(1)
		assert_equal 'التأليف الموسيقي', c[:category]
	end

	def test_lang_thought
		@mt.set_lang('ja')
		t = @mt.thought(1)
		assert_equal '知らないものを弾け。', t[:thought]
		@mt.set_lang('ar')
		t = @mt.thought(5)
		assert_equal 'الناس سينسون ما قلته وما فعلته لكنهم لن ينسوا أبداً الشعور الذي جعلتهم يشعرون به.', t[:thought]
	end

	def test_lang_thought_categories
		@mt.set_lang('zh')
		t = @mt.thought(3)
		assert_equal '演出中', t[:categories].pop[:category]
	end

	def test_lang_authors
		@mt.set_lang('pt')
		a = @mt.author(1)
		assert_equal 'Miles Davis', a[:name]
		tt = a[:thoughts]
		assert_equal 2, tt.size
		pt1 = 'Toca aquilo que não sabes.'
		pt2 = 'Não temas os erros. Eles não existem.'
		assert [pt1, pt2].include? tt.pop[:thought]
		assert [pt1, pt2].include? tt.pop[:thought]
	end

	# for now, searches all languages, no matter which one is shown
	def test_lang_search
		r = @mt.search('Spiele')
		assert_equal "Play what you don't know.", r[:thoughts][0][:en]
		r = @mt.search('作詞') 
		assert_equal 'writing lyrics', r[:categories][0][:en]
	end

	def test_add
		@mt.set_lang('fr')
		assert @mt.add(@nu)
	end

	# TODO: test add errors better

end

