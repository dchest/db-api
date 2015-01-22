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


