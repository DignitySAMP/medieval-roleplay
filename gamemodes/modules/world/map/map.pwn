#define MAP_BASE_STATIC (13684)
#define MAP_BASE_BLEND (16403)
#define MAP_BASE_DECAL (16014)

#define MAP_VISIBLE_OBJECTS (750)
#define MAP_LOD_PRIORITY (-1)

#define MAP_SPAWN_X (985.4214)
#define MAP_SPAWN_Y (-3183.9695)
#define MAP_SPAWN_Z (33.2912)
#define MAP_SPAWN_A (0.0)

#define AddSimpleModel Map_AddSimpleModel
#undef CreateDynamicObject
#define CreateDynamicObject Map_CreateDynamicObject
#include "map/handoff.pwn"
#undef AddSimpleModel
#undef CreateDynamicObject
#define CreateDynamicObject Nearby_CreateDynamicObject
#include "map/colbounds.pwn"

static s_MapObjects = 0;

stock Map_GetDetailObjectCount()
{
    return s_MapObjects;
}

stock Map_GetObjectCount()
{
	return s_MapObjects + Map_GetActiveLodCount();
}

Map_Load()
{
	s_MapObjects = Handoff_Load();
	Log_Info("map","%d map object(s) loaded, %d with collision from %d model(s)",s_MapObjects,Map_GetCollisionObjectCount(),Map_GetCollisionModelCount());
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	RemoveBuildingForPlayer(playerid,-1,0.0,0.0,0.0,MAP_STRIP_RADIUS);
	RemoveBuildingForPlayer(playerid,-1,MAP_EDGE_STRIP_X,MAP_EDGE_STRIP_Y,MAP_EDGE_STRIP_Z,MAP_EDGE_STRIP_RADIUS);
}

hook Models_OnRegister()
{
	Map_Load();
	Map_LoadLods();
	Map_FitLods();
}
