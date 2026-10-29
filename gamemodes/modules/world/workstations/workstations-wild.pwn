#define WORK_WILD_LINGER_MS (60000)
#define WORK_WILD_RESPAWN_MIN_MS (300000)
#define WORK_WILD_RESPAWN_MAX_MS (900000)
#define WORK_WILD_NODE_SPACING (8.0)
#define WORK_WILD_STATION_SPACING (5.0)
#define WORK_WILD_PLAYER_SPACING (60.0)
#define WORK_WILD_PICK_TRIES (200)
#define WORK_NODE_COOLDOWN_SECONDS (1200)
#define WORK_NODE_COOLDOWN_SLOTS (2048)
#define WORK_KEEP_CLEAR_HEIGHT (4.0)

enum E_WORK_WILD_DEF
{
	E_WORK_WILD_DEF_KIND[WORK_KIND_KEY_LEN],
	E_WORK_WILD_DEF_HABITAT,
	E_WORK_WILD_DEF_TARGET,
	E_WORK_WILD_DEF_RADIUS_CM,
}

static const s_WorkWildDefs[][E_WORK_WILD_DEF] = {
	{"claypit", WORK_HABITAT_WET, 15, 140},
	{"bog", WORK_HABITAT_WET, 15, 140},
	{"seam", WORK_HABITAT_ROCK, 18, 100},
	{"outcrop", WORK_HABITAT_ROCK, 30, 100},
	{"trunk", WORK_HABITAT_FOREST, 36, 140},
	{"wildhive", WORK_HABITAT_FOREST, 12, 60},
	{"swarm", WORK_HABITAT_FOREST, 6, 60},
	{"fruitbush", WORK_HABITAT_FOREST | WORK_HABITAT_EDGE, 24, 100},
	{"ground", WORK_HABITAT_EDGE | WORK_HABITAT_FOREST, 24, 100},
	{"windfall", WORK_HABITAT_FOREST, 42, 100},
	{"stump", WORK_HABITAT_FOREST, 30, 60},
	{"herbs", WORK_HERB_ALL_HABITATS, 140, 60}
};

enum E_WORK_NODE_COOLDOWN
{
	E_WORK_NODE_COOLDOWN_CHARACTER,
	E_WORK_NODE_COOLDOWN_ROW,
	E_WORK_NODE_COOLDOWN_UNTIL,
}

static bool:s_WorkSpotUsed[WORK_SPOT_COUNT];
static bool:s_WorkSpotKeptClear[WORK_SPOT_COUNT];
static s_WorkNodeCooldowns[WORK_NODE_COOLDOWN_SLOTS][E_WORK_NODE_COOLDOWN];
static s_WorkNodeCooldownNext;
static s_WorkWildPending;
static bool:s_WorkHerbsRefreshing;
static bool:s_WorkHerbsRefreshAgain;

static Work_GetWildTarget(def)
{
	if (!strcmp(s_WorkWildDefs[def][E_WORK_WILD_DEF_KIND],"herbs") && Calendar_GetSeason() == SEASON_WINTER)
	{
		return s_WorkWildDefs[def][E_WORK_WILD_DEF_TARGET] * WORK_HERB_WINTER_SHARE / 100;
	}

	return s_WorkWildDefs[def][E_WORK_WILD_DEF_TARGET];
}

static bool:Work_IsWildHerbStale(nodeid)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(g_WorkNodes[nodeid][E_WORK_NODE_KIND],key);

	if (strcmp(key,"herbs") != 0 || !Calendar_IsLoaded())
	{
		return false;
	}

	new species = Work_GetNodeHerb(nodeid);
	return species == -1 || !Work_IsHerbUpNow(species);
}

static bool:Work_IsMoonHerbNode(nodeid)
{
	return Work_GetHerbMoon(Work_GetNodeHerb(nodeid)) != WORK_HERB_MOON_NONE;
}

static Work_CountWildKind(def)
{
	new count = 0;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (g_WorkNodes[i][E_WORK_NODE_USED] && g_WorkNodes[i][E_WORK_NODE_SPOT] != -1 && !Work_IsMoonHerbNode(i) && Work_FindWildDef(g_WorkNodes[i][E_WORK_NODE_KIND]) == def)
		{
			count++;
		}
	}

	return count;
}

stock Work_CountHerbNodes(species)
{
	new count = 0;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (Work_GetNodeHerb(i) == species && species != -1)
		{
			count++;
		}
	}

	return count;
}

static Work_FindWildDef(kind)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);

	for (new i = 0;i < sizeof(s_WorkWildDefs);i++)
	{
		if (strcmp(s_WorkWildDefs[i][E_WORK_WILD_DEF_KIND],key) == 0)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Work_IsWildNode(nodeid)
{
	return Work_GetNodeSpot(nodeid) != -1;
}

stock Work_GetWildNodeCount()
{
	new count = 0;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (g_WorkNodes[i][E_WORK_NODE_USED] && g_WorkNodes[i][E_WORK_NODE_SPOT] != -1)
		{
			count++;
		}
	}

	return count;
}

