#define SCENE_WORLD_BASE (100000)
#define SCENE_NIGHT_HOUR (23)
#define SCENE_WEATHER (5)
#define SCENE_CONNECT_DELAY_MS (150)
#define SCENE_CLIENT_READY_DELAY_MS (300)
#define SCENE_REAPPLY_STEPS (4)

#define SCENE_LOGIN_CAM_X (985.0)
#define SCENE_LOGIN_CAM_Y (-3575.0)
#define SCENE_LOGIN_CAM_Z (125.0)
#define SCENE_LOGIN_LOOK_X (1005.0)
#define SCENE_LOGIN_LOOK_Y (-3470.0)
#define SCENE_LOGIN_LOOK_Z (85.0)

#define SCENE_CREATOR_X (957.3705)
#define SCENE_CREATOR_Y (-2848.5869)
#define SCENE_CREATOR_Z (100.1858)
#define SCENE_CREATOR_A (347.6559)
#define SCENE_CREATOR_EYE (1.5)
#define SCENE_CREATOR_REACH (80.0)
#define SCENE_CREATOR_DIP (10.0)
#define SCENE_CREATOR_PED_LIFT (6.0)
#define SCENE_LOOK_DISTANCE (3.0)
#define SCENE_LOOK_CAM_LIFT (0.4)
#define SCENE_LOOK_AIM_LIFT (0.2)

enum E_SCENE
{
	SCENE_NONE,
	SCENE_LOGIN,
	SCENE_CREATOR,
	SCENE_LOOK,
}

static const s_SceneReapplyMs[SCENE_REAPPLY_STEPS] = {150, 500, 1000, 2000};

static E_SCENE:s_Scene[MAX_PLAYERS];
static bool:s_SceneSpectating[MAX_PLAYERS];
static s_SceneToken[MAX_PLAYERS];

stock bool:Scene_IsActive(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Scene[playerid] != SCENE_NONE;
}

stock bool:Scene_IsSpectating(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SceneSpectating[playerid];
}

static Scene_GetCreatorFacing(&Float:dx,&Float:dy)
{
	dx = -floatsin(SCENE_CREATOR_A,degrees);
	dy = floatcos(SCENE_CREATOR_A,degrees);
}

static Scene_ApplyNight(playerid)
{
	SetPlayerTime(playerid,SCENE_NIGHT_HOUR,0);
	SetPlayerWeather(playerid,SCENE_WEATHER);
}

static Scene_ApplyCamera(playerid)
{
	new Float:dx, Float:dy;
	Scene_GetCreatorFacing(dx,dy);

	switch (s_Scene[playerid])
	{
		case SCENE_LOGIN:
		{
			Streamer_UpdateEx(playerid,SCENE_LOGIN_LOOK_X,SCENE_LOGIN_LOOK_Y,SCENE_LOGIN_LOOK_Z,SCENE_WORLD_BASE + playerid);
			SetPlayerCameraPos(playerid,SCENE_LOGIN_CAM_X,SCENE_LOGIN_CAM_Y,SCENE_LOGIN_CAM_Z);
			SetPlayerCameraLookAt(playerid,SCENE_LOGIN_LOOK_X,SCENE_LOGIN_LOOK_Y,SCENE_LOGIN_LOOK_Z);
		}
		case SCENE_CREATOR:
		{
			TogglePlayerControllable(playerid,false);
			SetPlayerPos(playerid,SCENE_CREATOR_X,SCENE_CREATOR_Y,SCENE_CREATOR_Z + SCENE_CREATOR_PED_LIFT);
			SetPlayerCameraPos(playerid,SCENE_CREATOR_X + dx * SCENE_LOOK_DISTANCE,SCENE_CREATOR_Y + dy * SCENE_LOOK_DISTANCE,SCENE_CREATOR_Z + SCENE_CREATOR_EYE);
			SetPlayerCameraLookAt(playerid,SCENE_CREATOR_X - dx * SCENE_CREATOR_REACH,SCENE_CREATOR_Y - dy * SCENE_CREATOR_REACH,SCENE_CREATOR_Z - SCENE_CREATOR_DIP);
		}
		case SCENE_LOOK:
		{
			TogglePlayerControllable(playerid,false);
			SetPlayerPos(playerid,SCENE_CREATOR_X,SCENE_CREATOR_Y,SCENE_CREATOR_Z);
			SetPlayerFacingAngle(playerid,SCENE_CREATOR_A);
			SetPlayerCameraPos(playerid,SCENE_CREATOR_X + dx * SCENE_LOOK_DISTANCE,SCENE_CREATOR_Y + dy * SCENE_LOOK_DISTANCE,SCENE_CREATOR_Z + SCENE_LOOK_CAM_LIFT);
			SetPlayerCameraLookAt(playerid,SCENE_CREATOR_X,SCENE_CREATOR_Y,SCENE_CREATOR_Z + SCENE_LOOK_AIM_LIFT);
		}
		default: {}
	}
}

