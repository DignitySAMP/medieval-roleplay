#define FALL_SAMPLES_TO_RESCUE (2)
#define FALL_SAMPLES_VOID (3)
#define FALL_FAST_MS (250)
#define FALL_VOID_REACH (80.0)
#define FALL_UNDER_MARGIN (2.0)
#define FALL_FLOOR_Z (-30.0)
#define FALL_SURFACE_LIFT (0.5)
#define FALL_SEA_LEVEL (2.0)
#define FALL_RAY_TOP (1000.0)
#define FALL_INTERIOR_DROP (6.0)
#define FALL_INTERIOR_AIR_DROP (4.0)
#define FALL_INTERIOR_FREEFALL (2.5)
#define FALL_INTERIOR_AIR_MS (750)
#define FALL_INTERIOR_RADIUS (80.0)
#define FALL_INTERIOR_SKY_Z (1000.0)
#define FALL_STUCK_COOLDOWN (120)
#define FALL_LANDED_REACH (3.0)

new g_FallTicks[MAX_PLAYERS char];
new g_FallFast[MAX_PLAYERS];
new g_FallAirSince[MAX_PLAYERS];
new bool:g_FallHasSafe[MAX_PLAYERS];
new Float:g_FallSafe[MAX_PLAYERS][4];
new Float:g_FallFloorZ[MAX_PLAYERS];
new g_FallSafeWorld[MAX_PLAYERS];
new g_FallSafeInterior[MAX_PLAYERS];
new bool:g_FallInside[MAX_PLAYERS];
new bool:g_FallReanchor[MAX_PLAYERS];
new g_FallStuckUntil[MAX_PLAYERS];

static Fall_StopFast(playerid)
{
	if (g_FallFast[playerid] != 0)
	{
		KillTimer(g_FallFast[playerid]);
		g_FallFast[playerid] = 0;
	}
}

static Fall_WatchClosely(playerid)
{
	if (g_FallFast[playerid] == 0)
	{
		g_FallFast[playerid] = SetTimerEx("Fall_FastSample",FALL_FAST_MS,true,"d",playerid);
	}
}

static Fall_Reset(playerid)
{
	Fall_StopFast(playerid);
	g_FallTicks{playerid} = 0;
	g_FallAirSince[playerid] = 0;
	g_FallHasSafe[playerid] = false;
	g_FallInside[playerid] = false;
	g_FallReanchor[playerid] = false;
	g_FallStuckUntil[playerid] = 0;
}

static bool:Fall_IsWatched(playerid)
{
	return Session_IsPlaying(playerid) || Session_IsSpawning(playerid);
}

static bool:Fall_Survey(Float:x,Float:y,Float:z,&Float:lowest,&bool:groundBelow)
{
	new Float:hitX[MAX_MULTICAST_SIZE], Float:hitY[MAX_MULTICAST_SIZE], Float:hitZ[MAX_MULTICAST_SIZE], Float:hitDist[MAX_MULTICAST_SIZE], hitModel[MAX_MULTICAST_SIZE];
	new hits = CA_RayCastMultiLine(x,y,FALL_RAY_TOP,x,y,FALL_FLOOR_Z,hitX,hitY,hitZ,hitDist,hitModel);
	new bool:isOverMap = false;

	lowest = FALL_RAY_TOP;
	groundBelow = hits < 0 || z > FALL_RAY_TOP || Map_GetCollisionObjectCount() == 0;

	for (new i = 0;i < hits;i++)
	{
		if (hitZ[i] < z && z - hitZ[i] <= FALL_VOID_REACH)
		{
			groundBelow = true;
		}

		if (hitModel[i] == WATER_OBJECT)
		{
			continue;
		}

		isOverMap = true;

		if (hitZ[i] < lowest)
		{
			lowest = hitZ[i];
		}
	}

	return isOverMap;
}

static bool:Fall_IsUnderMap(Float:x,Float:y,Float:z)
{
	if (z < FALL_FLOOR_Z)
	{
		return true;
	}

	new Float:lowest, bool:groundBelow;
	return Fall_Survey(x,y,z,lowest,groundBelow) && z < lowest - FALL_UNDER_MARGIN;
}

