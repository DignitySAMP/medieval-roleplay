#define TUTORIAL_WORLD_BASE (200000)
#define TUTORIAL_ISLAND_STREAM (400.0)
#define TUTORIAL_ISLAND_DRAW (400.0)
#define TUTORIAL_ISLAND_PARTS (2)
#define TUTORIAL_POSTERS (3)
#define TUTORIAL_POSTER_MODEL (2684)
#define TUTORIAL_POSTER_DRAW (150.0)

#define TUTORIAL_MODEL_WEST (-3401)
#define TUTORIAL_MODEL_EAST (-3402)

#define TUTORIAL_SPAWN_X (-2328.1399)
#define TUTORIAL_SPAWN_Y (-2781.2244)
#define TUTORIAL_SPAWN_Z (16.2567)
#define TUTORIAL_SPAWN_A (158.0)
#define TUTORIAL_SPAWN_PRELOAD_MS (2000)

#define TUTORIAL_RACK_X (-2307.18)
#define TUTORIAL_RACK_Y (-2779.07)
#define TUTORIAL_RACK_Z (16.28)

#define TUTORIAL_CAMP_X (-2325.23)
#define TUTORIAL_CAMP_Y (-2772.19)
#define TUTORIAL_CAMP_Z (16.28)

#define TUTORIAL_STABLES_X (-2314.34)
#define TUTORIAL_STABLES_Y (-2767.02)
#define TUTORIAL_STABLES_Z (16.27)
#define TUTORIAL_STABLES_A (0.0)

#define TUTORIAL_END_X (-2214.60)
#define TUTORIAL_END_Y (-2770.84)
#define TUTORIAL_END_Z (35.98)

#define TUTORIAL_MARKER_SIZE (1.5)

#define TUTORIAL_STRIP_RADIUS (250.0)

static const s_TutorialStrippedModels[] = {1297, 1319};

enum E_TUTORIAL_ISLAND_PART
{
	E_TUTORIAL_PART_MODEL,
	E_TUTORIAL_PART_DFF[40],
	E_TUTORIAL_PART_TXD[40],
	Float:E_TUTORIAL_PART_POS[3],
}

static const s_TutorialIslandParts[TUTORIAL_ISLAND_PARTS][E_TUTORIAL_ISLAND_PART] = {
	{TUTORIAL_MODEL_WEST, "tutorial/island_west.dff", "tutorial/island_west.txd", {-2333.666317, -2775.702055, 14.123654}},
	{TUTORIAL_MODEL_EAST, "tutorial/island_east.dff", "tutorial/island_east.txd", {-2310.184097, -2774.018777, 15.334863}}
};

enum E_TUTORIAL_POSTER
{
	Float:E_TUTORIAL_POSTER_POSE[6],
	E_TUTORIAL_POSTER_TEXT[32],
	E_TUTORIAL_POSTER_FONT[20],
	E_TUTORIAL_POSTER_SIZE,
	E_TUTORIAL_POSTER_COLOUR,
}

static const s_TutorialPosters[TUTORIAL_POSTERS][E_TUTORIAL_POSTER] = {
	{{-2306.6574, -2767.4960, 15.8023, 270.0, 0.0, 144.4998}, "TRAVELLER", "Terminal", 14, 0xFF9D9872},
	{{-2306.5905, -2767.3342, 15.8023, 270.0, 0.0, 144.4998}, "REY DAVINTY", "Segoe UI Light", 12, 0xFF221918},
	{{-2306.6459, -2767.4794, 15.8023, 270.0, 0.0, 144.4998}, "LETTER TO THE HOMELAND", "Segoe Print", 10, 0xFF221918}
};

static s_TutorialIslandIds[TUTORIAL_ISLAND_PARTS + TUTORIAL_POSTERS + TUTORIAL_PALISADE_OBJECTS];
static bool:s_TutorialOnIsland[MAX_PLAYERS];
static s_TutorialDonkey[MAX_PLAYERS] = {INVALID_HORSE_ID, ...};
static Float:s_TutorialSpawnAt[MAX_PLAYERS][3];

