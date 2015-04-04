# Transform stuff from Mikel's Mail class into my PostgreSQL-ready clean data
require_relative 'peeps.rb'
require 'mail'

module MyMail
	class << self

		# hash with id, profile, their_email, subject, body, message_id, referencing
		def send(email, smtp_hash)
			Mail::Configuration.instance.delivery_method(:smtp, smtp_hash)
			m = Mail.new
			m.charset = 'UTF-8'
			m.from = 'Derek Sivers <derek@sivers.org>'  # TODO: in profile config?
			m.sender = smtp_hash[:user_name]
			m.to = email[:their_email]
			m.subject = email[:subject]
			m.body = email[:body]
			m.message_id = '<%s>' % email[:message_id]
			m.in_reply_to = email[:referencing] if email[:referencing]
			m.deliver!
		end

		# IN:
		# profile string : 'derek@sivers' or 'we@woodegg'
		# hash with address, port, user_name, password, enable_ssl
		# db_api = B50D::Peeps.new(api_key, api_pass)
		def import(profile, pop3_hash, db_api)
			Mail::Configuration.instance.retriever_method(:pop3, pop3_hash)
			what2find = {what: :first, count: 1, order: :asc, delete_after_find: true}
			mail = Mail.find(what2find)
			while mail != [] do
				puts mail.message_id + "\t" + mail.from[0]
				db_api.import_email(parse(mail, profile))
				mail = Mail.find(what2find)
			end
		end

		def attachments_dir
			'/srv/http/attachments/'
		end

		# IN:
		# mail = object from Mail class
		# profile string : 'derek@sivers' or 'we@woodegg'
		# RETURNS: hash of clean values for importing into database
		def parse(mail, profile)
			h = {profile: profile, category: profile}
			h[:message_id] = mail.message_id[0,255]
			h[:their_email] = mail.from[0][0,127].downcase
			h[:their_name] = their_name(mail)
			h[:subject] = (mail.subject.nil?) ? 'email' : mail.subject[0,127]
			h[:body] = body(mail)
			h[:headers] = headers(mail)
			h[:references] = references(mail)
			h[:attachments] = attachments(mail)
			h
		end

		def their_name(mail)
		begin
			# crashes when unknown encoding name
			full_from_line = mail[:from].decoded
		rescue
			full_from_line = mail[:from].value
		end
		begin
			# badly formatted 'From' (non-ASCII characters) crashes Address.new
			a = Mail::Address.new(full_from_line)
			if a.display_name
				return a.display_name[0,127]
			elsif a.name
				return a.name[0,127]
			else
				return mail.from[0][0,127]
			end
		rescue
			if /(.+)\s<\S+@\S+>/.match(full_from_line)
				return $1.gsub('"', '')
			else
				return full_from_line[0,127]
			end
		end
		end

		def body(mail)
			strip_tags = %r{</?[^>]+?>}
			unless mail.multipart?
				text = (mail.content_type =~ /html/i) ?
					mail.decoded.gsub(strip_tags, '') : mail.decoded
				return cleaned text
			end
			text = ''
			parts_with_ctype(mail.parts, 'text/plain').each do |p|
				text << p.decoded
			end
			if text == ''
				parts_with_ctype(mail.parts, 'text/html').each do |p|
					text << p.decoded.gsub(strip_tags, '')
				end
			end
			cleaned text
		end

		def headers(mail)
			begin
				s = mail.header.to_s
			rescue
				s = mail.header.raw_source
			end
			lines = []
			%w(to from message-id subject date in-reply-to references cc).each do |f|
				r = Regexp.new('^' + f + ':.*$', true)
				m = r.match(s)
				lines << m[0].strip if m
			end
			lines.join("\n")
		end

		# array of message_ids (if any) referenced in In-Reply-To: or References: headers
		def references(mail)
			res = []
			if mail.references
				Array(mail.references).each do |i|
					res.push(i) unless res.include?(i)
				end
			end
			if mail.in_reply_to
				Array(mail.in_reply_to).each do |i|
					res.push(i) unless res.include?(i)
				end
			end
			res
		end

		# NOTE: actually saves the binary files to the attachments_dir!
		def attachments(mail)
			res = []
			mail.attachments.each do |a|
				h = {}
				h[:mime_type] = a.content_type.split(';')[0]
				h[:filename] = our_filename_for a.filename
				filepath = attachments_dir + h[:filename]
				File.open(filepath, 'w+b', 0644) {|f| f.write a.body.decoded}
				h[:bytes] = FileTest.size(filepath)
				res << h
			end
			res
		end

		def cleaned(str)
			enc_opts = {invalid: :replace, undef: :replace, replace: ' '}
			begin
				str.strip.gsub("\r", '').encode('UTF-8', enc_opts).force_encoding('UTF-8')
			rescue
				enc = str.encoding
				str.force_encoding('BINARY')
				# remove bad UTF-8 characters here
				str.gsub!(0xA0.chr, '')
				str.gsub!(0x8A.chr, '')
				str.gsub!(0xC2.chr, '')
				str.force_encoding(enc)
				str.strip.gsub("\r", '').encode('UTF-8', enc_opts).force_encoding('UTF-8')
			end
		end

		def parts_with_ctype(partslist, content_type)
			res = []
			partslist.each do |p|
				if p.multipart?
					res << parts_with_ctype(p.parts, content_type)
				elsif p.content_type.downcase.include?(content_type) && (p.content_disposition =~ /attach/i).nil?
					res << p
				end
			end
			res.flatten
		end

		def our_filename_for(str)
			alpha = Range.new('a', 'z').to_a
			ourbit = Time.now.to_s[0,10].gsub('-', '')
			4.times { ourbit << alpha[rand(alpha.size)] }
			ourbit + '-' + str.gsub(/[^a-zA-Z0-9\-._]/, '')
		end

	end
end
