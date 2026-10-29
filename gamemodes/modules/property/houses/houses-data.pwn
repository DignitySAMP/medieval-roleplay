#define HOUSE_EXIT_KEY_PRIO (KEYS_PRIO_MENU + 3)

#define HOUSE_WORLD_BASE (7200)
#define HOUSE_INTERIOR (1)
#define HOUSE_SKY_X (-3000.0)
#define HOUSE_SKY_Y (-3000.0)
#define HOUSE_SKY_Z (1500.0)
#define HOUSE_STREAM_RANGE (60.0)
#define HOUSE_DOOR_PRELOAD_MS (1200)
#define HOUSE_DOOR_REACH (1.6)
#define HOUSE_SPOT_REACH (1.4)
#define HOUSE_OPEN_HOUR (6)
#define HOUSE_CLOSE_HOUR (21)
#define HOUSE_FIRE_FROM (5)
#define HOUSE_FIRE_UNTIL (22)
#define HOUSE_PROMPT_MS (500)
#define HOUSE_TICK_MS (60000)
#define HOUSE_ROOM_HOLDERS (2)
#define HOUSE_RENT_BASE (60)
#define HOUSE_INACTIVE_DAYS (21)
#define HOUSE_FURNITURE_MAX (512)
#define HOUSE_FURNITURE_PER_ROOM (12)
#define HOUSE_PANEL_WIDTH (270.0)
#define HOUSE_REGISTER_HOUSE "tb_reeve"
#define HOUSE_DARK_ALPHA (0x000000B4)

forward bool:Houses_IsInside(playerid);
forward bool:Houses_IsOpen();
forward bool:Houses_HoldsRoomIn(playerid,house);
forward Task:Houses_LoadFurniture();
forward Task:Houses_PlaceFurniture(room,item,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz);
forward bool:Houses_ShareRoom(room,characterid);

stock Houses_LocalToWorld(Float:localX,Float:localY,Float:localZ,&Float:x,&Float:y,&Float:z)
{
	x = HOUSE_SKY_X + localX;
	y = HOUSE_SKY_Y + localY;
	z = HOUSE_SKY_Z + localZ;
}

stock Houses_WorldToLocal(Float:x,Float:y,Float:z,&Float:localX,&Float:localY,&Float:localZ)
{
	localX = x - HOUSE_SKY_X;
	localY = y - HOUSE_SKY_Y;
	localZ = z - HOUSE_SKY_Z;
}

stock Houses_GetWorld(house)
{
	return HOUSE_WORLD_BASE + house;
}

stock bool:Houses_IsValid(house)
{
	return house >= 0 && house < HOUSE_SEED_COUNT;
}

stock Houses_FindByKey(const key[])
{
	for (new i = 0;i < HOUSE_SEED_COUNT;i++)
	{
		if (!strcmp(g_HouseDefs[i][E_HOUSE_DEF_KEY],key,true))
		{
			return i;
		}
	}

	return -1;
}

stock bool:Houses_GetDoorPose(house,&Float:x,&Float:y,&Float:z,&Float:angle)
{
    if (!Houses_IsValid(house))
    {
        return false;
    }
    x = g_HouseDefs[house][E_HOUSE_DEF_DOOR][0];
    y = g_HouseDefs[house][E_HOUSE_DEF_DOOR][1];
    z = g_HouseDefs[house][E_HOUSE_DEF_DOOR][2];
    angle = g_HouseDefs[house][E_HOUSE_DEF_DOOR][3];
    return true;
}

stock Houses_GetName(house,dest[],size = sizeof(dest))
{
	if (!Houses_IsValid(house))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,g_HouseDefs[house][E_HOUSE_DEF_NAME],size);
}

stock Houses_GetKey(house,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (house >= 0 && house < HOUSE_SEED_COUNT)
	{
		strcopy(dest,g_HouseDefs[house][E_HOUSE_DEF_KEY],size);
	}
}

stock bool:Houses_IsTavern(house)
{
	new key[16];
	Houses_GetKey(house,key);
	return strfind(key,"tavern",true) != -1;
}

stock bool:Houses_IsInRoomBox(room,Float:localX,Float:localY,Float:localZ,bool:isFreeZone = false)
{
	new Float:box[6];

	for (new i = 0;i < 6;i++)
	{
		box[i] = isFreeZone ? g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_FREE][i] : g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_BOX][i];
	}

	return localX >= box[0] && localX <= box[3] && localY >= box[1] && localY <= box[4] && localZ >= box[2] - 0.2 && localZ <= box[5];
}
