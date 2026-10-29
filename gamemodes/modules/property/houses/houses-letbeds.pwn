#define HOUSE_LETBED_COUNT (4)
#define HOUSE_LETBED_MODEL (MODEL_FURNITURE_BED)
#define HOUSE_LETBED_MATTRESS (0.45)
#define HOUSE_LETBED_LIE_OFFSET (0.05)

enum E_HOUSE_LETBED_DEF
{
	E_HOUSE_LETBED_DEF_ROOM[32],
	Float:E_HOUSE_LETBED_DEF_POS[4],
}

static const s_HouseLetBedDefs[HOUSE_LETBED_COUNT][E_HOUSE_LETBED_DEF] = {
	{"tb_crofter:loft_corner", {5.300, 1.150, 3.600, 180.0}},
	{"tb_weaver:loft_corner", {4.500, 1.150, 3.600, 180.0}},
	{"tb_reeve:guest_chamber", {3.700, 1.150, 3.600, 180.0}},
	{"tb_carpenter:loft_corner", {5.400, 1.150, 3.600, 180.0}}
};

static s_HouseLetBedRooms[HOUSE_LETBED_COUNT] = {-1, ...};
static STREAMER_TAG_OBJECT:s_HouseLetBedObjects[HOUSE_LETBED_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};

stock Houses_PlaceLetBeds()
{
	for (new i = 0;i < HOUSE_LETBED_COUNT;i++)
	{
		new room = Houses_FindRoomByKey(s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_ROOM]);
		s_HouseLetBedRooms[i] = room;

		if (room == -1)
		{
			continue;
		}

		new house = g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE], Float:x, Float:y, Float:z;
		Houses_LocalToWorld(s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][0],s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][1],s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][2],x,y,z);
		s_HouseLetBedObjects[i] = CreateDynamicObject(HOUSE_LETBED_MODEL,x,y,z,0.0,0.0,s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][3],Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
	}
}

stock Houses_FindRoomLetBed(room)
{
	for (new i = 0;i < HOUSE_LETBED_COUNT;i++)
	{
		if (room != -1 && s_HouseLetBedRooms[i] == room)
		{
			return HOUSE_SEED_BEDS + i;
		}
	}

	return -1;
}

stock bool:Houses_IsLetBedPlaced(bed)
{
	new i = bed - HOUSE_SEED_BEDS;
	return i >= 0 && i < HOUSE_LETBED_COUNT && IsValidDynamicObject(s_HouseLetBedObjects[i]);
}

stock Houses_GetBedCapacity(bed)
{
    if (bed < 0 || bed >= HOUSE_SEED_BEDS)
    {
        return 0;
    }

    if (strfind(g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_WHO]," and ") != -1 || strfind(g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_WHO],"twins") != -1 || strfind(g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_WHO],"couple") != -1 || strfind(g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_WHO],"the sons") != -1 || strfind(g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_WHO],"little ones") != -1 || strfind(g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_WHO],"two smallest") != -1)
    {
        return 2;
    }

    return 1;
}

stock bool:Houses_GetBedPose(bed,&Float:x,&Float:y,&Float:z,&Float:a)
{
	if (bed >= 0 && bed < HOUSE_SEED_BEDS)
	{
		x = g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_POS][0];
		y = g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_POS][1];
		z = g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_POS][2];
		a = g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_POS][3];
		return true;
	}

	new i = bed - HOUSE_SEED_BEDS;

	if (i < 0 || i >= HOUSE_LETBED_COUNT)
	{
		return false;
	}

	new Float:rz = s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][3];
	x = s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][0] + HOUSE_LETBED_LIE_OFFSET * floatcos(rz,degrees);
	y = s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][1] + HOUSE_LETBED_LIE_OFFSET * floatsin(rz,degrees);
	z = s_HouseLetBedDefs[i][E_HOUSE_LETBED_DEF_POS][2] + HOUSE_LETBED_MATTRESS;
	a = floatfract((rz + 180.0) / 360.0) * 360.0;
	return true;
}

stock Houses_GetBedStyle(bed,dest[],size = sizeof(dest))
{
	if (bed >= 0 && bed < HOUSE_SEED_BEDS)
	{
		strcopy(dest,g_HouseBedDefs[bed][E_HOUSE_POSE_DEF_STYLE],size);
		return;
	}

	strcopy(dest,"BED_Loop_R",size);
}
