SET client_min_messages TO ERROR;
SET client_encoding = 'UTF8';
DROP SCHEMA IF EXISTS peeps CASCADE;
BEGIN;

CREATE SCHEMA peeps;
SET search_path = peeps,public;

-- Country codes used mainly for foreign key constraint on people.country
-- From http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2 - data loaded below
-- No need for any API to update, insert, or delete from this table.
CREATE TABLE countries (
	code character(2) NOT NULL primary key,
	name text
);

CREATE TABLE currencies (
	code character(3) NOT NULL primary key,
	name text,
	rate numeric
);

-- Big master table for people
CREATE TABLE people (
	id serial primary key,
	email varchar(127) UNIQUE CONSTRAINT valid_email CHECK (email ~ '\A\S+@\S+\.\S+\Z'),
	name varchar(127) NOT NULL CONSTRAINT no_name CHECK (LENGTH(name) > 0),
	address varchar(64), --  not mailing address, but "how do I address you?".  Usually firstname.
	hashpass varchar(72), -- user-chosen password, blowfish crypted using set_password function below.
	lopass char(4), -- random used with id for low-security unsubscribe links to deter id spoofing
	newpass char(8) UNIQUE, -- random for "forgot my password" emails, erased when set_password
	company varchar(127),
	city varchar(24),
	state varchar(16),
	postalcode varchar(12),
	country char(2) REFERENCES countries(code),
	phone varchar(18),
	notes text,
	email_count integer not null default 0,
	listype varchar(4),
	categorize_as varchar(16), -- if not null, incoming emails.category set to this
	created_at date not null default CURRENT_DATE
);
CREATE INDEX person_name ON people(name);

-- People authorized to answer/create emails
CREATE TABLE emailers (
	id serial primary key,
	person_id integer NOT NULL UNIQUE REFERENCES people(id) ON DELETE RESTRICT,
	admin boolean NOT NULL DEFAULT 'f',
	profiles text[] NOT NULL DEFAULT '{}',  -- only allowed to view these emails.profile
	categories text[] NOT NULL DEFAULT '{}' -- only allowed to view these emails.category
);

-- Catch-all for any random facts about this person
CREATE TABLE userstats (
	id serial primary key,
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	statkey varchar(32) not null,
	statvalue text,
	created_at date not null default CURRENT_DATE
);
CREATE INDEX userstats_person ON userstats(person_id);
CREATE INDEX userstats_statkey ON userstats(statkey);

-- This person's websites
CREATE TABLE urls (
	id serial primary key,
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	url varchar(255),
	main boolean  -- means it's their main/home site
);
CREATE INDEX urls_person ON urls(person_id);

-- Logged-in users given a cookie with random string, to look up their person_id
CREATE TABLE logins (
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	cookie_id char(32) not null,
	cookie_tok char(32) not null,
	cookie_exp integer not null,
	domain varchar(32) not null,
	last_login date not null default CURRENT_DATE,
	ip varchar(15),
	PRIMARY KEY (cookie_id, cookie_tok)
);
CREATE INDEX logins_person_id ON logins(person_id);

-- All incoming and outgoing emails
CREATE TABLE emails (
	id serial primary key,
	person_id integer REFERENCES people(id),
	profile varchar(18) not null CHECK (length(profile) > 0),  -- which email address sent to/from
	category varchar(16) not null CHECK (length(category) > 0),  -- like gmail's labels, but 1-to-1
	created_at timestamp without time zone not null DEFAULT current_timestamp,
	created_by integer REFERENCES emailers(id),
	opened_at timestamp without time zone,
	opened_by integer REFERENCES emailers(id),
	closed_at timestamp without time zone,
	closed_by integer REFERENCES emailers(id),
	reference_id integer REFERENCES emails(id) DEFERRABLE, -- email this is replying to
	answer_id integer REFERENCES emails(id) DEFERRABLE, -- email replying to this one
	their_email varchar(127) CONSTRAINT valid_email CHECK (their_email ~ '\A\S+@\S+\.\S+\Z'),  -- their email address (whether incoming or outgoing)
	their_name varchar(127),
	subject varchar(127),
	headers text,
	body text,
	message_id varchar(255) UNIQUE,
	outgoing boolean default 'f',
	flag integer  -- rarely used, to mark especially important emails 
);
CREATE INDEX emails_person_id ON emails(person_id);
CREATE INDEX emails_category ON emails(category);
CREATE INDEX emails_profile ON emails(profile);
CREATE INDEX emails_created_by ON emails(created_by);
CREATE INDEX emails_opened_by ON emails(opened_by);
CREATE INDEX emails_outgoing ON emails(outgoing);

-- Attachments sent with incoming emails
CREATE TABLE email_attachments (
	id serial primary key,
	email_id integer REFERENCES emails(id) ON DELETE CASCADE,
	mime_type text,
	filename text,
	bytes integer
);
CREATE INDEX email_attachments_email_id ON email_attachments(email_id);

