enum _:E_NEARBY_STREAM_KIND
{
	NEARBY_STREAM_OBJECTS,
	NEARBY_STREAM_LABELS,
}

new Iterator:NearbyPlayers[MAX_PLAYERS]<MAX_PLAYERS>;
static bool:s_NearbyStreamDirty[E_NEARBY_STREAM_KIND][MAX_PLAYERS];
static s_NearbyStreamDirtyCount[E_NEARBY_STREAM_KIND];
static Float:s_NearbyStreamPos[MAX_PLAYERS][3];
static s_NearbyStreamWorld[MAX_PLAYERS];
static s_NearbyStreamInterior[MAX_PLAYERS];
static bool:s_NearbyStreamPending;

stock bool:Nearby_IsPlayerStreamed(playerid,forplayerid)
{
	return Iter_Contains(NearbyPlayers[forplayerid],playerid);
}

stock Nearby_PlayerCount(playerid)
{
	return Iter_Count(NearbyPlayers[playerid]);
}

stock bool:Nearby_CanStreamObjects(playerid)
{
	return Streamer_IsToggleItemUpdate(playerid,STREAMER_TYPE_OBJECT) != 0;
}

stock Nearby_StreamObjectsAt(Float:x,Float:y,Float:z,world,interior,Float:range)
{
	foreach (new i : Player)
	{
		if (Nearby_CanStreamObjects(i) && (world == -1 || GetPlayerVirtualWorld(i) == world) && (interior == -1 || GetPlayerInterior(i) == interior) && GetPlayerDistanceFromPoint(i,x,y,z) <= range)
		{
			Streamer_Update(i,STREAMER_TYPE_OBJECT);
		}
	}
}

static Nearby_MarkStream(kind,playerid,Float:x,Float:y,Float:z,world,interior,Float:range)
{
	if (s_NearbyStreamDirty[kind][playerid] || (world != -1 && s_NearbyStreamWorld[playerid] != world) || (interior != -1 && s_NearbyStreamInterior[playerid] != interior))
	{
		return;
	}

	new Float:dx = s_NearbyStreamPos[playerid][0] - x, Float:dy = s_NearbyStreamPos[playerid][1] - y, Float:dz = s_NearbyStreamPos[playerid][2] - z;

	if (dx * dx + dy * dy + dz * dz <= range * range)
	{
		s_NearbyStreamDirty[kind][playerid] = true;
		s_NearbyStreamDirtyCount[kind]++;
	}
}

stock Nearby_QueueStream(type,Float:x,Float:y,Float:z,world,interior,playerid,Float:range)
{
	new kind = type == STREAMER_TYPE_OBJECT ? NEARBY_STREAM_OBJECTS : NEARBY_STREAM_LABELS, players = Iter_Count(Player);

	if (players == 0 || s_NearbyStreamDirtyCount[kind] >= players)
	{
		return;
	}

	if (!s_NearbyStreamPending)
	{
		s_NearbyStreamPending = true;

		foreach (new i : Player)
		{
			GetPlayerPos(i,s_NearbyStreamPos[i][0],s_NearbyStreamPos[i][1],s_NearbyStreamPos[i][2]);
			s_NearbyStreamWorld[i] = GetPlayerVirtualWorld(i);
			s_NearbyStreamInterior[i] = GetPlayerInterior(i);
		}

		SetTimer("Nearby_FlushStream",0,false);
	}

	if (playerid != -1)
	{
		if (IsPlayerConnected(playerid))
		{
			Nearby_MarkStream(kind,playerid,x,y,z,world,interior,range);
		}

		return;
	}

	foreach (new i : Player)
	{
		Nearby_MarkStream(kind,i,x,y,z,world,interior,range);
	}
}

stock bool:Nearby_IsObjectStreamPending()
{
	return s_NearbyStreamDirtyCount[NEARBY_STREAM_OBJECTS] > 0;
}

forward Nearby_FlushStream();

