#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_WORK,"How do I hunt?","~w~Buy a hunting licence for the season from the steward in the ducal fortress; hunting without one, a protected beast or in a closed season is poaching. Bring down game with a bow or a spear. Take up small game with ~y~Y~w~; dress a deer, boar, wolf or bear where it fell with a knife (~y~Y~w~ at the body), or shoulder it with ~y~Walk + Y~w~ for the butcher. A body left lying rots away after 15 minutes, and the remains of a dressed one are gone 15 minutes after the dressing.",true);
	Help_Register(HELP_SECTION_WORK,"How do traps work?","~w~Use a snare or a trap from your bag to set it where you stand, or a shovel to dig a pit. Snares take hares, rabbits, foxes and pheasants; a foothold trap holds deer, boar and wolves, and anyone who steps in it; a pit holds boar, wolves and bears. Bait draws game to a trap from afar. Springing or taking someone else's trap is theft.",true);
	Help_Register(HELP_SECTION_WORK,"Do I need a licence to cut wood or mine?","~w~Yes. Hunting, woodcutting and mining are the count's rights: buy a licence for the season from the steward in the ducal fortress. Working without one is poaching if anyone sees you.",true);
	Help_Register(HELP_SECTION_WORK,"Is there a bounty on wolves?","~w~Yes. The steward in the ducal fortress pays the county's bounty for every wolf's pelt you hand over.",false);
	Command_Describe("hunt","Staff: hunting info, lay a carcass, grant a licence, set a trap, clear the traps.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Hunting_PromptContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Hunting_TrapContext");
	SetTimer("Hunting_Sweep",HUNTING_SWEEP_MS,true);
	SetTimer("Hunting_PromptTick",HUNTING_PROMPT_MS,true);
	SetTimer("Hunting_TrapTick",HUNTING_TRAP_TICK_MS,true);
	Boot_RegisterLoader("Hunting_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("hunting-1-licences","CREATE TABLE IF NOT EXISTS licences (character_id INT UNSIGNED NOT NULL, licence TINYINT NOT NULL, season_index INT NOT NULL, PRIMARY KEY (character_id, licence)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("hunting-2-traps","CREATE TABLE IF NOT EXISTS traps (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, owner_character_id INT UNSIGNED NOT NULL, armed TINYINT NOT NULL DEFAULT 1, baited TINYINT NOT NULL DEFAULT 0, caught_species TINYINT NOT NULL DEFAULT -1, set_at INT NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Hunting_LoadOnBoot();

public Hunting_LoadOnBoot()
{
	new cleared = 0;

	for (new node = 0;node < WORK_MAX_NODES;node++)
	{
		if (!Work_IsValidNode(node))
		{
			continue;
		}

		new key[WORK_KIND_KEY_LEN];
		Work_GetKindKey(Work_GetTargetKind(WORK_TARGET_NODE,node),key);

		if (!strcmp(key,"kill") || !strcmp(key,"kill_boar") || !strcmp(key,"kill_wolf") || !strcmp(key,"kill_bear"))
		{
			Work_DeleteNode(node);
			cleared++;
		}
	}

	new traps = await Hunting_LoadTraps();
	Log_Info("hunting","%d traps set, %d old kills cleared",traps,cleared);
	Boot_LoaderDone();
	return 1;
}