static bool:Fall_IsOverMap(Float:x,Float:y)
{
	new Float:lowest, bool:groundBelow;
	return Fall_Survey(x,y,FALL_RAY_TOP,lowest,groundBelow);
}

static Fall_LostSamples(playerid,Float:x,Float:y,Float:z)
{
	if (z < FALL_FLOOR_Z)
	{
		return FALL_SAMPLES_TO_RESCUE;
	}

	if (GetPlayerInterior(playerid) != 0)
	{
		return 0;
	}

	new Float:lowest, bool:groundBelow;

	if (Fall_Survey(x,y,z,lowest,groundBelow) && z < lowest - FALL_UNDER_MARGIN)
	{
		return FALL_SAMPLES_TO_RESCUE;
	}

	return groundBelow ? 0 : FALL_SAMPLES_VOID;
}

stock bool:Fall_IsCarried(playerid)
{
	return Mount_IsRiding(playerid) || Carts_GetSeat(playerid) != -1;
}

static bool:Fall_IsGrounded(playerid)
{
	switch (Movement_GetState(playerid))
	{
		case MOVE_STATE_IDLE, MOVE_STATE_WALKING, MOVE_STATE_RUNNING, MOVE_STATE_SPRINTING, MOVE_STATE_CROUCHING, MOVE_STATE_STOPPING:
		{
			return true;
		}
	}

	return false;
}

static bool:Fall_HasGroundUnder(Float:x,Float:y,Float:z)
{
	new Float:hitX, Float:hitY, Float:hitZ;
	return CA_RayCastLine(x,y,z,x,y,z - FALL_LANDED_REACH,hitX,hitY,hitZ) != 0;
}

static bool:Fall_SafeIsHere(playerid)
{
	return g_FallHasSafe[playerid] && g_FallSafeWorld[playerid] == GetPlayerVirtualWorld(playerid) && g_FallSafeInterior[playerid] == GetPlayerInterior(playerid);
}

stock Fall_SetSafe(playerid,Float:x,Float:y,Float:z,Float:a)
{
	g_FallFloorZ[playerid] = Fall_SafeIsHere(playerid) && z >= FALL_INTERIOR_SKY_Z && g_FallFloorZ[playerid] < z ? g_FallFloorZ[playerid] : z;
	g_FallHasSafe[playerid] = true;
	g_FallSafe[playerid][0] = x;
	g_FallSafe[playerid][1] = y;
	g_FallSafe[playerid][2] = z;
	g_FallSafe[playerid][3] = a;
	g_FallSafeWorld[playerid] = GetPlayerVirtualWorld(playerid);
	g_FallSafeInterior[playerid] = GetPlayerInterior(playerid);
}

stock Fall_ForgetSafe(playerid)
{
	g_FallHasSafe[playerid] = false;
}

stock Fall_GetRecoverySpot(playerid,&Float:x,&Float:y,&Float:z,&Float:a,&interior,&world)
{
	if (Fall_SafeIsHere(playerid))
	{
		x = g_FallSafe[playerid][0];
		y = g_FallSafe[playerid][1];
		z = g_FallSafe[playerid][2];
		a = g_FallSafe[playerid][3];
		interior = GetPlayerInterior(playerid);
		world = GetPlayerVirtualWorld(playerid);
		return;
	}

	Character_GetSpawn(playerid,x,y,z,a,interior,world);

	if (z < FALL_FLOOR_Z || (interior != 0 && z < FALL_INTERIOR_SKY_Z))
	{
		x = MAP_SPAWN_X;
		y = MAP_SPAWN_Y;
		z = MAP_SPAWN_Z;
		a = MAP_SPAWN_A;
		interior = 0;
		world = 0;
	}
}

