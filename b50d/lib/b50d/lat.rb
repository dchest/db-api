require_relative 'dbapi.rb'

module B50D
	class Lat
		def error ; @db.error ; end
		def message ; @db.message ; end

		def initialize(server='live')
			@db = DbAPI.new(server)
		end

		def get_concepts
			@db.js('lat.get_concepts()')
		end

		def get_concept(id)
			@db.js('lat.get_concept($1)', [id])
		end

		def create_concept(title, concept)
			@db.js('lat.create_concept($1, $2)', [title, concept])
		end

		def update_concept(id, title, concept)
			@db.js('lat.update_concept($1, $2, $3)', [id, title, concept])
		end

		def delete_concept(id)
			@db.js('lat.delete_concept($1)', [id])
		end

		def tag_concept(id, tag)
			@db.js('lat.tag_concept($1, $2)', [id, tag])
		end

		def untag_concept(concept_id, tag_id)
			@db.js('lat.untag_concept($1, $2)', [concept_id, tag_id])
		end

		def add_url(concept_id, url, notes)
			@db.js('lat.add_url($1, $2, $3)', [concept_id, url, notes])
		end

		def update_url(url_id, url, notes)
			@db.js('lat.update_url($1, $2, $3)', [url_id, url, notes])
		end

		def delete_url(id)
			@db.js('lat.delete_url($1)', [id])
		end

		def tags
			@db.js('lat.tags()')
		end

		def concepts_tagged(tag)
			@db.js('lat.concepts_tagged($1)', [tag])
		end

		def get_pairings
			@db.js('lat.get_pairings()')
		end

		def get_pairing(id)
			@db.js('lat.get_pairing($1)', [id])
		end

		def create_pairing
			@db.js('lat.create_pairing()')
		end

		def update_pairing(id, thoughts)
			@db.js('lat.update_pairing($1, $2)', [id, thoughts])
		end

		def delete_pairing(id)
			@db.js('lat.delete_pairing($1)', [id])
		end

		def tag_pairing(id, tag)
			@db.js('lat.tag_pairing($1, $2)', [id, tag])
		end

	end
end