-- Commonly used emails.body templates
CREATE TABLE formletters (
	id serial primary key,
	title varchar(64) UNIQUE,
	explanation varchar(255),
	body text,
	created_at date not null default CURRENT_DATE
);

-- Users given direct API access
CREATE TABLE api_keys (
	person_id integer NOT NULL UNIQUE REFERENCES people(id) ON DELETE CASCADE,
	akey char(8) NOT NULL UNIQUE,
	apass char(8) NOT NULL,
	apis text[] NOT NULL DEFAULT '{}',  -- can only access these APIs
	PRIMARY KEY (akey, apass)
);

-- From http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
-- Please let me know if anything wrong or missing
INSERT INTO countries(code, name) VALUES 
('AD', 'Andorra'),
('AE', 'United Arab Emirates'),
('AF', 'Afghanistan'),
('AG', 'Antigua and Barbuda'),
('AI', 'Anguilla'),
('AL', 'Albania'),
('AM', 'Armenia'),
('AN', 'Netherlands Antilles'),
('AO', 'Angola'),
('AR', 'Argentina'),
('AS', 'American Samoa'),
('AT', 'Austria'),
('AU', 'Australia'),
('AW', 'Aruba'),
('AX', 'Åland Islands'),
('AZ', 'Azerbaijan'),
('BA', 'Bosnia and Herzegovina'),
('BB', 'Barbados'),
('BD', 'Bangladesh'),
('BE', 'Belgium'),
('BF', 'Burkina Faso'),
('BG', 'Bulgaria'),
('BH', 'Bahrain'),
('BI', 'Burundi'),
('BJ', 'Benin'),
('BL', 'Saint Barthélemy'),
('BM', 'Bermuda'),
('BN', 'Brunei Darussalam'),
('BO', 'Bolivia'),
('BR', 'Brazil'),
('BS', 'Bahamas'),
('BT', 'Bhutan'),
('BW', 'Botswana'),
('BY', 'Belarus'),
('BZ', 'Belize'),
('CA', 'Canada'),
('CC', 'Cocos Islands'),
('CD', 'Congo, Democratic Republic'),
('CF', 'Central African Republic'),
('CG', 'Congo'),
('CH', 'Switzerland'),
('CI', 'Côte d’Ivoire'),
('CK', 'Cook Islands'),
('CL', 'Chile'),
('CM', 'Cameroon'),
('CN', 'China'),
('CO', 'Colombia'),
('CR', 'Costa Rica'),
('CU', 'Cuba'),
('CV', 'Cape Verde'),
('CW', 'Curaçao'),
('CX', 'Christmas Island'),
('CY', 'Cyprus'),
('CZ', 'Czech Republic'),
('DE', 'Germany'),
('DJ', 'Djibouti'),
('DK', 'Denmark'),
('DM', 'Dominica'),
('DO', 'Dominican Republic'),
('DZ', 'Algeria'),
('EC', 'Ecuador'),
('EE', 'Estonia'),
('EG', 'Egypt'),
('EH', 'Western Sahara'),
('ER', 'Eritrea'),
('ES', 'Spain'),
('ET', 'Ethiopia'),
('FI', 'Finland'),
('FJ', 'Fiji'),
('FK', 'Falkland Islands'),
('FM', 'Micronesia'),
('FO', 'Faroe Islands'),
('FR', 'France'),
('GA', 'Gabon'),
('GB', 'United Kingdom'),
('GD', 'Grenada'),
('GE', 'Georgia'),
('GF', 'French Guiana'),
('GG', 'Guernsey'),
('GH', 'Ghana'),
('GI', 'Gibraltar'),
('GL', 'Greenland'),
('GM', 'Gambia'),
('GN', 'Guinea'),
('GP', 'Guadeloupe'),
('GQ', 'Equatorial Guinea'),
('GR', 'Greece'),
('GT', 'Guatemala'),
('GU', 'Guam'),
('GW', 'Guinea-Bissau'),
('GY', 'Guyana'),
('HK', 'Hong Kong'),
('HN', 'Honduras'),
('HR', 'Croatia'),
('HT', 'Haiti'),
('HU', 'Hungary'),
('ID', 'Indonesia'),
('IE', 'Ireland'),
('IL', 'Israel'),
('IM', 'Isle of Man'),
('IN', 'India'),
('IO', 'British Indian Ocean'),
('IQ', 'Iraq'),
('IR', 'Iran'),
('IS', 'Iceland'),
('IT', 'Italy'),
('JE', 'Jersey'),
('JM', 'Jamaica'),
('JO', 'Jordan'),
('JP', 'Japan'),
('KE', 'Kenya'),
('KG', 'Kyrgyzstan'),
('KH', 'Cambodia'),
('KI', 'Kiribati'),
('KM', 'Comoros'),
('KN', 'Saint Kitts and Nevis'),
('KP', 'Korea, North'),
('KR', 'Korea, South'),
('KW', 'Kuwait'),
('KY', 'Cayman Islands'),
('KZ', 'Kazakhstan'),
('LA', 'Laos'),
('LB', 'Lebanon'),
('LC', 'Saint Lucia'),
('LI', 'Liechtenstein'),
('LK', 'Sri Lanka'),
('LR', 'Liberia'),
('LS', 'Lesotho'),
('LT', 'Lithuania'),
('LU', 'Luxembourg'),
('LV', 'Latvia'),
('LY', 'Libyan Arab Jamahiriya'),
('MA', 'Morocco'),
('MC', 'Monaco'),
('MD', 'Moldova, Republic of'),
('ME', 'Montenegro'),
('MF', 'Saint Martin (French)'),
('MG', 'Madagascar'),
('MH', 'Marshall Islands'),
('MK', 'Macedonia'),
('ML', 'Mali'),
('MM', 'Myanmar'),
('MN', 'Mongolia'),
('MO', 'Macao'),
('MP', 'Northern Mariana Islands'),
('MQ', 'Martinique'),
('MR', 'Mauritania'),
('MS', 'Montserrat'),
('MT', 'Malta'),
('MU', 'Mauritius'),
('MV', 'Maldives'),
('MW', 'Malawi'),
('MX', 'Mexico'),
('MY', 'Malaysia'),
('MZ', 'Mozambique'),
('NA', 'Namibia'),
('NC', 'New Caledonia'),
('NE', 'Niger'),
('NF', 'Norfolk Island'),
('NG', 'Nigeria'),
('NI', 'Nicaragua'),
('NL', 'Netherlands'),
('NO', 'Norway'),
('NP', 'Nepal'),
('NR', 'Nauru'),
('NU', 'Niue'),
('NZ', 'New Zealand'),
('OM', 'Oman'),
('PA', 'Panama'),
('PE', 'Peru'),
('PF', 'French Polynesia'),
('PG', 'Papua New Guinea'),
('PH', 'Philippines'),
('PK', 'Pakistan'),
('PL', 'Poland'),
('PM', 'Saint Pierre and Miquelon'),
('PN', 'Pitcairn'),
('PR', 'Puerto Rico'),
('PS', 'Palestinian Territory'),
('PT', 'Portugal'),
('PW', 'Palau'),
('PY', 'Paraguay'),
('QA', 'Qatar'),
('RE', 'Réunion'),
('RO', 'Romania'),
('RS', 'Serbia'),
('RU', 'Russian Federation'),
('RW', 'Rwanda'),
('SA', 'Saudi Arabia'),
('SB', 'Solomon Islands'),
('SC', 'Seychelles'),
('SD', 'Sudan'),
('SE', 'Sweden'),
('SG', 'Singapore'),
('SH', 'Saint Helena'),
('SI', 'Slovenia'),
('SJ', 'Svalbard and Jan Mayen'),
('SK', 'Slovakia'),
('SL', 'Sierra Leone'),
('SM', 'San Marino'),
('SN', 'Senegal'),
('SO', 'Somalia'),
('SR', 'Suriname'),
('SS', 'South Sudan'),
('ST', 'Sao Tome and Principe'),
('SV', 'El Salvador'),
('SX', 'Sint Maarten (Dutch)'),
('SY', 'Syrian Arab Republic'),
('SZ', 'Swaziland'),
('TC', 'Turks and Caicos Islands'),
('TD', 'Chad'),
('TG', 'Togo'),
('TH', 'Thailand'),
('TJ', 'Tajikistan'),
('TK', 'Tokelau'),
('TL', 'Timor-Leste'),
('TM', 'Turkmenistan'),
('TN', 'Tunisia'),
('TO', 'Tonga'),
('TR', 'Turkey'),
('TT', 'Trinidad and Tobago'),
('TV', 'Tuvalu'),
('TW', 'Taiwan'),
('TZ', 'Tanzania'),
('UA', 'Ukraine'),
('UG', 'Uganda'),
('US', 'United States'),
('UY', 'Uruguay'),
('UZ', 'Uzbekistan'),
('VC', 'Saint Vincent & Grenadines'),
('VE', 'Venezuela'),
('VG', 'Virgin Islands, British'),
('VI', 'Virgin Islands, U.S.'),
('VN', 'Vietnam'),
('VU', 'Vanuatu'),
('WF', 'Wallis and Futuna'),
('WS', 'Samoa'),
('YE', 'Yemen'),
('YT', 'Mayotte'),
('ZA', 'South Africa'),
('ZM', 'Zambia'),
('ZW', 'Zimbabwe');

