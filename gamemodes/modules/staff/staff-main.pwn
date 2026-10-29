#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_START,"How do I reach the staff?","~w~Open ~y~/help~w~ and pick ~y~Ask the staff~w~. Say what's wrong, out of character, and name the other player's id if it's about someone. A member of staff answers you in chat and can come to you.",true);
	Command_Describe("staff","Staff: the staff panel: who's on, reports, actions on a player.");
	Command_Describe("reports","Staff: open reports, to claim, answer, visit and close.");
	Command_Describe("a","Staff: staff chat.");
	Command_Describe("duty","Staff: on or off duty.");
	Command_Describe("spec","Staff: watch a player; again to stop.");
	Command_Describe("inspect","Staff: a character's sheet: body, needs, bag, skills, faith, house, law, record.");
	Command_Describe("warn","Staff: a warning on a player's record.");
	Command_Describe("warnings","Staff: a player's warnings.");
	Command_Describe("goto","Staff: go to a player.");
	Command_Describe("gethere","Admin: bring a player to you.");
	Command_Describe("heal","Admin: restore health, clear wounds and bleeding, revive and restore needs. /heal [player]; defaults to yourself.");
	Command_Describe("revive","Admin: help a struck-down player up. /revive [player]; defaults to yourself.");
	Command_Describe("unstick","Staff: clear panels, actions, combat and riding; return to ground. /unstick [player]; defaults to yourself.");
	Command_Describe("tp","Staff: /tp <x> <y> <z> [interior] [world]. Omitted interior and world keep your current ones.");
	Command_Describe("kick","Admin: kick a player.");
	Command_Describe("ban","Admin: ban an account and its address; over a week needs a second member of staff.");
	Command_Describe("unban","Admin: lift the bans on an account.");
	Command_Describe("jail","Admin: OOC jail for some minutes.");
	Command_Describe("unjail","Admin: let a player out of OOC jail.");
	Command_Describe("freeze","Admin: hold a player still.");
	Command_Describe("unfreeze","Admin: let a held player move.");
	Command_Describe("logs","Admin: the staff log.");
	Command_Describe("crier","Loremaster: post a notice on the Events tab for the crier.");
	Command_Describe("setstaff","Management: set a player's staff level, or give or take the loremaster or faction team role.");
	Command_Describe("giveitem","Management: give an item.");
	Command_Describe("givecoin","Management: give coin.");
	Command_Describe("shutdown","Management: restart the server after some minutes, warning everyone.");
	Command_Describe("seat","Faction team: seat or strip the duke, the count or a regent (two-person rule).");
	SetTimer("Staff_JailTick",STAFF_JAIL_TICK_MS,true);
}

hook OnMigrationRun()
{
	Migration_Add("staff-1-roles","CREATE TABLE IF NOT EXISTS staff_roles (account_id INT UNSIGNED NOT NULL, role TINYINT NOT NULL, granted_by INT UNSIGNED NOT NULL DEFAULT 0, granted_at INT NOT NULL, PRIMARY KEY (account_id, role)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("staff-2-tickets","CREATE TABLE IF NOT EXISTS tickets (id INT UNSIGNED NOT NULL AUTO_INCREMENT, reporter_account_id INT UNSIGNED NOT NULL, target_account_id INT UNSIGNED NULL, text VARCHAR(256) NOT NULL, state TINYINT NOT NULL DEFAULT 0, claimed_by INT UNSIGNED NULL, created_at INT NOT NULL, closed_at INT NULL, PRIMARY KEY (id), KEY state (state)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("staff-3-actions","CREATE TABLE IF NOT EXISTS staff_actions (id INT UNSIGNED NOT NULL AUTO_INCREMENT, staff_account_id INT UNSIGNED NOT NULL DEFAULT 0, action VARCHAR(32) NOT NULL, target VARCHAR(64) NOT NULL, detail VARCHAR(256) NOT NULL DEFAULT '', at INT NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("staff-4-warnings","CREATE TABLE IF NOT EXISTS warnings (id INT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NOT NULL, staff_account_id INT UNSIGNED NOT NULL DEFAULT 0, reason VARCHAR(144) NOT NULL, at INT NOT NULL, PRIMARY KEY (id), KEY account_id (account_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("staff-5-bans","CREATE TABLE IF NOT EXISTS bans (id INT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NULL, ip VARCHAR(45) NULL, until INT NOT NULL DEFAULT 0, reason VARCHAR(144) NOT NULL, staff_account_id INT UNSIGNED NOT NULL DEFAULT 0, at INT NOT NULL, lifted TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (id), KEY account_id (account_id), KEY ip (ip)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("staff-6-jail","CREATE TABLE IF NOT EXISTS staff_jail (account_id INT UNSIGNED NOT NULL, until INT NOT NULL, reason VARCHAR(144) NOT NULL, staff_account_id INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (account_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("staff-7-actions-target","ALTER TABLE staff_actions MODIFY target VARCHAR(192) NOT NULL");
}
