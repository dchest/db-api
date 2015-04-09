--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = peeps, pg_catalog;

--
-- Data for Name: people; Type: TABLE DATA; Schema: peeps; Owner: d50b
--
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


SET SESSION AUTHORIZATION DEFAULT;

ALTER TABLE people DISABLE TRIGGER ALL;

INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (1, 'derek@sivers.org', '$2a$08$0yI7Vpn3UNEf5q.muDgLL.y5GJRM5ak2awUOnd9z9ZCBFoCz0/Rfy', 'yTAy', 'Dyh15IHs', 'Derek Sivers', '50POP LLC', 'Derek', 'Singapore', NULL, '018980', 'SG', '+65 9763 3568', 'This is me.', 0, 'all', 'derek', '1994-11-01');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (2, 'willy@wonka.com', '$2a$08$3UjNlK6PbXMXC7Rh.EVIFeRcvmij/b8bSfNZ.MwwmD8QtQ0sy2zje', 'R5Gf', 'NvaGAkHK', 'Willy Wonka', 'Wonka Chocolate Inc', 'Mr. Wonka', 'Hershey', 'PA', '12354', 'US', '+1 215 555 1034', NULL, 2, 'some', NULL, '2000-01-01');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (3, 'veruca@salt.com', '$2a$08$GcHJDheKQR7zu8qTr1anz.WpLoVPbZG6dA/9zaUkowcypCczUYozy', '8gcr', 'FJKApvpY', 'Veruca Salt', 'Daddy Empires Ltd', 'Veruca', 'London', 'England', 'NW1ER1', 'GB', '+44 9273 7231', NULL, 4, NULL, NULL, '2010-01-01');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (4, 'charlie@bucket.org', '$2a$08$Nf7VymjLuGGUhMl9lGTPAO0GrNq0bE5yTVMyimlFR2f7SmTMNxN46', 'AgA2', 'fdkeWoID', 'Charlie Buckets', NULL, 'Charlie', 'Hershey', 'PA', '12354', 'US', NULL, NULL, 0, 'all', NULL, '2010-09-01');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (5, 'oompa@loompa.mm', '$2a$08$vr40BeQAbNFkKaes4WPPw.lCQKPsyzAsNPRVQ2bPgVVatyvtwSKSO', 'LYtp', 'a5JDIleE', 'Oompa Loompa', NULL, 'Oompa Loompa', 'Hershey', 'PA', '12354', 'US', NULL, NULL, 0, NULL, NULL, '2010-10-01');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (6, 'augustus@gloop.de', '$2a$08$JmphXF9YeW7Fi2IQVUnZtenBU2Ftacz454V1B1Ort4/VZhFgpMzWO', 'AKyv', '8LLRaMwm', 'Augustus Gloop', NULL, 'Master Gloop', 'Munich', NULL, 'E01515', 'DE', NULL, NULL, 0, 'some', NULL, '2010-11-01');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (7, 'gong@li.cn', '$2a$08$x/C0JU7r7Obp2Ar/1G0kz.t.mrW/r0Nan0sDggw3wjjBdr6jvcpge', 'FBvY', 'xPAJKaRm', '巩俐', 'Gong Li', '巩俐', 'Shanghai', NULL, '987654', 'CN', NULL, NULL, 2, NULL, 'translator', '2010-12-12');
INSERT INTO people (id, email, hashpass, lopass, newpass, name, company, address, city, state, postalcode, country, phone, notes, email_count, listype, categorize_as, created_at) VALUES (8, 'yoko@ono.com', '$2a$08$3yMZNGqUsUH3bQaCE7Rmbeay6FHW/Us2axycwUMDsvGKSDGlVfZPS', 'uUyS', 'ysIFMj3L', 'Yoko Ono', 'yoko@lennon.com', 'Ono-San', 'Tokyo', NULL, '22534', 'JP', NULL, NULL, 0, NULL, 'translator', '2010-12-12');


ALTER TABLE people ENABLE TRIGGER ALL;

--
-- Data for Name: api_keys; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE api_keys DISABLE TRIGGER ALL;

INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (1, 'aaaaaaaa', 'bbbbbbbb', '{Peep,SiversComments,MuckworkManager}');
INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (2, 'cccccccc', 'dddddddd', '{MuckworkManager}');
INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (3, 'eeeeeeee', 'ffffffff', '{MuckworkClient}');
INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (4, 'gggggggg', 'hhhhhhhh', '{Peep}');
INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (5, 'iiiiiiii', 'jjjjjjjj', '{}');
INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (6, 'kkkkkkkk', 'llllllll', '{MuckworkClient,SiversComments,Peep}');
INSERT INTO api_keys (person_id, akey, apass, apis) VALUES (7, 'mmmmmmmm', 'nnnnnnnn', '{Peep}');