INSERT INTO currencies(code, name, rate) VALUES
('AUD', 'Australian Dollar', 1.5053),
('BGN', 'Bulgarian Lev', 1.9558),
('BRL', 'Brazilian Real', 3.2921),
('BTC', 'Bitcoin', 0.003727865796831314),
('CAD', 'Canadian Dollar', 1.4164),
('CHF', 'Swiss Franc', 1.2025),
('CNY', 'China Yuan Renminbi', 7.5969),
('CZK', 'Czech Koruna', 27.777),
('DKK', 'Danish Krone', 7.4396),
('EUR', 'Euro', 1),
('GBP', 'Pound Sterling', 0.7865),
('HKD', 'Hong Kong Dollar', 9.4844),
('HRK', 'Croatian Kuna', 7.663),
('HUF', 'Hungary Forint', 316.08),
('IDR', 'Indonesia Rupiah', 15214.5),
('ILS', 'Israeli Sheqel', 4.778),
('INR', 'Indian Rupee', 77.5589),
('JPY', 'Japan Yen', 147.07),
('KRW', 'Korea Won', 1347.55),
('LTL', 'Lithuanian Litas', 3.4528),
('MXN', 'Mexican Peso', 18.0123),
('MYR', 'Malaysian Ringgit', 4.2729),
('NOK', 'Norwegian Krone', 9.1511),
('NZD', 'New Zealand Dollar', 1.5807),
('PHP', 'Philippine Peso', 54.596),
('PLN', 'Polish Zloty', 4.3078),
('RON', 'New Romanian Leu', 4.4628),
('RUB', 'Russian Ruble', 66.8863),
('SEK', 'Swedish Krona', 9.54),
('SGD', 'Singapore Dollar', 1.616),
('THB', 'Thai Baht', 40.169),
('TRY', 'Turkish Lira', 2.841),
('USD', 'US Dollar', 1.2219),
('ZAR', 'South African Rand', 14.2498);

