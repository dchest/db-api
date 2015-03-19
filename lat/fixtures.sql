BEGIN;
INSERT INTO concepts (concept) VALUES ('roses are red');
INSERT INTO concepts (concept) VALUES ('violets are blue');
INSERT INTO concepts (concept) VALUES ('sugar is sweet');
INSERT INTO tags VALUES (1, 'flower');
INSERT INTO tags VALUES (2, 'flower');
INSERT INTO tags VALUES (1, 'color');
INSERT INTO tags VALUES (2, 'color');
INSERT INTO tags VALUES (3, 'flavor');
INSERT INTO pairings (concept1_id, concept2_id, thoughts) VALUES (1, 2, 'describing flowers');
COMMIT;