public Nearby_FlushStream()
{
	foreach (new i : Player)
	{
		if (s_NearbyStreamDirty[NEARBY_STREAM_OBJECTS][i] && Nearby_CanStreamObjects(i))
		{
			Streamer_Update(i,STREAMER_TYPE_OBJECT);
		}

		if (s_NearbyStreamDirty[NEARBY_STREAM_LABELS][i])
		{
			Streamer_Update(i,STREAMER_TYPE_3D_TEXT_LABEL);
		}
	}

	for (new i = 0;i < MAX_PLAYERS;i++)
	{
		s_NearbyStreamDirty[NEARBY_STREAM_OBJECTS][i] = false;
		s_NearbyStreamDirty[NEARBY_STREAM_LABELS][i] = false;
	}

	s_NearbyStreamDirtyCount[NEARBY_STREAM_OBJECTS] = 0;
	s_NearbyStreamDirtyCount[NEARBY_STREAM_LABELS] = 0;
	s_NearbyStreamPending = false;
	return 1;
}

stock STREAMER_TAG_OBJECT:Nearby_CreateDynamicObject(modelid,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz,worldid = -1,interiorid = -1,playerid = -1,Float:streamdistance = STREAMER_OBJECT_SD,Float:drawdistance = STREAMER_OBJECT_DD,STREAMER_TAG_AREA:areaid = STREAMER_TAG_AREA:-1,priority = 0)
{
	new STREAMER_TAG_OBJECT:objectid = CreateDynamicObject(modelid,x,y,z,rx,ry,rz,worldid,interiorid,playerid,streamdistance,drawdistance,areaid,priority);

	if (objectid != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		Nearby_QueueStream(STREAMER_TYPE_OBJECT,x,y,z,worldid,interiorid,playerid,streamdistance);
	}

	return objectid;
}

stock STREAMER_TAG_3D_TEXT_LABEL:Nearby_CreateDynamic3DTextLabel(const text[],color,Float:x,Float:y,Float:z,Float:drawdistance,attachedplayer = INVALID_PLAYER_ID,attachedvehicle = INVALID_VEHICLE_ID,testlos = 0,worldid = -1,interiorid = -1,playerid = -1,Float:streamdistance = STREAMER_3D_TEXT_LABEL_SD,STREAMER_TAG_AREA:areaid = STREAMER_TAG_AREA:-1,priority = 0)
{
	new STREAMER_TAG_3D_TEXT_LABEL:labelid = CreateDynamic3DTextLabel(text,color,x,y,z,drawdistance,attachedplayer,attachedvehicle,testlos,worldid,interiorid,playerid,streamdistance,areaid,priority);

	if (labelid != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
	{
		new Float:at[3];
		at[0] = x;
		at[1] = y;
		at[2] = z;

		if (attachedplayer != INVALID_PLAYER_ID)
		{
			GetPlayerPos(attachedplayer,at[0],at[1],at[2]);
		}

		if (attachedvehicle != INVALID_VEHICLE_ID)
		{
			GetVehiclePos(attachedvehicle,at[0],at[1],at[2]);
		}

		Nearby_QueueStream(STREAMER_TYPE_3D_TEXT_LABEL,at[0],at[1],at[2],worldid,interiorid,playerid,streamdistance);
	}

	return labelid;
}

#define CreateDynamicObject Nearby_CreateDynamicObject
#define CreateDynamic3DTextLabel Nearby_CreateDynamic3DTextLabel

static Nearby_ForgetPlayer(playerid)
{
	foreach (new i : Player)
	{
		if (Iter_Contains(NearbyPlayers[i],playerid))
		{
			Iter_Remove(NearbyPlayers[i],playerid);
		}
	}

	Iter_Clear(NearbyPlayers[playerid]);
}

#include <pp-hooks>

hook OnGameModeInit()
{
	Iter_Init(NearbyPlayers);
}

hook OnPlayerStreamIn(playerid,forplayerid)
{
	if (!Iter_Contains(NearbyPlayers[forplayerid],playerid))
	{
		Iter_Add(NearbyPlayers[forplayerid],playerid);
	}
}

hook OnPlayerStreamOut(playerid,forplayerid)
{
	if (Iter_Contains(NearbyPlayers[forplayerid],playerid))
	{
		Iter_Remove(NearbyPlayers[forplayerid],playerid);
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	Nearby_ForgetPlayer(playerid);
}