COMMIT;


----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

CREATE VIEW emails_view AS
	SELECT id, subject, created_at, their_name, their_email FROM emails;

CREATE VIEW email_view AS
	SELECT id, person_id, profile, category,
		created_at, (SELECT row_to_json(p1) AS creator FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = created_by) p1),
		opened_at, (SELECT row_to_json(p2) AS openor FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = opened_by) p2),
		closed_at, (SELECT row_to_json(p3) AS closor FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = closed_by) p3),
		message_id, outgoing, their_email, their_name, headers, subject, body,
		(SELECT json_agg(a) AS attachments FROM
			(SELECT id, filename FROM email_attachments WHERE email_id=emails.id) a)
		FROM emails;

----------------------------
---------- public FUNCTIONS:
----------------------------

-- used by other functions, below, for any random strings needed
CREATE OR REPLACE FUNCTION public.random_string(length integer) RETURNS text AS $$
DECLARE
	chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
	result text := '';
	i integer := 0;
BEGIN
	FOR i IN 1..length LOOP
		result := result || chars[1+random()*(array_length(chars, 1)-1)];
	END LOOP;
	RETURN result;
END;
$$ LANGUAGE plpgsql;


-- ensure unique unused value for any table.field.
CREATE OR REPLACE FUNCTION public.unique_for_table_field(str_len integer, table_name text, field_name text) RETURNS text AS $$
DECLARE
	nu text;
	rowcount integer;
BEGIN
	nu := public.random_string(str_len);
	LOOP
		EXECUTE 'SELECT 1 FROM ' || table_name || ' WHERE ' || field_name || ' = ' || quote_literal(nu);
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount = 0 THEN
			RETURN nu; 
		END IF;
		nu := public.random_string(str_len);
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- For updating foreign keys, array of tables referencing this one.  USAGE: see merge function below.
-- Returns in schema.table format like {'woodegg.researchers', 'musicthoughts.contributors'}
CREATE OR REPLACE FUNCTION public.tables_referencing(my_schema text, my_table text, my_column text) RETURNS text[] AS $$
DECLARE
	tables text[] := ARRAY[]::text[];
BEGIN
	SELECT ARRAY(
		SELECT CONCAT(R.TABLE_SCHEMA, '.', R.TABLE_NAME)
			FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE U
				INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS FK
					ON U.CONSTRAINT_CATALOG = FK.UNIQUE_CONSTRAINT_CATALOG
					AND U.CONSTRAINT_SCHEMA = FK.UNIQUE_CONSTRAINT_SCHEMA
					AND U.CONSTRAINT_NAME = FK.UNIQUE_CONSTRAINT_NAME
				INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE R
					ON R.CONSTRAINT_CATALOG = FK.CONSTRAINT_CATALOG
					AND R.CONSTRAINT_SCHEMA = FK.CONSTRAINT_SCHEMA
					AND R.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
			WHERE U.COLUMN_NAME = my_column
				AND U.TABLE_SCHEMA = my_schema
				AND U.TABLE_NAME = my_table) INTO tables;
	RETURN tables;
END;
$$ LANGUAGE plpgsql;


-- RETURNS: array of column names that ARE allowed to be updated
-- PARAMS: schema name, table name, array of col names NOT allowed to be updated
CREATE OR REPLACE FUNCTION public.cols2update(text, text, text[]) RETURNS text[] AS $$
BEGIN
	RETURN array(SELECT column_name::text FROM information_schema.columns
		WHERE table_schema=$1 AND table_name=$2 AND column_name != ALL($3));