TutorialIsland_Create()
{
	for (new i = 0;i < TUTORIAL_ISLAND_PARTS;i++)
	{
		new model = s_TutorialIslandParts[i][E_TUTORIAL_PART_MODEL], Float:x = s_TutorialIslandParts[i][E_TUTORIAL_PART_POS][0], Float:y = s_TutorialIslandParts[i][E_TUTORIAL_PART_POS][1], Float:z = s_TutorialIslandParts[i][E_TUTORIAL_PART_POS][2];
		s_TutorialIslandIds[i] = _:CreateDynamicObject(model,x,y,z,0.0,0.0,0.0,-1,-1,-1,TUTORIAL_ISLAND_STREAM,TUTORIAL_ISLAND_DRAW);

		if (CA_LoadFromDff(model,s_TutorialIslandParts[i][E_TUTORIAL_PART_DFF]) == 1)
		{
			CA_CreateObject(model,x,y,z,0.0,0.0,0.0,true);
		}
		else
		{
			Log_Warn("tutorial","no collision for island part %d (%s)",model,s_TutorialIslandParts[i][E_TUTORIAL_PART_DFF]);
		}
	}

	for (new i = 0;i < TUTORIAL_POSTERS;i++)
	{
		new STREAMER_TAG_OBJECT:poster = CreateDynamicObject(TUTORIAL_POSTER_MODEL,s_TutorialPosters[i][E_TUTORIAL_POSTER_POSE][0],s_TutorialPosters[i][E_TUTORIAL_POSTER_POSE][1],s_TutorialPosters[i][E_TUTORIAL_POSTER_POSE][2],s_TutorialPosters[i][E_TUTORIAL_POSTER_POSE][3],s_TutorialPosters[i][E_TUTORIAL_POSTER_POSE][4],s_TutorialPosters[i][E_TUTORIAL_POSTER_POSE][5],-1,-1,-1,TUTORIAL_ISLAND_STREAM,TUTORIAL_POSTER_DRAW);
		SetDynamicObjectMaterialText(poster,0,s_TutorialPosters[i][E_TUTORIAL_POSTER_TEXT],_:OBJECT_MATERIAL_SIZE_256x128,s_TutorialPosters[i][E_TUTORIAL_POSTER_FONT],s_TutorialPosters[i][E_TUTORIAL_POSTER_SIZE],1,s_TutorialPosters[i][E_TUTORIAL_POSTER_COLOUR],0,_:OBJECT_MATERIAL_TEXT_ALIGN_CENTRE);
		s_TutorialIslandIds[TUTORIAL_ISLAND_PARTS + i] = _:poster;
	}

	TutorialPalisade_Create();

	for (new i = 0;i < TUTORIAL_PALISADE_OBJECTS;i++)
	{
		s_TutorialIslandIds[TUTORIAL_ISLAND_PARTS + TUTORIAL_POSTERS + i] = TutorialPalisade_GetObject(i);
	}

	Log_Info("tutorial","the tutorial island stands: %d baked parts, %d posters",TUTORIAL_ISLAND_PARTS,TUTORIAL_POSTERS);
}

stock bool:TutorialIsland_IsOn(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TutorialOnIsland[playerid];
}

stock TutorialIsland_GetWorld(playerid)
{
	return TUTORIAL_WORLD_BASE + playerid;
}

stock TutorialIsland_Enter(playerid)
{
	if (s_TutorialOnIsland[playerid])
	{
		return;
	}

	s_TutorialOnIsland[playerid] = true;
	Streamer_ToggleAllItems(playerid,STREAMER_TYPE_OBJECT,false,s_TutorialIslandIds,sizeof(s_TutorialIslandIds));

	if (!Horse_IsValid(s_TutorialDonkey[playerid]))
	{
		s_TutorialDonkey[playerid] = Horse_Create(MOUNT_DONKEY_TYPE,TUTORIAL_STABLES_X,TUTORIAL_STABLES_Y,TUTORIAL_STABLES_Z,TUTORIAL_STABLES_A,TutorialIsland_GetWorld(playerid));
	}

	TutorialIsland_HoldDonkey(playerid,true);
}

