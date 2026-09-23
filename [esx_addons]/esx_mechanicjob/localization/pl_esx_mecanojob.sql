-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

INSERT INTO `addon_account` (name, label, shared) VALUES
	('society_mechanic', 'Mechanik', 1)
;

INSERT INTO `addon_inventory` (name, label, shared) VALUES
	('society_mechanic', 'Mechanik', 1)
;

INSERT INTO `datastore` (name, label, shared) VALUES
	('society_mechanic', 'Mechanik', 1)
;

INSERT INTO `jobs` (name, label) VALUES
	('mechanic', 'Mechanik')
;

SET @mechanic_skin_male = '{"tshirt_1":15,"tshirt_2":0,"torso_1":243,"torso_2":5,"decals_1":0,"decals_2":0,"arms":8,"pants_1":94,"pants_2":0,"shoes_1":67,"shoes_2":0,"mask_1":0,"mask_2":0,"bproof_1":0,"bproof_2":0,"bags_1":0,"bags_2":0,"helmet_1":-1,"helmet_2":0,"glasses_1":-1,"glasses_2":0,"chain_1":0,"chain_2":0,"ears_1":-1,"ears_2":0}';
SET @mechanic_skin_female = '{"tshirt_1":1,"tshirt_2":0,"torso_1":251,"torso_2":5,"decals_1":0,"decals_2":0,"arms":6,"pants_1":97,"pants_2":5,"shoes_1":70,"shoes_2":0,"mask_1":0,"mask_2":0,"bproof_1":0,"bproof_2":0,"bags_1":0,"bags_2":0,"helmet_1":-1,"helmet_2":0,"glasses_1":-1,"glasses_2":0,"chain_1":0,"chain_2":0,"ears_1":-1,"ears_2":0}';

INSERT INTO `job_grades` (job_name, grade, name, label, salary, skin_male, skin_female) VALUES
	('mechanic',0,'recrue','Praktykant',12,@mechanic_skin_male,@mechanic_skin_female),
	('mechanic',1,'novice','Nowicjusz',24,@mechanic_skin_male,@mechanic_skin_female),
	('mechanic',2,'experimente','Doświadczony',36,@mechanic_skin_male,@mechanic_skin_female),
	('mechanic',3,'chief','Kierownik',48,@mechanic_skin_male,@mechanic_skin_female),
	('mechanic',4,'boss','Szef',0,@mechanic_skin_male,@mechanic_skin_female)
;

INSERT INTO `items` (name, label, weight) VALUES
	('gazbottle', 'Butelka z gazem', 2),
	('fixtool', 'Zestaw do naprawy', 2),
	('carotool', 'Częsci naprawcze', 2),
	('blowpipe', 'Palnik', 2),
	('fixkit', 'Narzedzia naprawcze', 3),
	('carokit', 'Części blacharskie', 3)
;
