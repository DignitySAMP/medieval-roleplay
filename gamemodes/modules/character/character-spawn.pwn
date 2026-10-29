#define CHARACTER_RESPAWN_MS (5000)
#define CHARACTER_SPAWN_FADE_FROM (0x000000FF)
#define CHARACTER_SPAWN_FADE_MS (3500)
#define CHARACTER_SPAWN_FADE_STEPS (35)
#define CHARACTER_GET_UP_DELAY_MS (300)
#define CHARACTER_LANDING_PRELOAD_MS (2000)
#define CHARACTER_LANDING_CHECK_MS (400)
#define CHARACTER_LANDING_CHECKS (3)
#define CHARACTER_LANDING_SLACK (3.0)
#define CHARACTER_LANDING_EXPIRY_MS (5000)
#define CHARACTER_INTERIOR_MIN_Z (1000.0)

static bool:s_SpawnOverride[MAX_PLAYERS];
static Float:s_SpawnOverridePos[MAX_PLAYERS][4];
static s_SpawnOverridePlace[MAX_PLAYERS][2];
static bool:s_Landing[MAX_PLAYERS];
static Float:s_LandingPos[MAX_PLAYERS][4];
static s_LandingTick[MAX_PLAYERS];
static Float:s_InteriorSpawnPos[MAX_PLAYERS][3];

stock Character_SetNextSpawn(playerid,Float:x,Float:y,Float:z,Float:a,interior,world)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_SpawnOverride[playerid] = true;
	s_SpawnOverridePos[playerid][0] = x;
	s_SpawnOverridePos[playerid][1] = y;
	s_SpawnOverridePos[playerid][2] = z;
	s_SpawnOverridePos[playerid][3] = a;
	s_SpawnOverridePlace[playerid][0] = interior;
	s_SpawnOverridePlace[playerid][1] = world;
}

stock bool:Character_HasNextSpawn(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SpawnOverride[playerid];
}

Character_Spawn(playerid)
{
	new Float:x, Float:y, Float:z, Float:a, interior, world;
	s_SpawnOverride[playerid] = false;
	pawn_call_public("Character_OnSpawning","d",playerid);

	if (s_Landing[playerid] && GetTickCount() - s_LandingTick[playerid] > CHARACTER_LANDING_EXPIRY_MS)
	{
		s_Landing[playerid] = false;
	}

	if (s_Landing[playerid])
	{
		s_SpawnOverride[playerid] = false;
		x = s_LandingPos[playerid][0];
		y = s_LandingPos[playerid][1];
		z = s_LandingPos[playerid][2];
		a = s_LandingPos[playerid][3];
		interior = GetPlayerInterior(playerid);
		world = GetPlayerVirtualWorld(playerid);
	}
	else if (s_SpawnOverride[playerid])
	{
		s_SpawnOverride[playerid] = false;
		x = s_SpawnOverridePos[playerid][0];
		y = s_SpawnOverridePos[playerid][1];
		z = s_SpawnOverridePos[playerid][2];
		a = s_SpawnOverridePos[playerid][3];
		interior = s_SpawnOverridePlace[playerid][0];
		world = s_SpawnOverridePlace[playerid][1];
	}
	else
	{
		Character_GetSpawn(playerid,x,y,z,a,interior,world);
	}

	if (interior != 0 && z < CHARACTER_INTERIOR_MIN_Z)
	{
		interior = 0;
		world = 0;
	}

	s_InteriorSpawnPos[playerid][0] = x;
	s_InteriorSpawnPos[playerid][1] = y;
	s_InteriorSpawnPos[playerid][2] = z;
	Session_SetState(playerid,SESSION_SPAWNING);
	SetSpawnInfo(playerid,NO_TEAM,Character_GetSkin(playerid),x,y,z,a,WEAPON:0,0,WEAPON:0,0,WEAPON:0,0);
	SetPlayerInterior(playerid,interior);
	SetPlayerVirtualWorld(playerid,world);

	if (Scene_Leave(playerid))
	{
		TogglePlayerSpectating(playerid,false);
		return;
	}

	SpawnPlayer(playerid);
}

stock Character_RespawnAt(playerid,Float:x,Float:y,Float:z,Float:angle)
{
	s_Landing[playerid] = true;
	s_LandingTick[playerid] = GetTickCount();
	s_LandingPos[playerid][0] = x;
	s_LandingPos[playerid][1] = y;
	s_LandingPos[playerid][2] = z;
	s_LandingPos[playerid][3] = angle;
	s_InteriorSpawnPos[playerid][0] = x;
	s_InteriorSpawnPos[playerid][1] = y;
	s_InteriorSpawnPos[playerid][2] = z;
	Session_SetState(playerid,SESSION_SPAWNING);
	SetSpawnInfo(playerid,NO_TEAM,Character_GetSkin(playerid),x,y,z,angle,WEAPON:0,0,WEAPON:0,0,WEAPON:0,0);
}

