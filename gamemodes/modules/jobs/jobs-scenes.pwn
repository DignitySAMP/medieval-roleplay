#define SCENE_ANIM_LIB_LEN (16)
#define SCENE_ANIM_NAME_LEN (24)
#define SCENE_NO_PROP (-1)
#define SCENE_WORKPIECE_PROP (0)
#define SCENE_DEFAULT_DIST (2.4)
#define SCENE_DEFAULT_LIFT (1.3)
#define SCENE_DEFAULT_AIM (0.4)
#define SCENE_DEFAULT_MOVE_MS (1100)

enum E_SCENE_STAGE_DEF
{
	E_SCENE_STAGE_DEF_RECIPE[RECIPE_NAME_LEN],
	E_SCENE_STAGE_DEF_STAGE,
	Float:E_SCENE_STAGE_DEF_ROT,
	Float:E_SCENE_STAGE_DEF_DIST,
	Float:E_SCENE_STAGE_DEF_LIFT,
	Float:E_SCENE_STAGE_DEF_AIM,
	Float:E_SCENE_STAGE_DEF_SIDE,
	E_SCENE_STAGE_DEF_MOVE_MS,
	E_SCENE_STAGE_DEF_ANIM_LIB[SCENE_ANIM_LIB_LEN],
	E_SCENE_STAGE_DEF_ANIM_NAME[SCENE_ANIM_NAME_LEN],
	bool:E_SCENE_STAGE_DEF_ANIM_LOOP,
	E_SCENE_STAGE_DEF_PROP,
}

static const s_SceneStageDefs[][E_SCENE_STAGE_DEF] = {
	{"Stew", 0, 30.0, 2.2, 1.2, 0.3, 0.0, 1100, "INT_HOUSE", "wash_up", true, SCENE_NO_PROP},
	{"Stew", 1, -35.0, 1.6, 0.9, 0.2, 0.2, 900, "CASINO", "cards_loop", true, 2},
	{"Stew", 2, -20.0, 1.4, 0.8, 0.1, 0.3, 900, "CASINO", "dealone", false, 2},
	{"Stew", 3, 40.0, 1.8, 1.0, 0.2, -0.2, 1000, "SHOP", "SHP_Serve_Loop", true, 3},
	{"Stew", 4, 0.0, 2.0, 1.1, 0.2, 0.0, 900, "CARRY", "putdwn", false, 3},
	{"Stew", 5, 60.0, 1.8, 1.2, 0.3, 0.0, 900, "BAR", "Barserve_bottle", false, 0},
	{"Stew", 6, 15.0, 1.5, 1.4, 0.0, 0.0, 1000, "SHOP", "SHP_Serve_Loop", true, 0},
	{"Stew", 7, -50.0, 2.3, 1.3, 0.3, 0.0, 1200, "BAR", "Barserve_give", false, 0},
	{"Fish", 0, 40.0, 1.6, 1.0, 0.3, 0.0, 900, "INT_SHOP", "shop_loop", true, SCENE_NO_PROP},
	{"Fish", 1, 70.0, 3.0, 1.3, 0.4, 0.0, 900, "KNIFE", "KNIFE_1", false, SCENE_NO_PROP},
	{"Fish", 2, 0.0, 3.4, 1.6, 0.2, 0.6, 1500, "SAMP", "FishingIdle", true, SCENE_NO_PROP},
	{"Fish", 3, 20.0, 2.6, 1.3, 0.3, 0.3, 500, "SAMP", "FishingIdle", true, SCENE_NO_PROP},
	{"Fish", 4, -30.0, 2.8, 1.3, 0.3, 0.0, 900, "SWORD", "sword_idle", true, SCENE_NO_PROP},
	{"Fish", 5, 60.0, 2.2, 1.1, 0.3, 0.0, 900, "SWORD", "sword_idle", true, SCENE_NO_PROP}
};

static const s_SceneFallbackAnims[CHALLENGE_COUNT][2][SCENE_ANIM_NAME_LEN] = {
	{"INT_SHOP", "shop_loop"},
	{"CASINO", "dealone"},
	{"SHOP", "SHP_Serve_Loop"},
	{"BAR", "Barserve_glass"},
	{"CARRY", "liftup"},
	{"PED", "IDLE_stance"}
};

static Recipe_FindStageDef(recipe,stage)
{
	new name[RECIPE_NAME_LEN];
	Recipe_GetName(recipe,name);

	for (new i = 0;i < sizeof(s_SceneStageDefs);i++)
	{
		if (s_SceneStageDefs[i][E_SCENE_STAGE_DEF_STAGE] == stage && strcmp(s_SceneStageDefs[i][E_SCENE_STAGE_DEF_RECIPE],name) == 0)
		{
			return i;
		}
	}

	return -1;
}

stock Recipe_GetStageShot(recipe,stage,&Float:rot,&Float:dist,&Float:lift,&Float:aim,&Float:side,&moveMs)
{
	new def = Recipe_FindStageDef(recipe,stage);

	if (def == -1)
	{
		rot = (stage % 2 == 0) ? 25.0 : -25.0;
		dist = SCENE_DEFAULT_DIST;
		lift = SCENE_DEFAULT_LIFT;
		aim = SCENE_DEFAULT_AIM;
		side = 0.0;
		moveMs = SCENE_DEFAULT_MOVE_MS;
		return;
	}

	rot = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_ROT];
	dist = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_DIST];
	lift = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_LIFT];
	aim = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_AIM];
	side = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_SIDE];
	moveMs = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_MOVE_MS];
}

stock Recipe_GetStageAnim(recipe,stage,lib[],name[],&bool:isLoop,libSize = sizeof(lib),nameSize = sizeof(name))
{
	new def = Recipe_FindStageDef(recipe,stage);

	if (def == -1)
	{
		new kind = Recipe_GetStageKind(recipe,stage);

		if (kind < 0 || kind >= CHALLENGE_COUNT)
		{
			kind = 0;
		}

		strcopy(lib,s_SceneFallbackAnims[kind][0],libSize);
		strcopy(name,s_SceneFallbackAnims[kind][1],nameSize);
		isLoop = true;
		return;
	}

	strcopy(lib,s_SceneStageDefs[def][E_SCENE_STAGE_DEF_ANIM_LIB],libSize);
	strcopy(name,s_SceneStageDefs[def][E_SCENE_STAGE_DEF_ANIM_NAME],nameSize);
	isLoop = s_SceneStageDefs[def][E_SCENE_STAGE_DEF_ANIM_LOOP];
}

stock Recipe_GetStageProp(recipe,stage)
{
	new def = Recipe_FindStageDef(recipe,stage);
	return def == -1 ? SCENE_WORKPIECE_PROP : s_SceneStageDefs[def][E_SCENE_STAGE_DEF_PROP];
}

stock Recipe_RegisterSceneAnims()
{
	for (new i = 0;i < sizeof(s_SceneStageDefs);i++)
	{
		AnimPreload_Register(s_SceneStageDefs[i][E_SCENE_STAGE_DEF_ANIM_LIB]);
	}

	for (new i = 0;i < CHALLENGE_COUNT;i++)
	{
		AnimPreload_Register(s_SceneFallbackAnims[i][0]);
	}
}