static Fall_Recover(playerid,const message[])
{
	new Float:x, Float:y, Float:z, Float:a, interior, world;
	Fall_GetRecoverySpot(playerid,x,y,z,a,interior,world);
	Util_SafeTeleport(playerid,x,y,z + FALL_SURFACE_LIFT,a,world,interior);
	Gui_Notify(playerid,message);
	Log_Info("falling","player %d recovered to %.1f, %.1f, %.1f",playerid,x,y,z);
}

static Fall_ReturnToSafe(playerid)
{
	Fall_Recover(playerid,"The ground gave way under you. You are back where you last stood.");
}

stock Fall_StuckWait(playerid)
{
	return Util_IsValidPlayer(playerid) ? max(g_FallStuckUntil[playerid] - gettime(),0) : 0;
}

stock bool:Fall_IsOutOfInterior(Float:x,Float:y,Float:z,Float:anchorX,Float:anchorY,Float:anchorZ,Float:drop = FALL_INTERIOR_DROP)
{
	return anchorZ >= FALL_INTERIOR_SKY_Z && (z < anchorZ - drop || VectorSize(x - anchorX,y - anchorY,0.0) > FALL_INTERIOR_RADIUS);
}

static bool:Fall_LeftInterior(playerid,Float:x,Float:y,Float:z,bool:airborne)
{
	if (Fall_IsOutOfInterior(x,y,z,g_FallSafe[playerid][0],g_FallSafe[playerid][1],g_FallFloorZ[playerid],airborne ? FALL_INTERIOR_AIR_DROP : FALL_INTERIOR_DROP))
	{
		return true;
	}

	return airborne && g_FallSafe[playerid][2] >= FALL_INTERIOR_SKY_Z && GetTickCount() - g_FallAirSince[playerid] >= FALL_INTERIOR_AIR_MS && z < g_FallSafe[playerid][2] - FALL_INTERIOR_FREEFALL;
}

forward bool:Gaol_IsHeld(playerid);
forward bool:Staff_IsJailed(playerid);

stock bool:Fall_CatchInterior(playerid)
{
	if (!Session_IsPlaying(playerid) || GetPlayerInterior(playerid) == 0 || Gaol_IsHeld(playerid) || Staff_IsJailed(playerid))
	{
		g_FallInside[playerid] = false;
		g_FallAirSince[playerid] = 0;
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	if (!Util_IsInteriorReady(playerid))
	{
		return false;
	}

	if (!Fall_SafeIsHere(playerid))
	{
		g_FallInside[playerid] = false;
		return false;
	}

	new bool:airborne = Movement_GetState(playerid) == MOVE_STATE_FALLING;

	if (!airborne)
	{
		g_FallAirSince[playerid] = 0;
	}
	else if (g_FallAirSince[playerid] == 0)
	{
		g_FallAirSince[playerid] = max(GetTickCount(),1);
	}

	if (!g_FallInside[playerid] || !Fall_LeftInterior(playerid,x,y,z,airborne))
	{
		g_FallInside[playerid] = z >= FALL_INTERIOR_SKY_Z;
		return false;
	}

	g_FallTicks{playerid} = 0;
	g_FallAirSince[playerid] = 0;
	g_FallInside[playerid] = false;
	Util_SafeTeleport(playerid,g_FallSafe[playerid][0],g_FallSafe[playerid][1],g_FallSafe[playerid][2] + FALL_SURFACE_LIFT,g_FallSafe[playerid][3],GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));
	Gui_Notify(playerid,"The floor gave way under you. You are back where you last stood inside.");
	Log_Info("falling","player %d left the interior at %.1f, %.1f, %.1f, returned to %.1f, %.1f, %.1f",playerid,x,y,z,g_FallSafe[playerid][0],g_FallSafe[playerid][1],g_FallSafe[playerid][2]);
	return true;
}

