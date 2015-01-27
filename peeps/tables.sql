SET client_min_messages TO ERROR;
SET client_encoding = 'UTF8';
DROP SCHEMA IF EXISTS peeps CASCADE;
BEGIN;

CREATE SCHEMA peeps;
SET search_path = peeps;

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
	city varchar(32),
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
	statkey varchar(32) not null CONSTRAINT statkey_format CHECK (statkey ~ '\A[a-z0-9._-]+\Z'),
	statvalue text not null CONSTRAINT statval_not_empty CHECK (length(statvalue) > 0),
	created_at date not null default CURRENT_DATE
);
CREATE INDEX userstats_person ON userstats(person_id);
CREATE INDEX userstats_statkey ON userstats(statkey);

-- This person's websites
CREATE TABLE urls (
	id serial primary key,
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	url varchar(255) CONSTRAINT url_format CHECK (url ~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+'),
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
	their_email varchar(127) NOT NULL CONSTRAINT valid_email CHECK (their_email ~ '\A\S+@\S+\.\S+\Z'),  -- their email address (whether incoming or outgoing)
	their_name varchar(127) NOT NULL,
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

COMMIT;


