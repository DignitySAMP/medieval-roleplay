#define FLY_MOVE_SPEED (100.0)
#define FLY_ACCEL_RATE (0.03)
#define FLY_MOVE_INTERVAL_MS (100)
#define FLY_OBJECT_MODEL (19300)
#define FLY_REACH (6000.0)
#define FLY_OBJECT_PRIORITY (10)
#define FLY_LAND_PROBE (500.0)
#define FLY_LAND_HEIGHT (1.0)

enum
{
	FLY_MOVE_NONE,
	FLY_MOVE_FORWARD,
	FLY_MOVE_BACK,
	FLY_MOVE_LEFT,
	FLY_MOVE_RIGHT,
	FLY_MOVE_FORWARD_LEFT,
	FLY_MOVE_FORWARD_RIGHT,
	FLY_MOVE_BACK_LEFT,
	FLY_MOVE_BACK_RIGHT,
}

enum E_FLY
{
	bool:E_FLY_ACTIVE,
	STREAMER_TAG_OBJECT:E_FLY_OBJECT,
	E_FLY_MODE,
	E_FLY_LR_OLD,
	E_FLY_UD_OLD,
	E_FLY_LAST_MOVE,
	Float:E_FLY_ACCEL,
}

static s_Fly[MAX_PLAYERS][E_FLY];

stock bool:Fly_IsActive(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Fly[playerid][E_FLY_ACTIVE];
}