END;
$$ LANGUAGE plpgsql;


-- PARAMS: table name, id, json, array of cols that ARE allowed to be updated
CREATE OR REPLACE FUNCTION public.jsonupdate(text, integer, json, text[]) RETURNS VOID AS $$
DECLARE
	col record;
BEGIN
	FOR col IN SELECT name FROM json_object_keys($3) AS name LOOP
		CONTINUE WHEN col.name != ALL($4);
		EXECUTE format ('UPDATE %s SET %I =
			(SELECT %I FROM json_populate_record(null::%s, $1)) WHERE id = %L',
			$1, col.name, col.name, $1, $2) USING $3;
	END LOOP;
END;
$$ LANGUAGE plpgsql;


----------------------------
----------- peeps FUNCTIONS:
----------------------------

-- pgcrypto for people.hashpass
CREATE FUNCTION crypt(text, text) RETURNS text AS '$libdir/pgcrypto', 'pg_crypt' LANGUAGE c IMMUTABLE STRICT;
CREATE FUNCTION gen_salt(text, integer) RETURNS text AS '$libdir/pgcrypto', 'pg_gen_salt_rounds' LANGUAGE c STRICT;


-- Use this to add a new person to the database.  Ensures unique email without clash.
-- USAGE: SELECT * FROM person_create('Dude Abides', 'dude@abid.es');
-- Will always return peeps.people row, whether new INSERT or existing SELECT
CREATE FUNCTION person_create(new_name text, new_email text) RETURNS SETOF peeps.people AS $$
DECLARE
	clean_email text;
BEGIN
	clean_email := lower(regexp_replace(new_email, '\s', '', 'g'));
	IF clean_email IS NULL OR clean_email = '' THEN
		RAISE 'missing_email';
	END IF;
	IF NOT EXISTS (SELECT 1 FROM peeps.people WHERE email = clean_email) THEN
		RETURN QUERY INSERT INTO peeps.people (name, email) VALUES (new_name, clean_email) RETURNING peeps.people.*;
	ELSE
		RETURN QUERY SELECT * FROM peeps.people WHERE email = clean_email;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Use this for user choosing their own password.
-- USAGE: SELECT set_password(123, 'Th€IR nü FunK¥(!) pá$$werđ');
-- Returns false if that peeps.people.id doesn't exist, otherwise true.
CREATE FUNCTION set_password(person_id integer, password text) RETURNS boolean AS $$
BEGIN
	IF password IS NULL OR length(btrim(password)) < 4 THEN
		RAISE 'short_password';
	END IF;
	UPDATE peeps.people SET newpass=NULL, hashpass=crypt(password, gen_salt('bf', 8)) WHERE id = person_id;
	IF FOUND THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Use this when a user is logging in with their email and (their own chosen) password.
-- USAGE: SELECT * FROM person_email_pass('dude@abid.es', 'Th€IR öld FunK¥ pá$$werđ');
-- Returns peeps.people.* if both are correct, or nothing if not.
-- Once authorized here, give logins or api_key cookie for future lookups.
CREATE FUNCTION person_email_pass(my_email text, my_pass text) RETURNS SETOF peeps.people AS $$
DECLARE
	clean_email text;
BEGIN
	clean_email := lower(regexp_replace(my_email, '\s', '', 'g'));
	IF clean_email !~ '\A\S+@\S+\.\S+\Z' THEN
		RAISE 'bad_email';
	END IF;
	IF my_pass IS NULL OR length(btrim(my_pass)) < 4 THEN
		RAISE 'short_password';
	END IF;
	RETURN QUERY SELECT * FROM peeps.people WHERE email=clean_email AND hashpass=crypt(my_pass, hashpass);
END;
$$ LANGUAGE plpgsql;


-- Use this to find users matching query string, whether in their name, email address, or company.
-- USAGE: SELECT * FROM people_search('wonka');
-- Returns peeps.people.* rows found
CREATE FUNCTION people_search(term text) RETURNS SETOF peeps.people AS $$
DECLARE
	q text := '%' || btrim(term) || '%';
BEGIN
	IF length(btrim(term)) < 2 THEN
		RAISE 'short_search_term';
	END IF;
	RETURN QUERY SELECT * FROM peeps.people WHERE name ILIKE q OR company ILIKE q OR email ILIKE q;
END;
$$ LANGUAGE plpgsql;


-- When a person has multiple entries in peeps.people, merge two into one, updating foreign keys.
-- USAGE: SELECT person_merge_from_to(5432, 4321);
-- Returns array of tables actually updated in schema.table format like {'muckwork.clients', 'sivers.comments'}
-- (Return value is probably unneeded, but here it is anyway, just in case.)
CREATE FUNCTION person_merge_from_to(old_id integer, new_id integer) RETURNS text[] AS $$
DECLARE
	done_tables text[] := ARRAY[]::text[];
	a_table text;
	rowcount integer;
