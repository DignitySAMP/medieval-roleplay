#define SEASONS_WATER_FREEZE_STAGE (4)
#define SEASONS_WATER_PIECES (5)
#define SEASONS_ICE_CREEK (-12801)
#define SEASONS_ICE_MILL (-12802)
#define SEASONS_ICE_BROOK (-12803)
#define SEASONS_ICE_LAKE (-12804)
#define SEASONS_ICE_POOLS (-12805)
#define SEASONS_ICE_MILL_LOD (-12812)
#define SEASONS_ICE_BROOK_LOD (-12813)
#define SEASONS_ICE_LAKE_LOD (-12814)

enum E_SEASONS_WATER
{
    E_SEASONS_WATER_ORIGINAL,
    E_SEASONS_WATER_ICE,
    E_SEASONS_WATER_LOD,
    E_SEASONS_WATER_BASE,
    E_SEASONS_WATER_FILE[64],
    E_SEASONS_WATER_LOD_FILE[64],
    E_SEASONS_WATER_TXD[64],
}

static const s_SeasonsWater[SEASONS_WATER_PIECES][E_SEASONS_WATER] = {
    {-12701, SEASONS_ICE_CREEK, 0, MAP_BASE_BLEND, "map/ice/rv_creek_c.dff", "", "map/ice/ice.txd"},
    {-12702, SEASONS_ICE_MILL, SEASONS_ICE_MILL_LOD, MAP_BASE_BLEND, "map/ice/rv_mill_a.dff", "map/ice/rv_mill_a_lod.dff", "map/ice/ice.txd"},
    {-12706, SEASONS_ICE_BROOK, SEASONS_ICE_BROOK_LOD, MAP_BASE_BLEND, "map/ice/rv_brook_b.dff", "map/ice/rv_brook_b_lod.dff", "map/ice/ice.txd"},
    {-12570, SEASONS_ICE_LAKE, SEASONS_ICE_LAKE_LOD, MAP_BASE_STATIC, "map/ice/c9w_lake.dff", "map/ice/c9w_lake_lod.dff", "map/ice/ice.txd"},
    {-12443, SEASONS_ICE_POOLS, 0, MAP_BASE_STATIC, "map/ice/c9w_pools.dff", "", "map/ice/ice.txd"}
};

static bool:s_SeasonsWaterFrozen;
static s_SeasonsIceCollision[SEASONS_WATER_PIECES] = {-1, ...};

stock bool:Seasons_IsWaterFrozen()
{
    return s_SeasonsWaterFrozen;
}

stock Seasons_GetWaterCollisionCount()
{
    new count = 0;

    for (new row = 0; row < SEASONS_WATER_PIECES; row++)
    {
        if (s_SeasonsIceCollision[row] >= 0 && s_SeasonsIceCollision[row] != 0xFFFF)
        {
            count++;
        }
    }

    return count;
}

stock Seasons_GetWaterPieceCount()
{
    return SEASONS_WATER_PIECES;
}

stock Seasons_GetWaterOriginal(row)
{
    return row >= 0 && row < SEASONS_WATER_PIECES ? s_SeasonsWater[row][E_SEASONS_WATER_ORIGINAL] : 0;
}

stock Seasons_GetWaterModel(row)
{
    new original = Seasons_GetWaterOriginal(row);

    if (original == 0)
    {
        return 0;
    }

    new STREAMER_TAG_OBJECT:objectid = Map_GetModelObject(original);
    return IsValidDynamicObject(objectid) ? Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID) : 0;
}

stock Seasons_GetWaterLodModel(row)
{
    new original = Seasons_GetWaterOriginal(row);

    if (original == 0)
    {
        return 0;
    }

    new STREAMER_TAG_OBJECT:objectid = Map_GetLodObject(original);
    return IsValidDynamicObject(objectid) ? Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID) : 0;
}

stock Seasons_UpdateWater()
{
    new bool:frozen = Seasons_GetLook() == SEASONS_LOOK_WINTER && Seasons_GetStage() >= SEASONS_WATER_FREEZE_STAGE;

    if (frozen == s_SeasonsWaterFrozen)
    {
        return;
    }

    for (new row = 0; row < SEASONS_WATER_PIECES; row++)
    {
        new original = s_SeasonsWater[row][E_SEASONS_WATER_ORIGINAL];
        new STREAMER_TAG_OBJECT:objectid = Map_GetModelObject(original);

        if (!IsValidDynamicObject(objectid))
        {
            continue;
        }

        new Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz, Float:distance;
        GetDynamicObjectPos(objectid, x, y, z);
        GetDynamicObjectRot(objectid, rx, ry, rz);
        Streamer_GetFloatData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_STREAM_DISTANCE, distance);
        Streamer_SetIntData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_MODEL_ID, frozen ? s_SeasonsWater[row][E_SEASONS_WATER_ICE] : original);
        Nearby_QueueStream(STREAMER_TYPE_OBJECT, x, y, z, -1, -1, -1, distance);

        if (frozen)
        {
            s_SeasonsIceCollision[row] = CA_CreateObject(s_SeasonsWater[row][E_SEASONS_WATER_ICE], x, y, z, rx, ry, rz, true);
        }
        else if (s_SeasonsIceCollision[row] >= 0 && s_SeasonsIceCollision[row] != 0xFFFF)
        {
            CA_DestroyObject(s_SeasonsIceCollision[row]);
            s_SeasonsIceCollision[row] = -1;
        }

        if (s_SeasonsWater[row][E_SEASONS_WATER_LOD] == 0)
        {
            continue;
        }

        Map_SetLodModel(original, frozen ? s_SeasonsWater[row][E_SEASONS_WATER_ICE] : original);
    }

    s_SeasonsWaterFrozen = frozen;
    pawn_call_public("Seasons_OnWaterFrozen", "i", _:frozen);
}

forward Seasons_OnWaterFrozen(frozen);

public Seasons_OnWaterFrozen(frozen)
{
    #pragma unused frozen
    return 1;
}

#include <pp-hooks>

hook Models_OnRegister()
{
    for (new row = 0; row < SEASONS_WATER_PIECES; row++)
    {
        Models_AddObject(s_SeasonsWater[row][E_SEASONS_WATER_ICE], s_SeasonsWater[row][E_SEASONS_WATER_FILE], s_SeasonsWater[row][E_SEASONS_WATER_TXD], s_SeasonsWater[row][E_SEASONS_WATER_BASE]);

        if (CA_LoadFromDff(s_SeasonsWater[row][E_SEASONS_WATER_ICE], s_SeasonsWater[row][E_SEASONS_WATER_FILE]) != 1)
        {
            Log_Error("seasons", "ice collision failed for %d", s_SeasonsWater[row][E_SEASONS_WATER_ICE]);
        }

        if (s_SeasonsWater[row][E_SEASONS_WATER_LOD] != 0)
        {
            Models_AddObject(s_SeasonsWater[row][E_SEASONS_WATER_LOD], s_SeasonsWater[row][E_SEASONS_WATER_LOD_FILE], s_SeasonsWater[row][E_SEASONS_WATER_TXD], MAP_BASE_BLEND);
        }
    }
}