stock STREAMER_TAG_OBJECT:Fly_GetCameraObject(playerid)
{
	return Fly_IsActive(playerid) ? s_Fly[playerid][E_FLY_OBJECT] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Fly_Reset(playerid)
{
	s_Fly[playerid][E_FLY_ACTIVE] = false;
	s_Fly[playerid][E_FLY_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Fly[playerid][E_FLY_MODE] = FLY_MOVE_NONE;
	s_Fly[playerid][E_FLY_LR_OLD] = 0;
	s_Fly[playerid][E_FLY_UD_OLD] = 0;
	s_Fly[playerid][E_FLY_LAST_MOVE] = 0;
	s_Fly[playerid][E_FLY_ACCEL] = 0.0;
}

static Fly_GetDirection(updown,leftright)
{
	if (leftright < 0)
	{
		return updown < 0 ? FLY_MOVE_FORWARD_LEFT : (updown > 0 ? FLY_MOVE_BACK_LEFT : FLY_MOVE_LEFT);
	}

	if (leftright > 0)
	{
		return updown < 0 ? FLY_MOVE_FORWARD_RIGHT : (updown > 0 ? FLY_MOVE_BACK_RIGHT : FLY_MOVE_RIGHT);
	}

	if (updown < 0)
	{
		return FLY_MOVE_FORWARD;
	}

	return updown > 0 ? FLY_MOVE_BACK : FLY_MOVE_NONE;
}

static Fly_GetNextPosition(direction,const Float:camera[3],const Float:front[3],&Float:x,&Float:y,&Float:z)
{
	new Float:ox = front[0] * FLY_REACH, Float:oy = front[1] * FLY_REACH, Float:oz = front[2] * FLY_REACH;

	switch (direction)
	{
		case FLY_MOVE_FORWARD: { x = camera[0] + ox; y = camera[1] + oy; z = camera[2] + oz; }
		case FLY_MOVE_BACK: { x = camera[0] - ox; y = camera[1] - oy; z = camera[2] - oz; }
		case FLY_MOVE_LEFT: { x = camera[0] - oy; y = camera[1] + ox; z = camera[2]; }
		case FLY_MOVE_RIGHT: { x = camera[0] + oy; y = camera[1] - ox; z = camera[2]; }
		case FLY_MOVE_BACK_LEFT: { x = camera[0] + (-ox - oy); y = camera[1] + (-oy + ox); z = camera[2] - oz; }
		case FLY_MOVE_BACK_RIGHT: { x = camera[0] + (-ox + oy); y = camera[1] + (-oy - ox); z = camera[2] - oz; }
		case FLY_MOVE_FORWARD_LEFT: { x = camera[0] + (ox - oy); y = camera[1] + (oy + ox); z = camera[2] + oz; }
		case FLY_MOVE_FORWARD_RIGHT: { x = camera[0] + (ox + oy); y = camera[1] + (oy - ox); z = camera[2] + oz; }
		default: { x = camera[0]; y = camera[1]; z = camera[2]; }
	}
}

static Fly_MoveCamera(playerid)
{
	new Float:camera[3], Float:front[3], Float:x, Float:y, Float:z;
	GetPlayerCameraPos(playerid,camera[0],camera[1],camera[2]);
	GetPlayerCameraFrontVector(playerid,front[0],front[1],front[2]);

	if (s_Fly[playerid][E_FLY_ACCEL] <= 1.0)
	{
		s_Fly[playerid][E_FLY_ACCEL] += FLY_ACCEL_RATE;
	}

	Fly_GetNextPosition(s_Fly[playerid][E_FLY_MODE],camera,front,x,y,z);
	MoveDynamicObject(s_Fly[playerid][E_FLY_OBJECT],x,y,z,FLY_MOVE_SPEED * s_Fly[playerid][E_FLY_ACCEL]);
	s_Fly[playerid][E_FLY_LAST_MOVE] = GetTickCount();
}

static bool:Fly_Start(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	Fly_Reset(playerid);
	s_Fly[playerid][E_FLY_OBJECT] = CreateDynamicObject(FLY_OBJECT_MODEL,x,y,z,0.0,0.0,0.0,-1,-1,playerid,.streamdistance = -1.0,.priority = FLY_OBJECT_PRIORITY);

	if (!IsValidDynamicObject(s_Fly[playerid][E_FLY_OBJECT]))
	{
		Fly_Reset(playerid);
		return false;
	}

	TogglePlayerSpectating(playerid,true);
	Streamer_ToggleCameraUpdate(playerid,true);
	Streamer_Update(playerid,STREAMER_TYPE_OBJECT);

	if (!AttachCameraToDynamicObject(playerid,s_Fly[playerid][E_FLY_OBJECT]))
	{
		DestroyDynamicObject(s_Fly[playerid][E_FLY_OBJECT]);
		Fly_Reset(playerid);
		Streamer_ToggleCameraUpdate(playerid,false);
		TogglePlayerSpectating(playerid,false);
		return false;
	}

	s_Fly[playerid][E_FLY_ACTIVE] = true;
	return true;
}

static Fly_Stop(playerid)
{
	new Float:x, Float:y, Float:z, Float:front[3];
	GetDynamicObjectPos(s_Fly[playerid][E_FLY_OBJECT],x,y,z);
	GetPlayerCameraFrontVector(playerid,front[0],front[1],front[2]);

	new Float:hx, Float:hy, Float:ground, hit = CA_RayCastLine(x,y,z,x,y,z - FLY_LAND_PROBE,hx,hy,ground);

	if (hit)
	{
		z = ground + FLY_LAND_HEIGHT;
	}

	if (Map_IsMapModel(hit))
	{
		SetPlayerVirtualWorld(playerid,0);
		SetPlayerInterior(playerid,0);
	}

	new Float:angle = atan2(front[1],front[0]) - 90.0, STREAMER_TAG_OBJECT:object = s_Fly[playerid][E_FLY_OBJECT];
	Fly_Reset(playerid);
	Streamer_ToggleCameraUpdate(playerid,false);

	Character_RespawnAt(playerid,x,y,z,angle);
	TogglePlayerSpectating(playerid,false);
	DestroyDynamicObject(object);
	SetPlayerPos(playerid,x,y,z);
	SetPlayerFacingAngle(playerid,angle);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Fly_Reset(playerid);
}

hook OnPlayerDisconnect(playerid,reason)
{
	if (s_Fly[playerid][E_FLY_ACTIVE])
	{
		DestroyDynamicObject(s_Fly[playerid][E_FLY_OBJECT]);
	}

	Fly_Reset(playerid);
}

hook OnPlayerUpdate(playerid)
{
	if (!s_Fly[playerid][E_FLY_ACTIVE])
	{
		return;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);

	if (s_Fly[playerid][E_FLY_MODE] != FLY_MOVE_NONE && GetTickCount() - s_Fly[playerid][E_FLY_LAST_MOVE] > FLY_MOVE_INTERVAL_MS)
	{
		Fly_MoveCamera(playerid);
	}

	if (s_Fly[playerid][E_FLY_UD_OLD] != updown || s_Fly[playerid][E_FLY_LR_OLD] != leftright)
	{
		if ((s_Fly[playerid][E_FLY_UD_OLD] != 0 || s_Fly[playerid][E_FLY_LR_OLD] != 0) && updown == 0 && leftright == 0)
		{
			StopDynamicObject(s_Fly[playerid][E_FLY_OBJECT]);
			s_Fly[playerid][E_FLY_MODE] = FLY_MOVE_NONE;
			s_Fly[playerid][E_FLY_ACCEL] = 0.0;
		}
		else
		{
			s_Fly[playerid][E_FLY_MODE] = Fly_GetDirection(updown,leftright);
			Fly_MoveCamera(playerid);
		}
	}

	s_Fly[playerid][E_FLY_UD_OLD] = updown;
	s_Fly[playerid][E_FLY_LR_OLD] = leftright;
}

CMD<ADMIN_LEVEL_TRIAL>:flymode(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	if (s_Fly[playerid][E_FLY_ACTIVE])
	{
		Fly_Stop(playerid);
		return 1;
	}

	if (!Session_IsPlaying(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can only fly while playing a character.");
		return 1;
	}

	if (!Fly_Start(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"The fly camera couldn't be set up here. Try again.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Fly mode is on. Move with your movement keys and look around with the mouse. Type /flymode again to land here. /pos marks a spot.");
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:pos(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new Float:x, Float:y, Float:z, Float:a;

	if (s_Fly[playerid][E_FLY_ACTIVE])
	{
		new Float:fx, Float:fy, Float:fz;
		GetPlayerCameraPos(playerid,x,y,z);
		GetPlayerCameraFrontVector(playerid,fx,fy,fz);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("camera %.3f, %.3f, %.3f  looks at %.3f, %.3f, %.3f",x,y,z,x + fx * 5.0,y + fy * 5.0,z + fz * 5.0));
		Log_Info("map","/pos camera %.3f, %.3f, %.3f looks at %.3f, %.3f, %.3f",x,y,z,x + fx * 5.0,y + fy * 5.0,z + fz * 5.0);
		return 1;
	}

	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%.3f, %.3f, %.3f  facing %.3f",x,y,z,a));
	Log_Info("map","/pos %.3f, %.3f, %.3f facing %.3f",x,y,z,a);
	return 1;
}
