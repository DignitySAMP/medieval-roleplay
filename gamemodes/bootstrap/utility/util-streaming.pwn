static s_UtilTeleportTimer[MAX_PLAYERS];
static Float:s_UtilTeleportPos[MAX_PLAYERS][3];
#define UTIL_INTERIOR_PRELOAD_MS (1500)
#define UTIL_INTERIOR_FALLBACK_MS (3000)
#define UTIL_LOCAL_MOVE_RANGE (15.0)

static Map:s_UtilInteriorShells;
static s_UtilInteriorTimer[MAX_PLAYERS];
static s_UtilInteriorFallbackTimer[MAX_PLAYERS];
static s_UtilInteriorStarted[MAX_PLAYERS];
static s_UtilTeleportWorld[MAX_PLAYERS];
static s_UtilTeleportInterior[MAX_PLAYERS];
static bool:s_UtilInteriorPending[MAX_PLAYERS];
static bool:s_UtilInteriorShellPending[MAX_PLAYERS];
static bool:s_UtilTeleportExplicit[MAX_PLAYERS];
static bool:s_UtilHasTeleport[MAX_PLAYERS];

stock Util_WatchInteriorShell(STREAMER_TAG_OBJECT:objectid,bool:watch = true)
{
    if (!IsValidDynamicObject(objectid))
    {
        return;
    }

    if (s_UtilInteriorShells == Map:0)
    {
        s_UtilInteriorShells = map_new();
    }

    if (watch)
    {
        map_set(s_UtilInteriorShells,_:objectid,1);
    }
    else
    {
        map_remove(s_UtilInteriorShells,_:objectid);
    }

    Streamer_ToggleItemCallbacks(STREAMER_TYPE_OBJECT,objectid,watch);
}

stock bool:Util_IsInteriorReady(playerid)
{
    return Util_IsValidPlayer(playerid) && !s_UtilInteriorPending[playerid];
}

stock bool:Util_GetTeleportDestination(playerid,&Float:x,&Float:y,&Float:z,&world,&interior)
{
    if (!Util_IsValidPlayer(playerid) || !s_UtilHasTeleport[playerid])
    {
        return false;
    }

    x = s_UtilTeleportPos[playerid][0];
    y = s_UtilTeleportPos[playerid][1];
    z = s_UtilTeleportPos[playerid][2];
    world = s_UtilTeleportWorld[playerid];
    interior = s_UtilTeleportInterior[playerid];
    return true;
}

stock Util_CancelTeleport(playerid,bool:release = false)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS)
    {
        return;
    }

    if (s_UtilInteriorFallbackTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorFallbackTimer[playerid]);
        s_UtilInteriorFallbackTimer[playerid] = 0;
    }

    if (s_UtilInteriorTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorTimer[playerid]);
        s_UtilInteriorTimer[playerid] = 0;
    }

    if (s_UtilTeleportTimer[playerid] != 0)
    {
        KillTimer(s_UtilTeleportTimer[playerid]);
        s_UtilTeleportTimer[playerid] = 0;
    }

    s_UtilInteriorPending[playerid] = false;
    s_UtilInteriorShellPending[playerid] = false;

    if (release && Util_IsValidPlayer(playerid))
    {
        if (s_UtilHasTeleport[playerid])
        {
            Streamer_UpdateEx(playerid,s_UtilTeleportPos[playerid][0],s_UtilTeleportPos[playerid][1],s_UtilTeleportPos[playerid][2],s_UtilTeleportWorld[playerid],s_UtilTeleportInterior[playerid],-1,0,0);
        }

        TogglePlayerControllable(playerid,true);
    }

    s_UtilHasTeleport[playerid] = false;
}

stock bool:Util_IsTeleportShell(playerid,STREAMER_TAG_OBJECT:objectid)
{
    if (!IsValidDynamicObject(objectid) || s_UtilInteriorShells == Map:0 || !map_has_key(s_UtilInteriorShells,_:objectid))
    {
        return false;
    }

    return (Streamer_IsInArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_WORLD_ID,s_UtilTeleportWorld[playerid]) || Streamer_IsInArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_WORLD_ID,-1)) && (Streamer_IsInArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_INTERIOR_ID,s_UtilTeleportInterior[playerid]) || Streamer_IsInArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_INTERIOR_ID,-1));
}

