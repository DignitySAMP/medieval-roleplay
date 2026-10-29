#include <pp-hooks>

hook Models_OnRegister()
{
    Models_AddObject(MODEL_TOURNEY_LANCE,"tourney/tourney_lance.dff","tourney/tourney.txd",MAP_BASE_STATIC);
    Models_AddObject(MODEL_TOURNEY_LANCE_STUB,"tourney/tourney_lance_stub.dff","tourney/tourney.txd",MAP_BASE_STATIC);
}

hook OnMigrationRun()
{
	Migration_Add("mounts-1-seats", "CREATE TABLE IF NOT EXISTS mount_seats (type TINYINT NOT NULL, gait TINYINT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, rx FLOAT NOT NULL, ry FLOAT NOT NULL, rz FLOAT NOT NULL, PRIMARY KEY (type, gait)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("mounts-2-stands", "CREATE TABLE IF NOT EXISTS mount_stands (type TINYINT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, rx FLOAT NOT NULL, ry FLOAT NOT NULL, rz FLOAT NOT NULL, PRIMARY KEY (type)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

hook OnGameModeInit()
{
    Help_Register(HELP_SECTION_SURVIVAL,"How do I mount and dismount a horse?","~w~Stand beside a horse and press ~y~F~w~ to mount it. The horse must accept you as its rider. Press ~y~F~w~ again to dismount.",true);
	Character_RegisterBusyCheck("Mount_BusyCheck");
	Command_Describe("horse","Dev: put a horse beside you.");
	Command_Describe("mountseat","Staff: tune where a rider sits for a gait.");
	Command_Describe("mountstand","Staff: tune how a parked mount stands.");
	Mount_ResetPoses();
	Boot_RegisterLoader("Mount_LoadPosesOnBoot");

	Keys_RegisterContext(KEY_SECONDARY_ATTACK,KEYS_PRIO_WORLD,"Mount_KeyContext");
	AnimPreload_Register("BIKED");
	Log_Info("mounts","%d horse types, %d frames each",MOUNT_TYPE_COUNT,MOUNT_IDLE_FRAMES + MOUNT_WALK_FRAMES + MOUNT_GALLOP_FRAMES + MOUNT_SPRINT_FRAMES);
}
