enum E_LIGHT_FOLLOW
{
	bool:E_LIGHT_FOLLOW_USED,
	E_LIGHT_FOLLOW_OWNER_KIND,
	E_LIGHT_FOLLOW_OWNER,
	STREAMER_TAG_OBJECT:E_LIGHT_FOLLOW_FLAME,
}

static s_LightFollows[LIGHT_FOLLOW_MAX][E_LIGHT_FOLLOW];
static STREAMER_TAG_OBJECT:s_LightMapFlames[LIGHT_MAP_FIRE_COUNT];

stock Light_CountModelFires(model)
{
	new count = 0;

	for (new i = 0;i < LIGHT_MODEL_FIRE_COUNT;i++)
	{
		if (g_LightModelFires[i][E_LIGHT_MODEL_FIRE_MODEL] == model)
		{
			count++;
		}
	}

	return count;
}

stock Light_CountMapFlames()
{
	new count = 0;

	for (new i = 0;i < LIGHT_MAP_FIRE_COUNT;i++)
	{
		if (IsValidDynamicObject(s_LightMapFlames[i]))
		{
			count++;
		}
	}

	return count;
}

stock Light_CountFollowFlames(ownerKind = -1,owner = -1)
{
	new count = 0;

	for (new i = 0;i < LIGHT_FOLLOW_MAX;i++)
	{
		if (s_LightFollows[i][E_LIGHT_FOLLOW_USED] && (ownerKind == -1 || s_LightFollows[i][E_LIGHT_FOLLOW_OWNER_KIND] == ownerKind) && (owner == -1 || s_LightFollows[i][E_LIGHT_FOLLOW_OWNER] == owner) && IsValidDynamicObject(s_LightFollows[i][E_LIGHT_FOLLOW_FLAME]))
		{
			count++;
		}
	}

	return count;
}

stock STREAMER_TAG_OBJECT:Light_GetFollowFlame(ownerKind,owner,nth = 0)
{
	for (new i = 0;i < LIGHT_FOLLOW_MAX;i++)
	{
		if (s_LightFollows[i][E_LIGHT_FOLLOW_USED] && s_LightFollows[i][E_LIGHT_FOLLOW_OWNER_KIND] == ownerKind && s_LightFollows[i][E_LIGHT_FOLLOW_OWNER] == owner && nth-- == 0)
		{
			return s_LightFollows[i][E_LIGHT_FOLLOW_FLAME];
		}
	}

	return STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Light_FindFreeFollow()
{
	for (new i = 0;i < LIGHT_FOLLOW_MAX;i++)
	{
		if (!s_LightFollows[i][E_LIGHT_FOLLOW_USED])
		{
			return i;
		}
	}

	return -1;
}

stock Light_FollowModel(ownerKind,owner,model,Float:x,Float:y,Float:z,Float:heading,world,interior)
{
	new created = 0;

	for (new i = 0;i < LIGHT_MODEL_FIRE_COUNT;i++)
	{
		if (g_LightModelFires[i][E_LIGHT_MODEL_FIRE_MODEL] != model)
		{
			continue;
		}

		new slot = Light_FindFreeFollow();

		if (slot == -1)
		{
			Log_Error("light","flame follow table full at %d",LIGHT_FOLLOW_MAX);
			break;
		}

		s_LightFollows[slot][E_LIGHT_FOLLOW_USED] = true;
		s_LightFollows[slot][E_LIGHT_FOLLOW_OWNER_KIND] = ownerKind;
		s_LightFollows[slot][E_LIGHT_FOLLOW_OWNER] = owner;
		s_LightFollows[slot][E_LIGHT_FOLLOW_FLAME] = Light_CreateFlameAt(x,y,z,heading,g_LightModelFires[i][E_LIGHT_MODEL_FIRE_OFFSET][0],g_LightModelFires[i][E_LIGHT_MODEL_FIRE_OFFSET][1],g_LightModelFires[i][E_LIGHT_MODEL_FIRE_OFFSET][2],world,interior,LIGHT_FLAME_RANGE);
		created++;
	}

	if (created > 0)
	{
		Nearby_StreamObjectsAt(x,y,z,world,interior,LIGHT_FLAME_RANGE);
	}

	return created;
}

stock Light_Unfollow(ownerKind,owner)
{
	new removed = 0;

	for (new i = 0;i < LIGHT_FOLLOW_MAX;i++)
	{
		if (!s_LightFollows[i][E_LIGHT_FOLLOW_USED] || s_LightFollows[i][E_LIGHT_FOLLOW_OWNER_KIND] != ownerKind || s_LightFollows[i][E_LIGHT_FOLLOW_OWNER] != owner)
		{
			continue;
		}

		Light_DestroyFlame(s_LightFollows[i][E_LIGHT_FOLLOW_FLAME]);
		s_LightFollows[i][E_LIGHT_FOLLOW_USED] = false;
		removed++;
	}

	return removed;
}

static Light_FollowStation(stationid)
{
	Light_Unfollow(LIGHT_FOLLOW_STATION,stationid);

	new kind = Work_GetStationKind(stationid), Float:x, Float:y, Float:z, Float:a, world, interior;

	if (kind == -1 || (Work_IsFireKind(kind) && !Work_IsStationAlight(stationid)) || !Work_GetStationPlace(stationid,x,y,z,a,world,interior))
	{
		return;
	}

	Light_FollowModel(LIGHT_FOLLOW_STATION,stationid,Work_GetKindBodyModel(kind),x,y,z,a,world,interior);
}

stock Light_InitFollows()
{
	for (new i = 0;i < LIGHT_FOLLOW_MAX;i++)
	{
		s_LightFollows[i][E_LIGHT_FOLLOW_USED] = false;
		s_LightFollows[i][E_LIGHT_FOLLOW_FLAME] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	for (new i = 0;i < LIGHT_MAP_FIRE_COUNT;i++)
	{
		s_LightMapFlames[i] = Light_CreateFlame(g_LightMapFires[i][0],g_LightMapFires[i][1],g_LightMapFires[i][2],-1,-1,LIGHT_FLAME_RANGE);
	}
}

#include <pp-hooks>

hook Work_OnStationVisuals(stationid,bool:isShown)
{
	if (isShown)
	{
		Light_FollowStation(stationid);
	}
	else
	{
		Light_Unfollow(LIGHT_FOLLOW_STATION,stationid);
	}
}
