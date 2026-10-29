#define MAX_HORSES (64)
#define INVALID_HORSE_ID (-1)
#define HORSE_MOUNT_RANGE (1.5)
#define HORSE_LABEL_COLOUR (0xA89C86AA)
#define HORSE_LABEL_RANGE (4.0)
#define HORSE_HOLD_LEN (96)
#define HORSE_WALK_TICK_MS (200)
#define HORSE_WALK_SPEED (1.4)
#define HORSE_WALK_FRAME_STEP (5)
#define HORSE_WALK_ARRIVE (1.2)
#define HORSE_TACK_SLOTS (3)
#define HORSE_TACK_STREAM (60.0)
#define HORSE_BASE_LIFT (1.0)

enum E_HORSE
{
	bool:E_HORSE_USED,
	E_HORSE_TYPE,
	E_HORSE_RIDER,
	STREAMER_TAG_OBJECT:E_HORSE_OBJECT,
	STREAMER_TAG_3D_TEXT_LABEL:E_HORSE_LABEL,
	Float:E_HORSE_X,
	Float:E_HORSE_Y,
	Float:E_HORSE_Z,
	Float:E_HORSE_A,
	E_HORSE_WORLD,
	E_HORSE_HOLD[HORSE_HOLD_LEN],
	E_HORSE_NAME[MOUNT_NAME_LEN],
	E_HORSE_LABEL_HINT[80],
	Float:E_HORSE_SPEED,
	E_HORSE_STAMINA_MAX,
	bool:E_HORSE_NO_GALLOP,
	bool:E_HORSE_WALKING,
	Float:E_HORSE_GOAL[3],
	Float:E_HORSE_WALK_SPEED,
	E_HORSE_WALK_FRAME,
	E_HORSE_WALK_TIMER,
	E_HORSE_TACK_MODEL[HORSE_TACK_SLOTS],
	STREAMER_TAG_OBJECT:E_HORSE_TACK_OBJECT[HORSE_TACK_SLOTS],
}

static s_Horses[MAX_HORSES][E_HORSE];

stock bool:Horse_IsValid(horseid)
{
	return horseid >= 0 && horseid < MAX_HORSES && s_Horses[horseid][E_HORSE_USED];
}

stock Horse_GetType(horseid)
{
	return Horse_IsValid(horseid) ? s_Horses[horseid][E_HORSE_TYPE] : 0;
}

stock Horse_GetRider(horseid)
{
	return Horse_IsValid(horseid) ? s_Horses[horseid][E_HORSE_RIDER] : INVALID_PLAYER_ID;
}

stock bool:Horse_IsStanding(horseid)
{
	return Horse_IsValid(horseid) && s_Horses[horseid][E_HORSE_RIDER] == INVALID_PLAYER_ID;
}

stock Horse_GetPos(horseid,&Float:x,&Float:y,&Float:z,&Float:a)
{
	x = s_Horses[horseid][E_HORSE_X];
	y = s_Horses[horseid][E_HORSE_Y];
	z = s_Horses[horseid][E_HORSE_Z];
	a = s_Horses[horseid][E_HORSE_A];
}

static Float:Horse_Ground(Float:x,Float:y,Float:z)
{
	new Float:hx, Float:hy, Float:hz;

	if (CA_RayCastLine(x,y,z + 2.0,x,y,z - 5.0,hx,hy,hz) != 0)
	{
		return hz + HORSE_BASE_LIFT;
	}

	return z;
}