ALTER TABLE api_keys ENABLE TRIGGER ALL;

--
-- Data for Name: emailers; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE emailers DISABLE TRIGGER ALL;

INSERT INTO emailers (id, person_id, admin, profiles, categories) VALUES (1, 1, true, '{ALL}', '{ALL}');
INSERT INTO emailers (id, person_id, admin, profiles, categories) VALUES (2, 4, false, '{ALL}', '{ALL}');
INSERT INTO emailers (id, person_id, admin, profiles, categories) VALUES (3, 6, false, '{derek@sivers}', '{translator,not-derek}');
INSERT INTO emailers (id, person_id, admin, profiles, categories) VALUES (4, 7, true, '{we@woodegg}', '{ALL}');


ALTER TABLE emailers ENABLE TRIGGER ALL;

--
-- Data for Name: emails; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE emails DISABLE TRIGGER ALL;

INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (1, 2, 'derek@sivers', 'derek@sivers', '2013-07-18 15:55:03', 1, '2013-07-20 03:42:19', 1, '2013-07-20 03:44:01', 1, NULL, 3, 'willy@wonka.com', 'Will Wonka', 'you coming by?', 'To: Derek Sivers <derek@sivers.org>
From: Will Wonka <willya@wonka.com>
Message-ID: <8w2mb4flbgdd0d95x35tk4ln.1374118952478@email.android.com>
Subject: you coming by?
Date: Wed, 17 Jul 2013 23:42:59 -0400', 'Dude -

Seriously. You coming by sometime soon?

- Will', '8w2mb4flbgdd0d95x35tk4ln.1374118952478@email.android.com', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (2, 7, 'derek@sivers', 'translator', '2013-07-18 15:55:03', 3, '2013-07-20 03:45:19', 3, '2013-07-20 03:47:01', 3, NULL, 4, 'gong@li.cn', 'Gong Li', 'translations almost done', 'To: Derek Sivers <derek@sivers.org>
From: Gong Li <gong@li.cn>
Message-ID: <CABk7SeW6+FaqxOUwHNdiaR2AdxQBTY1275uC0hdkA0kLPpKPVg@mail.li.cn>
Subject: translations almost done
Date: Thu, 18 Jul 2013 10:42:59 -0400', 'Hello Mr. Sivers -

Busy raising these red lanterns, but I''m almost done with the translations.

巩俐', 'CABk7SeW6+FaqxOUwHNdiaR2AdxQBTY1275uC0hdkA0kLPpKPVg@mail.li.cn', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (3, 2, 'derek@sivers', 'derek@sivers', '2013-07-20 03:47:01', 1, '2013-07-20 03:47:01', 1, '2013-07-20 03:47:01', 1, 1, NULL, 'willy@wonka.com', 'Will Wonka', 're: you coming by?', 'References: <8w2mb4flbgdd0d95x35tk4ln.1374118952478@email.android.com>
In-Reply-To: <8w2mb4flbgdd0d95x35tk4ln.1374118952478@email.android.com>', 'Hi Will -

Yep. On my way ASAP.

--
Derek Sivers  derek@sivers.org  http://sivers.org

> Dude -
> Seriously. You coming by sometime soon?
> - Will', '20130719234701.2@sivers.org', true, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (4, 7, 'derek@sivers', 'translator', '2013-07-20 03:47:01', 3, '2013-07-20 03:47:01', 3, '2013-07-20 03:47:01', 3, 2, NULL, 'gong@li.cn', 'Gong Li', 're: translations almost done', 'References: <CABk7SeW6+FaqxOUwHNdiaR2AdxQBTY1275uC0hdkA0kLPpKPVg@mail.li.cn>
In-Reply-To: <CABk7SeW6+FaqxOUwHNdiaR2AdxQBTY1275uC0hdkA0kLPpKPVg@mail.li.cn>', 'Hi Gong -

Thank you for the update.

--
Derek Sivers  derek@sivers.org  http://sivers.org/

> Hello Mr. Sivers -
> Busy raising these red lanterns, but I''m almost done with the translations.
> 巩俐', '20130719235701.7@sivers.org', NULL, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (5, NULL, 'derek@sivers', 'fix-client', '2013-07-20 15:42:03', 2, NULL, NULL, NULL, NULL, NULL, NULL, 'new@stranger.com', 'New Stranger', 'random question', 'To: Derek Sivers <derek@sivers.org>
From: New Stranger <new@stranger.com>
Message-ID: <COL401-EAS301156C36A4AA949CA6B320BA7C1@phx.gbl>
Subject: random question
Date: Fri, 20 Jul 2013 11:42:59 -0400', 'Derek -

I have a question

- Stranger', 'COL401-EAS301156C36A4AA949CA6B320BA7C1@phx.gbl', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (6, 3, 'we@woodegg', 'woodegg', '2014-05-20 15:55:03', 4, '2014-05-21 03:42:19', 4, NULL, NULL, NULL, NULL, 'veruca@salt.com', 'Veruca Salt', 'I want that Wood Egg book now', 'To: Wood Egg <we@woodegg.com>
From: Veruca Salt <veruca@salt.com>
Message-ID: <CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7A@mail.gmail.com>
Subject: I want it now
Date: Tue, 20 May 2014 11:42:59 -0400', 'Hi Wood Egg -

Now!

- v', 'CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7A@mail.gmail.com', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (7, 3, 'we@woodegg', 'not-derek', '2014-05-29 15:55:03', 1, NULL, NULL, NULL, NULL, NULL, NULL, 'veruca@salt.com', 'Veruca Salt', 'I said now!!!', 'To: Wood Egg <we@woodegg.com>
From: Veruca Salt <veruca@salt.com>
Message-ID: <CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7B@mail.gmail.com>
Subject: I said now!!!
Date: Thurs, 29 May 2014 11:42:59 -0400', 'I said now!!! I changed my email from veruca@salt.com to veruca@salt.net. My new sites are salt.net and https://something.travel/salt  You already have www.salt.com', 'CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7B@mail.gmail.com', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (8, 3, 'we@woodegg', 'woodegg', '2014-05-29 15:56:03', 1, NULL, NULL, NULL, NULL, NULL, NULL, 'veruca@salt.com', 'Veruca Salt', 'I refuse to wait', 'To: Wood Egg <we@woodegg.com>
From: Veruca Salt <veruca@salt.com>
Message-ID: <CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7C@mail.gmail.com>
Subject: I refuse to wait
Date: Thurs, 29 May 2014 11:44:59 -0400', 'I refuse to wait', 'CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7C@mail.gmail.com', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (9, 3, 'derek@sivers', 'derek', '2014-05-29 15:57:03', 1, NULL, NULL, NULL, NULL, NULL, NULL, 'veruca@salt.com', 'Veruca Salt', 'getting personal', 'To: Derek Sivers <derek@sivers.org>
From: Veruca Salt <veruca@salt.com>
Message-ID: <CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7D@mail.gmail.com>
Subject: getting personal
Date: Thurs, 29 May 2014 11:45:59 -0400', 'Wood Egg is not replying to my last three emails!', 'CAGfCXh-fw-xxC_traMbbKTUdpcuq=N774ya=LTn0vejrAPVm7D@mail.gmail.com', false, NULL);
INSERT INTO emails (id, person_id, profile, category, created_at, created_by, opened_at, opened_by, closed_at, closed_by, reference_id, answer_id, their_email, their_name, subject, headers, body, message_id, outgoing, flag) VALUES (10, NULL, 'derek@sivers', 'fix-client', '2013-07-20 15:42:03', 2, NULL, NULL, NULL, NULL, NULL, NULL, 'oompaloompa@outlook.com', 'Oompa Loompa', 'remember me?', 'To: Derek Sivers <derek@sivers.org>
From: Oompa Loompa <oompaloompa@outlook.com>
Message-ID: <ABC123-EAS301156C36A4AA949CA6B320BA7C1@phx.gbl>
Subject: remember me?
Date: Fri, 20 Jul 2013 11:42:59 -0400', 'Derek -

Remember me?

- Ooompa, from my new email address.', 'ABC123-EAS301156C36A4AA949CA6B320BA7C1@phx.gbl', false, NULL);


ALTER TABLE emails ENABLE TRIGGER ALL;

--
-- Data for Name: email_attachments; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE email_attachments DISABLE TRIGGER ALL;

INSERT INTO email_attachments (id, email_id, mime_type, filename, bytes) VALUES (1, 9, 'image/jpeg', '20140529-abcd-angry.jpg', 54321);
INSERT INTO email_attachments (id, email_id, mime_type, filename, bytes) VALUES (2, 9, 'image/jpeg', '20140529-efgh-mad.jpg', 65432);


ALTER TABLE email_attachments ENABLE TRIGGER ALL;

--
-- Name: email_attachments_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('email_attachments_id_seq', 2, true);


--
-- Name: emailers_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('emailers_id_seq', 4, true);


--
-- Name: emails_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('emails_id_seq', 10, true);


--
-- Data for Name: formletters; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE formletters DISABLE TRIGGER ALL;

INSERT INTO formletters (id, title, explanation, body, created_at) VALUES (1, 'one', 'use for one', 'Your email is {email}. Here is your URL: https://sivers.org/u/{id}/{newpass}', '2014-12-22');
INSERT INTO formletters (id, title, explanation, body, created_at) VALUES (2, 'two', 'can not do fields outside of person object', 'Hi {address}. Thank you for buying something on somedate.', '2014-12-22');
INSERT INTO formletters (id, title, explanation, body, created_at) VALUES (3, 'three', 'blah', 'meh', '2014-12-22');
INSERT INTO formletters (id, title, explanation, body, created_at) VALUES (4, 'four', 'blah', 'meh', '2014-12-22');
INSERT INTO formletters (id, title, explanation, body, created_at) VALUES (5, 'five', 'blah', 'meh', '2014-12-22');
INSERT INTO formletters (id, title, explanation, body, created_at) VALUES (6, 'six', 'blah', 'meh', '2014-12-22');


ALTER TABLE formletters ENABLE TRIGGER ALL;

--
-- Name: formletters_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('formletters_id_seq', 6, true);


--
-- Data for Name: logins; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE logins DISABLE TRIGGER ALL;

INSERT INTO logins (person_id, cookie_id, cookie_tok, cookie_exp, domain, last_login, ip) VALUES (1, '2a9c0226c871c711a5e944bec5f6df5d', '18e8b4f0a05db21eed590e96eb27be9c', 1597389543, '50pop.com', '2012-09-14', '121.232.43.34');
INSERT INTO logins (person_id, cookie_id, cookie_tok, cookie_exp, domain, last_login, ip) VALUES (1, 'c776d5b6249a9fb45eec8d2af2fd7954', '18e8b4f0a05db21eed590e96eb27be9f', 946659600, 'sivers.org', '1980-01-01', '121.232.43.34');
INSERT INTO logins (person_id, cookie_id, cookie_tok, cookie_exp, domain, last_login, ip) VALUES (1, '95fcacd3d2c6e3e006906cc4f4cdf908', '18e8b4f0a05db21eed590e96eb27be9c', 1357613544, '50pop.com', '2013-02-14', '121.232.43.34');
INSERT INTO logins (person_id, cookie_id, cookie_tok, cookie_exp, domain, last_login, ip) VALUES (1, '5bf15bb6301eb8882f2afabf0ac7c520', '9KaJNiweUPkGGkTByR2pVsCrZZee9CEM', 1406276166, 'example.org', '2013-07-25', '121.232.43.34');


ALTER TABLE logins ENABLE TRIGGER ALL;

--
-- Name: people_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('people_id_seq', 8, true);


--
-- Data for Name: urls; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE urls DISABLE TRIGGER ALL;

INSERT INTO urls (id, person_id, url, main) VALUES (1, 1, 'https://twitter.com/sivers', false);
INSERT INTO urls (id, person_id, url, main) VALUES (2, 1, 'http://sivers.org/', true);
INSERT INTO urls (id, person_id, url, main) VALUES (3, 2, 'http://www.wonka.com/', true);
INSERT INTO urls (id, person_id, url, main) VALUES (4, 2, 'http://cdbaby.com/cd/wonka', NULL);
INSERT INTO urls (id, person_id, url, main) VALUES (5, 2, 'https://twitter.com/wonka', NULL);
INSERT INTO urls (id, person_id, url, main) VALUES (6, 3, 'http://salt.com/', NULL);
INSERT INTO urls (id, person_id, url, main) VALUES (7, 3, 'http://facebook.com/salt', NULL);
INSERT INTO urls (id, person_id, url, main) VALUES (8, 5, 'http://oompa.loompa', NULL);


ALTER TABLE urls ENABLE TRIGGER ALL;

--
-- Name: urls_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('urls_id_seq', 8, true);


--
-- Data for Name: userstats; Type: TABLE DATA; Schema: peeps; Owner: d50b
--

ALTER TABLE userstats DISABLE TRIGGER ALL;

INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (1, 1, 'listype', 'all', '2008-01-01');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (2, 1, 'twitter', '987654321 = sivers', '2010-01-01');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (3, 2, 'listype', 'some', '2011-03-15');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (4, 2, 'musicthoughts', 'clicked', '2011-03-16');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (5, 1, 'ayw', 'a', '2013-07-25');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (6, 6, 'woodegg-mn', 'interview', '2013-09-09');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (7, 6, 'woodegg-bio', 'Augustus has done a lot of business in Mongolia, importing chocolate.', '2013-09-09');
INSERT INTO userstats (id, person_id, statkey, statvalue, created_at) VALUES (8, 5, 'media', 'interview', '2014-12-23');


ALTER TABLE userstats ENABLE TRIGGER ALL;

--
-- Name: userstats_id_seq; Type: SEQUENCE SET; Schema: peeps; Owner: d50b
--

SELECT pg_catalog.setval('userstats_id_seq', 8, true);


--
-- PostgreSQL database dump complete
--