stock TutorialIsland_SetSpawn(playerid,Float:x,Float:y,Float:z)
{
	s_TutorialSpawnAt[playerid][0] = x;
	s_TutorialSpawnAt[playerid][1] = y;
	s_TutorialSpawnAt[playerid][2] = z;
}

stock TutorialIsland_GetDonkey(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_TutorialDonkey[playerid] : INVALID_HORSE_ID;
}

stock TutorialIsland_HoldDonkey(playerid,bool:isHeld)
{
	Horse_SetHold(s_TutorialDonkey[playerid],isHeld ? ("You shouldn't leave yet. If you're unsure on what to do next, read the box under your HUD.") : (""));
}

stock TutorialIsland_Leave(playerid)
{
	if (!s_TutorialOnIsland[playerid])
	{
		return;
	}

	s_TutorialOnIsland[playerid] = false;
	DisablePlayerCheckpoint(playerid);

	if (Horse_IsValid(s_TutorialDonkey[playerid]))
	{
		Horse_Destroy(s_TutorialDonkey[playerid]);
	}

	s_TutorialDonkey[playerid] = INVALID_HORSE_ID;
	Work_DeleteStationsInWorld(TutorialIsland_GetWorld(playerid));
	Streamer_ToggleAllItems(playerid,STREAMER_TYPE_OBJECT,true);
}

stock TutorialIsland_Mark(playerid,Float:x,Float:y,Float:z)
{
	SetPlayerCheckpoint(playerid,x,y,z,TUTORIAL_MARKER_SIZE);
}

#include <pp-hooks>

hook Models_OnRegister()
{
	for (new i = 0;i < TUTORIAL_ISLAND_PARTS;i++)
	{
		Models_AddObject(s_TutorialIslandParts[i][E_TUTORIAL_PART_MODEL],s_TutorialIslandParts[i][E_TUTORIAL_PART_DFF],s_TutorialIslandParts[i][E_TUTORIAL_PART_TXD]);
	}

	for (new i = 0;i < sizeof(s_TutorialStrippedModels);i++)
	{
		CA_RemoveBuilding(s_TutorialStrippedModels[i],TUTORIAL_END_X,TUTORIAL_END_Y,TUTORIAL_END_Z,TUTORIAL_STRIP_RADIUS);
	}
}

hook OnPlayerConnect(playerid)
{
	for (new i = 0;i < sizeof(s_TutorialStrippedModels);i++)
	{
		RemoveBuildingForPlayer(playerid,s_TutorialStrippedModels[i],TUTORIAL_END_X,TUTORIAL_END_Y,TUTORIAL_END_Z,TUTORIAL_STRIP_RADIUS);
	}

	s_TutorialOnIsland[playerid] = false;
	s_TutorialDonkey[playerid] = INVALID_HORSE_ID;
	TutorialIsland_SetSpawn(playerid,TUTORIAL_SPAWN_X,TUTORIAL_SPAWN_Y,TUTORIAL_SPAWN_Z);
}

hook OnPlayerSpawn(playerid)
{
	if (s_TutorialOnIsland[playerid])
	{
		Streamer_UpdateEx(playerid,s_TutorialSpawnAt[playerid][0],s_TutorialSpawnAt[playerid][1],s_TutorialSpawnAt[playerid][2],TutorialIsland_GetWorld(playerid),0,STREAMER_TYPE_OBJECT,TUTORIAL_SPAWN_PRELOAD_MS,1);
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_TutorialOnIsland[playerid])
	{
		TutorialIsland_Leave(playerid);
	}
}