stock Work_GetWildPending()
{
	return s_WorkWildPending;
}

static bool:Work_IsPlayerNear(Float:x,Float:y,Float:range)
{
	foreach (new playerid : Player)
	{
		new Float:px, Float:py, Float:pz;
		GetPlayerPos(playerid,px,py,pz);

		if (GetPlayerVirtualWorld(playerid) == 0 && Util_GetDistance2D(x,y,px,py) < range)
		{
			return true;
		}
	}

	return false;
}

stock Work_PickWildSpot(kind,habitat = 0)
{
	new def = Work_FindWildDef(kind);

	if (def == -1)
	{
		return -1;
	}

	new bool:isHerbs = !strcmp(s_WorkWildDefs[def][E_WORK_WILD_DEF_KIND],"herbs"), E_SEASON:season = Calendar_GetSeason();

	if (habitat == 0)
	{
		habitat = s_WorkWildDefs[def][E_WORK_WILD_DEF_HABITAT];
	}

	for (new try = 0;try < WORK_WILD_PICK_TRIES;try++)
	{
		new spot = random(WORK_SPOT_COUNT);

		if (s_WorkSpotUsed[spot] || s_WorkSpotKeptClear[spot] || !(g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_HABITAT] & habitat) || g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_RADIUS_CM] < s_WorkWildDefs[def][E_WORK_WILD_DEF_RADIUS_CM])
		{
			continue;
		}

		if (isHerbs && habitat == s_WorkWildDefs[def][E_WORK_WILD_DEF_HABITAT] && Work_GetHerbWeightFor(g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_HABITAT],season) <= 0)
		{
			continue;
		}

		new Float:x = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][0], Float:y = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][1], Float:z = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][2];

		if (Work_FindNearestNode(x,y,z,0,WORK_WILD_NODE_SPACING) != -1 || Work_FindNearestStation(x,y,z,0,WORK_WILD_STATION_SPACING) != -1)
		{
			continue;
		}

		if (try < WORK_WILD_PICK_TRIES / 2 && Work_IsPlayerNear(x,y,WORK_WILD_PLAYER_SPACING))
		{
			continue;
		}

		return spot;
	}

	return -1;
}

#pragma warning push
#pragma warning disable 204
forward Task:Work_CreateWildNode(kind,spot,species = 0);

async Task:Work_CreateWildNode(kind,spot,species = 0)
{
	s_WorkSpotUsed[spot] = true;
	new nodeid = await Work_CreateNode(kind,g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][0],g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][1],g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][2],g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][3],0,0,spot,species);

	if (nodeid == -1)
	{
		s_WorkSpotUsed[spot] = false;
	}

	return async nodeid;
}

forward Task:Work_FillWildNodes();

async Task:Work_FillWildNodes()
{
	await task_ticks(1);

	new spawned = 0;

	for (new def = 0;def < sizeof(s_WorkWildDefs);def++)
	{
		new kind = Work_FindKind(s_WorkWildDefs[def][E_WORK_WILD_DEF_KIND]);

		for (new n = Work_CountWildKind(def), target = Work_GetWildTarget(def);n < target;n++)
		{
			new spot = Work_PickWildSpot(kind);

			if (spot == -1)
			{
				break;
			}

			new nodeid = await Work_CreateWildNode(kind,spot);

			if (nodeid == -1)
			{
				break;
			}

			spawned++;
		}
	}

	return async spawned;
}
#pragma warning pop

stock Work_ClearWildNodes()
{
	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (g_WorkNodes[i][E_WORK_NODE_USED] && g_WorkNodes[i][E_WORK_NODE_SPOT] != -1)
		{
			s_WorkSpotUsed[g_WorkNodes[i][E_WORK_NODE_SPOT]] = false;
			Work_DeleteNode(i);
		}
	}
}

stock Work_GetSpotInfo(spot,&Float:x,&Float:y,&Float:z)
{
	if (spot < 0 || spot >= WORK_SPOT_COUNT)
	{
		return 0;
	}

	x = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][0];
	y = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][1];
	z = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][2];
	return g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_HABITAT];
}

stock Work_KeepSpotsClear(Float:x,Float:y,Float:z,Float:range)
{
	new kept = 0;

	for (new spot = 0;spot < WORK_SPOT_COUNT;spot++)
	{
		if (Util_GetDistance2D(x,y,g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][0],g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][1]) <= range && floatabs(z - g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][2]) <= WORK_KEEP_CLEAR_HEIGHT)
		{
			s_WorkSpotKeptClear[spot] = true;
			kept++;
		}
	}

	return kept;
}

