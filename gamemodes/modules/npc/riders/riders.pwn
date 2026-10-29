#define NPC_RIDERS_MAX (8)
#define NPC_RIDERS_BUDGET (25)
#define NPC_RIDER_WALK (2.4)
#define NPC_RIDER_RUN (6.0)
#define NPC_RIDER_GALLOP (9.0)

enum E_NPC_RIDER
{
	bool:E_NR_USED,
	E_NR_ID,
	E_NR_TYPE,
	E_NR_TAG,
}

static s_NpcRiders[NPC_RIDERS_MAX][E_NPC_RIDER];
static s_NpcRiderAnim = -1;

stock NpcRiders_SitAnim()
{
	if (s_NpcRiderAnim != -1)
	{
		return s_NpcRiderAnim;
	}

	new lib[32], name[32];

	for (new index = 1;index < 2000;index++)
	{
		if (!GetAnimationName(index,lib,sizeof(lib),name,sizeof(name)))
		{
			continue;
		}

		if (!strcmp(lib,"BIKED",true) && !strcmp(name,"BIKEd_Ride",true))
		{
			s_NpcRiderAnim = index;
			return index;
		}
	}

	s_NpcRiderAnim = 0;
	return 0;
}

stock Float:NpcRiders_Speed(type,E_MOUNT_GAIT:gait)
{
	new Float:speed = NPC_RIDER_RUN;

	switch (gait)
	{
		case MOUNT_GAIT_WALK: speed = NPC_RIDER_WALK;
		case MOUNT_GAIT_GALLOP: speed = Mount_TypeCanGallop(type) ? NPC_RIDER_GALLOP : NPC_RIDER_RUN;
		default: speed = NPC_RIDER_RUN;
	}

	return speed * Mount_TypeSpeedFactor(type);
}

stock NpcRiders_Count()
{
	new count = 0;

	for (new i = 0;i < NPC_RIDERS_MAX;i++)
	{
		if (s_NpcRiders[i][E_NR_USED])
		{
			count++;
		}
	}

	return count;
}

stock bool:NpcRiders_IsRider(playerid)
{
	return NpcRiders_Slot(playerid) != -1;
}

stock NpcRiders_Slot(riderid)
{
	for (new i = 0;i < NPC_RIDERS_MAX;i++)
	{
		if (s_NpcRiders[i][E_NR_USED] && s_NpcRiders[i][E_NR_ID] == riderid)
		{
			return i;
		}
	}

	return -1;
}

stock NpcRiders_GetType(riderid)
{
	new slot = NpcRiders_Slot(riderid);
	return slot != -1 ? s_NpcRiders[slot][E_NR_TYPE] : 0;
}

stock NpcRiders_GetTag(riderid)
{
	new slot = NpcRiders_Slot(riderid);
	return slot != -1 ? s_NpcRiders[slot][E_NR_TAG] : 0;
}

stock NpcRiders_Create(const name[],skin,type,Float:x,Float:y,Float:z,Float:a,world = 0,tag = 0)
{
	new slot = -1, npcs = 0;

	foreach (new p : Player)
	{
		if (IsPlayerNPC(p))
		{
			npcs++;
		}
	}

	if (npcs >= NPC_RIDERS_BUDGET)
	{
		Log_Warn("riders","the NPC budget (%d) is full; %s not created",NPC_RIDERS_BUDGET,name);
		return INVALID_PLAYER_ID;
	}

	for (new i = 0;i < NPC_RIDERS_MAX;i++)
	{
		if (!s_NpcRiders[i][E_NR_USED])
		{
			slot = i;
			break;
		}
	}

	if (slot == -1 || !Mount_IsValidType(type))
	{
		return INVALID_PLAYER_ID;
	}

	new riderid = Rider_Create(name,skin,x,y,z + MOUNT_RIDE_HEIGHT,a,world,MOUNT_SLOT,ATTACH_BONE_SPINE,NpcRiders_SitAnim(),MOUNT_RIDE_HEIGHT);

	if (riderid == INVALID_PLAYER_ID || riderid < 0)
	{
		return INVALID_PLAYER_ID;
	}

	for (new E_MOUNT_GAIT:gait = MOUNT_GAIT_IDLE;gait <= MOUNT_GAIT_SPRINT;gait++)
	{
		new E_MOUNT_GAIT:rig = gait, Float:ox, Float:oy, Float:oz, Float:rx, Float:ry, Float:rz;

		if (Mount_TypeIsDonkey(type) && gait == MOUNT_GAIT_GALLOP)
		{
			rig = MOUNT_GAIT_SPRINT;
		}

		Mount_GetAttach(type,rig,ox,oy,oz,rx,ry,rz);
		Rider_SetGait(riderid,_:gait,Mount_FrameModel(type,rig,0),-1,Mount_TypeGaitFrames(type,rig),rig == MOUNT_GAIT_IDLE ? MOUNT_FRAME_IDLE_MS : MOUNT_FRAME_MOVE_MS,ox,oy,oz,rx,ry,rz);
	}

	s_NpcRiders[slot][E_NR_USED] = true;
	s_NpcRiders[slot][E_NR_ID] = riderid;
	s_NpcRiders[slot][E_NR_TYPE] = type;
	s_NpcRiders[slot][E_NR_TAG] = tag;
    Actors_RegisterRider(sprintf("rider:%d",riderid),riderid,name,"Coachman");
	return riderid;
}

stock NpcRiders_Ride(riderid,Float:x,Float:y,Float:z,E_MOUNT_GAIT:gait = MOUNT_GAIT_SPRINT)
{
	return Rider_MoveTo(riderid,x,y,z,_:gait,NpcRiders_Speed(NpcRiders_GetType(riderid),gait));
}

stock NpcRiders_RideRoute(riderid,const Float:points[],count,E_MOUNT_GAIT:gait = MOUNT_GAIT_SPRINT,Float:scale = 1.0)
{
	return Rider_SetRoute(riderid,points,count,_:gait,NpcRiders_Speed(NpcRiders_GetType(riderid),gait) * scale);
}

stock NpcRiders_Destroy(riderid)
{
	new slot = NpcRiders_Slot(riderid);

	if (slot == -1)
	{
		return;
	}

    Actors_Unregister(Actors_FindByKey(sprintf("rider:%d",riderid)));
	Rider_Destroy(riderid);
	s_NpcRiders[slot][E_NR_USED] = false;
}

forward NpcRiders_OnArrive(riderid,tag);

public NpcRiders_OnArrive(riderid,tag)
{
	return 1;
}

#include <pp-hooks>

hook OnRiderArrive(riderid)
{
	new slot = NpcRiders_Slot(riderid);

	if (slot != -1)
	{
		pawn_call_public("NpcRiders_OnArrive","dd",riderid,s_NpcRiders[slot][E_NR_TAG]);
	}
}
