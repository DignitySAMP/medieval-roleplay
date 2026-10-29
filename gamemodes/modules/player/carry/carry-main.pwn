#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"Why am I so slow?","~w~Everything you carry has a weight. Over what you can carry you can't sprint. Far over it you can only walk: hold ~y~~k~~SNEAK_ABOUT~~w~, or you stop to catch your breath. Willpower carries more, and so does a ~y~satchel~w~ or a ~y~backpack~w~ in your bag. Nothing is ever refused: you just slow down.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"How do I carry logs and sacks?","~w~Logs, beams, stone blocks, full sacks, barrels and carcasses are carried in your arms: you can't sprint, jump or fight, and with two you can only walk. ~y~Crouch~w~ to set one down; a blow knocks it out of your arms. A cart or a pack animal carries many.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"What are bags and baskets for?","~w~Use a ~y~satchel~w~, ~y~backpack~w~ or ~y~belt pouch~w~ from your bag to open it: more room for your things. A ~y~basket~w~ holds produce, a ~y~creel~w~ fish. What's in them goes where the bag goes.",false);
	Command_Describe("carrydebug","Staff: your weight, limit, load band, bulky loads and pace.");
	Character_RegisterBusyCheck("Carry_BusyCheck");
	SetTimer("Carry_Tick",CARRY_TICK_MS,true);
	AnimPreload_Register("CARRY");
	AnimPreload_Register(CARRY_SHOULDER_LIB);

	for (new load = 1;load < CARRY_LOAD_COUNT;load++)
	{
		new lib[16], name[24];
		Carry_GetHoldAnim(g_CarryLoadGrip[load] == CARRY_GRIP_ARMS ? CARRY_HOLD_STILL : CARRY_HOLD_SHOULDER,lib,name);
		Attach_SetPresetAnim(Attach_FindPresetByModel(g_CarryLoadModel[load]),lib,name);
	}
}

hook OnMigrationRun()
{
	new const tables[][] = {"character_items", "container_items", "dropped_items", "claims"};
	new const params[] = {ITEM_SATCHEL, ITEM_BACKPACK, ITEM_BELT_POUCH, ITEM_BASKET, ITEM_WOVEN_BASKET, ITEM_CREEL};
	new key[MIGRATION_KEY_LEN], sql[192];

	for (new i = 0;i < sizeof(tables);i++)
	{
		format(key,sizeof(key),"carry-data-%s",tables[i]);
		Inventory_FormatWearToData(sql,tables[i],params,sizeof(params));
		Migration_Add(key,sql);
	}
}