static bool:Fall_Check(playerid)
{
	if (!Fall_IsWatched(playerid))
	{
		Fall_Reset(playerid);
		return false;
	}

	if (Fly_IsActive(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		g_FallTicks{playerid} = 0;
		return false;
	}

	if (Fall_CatchInterior(playerid))
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	new moveState = Movement_GetState(playerid), bool:falling = moveState == MOVE_STATE_FALLING;

	if ((moveState == MOVE_STATE_SWIMMING || moveState == MOVE_STATE_DIVING) && Fall_IsOverMap(x,y) && z < FALL_SEA_LEVEL)
	{
		g_FallTicks{playerid} = 0;
		Fall_ReturnToSafe(playerid);
		return false;
	}

	if (!falling && z >= FALL_FLOOR_Z)
	{
		g_FallTicks{playerid} = 0;

		if (g_FallReanchor[playerid] && GetPlayerInterior(playerid) != 0)
		{
			g_FallReanchor[playerid] = false;
		}

		if (Session_IsPlaying(playerid) && (Fall_IsGrounded(playerid) || (g_FallReanchor[playerid] && Fall_HasGroundUnder(x,y,z))) && !Fall_IsUnderMap(x,y,z))
		{
			new Float:a;
			GetPlayerFacingAngle(playerid,a);
			g_FallReanchor[playerid] = false;
			Fall_SetSafe(playerid,x,y,z,a);
		}

		return false;
	}

	if (z >= FALL_FLOOR_Z && Fall_IsCarried(playerid))
	{
		g_FallTicks{playerid} = 0;
		return false;
	}

	new needed = Fall_LostSamples(playerid,x,y,z);

	if (needed == 0)
	{
		g_FallTicks{playerid} = 0;
		return true;
	}

	g_FallTicks{playerid}++;

	if (g_FallTicks{playerid} < needed)
	{
		return true;
	}

	g_FallTicks{playerid} = 0;
	Fall_ReturnToSafe(playerid);
	return false;
}

static Fall_Tick(playerid)
{
	if (Fall_Check(playerid))
	{
		Fall_WatchClosely(playerid);
	}
	else
	{
		Fall_StopFast(playerid);
	}
}

forward Fall_FastSample(playerid);

public Fall_FastSample(playerid)
{
	if (!IsPlayerConnected(playerid) || !Fall_Check(playerid))
	{
		Fall_StopFast(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Fall_Reset(playerid);
}

hook OnPlayerDisconnect(playerid,reason)
{
	Fall_StopFast(playerid);
}

hook Util_OnInteriorReady(playerid)
{
	new Float:x, Float:y, Float:z, world, interior;

	if (Fall_IsWatched(playerid) && !Fall_SafeIsHere(playerid) && Util_GetTeleportDestination(playerid,x,y,z,world,interior) && interior != 0 && z >= FALL_INTERIOR_SKY_Z && world == GetPlayerVirtualWorld(playerid) && interior == GetPlayerInterior(playerid))
	{
		new Float:a;
		GetPlayerFacingAngle(playerid,a);
		Fall_ForgetSafe(playerid);
		Fall_SetSafe(playerid,x,y,z,a);
		g_FallInside[playerid] = true;
	}
}

hook Util_OnTeleporting(playerid,bool:keepMounted)
{
	#pragma unused keepMounted

	g_FallReanchor[playerid] = true;
}

hook Tick_OnPlayerSecond(playerid)
{
	Fall_Tick(playerid);
}

CMD<ADMIN_LEVEL_NONE>:stuck(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	if (!Fall_IsWatched(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,"You can use /stuck once your character is in the world.");
		return 1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	if (Fall_IsUnderMap(x,y,z))
	{
		g_FallTicks{playerid} = 0;
		Fall_Recover(playerid,"You are back on solid ground, where you last stood.");
		return 1;
	}

	if (Law_IsBound(playerid) || Law_IsServing(playerid) || Combat_IsInMode(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,"You can't use /stuck while you are bound, serving a sentence or in a fight. If you are falling under the map, it works at once.");
		return 1;
	}

	new wait = Fall_StuckWait(playerid);

	if (wait > 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("You can use /stuck again in %d seconds.",wait));
		return 1;
	}

	g_FallStuckUntil[playerid] = gettime() + FALL_STUCK_COOLDOWN;
	Fall_Recover(playerid,"You are back where you last stood on open ground.");
	return 1;
}