static Scene_Apply(playerid)
{
	Scene_ApplyNight(playerid);
	Scene_ApplyCamera(playerid);
	SetTimerEx("Scene_ReapplyDeferred",s_SceneReapplyMs[0],false,"ddd",playerid,++s_SceneToken[playerid],0);
}

stock Scene_ShowLogin(playerid)
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid))
	{
		return;
	}

	s_Scene[playerid] = SCENE_LOGIN;
	SetPlayerVirtualWorld(playerid,SCENE_WORLD_BASE + playerid);
	Kit_ShowLogo(playerid);

	if (!s_SceneSpectating[playerid])
	{
		s_SceneSpectating[playerid] = true;
		TogglePlayerSpectating(playerid,true);
	}

	Scene_Apply(playerid);
}

stock Scene_ShowCreator(playerid,skin)
{
	Kit_HideLogo(playerid);
	s_Scene[playerid] = SCENE_CREATOR;
	SetPlayerVirtualWorld(playerid,SCENE_WORLD_BASE + playerid);

	if (s_SceneSpectating[playerid])
	{
		s_SceneSpectating[playerid] = false;
		SetSpawnInfo(playerid,NO_TEAM,skin,SCENE_CREATOR_X,SCENE_CREATOR_Y,SCENE_CREATOR_Z + SCENE_CREATOR_PED_LIFT,SCENE_CREATOR_A,WEAPON:0,0,WEAPON:0,0,WEAPON:0,0);
		TogglePlayerSpectating(playerid,false);
		return;
	}

	SetPlayerSkin(playerid,skin);
	Scene_Apply(playerid);
}

stock Scene_ShowLook(playerid)
{
	s_Scene[playerid] = SCENE_LOOK;
	Scene_Apply(playerid);
}

stock Scene_OnSpawn(playerid)
{
	if (s_Scene[playerid] == SCENE_LOGIN)
	{
		s_SceneSpectating[playerid] = false;
		Scene_ShowLogin(playerid);
		return;
	}

	if (s_Scene[playerid] != SCENE_NONE)
	{
		Scene_Apply(playerid);
	}
}

stock bool:Scene_Leave(playerid)
{
	new bool:wasSpectating = s_SceneSpectating[playerid];
	Kit_HideLogo(playerid);
	s_Scene[playerid] = SCENE_NONE;
	s_SceneSpectating[playerid] = false;
	s_SceneToken[playerid]++;
	Calendar_ApplyPlayer(playerid);
	return wasSpectating;
}

forward Scene_ReapplyDeferred(playerid,token,step);

public Scene_ReapplyDeferred(playerid,token,step)
{
	if (!IsPlayerConnected(playerid) || s_SceneToken[playerid] != token || s_Scene[playerid] == SCENE_NONE)
	{
		return 1;
	}

	Scene_ApplyNight(playerid);
	Scene_ApplyCamera(playerid);

	if (++step < SCENE_REAPPLY_STEPS)
	{
		SetTimerEx("Scene_ReapplyDeferred",s_SceneReapplyMs[step] - s_SceneReapplyMs[step - 1],false,"ddd",playerid,token,step);
	}

	return 1;
}

stock Scene_OnClientReady(playerid)
{
	SetTimerEx("Scene_ClientReadyDeferred",SCENE_CLIENT_READY_DELAY_MS,false,"d",playerid);
}

stock Scene_OnDownloadsFinished(playerid)
{
	if (Util_IsValidPlayer(playerid) && s_Scene[playerid] != SCENE_NONE)
	{
		Scene_OnClientReady(playerid);
	}
}

forward Scene_ClientReadyDeferred(playerid);

public Scene_ClientReadyDeferred(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 1;
	}

	if (s_Scene[playerid] == SCENE_LOGIN)
	{
		s_SceneSpectating[playerid] = false;
	}
	else if (s_Scene[playerid] != SCENE_NONE)
	{
		Scene_Apply(playerid);
		return 1;
	}

	return Scene_LoginDeferred(playerid);
}

forward Scene_LoginDeferred(playerid);

public Scene_LoginDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && !IsPlayerNPC(playerid) && !Session_HasCharacter(playerid) && s_Scene[playerid] != SCENE_CREATOR && s_Scene[playerid] != SCENE_LOOK)
	{
		Scene_ShowLogin(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Scene[playerid] = SCENE_NONE;
	s_SceneSpectating[playerid] = false;
	s_SceneToken[playerid]++;
}

hook OnPlayerDisconnect(playerid,reason)
{
	s_Scene[playerid] = SCENE_NONE;
	s_SceneSpectating[playerid] = false;
	s_SceneToken[playerid]++;
}