BEGIN
	FOREACH a_table IN ARRAY tables_referencing('peeps', 'people', 'id') LOOP
		EXECUTE 'UPDATE ' || a_table || ' SET person_id=' || new_id || ' WHERE person_id=' || old_id || ' RETURNING person_id';
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount > 0 THEN
			done_tables := done_tables || a_table;
		END IF;
	END LOOP;
	DELETE FROM peeps.people WHERE id = old_id;
	RETURN done_tables;
END;
$$ LANGUAGE plpgsql;


-- Returns emails.* only if emailers.profiles && emailers.cateories matches
CREATE FUNCTION emailer_get_email(emailer_id integer, email_id integer) RETURNS SETOF peeps.emails AS $$
DECLARE
	emailer emailers;
	email emails;
BEGIN
	SELECT * INTO emailer FROM peeps.emailers WHERE id = emailer_id;
	SELECT * INTO email FROM peeps.emails WHERE id = email_id;
	IF (emailer.profiles = '{ALL}' AND emailer.categories = '{ALL}') OR
	   (emailer.profiles = '{ALL}' AND email.category = ANY(emailer.categories)) OR
	   (email.profile = ANY(emailer.profiles) AND emailer.categories = '{ALL}') OR
	   (email.profile = ANY(emailer.profiles) AND email.category = ANY(emailer.categories)) THEN
		RETURN QUERY SELECT * FROM peeps.emails WHERE id = email_id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Returns unopened emails.* that this emailer is authorized to see
CREATE FUNCTION emailer_get_unopened(emailer_id integer) RETURNS SETOF peeps.emails AS $$
DECLARE
	qry text := 'SELECT * FROM peeps.emails WHERE opened_at IS NULL AND person_id IS NOT NULL';
	emailer emailers;
BEGIN
	SELECT * INTO emailer FROM peeps.emailers WHERE id = emailer_id;
	IF (emailer.profiles != '{ALL}') THEN
		qry := qry || ' AND profile IN (SELECT UNNEST(profiles) FROM peeps.emailers WHERE id=' || emailer_id || ')';
	END IF;
	IF (emailer.categories != '{ALL}') THEN
		qry := qry || ' AND category IN (SELECT UNNEST(categories) FROM peeps.emailers WHERE id=' || emailer_id || ')';
	END IF;
	qry := qry || ' ORDER BY id ASC';
	RETURN QUERY EXECUTE qry;
END;
$$ LANGUAGE plpgsql;


-- Once a person has correctly given their email and password, call this to create cookie info.
-- Returns a single 65-character string, ready to be set as the cookie value
CREATE FUNCTION login_person_domain(my_person_id integer, my_domain char) RETURNS text AS $$
DECLARE
	c_id text;
	c_tok text;
	c_exp integer;
BEGIN
	c_id := md5(my_domain || md5(my_person_id::char)); -- also in get_person_from_cookie
	c_tok := public.random_string(32);
	c_exp := FLOOR(EXTRACT(epoch from (NOW() + interval '1 year')));
	INSERT INTO peeps.logins(person_id, cookie_id, cookie_tok, cookie_exp, domain) VALUES (my_person_id, c_id, c_tok, c_exp, my_domain);
	RETURN CONCAT(c_id, ':', c_tok);
END;
$$ LANGUAGE plpgsql;


-- Give the cookie value returned from login_person_domain, and I'll return people.* if found and not expired
CREATE FUNCTION get_person_from_cookie(cookie char) RETURNS SETOF peeps.people AS $$
DECLARE
	c_id text;
	c_tok text;
	a_login logins;
BEGIN
	c_id := split_part(cookie, ':', 1);
	c_tok := split_part(cookie, ':', 2);
	SELECT * INTO a_login FROM peeps.logins WHERE cookie_id=c_id AND cookie_tok=c_tok;
	IF FOUND AND
	  a_login.cookie_exp > FLOOR(EXTRACT(epoch from NOW())) AND
	  c_id = md5(a_login.domain || md5(a_login.person_id::char)) THEN
		RETURN QUERY SELECT * FROM peeps.people WHERE id=a_login.person_id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of unopened emails this emailer is allowed to access
-- PARAMS: emailer_id
CREATE FUNCTION unopened_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
	cats text[];
BEGIN
	SELECT profiles, categories INTO pros, cats FROM emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL ORDER BY id;
	ELSIF cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL AND profile = ANY(pros) ORDER BY id;
	ELSIF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL AND category = ANY(cats) ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL
			AND profile = ANY(pros) AND category = ANY(cats) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of already-open emails this emailer is allowed to access
-- PARAMS: emailer_id
CREATE FUNCTION opened_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
	cats text[];
BEGIN
	SELECT profiles, categories INTO pros, cats FROM emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL ORDER BY id;
	ELSIF cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL AND profile = ANY(pros) ORDER BY id;
	ELSIF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL AND category = ANY(cats) ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL
			AND profile = ANY(pros) AND category = ANY(cats) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of unknown-person emails, if this emailer is admin or allowed