stock bool:Util_InteriorShellStreamed(playerid,STREAMER_TAG_OBJECT:objectid)
{
    if (!Util_IsValidPlayer(playerid) || !s_UtilInteriorPending[playerid] || !Util_IsTeleportShell(playerid,objectid))
    {
        return false;
    }

    if (s_UtilInteriorShellPending[playerid])
    {
        return true;
    }

    new remaining = UTIL_INTERIOR_FALLBACK_MS - (GetTickCount() - s_UtilInteriorStarted[playerid]);

    if (remaining <= 0)
    {
        Util_CompleteInteriorPreload(playerid);
        return true;
    }

    new delay = remaining < UTIL_INTERIOR_PRELOAD_MS ? remaining : UTIL_INTERIOR_PRELOAD_MS;
    s_UtilInteriorShellPending[playerid] = true;
    Streamer_UpdateEx(playerid,s_UtilTeleportPos[playerid][0],s_UtilTeleportPos[playerid][1],s_UtilTeleportPos[playerid][2],s_UtilTeleportWorld[playerid],s_UtilTeleportInterior[playerid],-1,delay,1);

    if (s_UtilInteriorTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorTimer[playerid]);
    }

    s_UtilInteriorTimer[playerid] = SetTimerEx("Util_InteriorShellReady",delay,false,"d",playerid);
    return true;
}

stock Util_RefreshTeleport(playerid,Float:x,Float:y,Float:z,worldid = -1,interiorid = -1,compensatedtime = -1)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return;
    }

    s_UtilHasTeleport[playerid] = true;
    s_UtilTeleportPos[playerid][0] = x;
    s_UtilTeleportPos[playerid][1] = y;
    s_UtilTeleportPos[playerid][2] = z;
    s_UtilTeleportExplicit[playerid] = worldid != -1 || interiorid != -1;
    s_UtilTeleportWorld[playerid] = worldid == -1 ? GetPlayerVirtualWorld(playerid) : worldid;
    s_UtilTeleportInterior[playerid] = interiorid == -1 ? GetPlayerInterior(playerid) : interiorid;

    if (compensatedtime == -1 && s_UtilTeleportInterior[playerid] != 0)
    {
        compensatedtime = UTIL_INTERIOR_PRELOAD_MS;
    }

    if (s_UtilInteriorTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorTimer[playerid]);
        s_UtilInteriorTimer[playerid] = 0;
    }

    if (s_UtilInteriorFallbackTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorFallbackTimer[playerid]);
        s_UtilInteriorFallbackTimer[playerid] = 0;
    }

    s_UtilInteriorPending[playerid] = compensatedtime >= 0;
    s_UtilInteriorShellPending[playerid] = false;
    s_UtilInteriorStarted[playerid] = GetTickCount();

    if (s_UtilInteriorPending[playerid])
    {
        s_UtilInteriorFallbackTimer[playerid] = SetTimerEx("Util_InteriorFallback",UTIL_INTERIOR_FALLBACK_MS,false,"d",playerid);
        s_UtilInteriorTimer[playerid] = SetTimerEx("Util_InteriorPreloadDone",compensatedtime < UTIL_INTERIOR_FALLBACK_MS ? compensatedtime : UTIL_INTERIOR_FALLBACK_MS,false,"d",playerid);
        compensatedtime = UTIL_INTERIOR_FALLBACK_MS;
    }

    Streamer_UpdateEx(playerid,x,y,z,s_UtilTeleportWorld[playerid],s_UtilTeleportInterior[playerid],-1,compensatedtime,1);

    if (s_UtilTeleportTimer[playerid] != 0)
    {
        KillTimer(s_UtilTeleportTimer[playerid]);
    }

    s_UtilTeleportTimer[playerid] = SetTimerEx("Util_TeleportRefreshDeferred",0,false,"d",playerid);
}

static bool:Util_IsLocalMove(playerid,Float:x,Float:y,Float:z)
{
    return Util_IsValidPlayer(playerid) && s_UtilHasTeleport[playerid] && !s_UtilInteriorPending[playerid] && GetPlayerInterior(playerid) != 0
        && GetPlayerVirtualWorld(playerid) == s_UtilTeleportWorld[playerid] && GetPlayerInterior(playerid) == s_UtilTeleportInterior[playerid]
        && IsPlayerInRangeOfPoint(playerid,UTIL_LOCAL_MOVE_RANGE,x,y,z);
}

stock bool:Util_SetPlayerPos(playerid,Float:x,Float:y,Float:z)
{
    new bool:isLocal = Util_IsLocalMove(playerid,x,y,z);
    new bool:result = SetPlayerPos(playerid,x,y,z);

    if (!result)
    {
        return false;
    }

    if (isLocal)
    {
        s_UtilTeleportPos[playerid][0] = x;
        s_UtilTeleportPos[playerid][1] = y;
        s_UtilTeleportPos[playerid][2] = z;
        s_UtilTeleportExplicit[playerid] = false;
        Streamer_UpdateEx(playerid,x,y,z,s_UtilTeleportWorld[playerid],s_UtilTeleportInterior[playerid]);

        if (s_UtilTeleportTimer[playerid] != 0)
        {
            KillTimer(s_UtilTeleportTimer[playerid]);
        }

        s_UtilTeleportTimer[playerid] = SetTimerEx("Util_TeleportRefreshDeferred",0,false,"d",playerid);
        return true;
    }

    Util_RefreshTeleport(playerid,x,y,z);
    return true;
}

