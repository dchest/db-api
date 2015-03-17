require_relative 'dbapi.rb'

# Main addition is to set the language so that categories and thoughts are
# translated, like this:
#
# @mt = B50D::MusicThoughts.new  (default English)
# t = @mt.thought(123)
# puts t[:thought]   # "Hi this is English"
# @mt.set_lang('fr')
# t = @mt.thought(123)
# puts t[:thought]   # "Bonjour, c'est français"
#
# The multi-lingual things are categories and thoughts.
# So for those, use the @lang key to assign self-named value to that.
# In other words:
# When getting category and language is French,
# set c[:category] to the same as c[:fr]
# When getting thought and language is Chinese,
# set t[:thought] to the same as t[:zh]
# Now website template views can just call c[:category] and t[:thought].

module B50D
	class MusicThoughts
		def error ; @db.error ; end
		def message ; @db.message ; end

		def initialize(server='live', lang='en')
			@db = DbAPI.new(server)
			set_lang(lang)
		end

		def languages
			# cached
			return ['ar', 'de', 'en', 'es', 'fr', 'it', 'ja', 'pt', 'ru', 'zh']
		end

		# restricts responses to this language
		def set_lang(lang)
			lang = 'en' unless languages.include? lang
			@lang = lang.to_sym
		end

		# hash keys: id, category, howmany
		def categories
			@cat_cache ||= @db.js('musicthoughts.all_categories()').map {|c| c.merge(category: c[@lang]) }
			@cat_cache
		end

		# hash keys: id, category, thoughts:[{id, thought, author:{id, name}}]
		def category(id)
			begin
				c = @db.js('musicthoughts.category($1)', [id])
				c[:category] = c[@lang]
				c[:thoughts].map! {|t| t.merge(thought: t[@lang]) }
				c
			rescue
				nil
			end
		end

		# hash keys: id, name, howmany
		def authors
			@db.js('musicthoughts.top_authors(NULL)')
		end

		# hash keys: id, name, howmany
		def authors_top
			@db.js('musicthoughts.top_authors($1)', [20])
		end

		# hash keys: id, name, thoughts:[{id, thought, author:{id, name}}]
		def author(id)
			begin
				a = @db.js('musicthoughts.get_author($1)', [id])
				a[:thoughts].map! do |t|
					t.merge(thought: t[@lang], author: {id: id, name: a[:name]})
				end if a[:thoughts]
				a
			rescue
				nil
			end
		end

		# hash keys: id, name, howmany
		def contributors
			@db.js('musicthoughts.top_contributors(NULL)')
		end

		# hash keys: id, name, howmany
		def contributors_top
			@db.js('musicthoughts.top_contributors($1)', [20])
		end

		# hash keys: id, name, thoughts:[{id, thought, author:{id, name}}]
		def contributor(id)
			begin
				c = @db.js('musicthoughts.get_contributor($1)', [id])
				c[:thoughts].map! do |t|
					t.merge(thought: t[@lang])
				end if c[:thoughts]
				c
			rescue
				nil
			end
		end

		# Format for all thought methods, below:
		# hash keys: id, source_url, thought,
		#   author:{id, name}, contributor:{id, name}, categories:[{id, category}]
		def thoughts_all
			@db.js('musicthoughts.new_thoughts(NULL)').map do |t|
				t[:categories].map! do |c|
					c.merge(category: c[@lang])
				end if t[:categories]
				t.merge(thought: t[@lang])
			end
		end

		def thoughts_new
			@db.js('musicthoughts.new_thoughts($1)', [20]).map do |t|
				t[:categories].map! do |c|
					c.merge(category: c[@lang])
				end if t[:categories]
				t.merge(thought: t[@lang])
			end
		end

		def thought(id)
			begin
				t = @db.js('musicthoughts.get_thought($1)', [id])
				t[:thought] = t[@lang] 
				t[:categories].map! do |c|
					c.merge(category: c[@lang])
				end if t[:categories]
				t
			rescue
				nil
			end
		end

		def thought_random
			t = @db.js('musicthoughts.random_thought()')
			t[:thought] = t[@lang] 
			t[:categories].map! do |c|
				c.merge(category: c[@lang])
			end if t[:categories]
			t
		end

		# hash keys:
		#  categories: nil || [{id, category]
		#  authors: nil || [{id, name, howmany}]
		#  contributors: nil || [{id, name, howmany}]
		#  thoughts: nil || [{id, source_url, thought,
		#   author:{id, name}, contributor:{id, name}, categories:[{id, category}]}]
		def search(q)
			res = @db.js('musicthoughts.search($1)', [q.strip])
			res[:categories].map! do |c|
				c.merge(category: c[@lang])
			end if res[:categories]
			res[:thoughts].map! do |t|
				t[:categories].map! do |c|
					c.merge(category: c[@lang])
				end if t[:categories]
				t.merge(thought: t[@lang])
			end if res[:thoughts]
			res
		end 


		def add(params)
			%i(thought contributor_name contributor_email author_name).each do |i|
				raise "#{i} required" unless String(params[i]).size > 0
			end
			params[:lang_code] ||= @lang
			params[:contributor_url] ||= ''
			params[:contributor_place] ||= ''
			params[:source_url] ||= ''
			params[:category_ids] ||= '{}' # format: {1,3,5}
			@db.js('musicthoughts.add_thought($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
				params[:lang_code],
				params[:thought],
				params[:contributor_name],
				params[:contributor_email],
				params[:contributor_url],
				params[:contributor_place],
				params[:author_name],
				params[:source_url],
				params[:category_ids]])
		end
	end
end