static Horse_Place(horseid,Float:x,Float:y,Float:z,Float:a,world)
{
	new name[MOUNT_NAME_LEN], label[128];

	if (s_Horses[horseid][E_HORSE_NAME][0] != EOS)
	{
		strcopy(name,s_Horses[horseid][E_HORSE_NAME]);
	}
	else
	{
		Mount_TypeName(s_Horses[horseid][E_HORSE_TYPE],name);
	}

	format(label,sizeof(label),"%s\n%s",name,s_Horses[horseid][E_HORSE_LABEL_HINT]);
	z = Horse_Ground(x,y,z);

	s_Horses[horseid][E_HORSE_X] = x;
	s_Horses[horseid][E_HORSE_Y] = y;
	s_Horses[horseid][E_HORSE_Z] = z;
	s_Horses[horseid][E_HORSE_A] = a;
	s_Horses[horseid][E_HORSE_WORLD] = world;
	s_Horses[horseid][E_HORSE_RIDER] = INVALID_PLAYER_ID;
	new Float:ox, Float:oy, Float:oz, Float:rx, Float:ry, Float:rz;
	Mount_GetStandPose(s_Horses[horseid][E_HORSE_TYPE],x,y,z,a,ox,oy,oz,rx,ry,rz);
	s_Horses[horseid][E_HORSE_OBJECT] = CreateDynamicObject(Mount_StandingModel(s_Horses[horseid][E_HORSE_TYPE]),ox,oy,oz,rx,ry,rz,world);
	Nearby_StreamObjectsAt(x,y,z,world,-1,HORSE_TACK_STREAM);
	Horse_AttachTack(horseid);
	s_Horses[horseid][E_HORSE_LABEL] = CreateDynamic3DTextLabel(label,HORSE_LABEL_COLOUR,x,y,z + 0.6,HORSE_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,world);
	Nearby_StreamObjectsAt(x,y,z,world,-1,HORSE_TACK_STREAM);
}