stock bool:Work_IsSpotKeptClear(spot)
{
	return spot >= 0 && spot < WORK_SPOT_COUNT && s_WorkSpotKeptClear[spot];
}

stock Work_FreeWildSpot(spot)
{
	if (spot >= 0 && spot < WORK_SPOT_COUNT)
	{
		s_WorkSpotUsed[spot] = false;
	}
}

stock Work_TakeDriftSpot()
{
	for (new try = 0;try < WORK_WILD_PICK_TRIES;try++)
	{
		new spot = random(WORK_SPOT_COUNT), Float:x = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][0], Float:y = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][1], Float:z = g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_POS][2];

		if (s_WorkSpotUsed[spot] || s_WorkSpotKeptClear[spot] || !(g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_HABITAT] & (WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE | WORK_HABITAT_VILLAGE | WORK_HABITAT_WET)) || Work_FindNearestNode(x,y,z,0,WORK_WILD_NODE_SPACING) != -1 || Work_FindNearestStation(x,y,z,0,WORK_WILD_STATION_SPACING) != -1)
		{
			continue;
		}

		s_WorkSpotUsed[spot] = true;
		return spot;
	}

	return -1;
}

stock Work_ClearStaleHerbs()
{
	new cleared = 0;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (g_WorkNodes[i][E_WORK_NODE_USED] && g_WorkNodes[i][E_WORK_NODE_SPOT] != -1 && Work_IsWildHerbStale(i))
		{
			Work_RemoveWildNode(i);
			cleared++;
		}
	}

	return cleared;
}

#pragma warning push
#pragma warning disable 204
forward Task:Work_SpawnMoonHerbs();

async Task:Work_SpawnMoonHerbs()
{
	await task_ticks(1);

	new kind = Work_FindKind("herbs"), spawned = 0;

	for (new species = 0;species < WORK_HERB_COUNT;species++)
	{
		if (Work_GetHerbMoon(species) == WORK_HERB_MOON_NONE || !Work_IsHerbUpNow(species) || Work_CountHerbNodes(species) > 0)
		{
			continue;
		}

		for (new n = WORK_HERB_MOON_MIN + random(WORK_HERB_MOON_MAX - WORK_HERB_MOON_MIN + 1);n > 0;n--)
		{
			new spot = Work_PickWildSpot(kind,Work_GetHerbHabitat(species));

			if (spot == -1)
			{
				break;
			}

			new nodeid = await Work_CreateWildNode(kind,spot,species + 1);

			if (nodeid != -1)
			{
				spawned++;
			}
		}
	}

	return async spawned;
}

forward Task:Work_RefreshHerbs();

async Task:Work_RefreshHerbs()
{
	if (s_WorkHerbsRefreshing)
	{
		s_WorkHerbsRefreshAgain = true;
		return async 0;
	}

	new spawned = 0;
	s_WorkHerbsRefreshing = true;

	do
	{
		s_WorkHerbsRefreshAgain = false;
		Work_ClearStaleHerbs();
		spawned += await Work_FillWildNodes();
		spawned += await Work_SpawnMoonHerbs();
		Work_ScatterHerbDrifts();
	}
	while (s_WorkHerbsRefreshAgain);

	s_WorkHerbsRefreshing = false;
	return async spawned;
}
#pragma warning pop

stock Work_WildOnEmptied(nodeid)
{
	SetTimerEx("Work_WildRemove",WORK_WILD_LINGER_MS,false,"dd",nodeid,g_WorkNodes[nodeid][E_WORK_NODE_ROW]);
}

stock Work_RemoveWildNode(nodeid)
{
	if (!Work_IsWildNode(nodeid))
	{
		return;
	}

	new kind = g_WorkNodes[nodeid][E_WORK_NODE_KIND], spot = g_WorkNodes[nodeid][E_WORK_NODE_SPOT], bool:isMoonHerb = Work_IsMoonHerbNode(nodeid);

	if (spot >= 0 && spot < WORK_SPOT_COUNT)
	{
		s_WorkSpotUsed[spot] = false;
	}

	Work_DeleteNode(nodeid);

	if (isMoonHerb)
	{
		return;
	}

	s_WorkWildPending++;
	SetTimerEx("Work_WildRespawn",Util_RandomRange(WORK_WILD_RESPAWN_MIN_MS,WORK_WILD_RESPAWN_MAX_MS),false,"d",kind);
}

stock Work_GetNodeCooldown(playerid,nodeid)
{
	new characterid = Character_GetId(playerid), now = gettime();

	if (characterid <= 0 || !Work_IsValidNode(nodeid))
	{
		return 0;
	}

	for (new i = 0;i < WORK_NODE_COOLDOWN_SLOTS;i++)
	{
		if (s_WorkNodeCooldowns[i][E_WORK_NODE_COOLDOWN_CHARACTER] == characterid && s_WorkNodeCooldowns[i][E_WORK_NODE_COOLDOWN_ROW] == g_WorkNodes[nodeid][E_WORK_NODE_ROW] && s_WorkNodeCooldowns[i][E_WORK_NODE_COOLDOWN_UNTIL] > now)
		{
			return s_WorkNodeCooldowns[i][E_WORK_NODE_COOLDOWN_UNTIL] - now;
		}
	}

	return 0;
}