public OnPlayerRequestClass(playerid,classid)
{
	#pragma unused classid

	if (IsPlayerNPC(playerid))
	{
		return 1;
	}

	if (Session_HasCharacter(playerid))
	{
		Character_Spawn(playerid);
		return 0;
	}

	Scene_OnClientReady(playerid);
	return 0;
}

public OnPlayerRequestSpawn(playerid)
{
	if (IsPlayerNPC(playerid))
	{
		return 1;
	}

	return 0;
}

forward Character_OnSpawning(playerid);

public Character_OnSpawning(playerid)
{
	return 1;
}

forward Character_GetUpDeferred(playerid,token);

public Character_GetUpDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_IsPlaying(playerid) && !Fly_IsActive(playerid))
	{
		ApplyAnimation(playerid,"SUNBATHE","ParkSit_M_out",4.1,false,false,false,false,0,SYNC_ALL);
	}

	return 1;
}

forward Character_LandingCheck(playerid,token,checksLeft);

public Character_LandingCheck(playerid,token,checksLeft)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Session_IsPlaying(playerid))
	{
		return 1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	if (VectorSize(x - s_LandingPos[playerid][0],y - s_LandingPos[playerid][1],0.0) > CHARACTER_LANDING_SLACK)
	{
		SetPlayerPos(playerid,s_LandingPos[playerid][0],s_LandingPos[playerid][1],s_LandingPos[playerid][2]);
		SetPlayerFacingAngle(playerid,s_LandingPos[playerid][3]);
	}

	if (checksLeft > 1)
	{
		SetTimerEx("Character_LandingCheck",CHARACTER_LANDING_CHECK_MS,false,"ddd",playerid,token,checksLeft - 1);
	}

	return 1;
}

forward Character_Respawn(playerid,token);

public Character_Respawn(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Session_GetState(playerid) != SESSION_DEAD)
	{
		return 1;
	}

	Character_Spawn(playerid);
	return 1;
}

#include <pp-hooks>

hook OnPlayerSpawn(playerid)
{
	if (IsPlayerNPC(playerid))
	{
		return;
	}

	if (Session_GetState(playerid) != SESSION_SPAWNING)
	{
		Scene_OnSpawn(playerid);
		return;
	}

	TogglePlayerControllable(playerid,true);

	if (s_Landing[playerid] && GetTickCount() - s_LandingTick[playerid] > CHARACTER_LANDING_EXPIRY_MS)
	{
		s_Landing[playerid] = false;
	}

	if (s_Landing[playerid])
	{
		s_Landing[playerid] = false;
		Streamer_UpdateEx(playerid,s_LandingPos[playerid][0],s_LandingPos[playerid][1],s_LandingPos[playerid][2],GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid),STREAMER_TYPE_OBJECT,CHARACTER_LANDING_PRELOAD_MS,1);
		SetPlayerFacingAngle(playerid,s_LandingPos[playerid][3]);
		SetTimerEx("Character_LandingCheck",CHARACTER_LANDING_CHECK_MS,false,"ddd",playerid,Account_GetToken(playerid),CHARACTER_LANDING_CHECKS);
	}

	if (GetPlayerInterior(playerid) != 0)
	{
		Util_RefreshTeleport(playerid,s_InteriorSpawnPos[playerid][0],s_InteriorSpawnPos[playerid][1],s_InteriorSpawnPos[playerid][2],GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid),1500);
	}

	SetCameraBehindPlayer(playerid);
	SetPlayerSkin(playerid,Character_GetSkin(playerid));
	Session_SetState(playerid,SESSION_PLAYING);

	ScreenFade_Set(playerid,CHARACTER_SPAWN_FADE_FROM);
	ScreenFade_Start(playerid,SCREENFADE_CLEAR,CHARACTER_SPAWN_FADE_MS,CHARACTER_SPAWN_FADE_STEPS);
	SetTimerEx("Character_GetUpDeferred",CHARACTER_GET_UP_DELAY_MS,false,"dd",playerid,Account_GetToken(playerid));

	new name[CHARACTER_NAME_MAX * 2 + 2];
	Character_GetName(playerid,name);
	Gui_Notify(playerid,sprintf("You step into the realm as %s.",name));
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_Landing[playerid] = false;
	s_SpawnOverride[playerid] = false;
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid, reason

	if (IsPlayerNPC(playerid) || !Session_HasCharacter(playerid))
	{
		return;
	}

	Session_SetState(playerid,SESSION_DEAD);
	Character_RequestSave(playerid);
	SetTimerEx("Character_Respawn",CHARACTER_RESPAWN_MS,false,"dd",playerid,Account_GetToken(playerid));
}
