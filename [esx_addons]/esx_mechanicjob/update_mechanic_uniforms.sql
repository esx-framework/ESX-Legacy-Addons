-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

SET @mechanic_skin_male = '{"tshirt_1":15,"tshirt_2":0,"torso_1":243,"torso_2":5,"decals_1":0,"decals_2":0,"arms":8,"pants_1":94,"pants_2":0,"shoes_1":67,"shoes_2":0,"mask_1":0,"mask_2":0,"bproof_1":0,"bproof_2":0,"bags_1":0,"bags_2":0,"helmet_1":-1,"helmet_2":0,"glasses_1":-1,"glasses_2":0,"chain_1":0,"chain_2":0,"ears_1":-1,"ears_2":0}';
SET @mechanic_skin_female = '{"tshirt_1":1,"tshirt_2":0,"torso_1":251,"torso_2":5,"decals_1":0,"decals_2":0,"arms":6,"pants_1":97,"pants_2":5,"shoes_1":70,"shoes_2":0,"mask_1":0,"mask_2":0,"bproof_1":0,"bproof_2":0,"bags_1":0,"bags_2":0,"helmet_1":-1,"helmet_2":0,"glasses_1":-1,"glasses_2":0,"chain_1":0,"chain_2":0,"ears_1":-1,"ears_2":0}';

UPDATE `job_grades`
SET `skin_male` = @mechanic_skin_male
WHERE `job_name` = 'mechanic'
	AND (`skin_male` IS NULL OR `skin_male` = '' OR `skin_male` = '{}');

UPDATE `job_grades`
SET `skin_female` = @mechanic_skin_female
WHERE `job_name` = 'mechanic'
	AND (`skin_female` IS NULL OR `skin_female` = '' OR `skin_female` = '{}');