static Horse_DropTack(horseid)
{
	for (new slot = 0;slot < HORSE_TACK_SLOTS;slot++)
	{
		if (s_Horses[horseid][E_HORSE_TACK_OBJECT][slot] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID && IsValidDynamicObject(s_Horses[horseid][E_HORSE_TACK_OBJECT][slot]))
		{
			DestroyDynamicObject(s_Horses[horseid][E_HORSE_TACK_OBJECT][slot]);
		}

		s_Horses[horseid][E_HORSE_TACK_OBJECT][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

static Horse_AttachTack(horseid)
{
	Horse_DropTack(horseid);

	if (Mount_TypeIsDonkey(s_Horses[horseid][E_HORSE_TYPE]) || !IsValidDynamicObject(s_Horses[horseid][E_HORSE_OBJECT]))
	{
		return;
	}

	for (new slot = 0;slot < HORSE_TACK_SLOTS;slot++)
	{
		if (s_Horses[horseid][E_HORSE_TACK_MODEL][slot] == 0)
		{
			continue;
		}

		new STREAMER_TAG_OBJECT:tack = CreateDynamicObject(s_Horses[horseid][E_HORSE_TACK_MODEL][slot],s_Horses[horseid][E_HORSE_X],s_Horses[horseid][E_HORSE_Y],s_Horses[horseid][E_HORSE_Z],0.0,0.0,0.0,s_Horses[horseid][E_HORSE_WORLD]);
		AttachDynamicObjectToObject(tack,_:s_Horses[horseid][E_HORSE_OBJECT],0.0,0.0,0.0,0.0,0.0,0.0,1);
		s_Horses[horseid][E_HORSE_TACK_OBJECT][slot] = tack;
	}
}

stock Horse_SetTack(horseid,slot,model)
{
	if (!Horse_IsValid(horseid) || slot < 0 || slot >= HORSE_TACK_SLOTS || s_Horses[horseid][E_HORSE_TACK_MODEL][slot] == model)
	{
		return;
	}

	s_Horses[horseid][E_HORSE_TACK_MODEL][slot] = model;

	if (s_Horses[horseid][E_HORSE_RIDER] == INVALID_PLAYER_ID)
	{
		Horse_AttachTack(horseid);
		Nearby_StreamObjectsAt(s_Horses[horseid][E_HORSE_X],s_Horses[horseid][E_HORSE_Y],s_Horses[horseid][E_HORSE_Z],s_Horses[horseid][E_HORSE_WORLD],-1,HORSE_TACK_STREAM);
	}
}

stock Horse_GetTack(horseid,slot)
{
	return Horse_IsValid(horseid) && slot >= 0 && slot < HORSE_TACK_SLOTS ? s_Horses[horseid][E_HORSE_TACK_MODEL][slot] : 0;
}

stock STREAMER_TAG_OBJECT:Horse_GetTackObject(horseid,slot)
{
	return Horse_IsValid(horseid) && slot >= 0 && slot < HORSE_TACK_SLOTS ? s_Horses[horseid][E_HORSE_TACK_OBJECT][slot] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Horse_Lift(horseid)
{
	Horse_DropTack(horseid);

	if (IsValidDynamicObject(s_Horses[horseid][E_HORSE_OBJECT]))
	{
		DestroyDynamicObject(s_Horses[horseid][E_HORSE_OBJECT]);
	}

	if (IsValidDynamic3DTextLabel(s_Horses[horseid][E_HORSE_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Horses[horseid][E_HORSE_LABEL]);
	}

	s_Horses[horseid][E_HORSE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Horses[horseid][E_HORSE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock Horse_Create(type,Float:x,Float:y,Float:z,Float:a,world = 0)
{
	if (!Mount_IsValidType(type))
	{
		return INVALID_HORSE_ID;
	}

	for (new i = 0; i < MAX_HORSES; i++)
	{
		if (s_Horses[i][E_HORSE_USED])
		{
			continue;
		}

		s_Horses[i][E_HORSE_USED] = true;
		s_Horses[i][E_HORSE_TYPE] = type;
		s_Horses[i][E_HORSE_HOLD][0] = EOS;
		s_Horses[i][E_HORSE_NAME][0] = EOS;
		strcopy(s_Horses[i][E_HORSE_LABEL_HINT],"Press F to ride",80);
		s_Horses[i][E_HORSE_SPEED] = 1.0;
		s_Horses[i][E_HORSE_STAMINA_MAX] = MOUNT_STAMINA_MAX;
		s_Horses[i][E_HORSE_NO_GALLOP] = false;
		s_Horses[i][E_HORSE_WALKING] = false;
		s_Horses[i][E_HORSE_WALK_TIMER] = 0;

		for (new slot = 0;slot < HORSE_TACK_SLOTS;slot++)
		{
			s_Horses[i][E_HORSE_TACK_MODEL][slot] = 0;
			s_Horses[i][E_HORSE_TACK_OBJECT][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		}

		Horse_Place(i,x,y,z,a,world);
		pawn_call_public("Horse_OnCreated","d",i);
		return i;
	}

	return INVALID_HORSE_ID;
}

stock Horse_Destroy(horseid)
{
	if (!Horse_IsValid(horseid))
	{
		return;
	}

	if (s_Horses[horseid][E_HORSE_RIDER] != INVALID_PLAYER_ID)
	{
		Mount_Dismount(s_Horses[horseid][E_HORSE_RIDER],false);
	}

	Horse_StopWalk(horseid);
	Horse_Lift(horseid);
	s_Horses[horseid][E_HORSE_USED] = false;
	pawn_call_public("Horse_OnDestroyed","d",horseid);
}

stock Horse_SetHold(horseid,const message[])
{
	if (Horse_IsValid(horseid))
	{
		strcopy(s_Horses[horseid][E_HORSE_HOLD],message,HORSE_HOLD_LEN);
	}
}

stock bool:Horse_GetHold(horseid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Horse_IsValid(horseid))
	{
		strcopy(dest,s_Horses[horseid][E_HORSE_HOLD],size);
	}

	return dest[0] != EOS;
}

stock Horse_SetName(horseid,const name[])
{
	if (!Horse_IsValid(horseid))
	{
		return;
	}

	strcopy(s_Horses[horseid][E_HORSE_NAME],name,MOUNT_NAME_LEN);

	if (s_Horses[horseid][E_HORSE_RIDER] == INVALID_PLAYER_ID && !s_Horses[horseid][E_HORSE_WALKING])
	{
		Horse_Reset(horseid);
	}
}

stock Horse_GetName(horseid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (!Horse_IsValid(horseid))
	{
		return;
	}

	if (s_Horses[horseid][E_HORSE_NAME][0] != EOS)
	{
		strcopy(dest,s_Horses[horseid][E_HORSE_NAME],size);
	}
	else
	{
		Mount_TypeName(s_Horses[horseid][E_HORSE_TYPE],dest,size);
	}
}

stock Horse_SetLabelHint(horseid,const hint[])
{
	if (!Horse_IsValid(horseid) || !strcmp(s_Horses[horseid][E_HORSE_LABEL_HINT],hint))
	{
		return;
	}

	strcopy(s_Horses[horseid][E_HORSE_LABEL_HINT],hint,80);

	if (IsValidDynamic3DTextLabel(s_Horses[horseid][E_HORSE_LABEL]))
	{
		new name[MOUNT_NAME_LEN], label[128];
		Horse_GetName(horseid,name);
		format(label,sizeof(label),"%s\n%s",name,hint);
		UpdateDynamic3DTextLabelText(s_Horses[horseid][E_HORSE_LABEL],HORSE_LABEL_COLOUR,label);
	}
}

stock bool:Horse_GetLabelText(horseid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (!Horse_IsValid(horseid) || !IsValidDynamic3DTextLabel(s_Horses[horseid][E_HORSE_LABEL]))
	{
		return false;
	}

	GetDynamic3DTextLabelText(s_Horses[horseid][E_HORSE_LABEL],dest,size);
	return true;
}

stock Horse_SetType(horseid,type)
{
	if (!Horse_IsValid(horseid) || !Mount_IsValidType(type))
	{
		return;
	}

	s_Horses[horseid][E_HORSE_TYPE] = type;

	if (s_Horses[horseid][E_HORSE_RIDER] == INVALID_PLAYER_ID && !s_Horses[horseid][E_HORSE_WALKING])
	{
		Horse_Reset(horseid);
	}
}

stock Horse_SetRideStats(horseid,Float:speed,staminaMax,bool:noGallop)
{
	if (!Horse_IsValid(horseid))
	{
		return;
	}

	s_Horses[horseid][E_HORSE_SPEED] = speed;
	s_Horses[horseid][E_HORSE_STAMINA_MAX] = max(staminaMax,MOUNT_STAMINA_GALLOP_MIN + 1);
	s_Horses[horseid][E_HORSE_NO_GALLOP] = noGallop;
}

stock Float:Horse_GetSpeed(horseid)
{
	return Horse_IsValid(horseid) ? s_Horses[horseid][E_HORSE_SPEED] : 1.0;
}

stock Horse_GetStaminaMax(horseid)
{
	return Horse_IsValid(horseid) ? s_Horses[horseid][E_HORSE_STAMINA_MAX] : MOUNT_STAMINA_MAX;
}

stock bool:Horse_IsNoGallop(horseid)
{
	return Horse_IsValid(horseid) && s_Horses[horseid][E_HORSE_NO_GALLOP];
}

stock Horse_Reset(horseid)
{
	if (!Horse_IsValid(horseid) || s_Horses[horseid][E_HORSE_RIDER] != INVALID_PLAYER_ID)
	{
		return;
	}

	new Float:x = s_Horses[horseid][E_HORSE_X], Float:y = s_Horses[horseid][E_HORSE_Y], Float:z = s_Horses[horseid][E_HORSE_Z], Float:a = s_Horses[horseid][E_HORSE_A], world = s_Horses[horseid][E_HORSE_WORLD];
	Horse_Lift(horseid);
	Horse_Place(horseid,x,y,z,a,world);
}

stock Horse_MoveTo(horseid,Float:x,Float:y,Float:z,Float:a,world = 0)
{
	if (!Horse_IsValid(horseid) || s_Horses[horseid][E_HORSE_RIDER] != INVALID_PLAYER_ID)
	{
		return;
	}

	Horse_StopWalk(horseid);
	Horse_Lift(horseid);
	Horse_Place(horseid,x,y,z,a,world);
}

stock bool:Horse_IsWalking(horseid)
{
	return Horse_IsValid(horseid) && s_Horses[horseid][E_HORSE_WALKING];
}

stock bool:Horse_WalkTo(horseid,Float:x,Float:y,Float:z,Float:speed = HORSE_WALK_SPEED)
{
	if (!Horse_IsValid(horseid) || s_Horses[horseid][E_HORSE_RIDER] != INVALID_PLAYER_ID)
	{
		return false;
	}

	s_Horses[horseid][E_HORSE_GOAL][0] = x;
	s_Horses[horseid][E_HORSE_GOAL][1] = y;
	s_Horses[horseid][E_HORSE_GOAL][2] = z;
	s_Horses[horseid][E_HORSE_WALK_SPEED] = speed;

	if (!s_Horses[horseid][E_HORSE_WALKING])
	{
		s_Horses[horseid][E_HORSE_WALKING] = true;
		s_Horses[horseid][E_HORSE_WALK_FRAME] = 0;

		if (IsValidDynamic3DTextLabel(s_Horses[horseid][E_HORSE_LABEL]))
		{
			DestroyDynamic3DTextLabel(s_Horses[horseid][E_HORSE_LABEL]);
			s_Horses[horseid][E_HORSE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
		}

		s_Horses[horseid][E_HORSE_WALK_TIMER] = SetTimerEx("Horse_WalkTick",HORSE_WALK_TICK_MS,true,"d",horseid);
	}

	return true;
}

stock Horse_StopWalk(horseid)
{
	if (!Horse_IsValid(horseid) || !s_Horses[horseid][E_HORSE_WALKING])
	{
		return;
	}

	s_Horses[horseid][E_HORSE_WALKING] = false;

	if (s_Horses[horseid][E_HORSE_WALK_TIMER] != 0)
	{
		KillTimer(s_Horses[horseid][E_HORSE_WALK_TIMER]);
		s_Horses[horseid][E_HORSE_WALK_TIMER] = 0;
	}

	if (s_Horses[horseid][E_HORSE_RIDER] == INVALID_PLAYER_ID)
	{
		Horse_Reset(horseid);
	}
}

forward Horse_WalkTick(horseid);

public Horse_WalkTick(horseid)
{
	if (!Horse_IsValid(horseid) || !s_Horses[horseid][E_HORSE_WALKING])
	{
		return 1;
	}

	new Float:x = s_Horses[horseid][E_HORSE_X], Float:y = s_Horses[horseid][E_HORSE_Y], Float:dx = s_Horses[horseid][E_HORSE_GOAL][0] - x, Float:dy = s_Horses[horseid][E_HORSE_GOAL][1] - y;
	new Float:distance = VectorSize(dx,dy,0.0), Float:step = s_Horses[horseid][E_HORSE_WALK_SPEED] * float(HORSE_WALK_TICK_MS) / 1000.0;

	if (distance <= HORSE_WALK_ARRIVE)
	{
		Horse_StopWalk(horseid);
		pawn_call_public("Horse_OnArrived","d",horseid);
		return 1;
	}

	if (step > distance)
	{
		step = distance;
	}

	x += dx / distance * step;
	y += dy / distance * step;
	new Float:z = Horse_Ground(x,y,s_Horses[horseid][E_HORSE_Z]), Float:a = atan2(dy,dx) - 90.0;
	s_Horses[horseid][E_HORSE_X] = x;
	s_Horses[horseid][E_HORSE_Y] = y;
	s_Horses[horseid][E_HORSE_Z] = z;
	s_Horses[horseid][E_HORSE_A] = a;

	new type = s_Horses[horseid][E_HORSE_TYPE], Float:ox, Float:oy, Float:oz, Float:rx, Float:ry, Float:rz;
	Mount_GetStandPose(type,x,y,z,a,ox,oy,oz,rx,ry,rz);
	s_Horses[horseid][E_HORSE_WALK_FRAME] = (s_Horses[horseid][E_HORSE_WALK_FRAME] + HORSE_WALK_FRAME_STEP) % Mount_TypeGaitFrames(type,MOUNT_GAIT_WALK);

	if (IsValidDynamicObject(s_Horses[horseid][E_HORSE_OBJECT]))
	{
		DestroyDynamicObject(s_Horses[horseid][E_HORSE_OBJECT]);
	}

	s_Horses[horseid][E_HORSE_OBJECT] = CreateDynamicObject(Mount_FrameModel(type,MOUNT_GAIT_WALK,s_Horses[horseid][E_HORSE_WALK_FRAME]),ox,oy,oz,rx,ry,rz,s_Horses[horseid][E_HORSE_WORLD]);
	Horse_AttachTack(horseid);
	return 1;
}

stock STREAMER_TAG_OBJECT:Horse_GetObject(horseid)
{
	return Horse_IsValid(horseid) ? s_Horses[horseid][E_HORSE_OBJECT] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock Horse_ReplaceType(type)
{
	for (new i = 0;i < MAX_HORSES;i++)
	{
		if (s_Horses[i][E_HORSE_USED] && s_Horses[i][E_HORSE_TYPE] == type && s_Horses[i][E_HORSE_RIDER] == INVALID_PLAYER_ID)
		{
			new Float:x = s_Horses[i][E_HORSE_X], Float:y = s_Horses[i][E_HORSE_Y], Float:z = s_Horses[i][E_HORSE_Z], Float:a = s_Horses[i][E_HORSE_A], world = s_Horses[i][E_HORSE_WORLD];
			Horse_Lift(i);
			Horse_Place(i,x,y,z,a,world);
		}
	}
}

stock Horse_Nearest(playerid,Float:range = 2.5)
{
	new best = INVALID_HORSE_ID, Float:bestDistance = range, Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new i = 0; i < MAX_HORSES; i++)
	{
		if (!s_Horses[i][E_HORSE_USED] || s_Horses[i][E_HORSE_RIDER] != INVALID_PLAYER_ID || s_Horses[i][E_HORSE_WALKING] || s_Horses[i][E_HORSE_WORLD] != GetPlayerVirtualWorld(playerid))
		{
			continue;
		}

		new Float:distance = Util_GetDistance3D(x,y,z,s_Horses[i][E_HORSE_X],s_Horses[i][E_HORSE_Y],s_Horses[i][E_HORSE_Z]);
		if (distance < bestDistance)
		{
			bestDistance = distance;
			best = i;
		}
	}

	return best;
}

stock Horse_GetSide(horseid,bool:left,&Float:x,&Float:y)
{
	new Float:a = s_Horses[horseid][E_HORSE_A] + (left ? 90.0 : -90.0);
	x = s_Horses[horseid][E_HORSE_X] + (1.0 * floatsin(-a,degrees));
	y = s_Horses[horseid][E_HORSE_Y] + (1.0 * floatcos(-a,degrees));
}

Horse_TakeRider(horseid,playerid)
{
	Horse_StopWalk(horseid);
	Horse_Lift(horseid);
	s_Horses[horseid][E_HORSE_RIDER] = playerid;
}

Horse_DropRider(horseid,Float:x,Float:y,Float:z,Float:a,world)
{
	Horse_Place(horseid,x,y,z,a,world);
}

forward Horse_OnCreated(horseid);

public Horse_OnCreated(horseid)
{
	return 1;
}

forward Horse_OnDestroyed(horseid);

public Horse_OnDestroyed(horseid)
{
	return 1;
}

forward Horse_OnArrived(horseid);

public Horse_OnArrived(horseid)
{
	return 1;
}

CMD:horse(cmdid, playerid, params[])
{
	new type;
	if (sscanf(params,"i",type) || !Mount_IsValidType(type))
	{
		Command_Usage(playerid,cmdid,sprintf("<type 0..%d>",MOUNT_TYPE_COUNT - 1));
		return 1;
	}

	new Float:x, Float:y, Float:z, Float:a;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	Util_GetOffsetPoint(x,y,a,2.0,x,y);

	if (Horse_Create(type,x,y,z,a,GetPlayerVirtualWorld(playerid)) == INVALID_HORSE_ID)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"No stable room left.");
	}

	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0; i < MAX_HORSES; i++)
	{
		s_Horses[i][E_HORSE_USED] = false;
		s_Horses[i][E_HORSE_RIDER] = INVALID_PLAYER_ID;
		s_Horses[i][E_HORSE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_Horses[i][E_HORSE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

		for (new slot = 0;slot < HORSE_TACK_SLOTS;slot++)
		{
			s_Horses[i][E_HORSE_TACK_OBJECT][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
			s_Horses[i][E_HORSE_TACK_MODEL][slot] = 0;
		}
	}
}