stock Work_NoteNodeWorked(playerid,nodeid)
{
	new characterid = Character_GetId(playerid);

	if (characterid <= 0 || !Work_IsValidNode(nodeid))
	{
		return;
	}

	new slot = s_WorkNodeCooldownNext;
	s_WorkNodeCooldownNext = (s_WorkNodeCooldownNext + 1) % WORK_NODE_COOLDOWN_SLOTS;
	s_WorkNodeCooldowns[slot][E_WORK_NODE_COOLDOWN_CHARACTER] = characterid;
	s_WorkNodeCooldowns[slot][E_WORK_NODE_COOLDOWN_ROW] = g_WorkNodes[nodeid][E_WORK_NODE_ROW];
	s_WorkNodeCooldowns[slot][E_WORK_NODE_COOLDOWN_UNTIL] = gettime() + WORK_NODE_COOLDOWN_SECONDS;
}

stock Work_ClearNodeCooldowns(playerid)
{
	new characterid = Character_GetId(playerid);

	for (new i = 0;i < WORK_NODE_COOLDOWN_SLOTS;i++)
	{
		if (s_WorkNodeCooldowns[i][E_WORK_NODE_COOLDOWN_CHARACTER] == characterid)
		{
			s_WorkNodeCooldowns[i][E_WORK_NODE_COOLDOWN_CHARACTER] = 0;
		}
	}
}

forward Work_WildRemove(nodeid,row);

public Work_WildRemove(nodeid,row)
{
	if (Work_IsValidNode(nodeid) && g_WorkNodes[nodeid][E_WORK_NODE_ROW] == row)
	{
		Work_RemoveWildNode(nodeid);
	}

	return 1;
}

forward Work_WildRespawn(kind);

public Work_WildRespawn(kind)
{
	s_WorkWildPending--;
	new def = Work_FindWildDef(kind);

	if (def == -1 || Work_CountWildKind(def) >= Work_GetWildTarget(def))
	{
		return 1;
	}

	new spot = Work_PickWildSpot(kind);

	if (spot != -1)
	{
		Work_CreateWildNode(kind,spot);
	}
	return 1;
}

forward Work_LoadWildOnBoot();

public Work_LoadWildOnBoot()
{
	yield 1;

	new spent = 0, trimmed = 0, counts[sizeof(s_WorkWildDefs)];

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (!g_WorkNodes[i][E_WORK_NODE_USED] || g_WorkNodes[i][E_WORK_NODE_SPOT] == -1)
		{
			continue;
		}

		new spot = g_WorkNodes[i][E_WORK_NODE_SPOT], def = Work_FindWildDef(g_WorkNodes[i][E_WORK_NODE_KIND]);

		if (g_WorkNodes[i][E_WORK_NODE_STOCK] <= 0 || spot >= WORK_SPOT_COUNT || Work_IsSpotKeptClear(spot) || Work_IsWildHerbStale(i))
		{
			Work_DeleteNode(i);
			spent++;
			continue;
		}

		if (def != -1 && !Work_IsMoonHerbNode(i) && counts[def] >= Work_GetWildTarget(def))
		{
			Work_DeleteNode(i);
			trimmed++;
			continue;
		}

		if (def != -1 && !Work_IsMoonHerbNode(i))
		{
			counts[def]++;
		}

		s_WorkSpotUsed[spot] = true;
	}

	new spawned = await Work_FillWildNodes();
	Log_Info("workstations","%d wild node(s) live, %d spawned, %d spent cleared, %d over the target cleared, %d spots",Work_GetWildNodeCount(),spawned,spent,trimmed,WORK_SPOT_COUNT);
	Boot_LoaderDone();
}

forward Work_LoadMoonHerbsOnBoot();

public Work_LoadMoonHerbsOnBoot()
{
	yield 1;

	new spawned = await Work_SpawnMoonHerbs();

	if (spawned > 0)
	{
		Log_Info("workstations","%d moon herb(s) out under the full moon",spawned);
	}

	Boot_LoaderDone();
}

#include <pp-hooks>

hook Calendar_OnSeason(season)
{
	#pragma unused season
	Work_RefreshHerbs();
}

hook Calendar_OnNightfall()
{
	Work_SpawnMoonHerbs();
}

hook Calendar_OnDawn()
{
	Work_ClearStaleHerbs();
}

hook Calendar_OnSet()
{
	Work_RefreshHerbs();
}
