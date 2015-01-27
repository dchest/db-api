--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = musicthoughts, pg_catalog;

--
-- Data for Name: authors; Type: TABLE DATA; Schema: musicthoughts; Owner: d50b
--

SET SESSION AUTHORIZATION DEFAULT;

ALTER TABLE authors DISABLE TRIGGER ALL;

INSERT INTO authors (id, name, url) VALUES (1, 'Miles Davis', 'http://www.milesdavis.com/');
INSERT INTO authors (id, name, url) VALUES (2, 'Dead Beat', 'http://www.deadbeat.com/');
INSERT INTO authors (id, name, url) VALUES (3, '老崔', 'http://www.cuijian.com/');
INSERT INTO authors (id, name, url) VALUES (4, 'Maya Angelou', 'http://www.mayaangelou.com/');


ALTER TABLE authors ENABLE TRIGGER ALL;

--
-- Name: authors_id_seq; Type: SEQUENCE SET; Schema: musicthoughts; Owner: d50b
--

SELECT pg_catalog.setval('authors_id_seq', 4, true);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: musicthoughts; Owner: d50b
--

ALTER TABLE categories DISABLE TRIGGER ALL;

INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (1, 'composing music', 'componer música', 'la composition', 'Musik komponieren', 'comporre musica', 'compôr música', '楽曲作り', '(正在)作曲樂曲', 'التأليف الموسيقي', 'сочинение музыки');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (2, 'writing lyrics', 'escribir letras', 'écrire des paroles', 'Liedtexte schreiben', 'scrivere testi', 'escrever letras', '歌詞作り', '(正在)作詞', 'كتابة كلمات الأغاني', 'написание текстов');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (3, 'music listening', 'escuchar música', 'écouter de la musique', 'Musik hören', 'ascoltare musica', 'ouvir música', '好きな音楽', '(正在)聽音樂', 'الاستماع إلى الموسيقى', 'прослушивание музыки');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (4, 'experiments', 'experimentos', 'expériences', 'Experimente', 'esperimenti', 'experiências', '実験', '實驗計畫', 'التجارب', 'эксперименты');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (5, 'writers block', 'bloqueo de escritor', 'l''angoisse de la page blanche', 'Schreiberblock', 'blocco dello scrittore', 'bloqueio criativo', 'ライターのブロック', '作者心理阻滯', 'عقدة الكاتب', 'колонка авторов');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (6, 'practicing', 'práctica', 'la pratique', 'Üben', 'esercitarsi', 'praticar', '練習', '練習中，練功中', 'التدرب', 'игра');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (7, 'performing', 'interpretación', 'la performance', 'Auftreten', 'esibirsi', 'actuar ao vivo', 'パフォーマンス', '演出中', 'العزف على المسرح', 'выступление');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (8, 'recording', 'grabación', 'l''enregistrement', 'Aufnehmen', 'registrare', 'gravar', 'レコーディング', '錄音中', 'التسجيل', 'запись');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (9, 'music business', 'industria de la música', 'l''industrie de la musique', 'Musikgeschäft', 'industria discografica', 'indústria musical', '音楽業界', '音樂生意，經商', 'المجال الموسيقى', 'музыкальный бизнес');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (10, 'career', 'carrera', 'carrière', 'Karriere', 'carriera', 'carreira', 'キャリア', '事業，行業', 'المهنة', 'карьера');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (11, 'big thoughts', 'grandes pensamientos', 'de grandes pensées', 'Große Gedanken', 'grandi pensieri', 'grandes pensamentos', '大きな考想', '大思維', 'أفكار كبيرة', 'великие высказывания');
INSERT INTO categories (id, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (12, 'technology', 'tecnología', 'la technologie', 'Technologie', 'tecnologia', 'tecnologia', '技術', '科技技術', 'تكنولوجيا', 'техника');


ALTER TABLE categories ENABLE TRIGGER ALL;

--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: musicthoughts; Owner: d50b
--

SELECT pg_catalog.setval('categories_id_seq', 12, true);


--
-- Data for Name: contributors; Type: TABLE DATA; Schema: musicthoughts; Owner: d50b
--

ALTER TABLE contributors DISABLE TRIGGER ALL;

INSERT INTO contributors (id, person_id, url, place) VALUES (1, 1, NULL, NULL);
INSERT INTO contributors (id, person_id, url, place) VALUES (2, 2, NULL, 'the magic chocolate factory');
INSERT INTO contributors (id, person_id, url, place) VALUES (3, 3, 'salt.com or verucaenterprises.co.uk', NULL);


ALTER TABLE contributors ENABLE TRIGGER ALL;

--
-- Data for Name: thoughts; Type: TABLE DATA; Schema: musicthoughts; Owner: d50b
--

ALTER TABLE thoughts DISABLE TRIGGER ALL;

INSERT INTO thoughts (id, approved, author_id, contributor_id, created_at, as_rand, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (1, true, 1, 1, '2011-11-11', true, 'http://www.milesdavis.com/', 'Play what you don''t know.', 'Toca lo que no sabes.', 'Joue ce que tu ne connais pas.', 'Spiele das, was du nicht kennst.', 'Suona quello che non conosci.', 'Toca aquilo que não sabes.', '知らないものを弾け。', '玩你所不知道的(音乐/风格)。', 'اعرف ما لا تعرفه.', 'Играйте то, что не знаете.');
INSERT INTO thoughts (id, approved, author_id, contributor_id, created_at, as_rand, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (2, false, 2, 2, '2011-11-12', false, 'http://www.buy-my-spam-vitamins.cc/', 'Hehehehe… This thought is unapproved.', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO thoughts (id, approved, author_id, contributor_id, created_at, as_rand, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (3, true, 3, 1, '2011-11-13', false, 'http://www.cuijian.com/', 'If music could be translated into human speech it would no longer need to exist.', 'Si la música pudiera ser traducida al lenguaje humano, ya no sería necesaria su existencia.', 'Si on pouvait traduire la musique en paroles humaines, elle n''aurai plus besoin d''exister.', 'Wenn man Musik in menschliche Sprache übersetzen könnte, gäbe es für sie keine Notwendigkeit mehr.', 'Se la musica potesse essere tradotta in un linguaggio umano non avrebbe più senso di esistere.', 'Se a música pudesse ser traduzida em linguagem humana não teria razão para existir.', 'もし、音楽が人間の言葉に翻訳できたら、もう[音楽が]存在する必要がなくなるだろうね。', '如果音乐可以被翻译成人类的言语，那音乐就再也没有存在的必要了。', 'إن كان بالإمكان ترجمة الموسيقى إلى لغة تخاطب إنسانية لانتفى مبرر وجودها.', 'Если бы музыку можно было преобразовать в человеческую речь, не было бы больше необходимости в ее существовании.');
INSERT INTO thoughts (id, approved, author_id, contributor_id, created_at, as_rand, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (4, true, 1, 1, '2011-11-14', true, 'http://www.milesdavis.com/', 'Do not fear mistakes. There are none.', 'No temas a los errores. No existen.', 'Ne crains pas les erreurs. Ils n''existent pas.', 'Fürchte dich nicht vor Fehlern. Es gibt keine.', 'Non aver paura degli errori. Non ce ne sono.', 'Não temas os erros. Eles não existem.', '失敗を恐れるな。［失敗なんてものは］一つもない。', '不要害怕错误。错误是不存在的。', 'لا تخف من الأخطاء فلا يوجد أي منها.', 'Не бойся совершать ошибки. Их не существует.');
INSERT INTO thoughts (id, approved, author_id, contributor_id, created_at, as_rand, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (5, true, 4, 3, '2011-11-15', false, 'http://www.mayaangelou.com/', 'People will forget what you said, people will forget what you did, but people will never forget how you made them feel.', 'La gente olvidará lo que dijiste, la gente olvidará lo que hiciste, pero la gente nunca olvidará cómo los hiciste sentir.', 'Les gens oublieront ce que tu as dit, ils oublieront ce que tu as fait, mais ils n''oublieront jamais ce que tu leur as fait ressentir.', 'Die Menschen werden vergessen, was du sagtest, die Menschen werden vergessen, was du tatest, aber die Menschen werden niemals vergessen, welches Gefühl du ihnen gabst.', 'La gente si dimentica quello che hai detto, la gente si dimentica quello che hai fatto, ma la gente non si dimenticherá mai quello che le hai fatto provare.', 'As pessoas esquecer-se-ão do que tu disseste, do que tu fizeste, mas nunca se esquecerão de como tu as fizeste sentir.', '人は君の言ったこと、やったことなんてのは忘れるだろうけど、どのような気持ちにさせてくれたかは決して忘れないよ。', '人们会忘记你所说的话，人们会忘记你做了什么事情，但人们永远不会忘记你给他们的感受。', 'الناس سينسون ما قلته وما فعلته لكنهم لن ينسوا أبداً الشعور الذي جعلتهم يشعرون به.', 'Люди забудут, что ты сказал им, забудут, что ты сделал, но никогда не забудут, как заставил их почувствовать.');
INSERT INTO thoughts (id, approved, author_id, contributor_id, created_at, as_rand, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru) VALUES (6, false, 4, 3, '2011-11-16', false, 'http://www.mayaangelou.com/', 'oops', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


ALTER TABLE thoughts ENABLE TRIGGER ALL;

--
-- Data for Name: categories_thoughts; Type: TABLE DATA; Schema: musicthoughts; Owner: d50b
--

ALTER TABLE categories_thoughts DISABLE TRIGGER ALL;

INSERT INTO categories_thoughts (thought_id, category_id) VALUES (1, 4);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (1, 6);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (1, 7);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (2, 11);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (3, 7);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (4, 2);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (5, 2);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (5, 1);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 1);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 2);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 3);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 4);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 5);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 6);
INSERT INTO categories_thoughts (thought_id, category_id) VALUES (6, 7);


ALTER TABLE categories_thoughts ENABLE TRIGGER ALL;

--
-- Name: contributors_id_seq; Type: SEQUENCE SET; Schema: musicthoughts; Owner: d50b
--

SELECT pg_catalog.setval('contributors_id_seq', 3, true);


--
-- Name: thoughts_id_seq; Type: SEQUENCE SET; Schema: musicthoughts; Owner: d50b
--

SELECT pg_catalog.setval('thoughts_id_seq', 6, true);



--
-- PostgreSQL database dump complete
--