#define SetPlayerPos Util_SetPlayerPos

forward Util_TeleportRefreshDeferred(playerid);

public Util_TeleportRefreshDeferred(playerid)
{
    s_UtilTeleportTimer[playerid] = 0;

    if (Util_IsValidPlayer(playerid))
    {
        if (!s_UtilTeleportExplicit[playerid] && (s_UtilTeleportWorld[playerid] != GetPlayerVirtualWorld(playerid) || s_UtilTeleportInterior[playerid] != GetPlayerInterior(playerid)))
        {
            Util_RefreshTeleport(playerid,s_UtilTeleportPos[playerid][0],s_UtilTeleportPos[playerid][1],s_UtilTeleportPos[playerid][2],GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));
            return 1;
        }

        Streamer_UpdateEx(playerid,s_UtilTeleportPos[playerid][0],s_UtilTeleportPos[playerid][1],s_UtilTeleportPos[playerid][2],s_UtilTeleportWorld[playerid],s_UtilTeleportInterior[playerid]);
    }

    return 1;
}

forward Util_OnInteriorReady(playerid);

public Util_OnInteriorReady(playerid)
{
    return 1;
}

stock Util_CompleteInteriorPreload(playerid)
{
    if (!Util_IsValidPlayer(playerid) || !s_UtilInteriorPending[playerid])
    {
        return;
    }

    if (s_UtilInteriorTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorTimer[playerid]);
        s_UtilInteriorTimer[playerid] = 0;
    }

    if (s_UtilInteriorFallbackTimer[playerid] != 0)
    {
        KillTimer(s_UtilInteriorFallbackTimer[playerid]);
        s_UtilInteriorFallbackTimer[playerid] = 0;
    }

    s_UtilInteriorPending[playerid] = false;
    s_UtilInteriorShellPending[playerid] = false;

    if (GetPlayerVirtualWorld(playerid) == s_UtilTeleportWorld[playerid] && GetPlayerInterior(playerid) == s_UtilTeleportInterior[playerid])
    {
        Streamer_UpdateEx(playerid,s_UtilTeleportPos[playerid][0],s_UtilTeleportPos[playerid][1],s_UtilTeleportPos[playerid][2],s_UtilTeleportWorld[playerid],s_UtilTeleportInterior[playerid],-1,0,0);
        pawn_call_public("Util_OnInteriorReady","d",playerid);
    }

    TogglePlayerControllable(playerid,true);
}

forward Util_InteriorFallback(playerid);

public Util_InteriorFallback(playerid)
{
    s_UtilInteriorFallbackTimer[playerid] = 0;
    Util_CompleteInteriorPreload(playerid);
    return 1;
}

forward Util_InteriorShellReady(playerid);

public Util_InteriorShellReady(playerid)
{
    s_UtilInteriorTimer[playerid] = 0;
    Util_CompleteInteriorPreload(playerid);
    return 1;
}

forward Util_InteriorPreloadDone(playerid);

public Util_InteriorPreloadDone(playerid)
{
    s_UtilInteriorTimer[playerid] = 0;

    if (!Util_IsValidPlayer(playerid) || !s_UtilInteriorPending[playerid])
    {
        return 1;
    }

    if (s_UtilInteriorShells != Map:0)
    {
        for_map (i : s_UtilInteriorShells)
        {
            new STREAMER_TAG_OBJECT:objectid = STREAMER_TAG_OBJECT:iter_get_key(i);

            if (Util_IsTeleportShell(playerid,objectid) && Streamer_IsItemVisible(playerid,STREAMER_TYPE_OBJECT,objectid))
            {
                Util_CompleteInteriorPreload(playerid);
                return 1;
            }
        }
    }

    if (s_UtilTeleportInterior[playerid] == 0)
    {
        Util_CompleteInteriorPreload(playerid);
    }

    return 1;
}

#include <pp-hooks>

hook Streamer_OnItemStreamIn(type,STREAMER_ALL_TAGS:id,forplayerid)
{
    if (type == STREAMER_TYPE_OBJECT)
    {
        Util_InteriorShellStreamed(forplayerid,STREAMER_TAG_OBJECT:id);
    }
}

hook ResetPlayerVariables(playerid)
{
    Util_CancelTeleport(playerid);
}

hook OnGameModeExit()
{
    if (s_UtilInteriorShells != Map:0)
    {
        map_delete(s_UtilInteriorShells);
        s_UtilInteriorShells = Map:0;
    }
}