-- (unknown-person emails don't have categories, so not checking for that)
-- PARAMS: emailer_id
CREATE FUNCTION unknown_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
BEGIN
	SELECT profiles INTO pros FROM emailers WHERE id = $1;
	IF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE person_id IS NULL ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM emails WHERE person_id IS NULL
			 AND profile = ANY(pros) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;

-- If this emailer is allowed to see this email,
-- update it to be shown as opened_by this emailer now (if not already open)
-- Returns email.id if found and permission granted, NULL if not
-- PARAMS: emailer_id, email_id
CREATE FUNCTION open_email(integer, integer) RETURNS integer AS $$
DECLARE
	pros text[];
	cats text[];
	open_id integer;
BEGIN
	SELECT profiles, categories INTO pros, cats FROM emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		SELECT id INTO open_id FROM emails WHERE id = $2;
	ELSIF cats = array['ALL'] THEN
		SELECT id INTO open_id FROM emails WHERE id = $2 AND profile = ANY(pros);
	ELSIF pros = array['ALL'] THEN
		SELECT id INTO open_id FROM emails WHERE id = $2 AND category = ANY(cats);
	ELSE
		SELECT id INTO open_id FROM emails WHERE id = $2
			AND profile = ANY(pros) AND category = ANY(cats);
	END IF;
	IF open_id IS NOT NULL THEN
		UPDATE emails SET opened_at=NOW(), opened_by=$1
			WHERE id=open_id AND opened_by IS NULL;
	END IF;
	RETURN open_id;
END;
$$ LANGUAGE plpgsql;

-- Strip spaces and lowercase email address before validating & storing
CREATE FUNCTION clean_email() RETURNS TRIGGER AS $$
BEGIN
	NEW.email = lower(regexp_replace(NEW.email, '\s', '', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_email BEFORE INSERT OR UPDATE OF email ON people FOR EACH ROW EXECUTE PROCEDURE clean_email();


-- Strip all line breaks and spaces around name before storing
CREATE FUNCTION clean_name() RETURNS TRIGGER AS $$
BEGIN
	NEW.name = btrim(regexp_replace(NEW.name, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_name BEFORE INSERT OR UPDATE OF name ON people FOR EACH ROW EXECUTE PROCEDURE clean_name();


-- Statkey has no whitespace at all. Statvalue trimmed but keeps inner whitespace.
CREATE FUNCTION clean_userstats() RETURNS TRIGGER AS $$
BEGIN
	NEW.statkey = lower(regexp_replace(NEW.statkey, '[^[:alnum:]_-]', '', 'g'));
	NEW.statvalue = btrim(NEW.statvalue, E'\r\n\t ');
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_userstats BEFORE INSERT OR UPDATE OF statkey, statvalue ON userstats FOR EACH ROW EXECUTE PROCEDURE clean_userstats();


-- urls.url remove all whitespace, then add http:// if not there
CREATE FUNCTION clean_url() RETURNS TRIGGER AS $$
BEGIN
	NEW.url = regexp_replace(NEW.url, '\s', '', 'g');
	IF NEW.url !~ '\Ahttps?://' THEN
		NEW.url = 'http://' || NEW.url;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_url BEFORE INSERT OR UPDATE OF url ON urls FOR EACH ROW EXECUTE PROCEDURE clean_url();


-- Create "address" (first word of name) and random password upon insert of new person
CREATE FUNCTION generated_person_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.address = split_part(btrim(regexp_replace(NEW.name, '\s+', ' ', 'g')), ' ', 1);
	NEW.lopass = public.random_string(4);
	NEW.newpass = public.unique_for_table_field(8, 'peeps.people', 'newpass');
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER generate_person_fields BEFORE INSERT ON peeps.people FOR EACH ROW EXECUTE PROCEDURE generated_person_fields();


-- If something sets any of these fields to '', change it to NULL before saving
CREATE FUNCTION null_person_fields() RETURNS TRIGGER AS $$
BEGIN
	IF btrim(NEW.country) = '' THEN
		NEW.country = NULL;
	END IF;
	IF btrim(NEW.email) = '' THEN
		NEW.email = NULL;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER null_person_fields BEFORE INSERT OR UPDATE OF country, email ON people FOR EACH ROW EXECUTE PROCEDURE null_person_fields();


-- No whitespace, all lowercase, for emails.profile and emails.category
CREATE FUNCTION clean_emails_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.profile = regexp_replace(lower(NEW.profile), '[^[:alnum:]_@-]', '', 'g');
	IF TG_OP = 'INSERT' AND (NEW.category IS NULL OR trim(both ' ' from NEW.category) = '') THEN
		NEW.category = NEW.profile;
	ELSE
		NEW.category = regexp_replace(lower(NEW.category), '[^[:alnum:]_@-]', '', 'g');
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_emails_fields BEFORE INSERT OR UPDATE OF profile, category ON emails FOR EACH ROW EXECUTE PROCEDURE clean_emails_fields();


-- Update people.email_count when number of emails for this person_id changes
CREATE FUNCTION update_email_count() RETURNS TRIGGER AS $$
DECLARE
	pid integer := NULL;
BEGIN
	IF ((TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.person_id IS NOT NULL) THEN
		pid := NEW.person_id;
	ELSIF (TG_OP = 'UPDATE' AND OLD.person_id IS NOT NULL) THEN
		pid := OLD.person_id;  -- in case updating to set person_id = NULL, recalcuate old one
	ELSIF (TG_OP = 'DELETE' AND OLD.person_id IS NOT NULL) THEN
		pid := OLD.person_id;
	END IF;
	IF pid IS NOT NULL THEN
		UPDATE peeps.people SET email_count=(SELECT COUNT(*) FROM peeps.emails WHERE person_id = pid) WHERE id = pid;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER update_email_count AFTER INSERT OR DELETE OR UPDATE OF person_id ON emails FOR EACH ROW EXECUTE PROCEDURE update_email_count();


-- Setting a URL to be the "main" one sets all other URLs for that person to be NOT main
CREATE FUNCTION one_main_url() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.main = 't' THEN
		UPDATE peeps.urls SET main=FALSE WHERE person_id=NEW.person_id AND id != NEW.id;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER one_main_url AFTER INSERT OR UPDATE OF main ON urls FOR EACH ROW EXECUTE PROCEDURE one_main_url();


-- Generate random strings when creating new api_key
CREATE FUNCTION generated_api_keys() RETURNS TRIGGER AS $$
BEGIN
	NEW.akey = public.unique_for_table_field(8, 'peeps.api_keys', 'akey');
	NEW.apass = public.random_string(8);
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER generated_api_keys BEFORE INSERT ON peeps.api_keys FOR EACH ROW EXECUTE PROCEDURE generated_api_keys();


-- Not used by peeps, but by other schemas that refer to peeps.people.id with their own views:  Example:
-- CREATE TRIGGER editor_up2person INSTEAD OF UPDATE ON editor_person FOR EACH FOR EXECUTE PROCEDURE peeps.up2person();
CREATE FUNCTION up2person() RETURNS TRIGGER AS $$
BEGIN
	UPDATE peeps.people SET name=NEW.name, email=NEW.email, address=NEW.address, city=NEW.city, state=NEW.state, country=NEW.country WHERE id=OLD.person_id;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- GET /emails/unopened/count
-- Grouped summary of howmany unopened emails in each profile/category
-- JSON format: {profiles:{categories:howmany}}
--{"derek@sivers":{"derek@sivers":43,"derek":2,"programmer":1},
-- "we@woodegg":{"woodeggRESEARCH":1,"woodegg":1,"we@woodegg":1}}
-- PARAMS: emailer_id
CREATE FUNCTION unopened_email_count(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_object_agg(profile, cats) INTO js FROM (WITH unopened AS
		(SELECT profile, category FROM emails WHERE id IN
			(SELECT * FROM unopened_email_ids($1)))
		SELECT profile, (SELECT json_object_agg(category, num) FROM
			(SELECT category, COUNT(*) AS num FROM unopened u2
				WHERE u2.profile=unopened.profile
				GROUP BY category ORDER BY num DESC) rr)
		AS cats FROM unopened GROUP BY profile) r;  
	IF js IS NULL THEN
		js := '{}';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/unopened/:profile/:category
-- PARAMS: emailer_id, profile, category
CREATE FUNCTION unopened_emails(integer, text, text, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT id FROM emails WHERE id IN (SELECT * FROM unopened_email_ids($1))
			AND profile = $2 AND category = $3)) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/next/:profile/:category
-- Opens email (updates status as opened by this emailer) then returns view
-- PARAMS: emailer_id, profile, category
CREATE FUNCTION open_next_email(integer, text, text, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	SELECT id INTO eid FROM emails
		WHERE id IN (SELECT * FROM unopened_email_ids($1))
		AND profile=$2 AND category=$3 LIMIT 1;
	IF eid IS NULL THEN

		mime := 'application/problem+json';
		js := '{"type": "about:blank", "title": "Not Found", "status": 404}';

	ELSE
		mime := 'application/json';
		PERFORM open_email($1, eid);
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/opened
-- PARAMS: emailer_id
CREATE FUNCTION opened_emails(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT * FROM opened_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/:id
-- PARAMS: emailer_id, email_id
CREATE FUNCTION get_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN

		mime := 'application/problem+json';
		js := '{"type": "about:blank", "title": "Not Found", "status": 404}';

	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id
-- PARAMS: emailer_id, email_id, JSON of new values
CREATE FUNCTION update_email(integer, integer, json, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN

		mime := 'application/problem+json';
		js := '{"type": "about:blank", "title": "Not Found", "status": 404}';

	ELSE
		PERFORM public.jsonupdate('peeps.emails', eid, $3,
			public.cols2update('peeps', 'emails', ARRAY['id', 'created_at']));
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;



