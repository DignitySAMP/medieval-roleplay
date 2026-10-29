#define HOUSE_WOODPILE_RACK (MODEL_INT_WOODRACK)
#define HOUSE_WOODPILE_RACK_SMALL (MODEL_INT_WOODRACK_SMALL)
#define HOUSE_WOODPILE_PILE (1463)

static STREAMER_TAG_OBJECT:s_HouseWoodpileRacks[HOUSE_WOODPILE_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static STREAMER_TAG_OBJECT:s_HouseWoodpilePiles[HOUSE_WOODPILE_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};

stock Houses_PlaceWoodpiles()
{
	for (new i = 0;i < HOUSE_WOODPILE_COUNT;i++)
	{
		new house = Houses_FindByKey(g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_HOUSE]);

		if (house == -1)
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:rz = g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_POS][3];
		Houses_LocalToWorld(g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_POS][0],g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_POS][1],g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_POS][2],x,y,z);
		if (g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_SMALL])
		{
			s_HouseWoodpileRacks[i] = CreateDynamicObject(HOUSE_WOODPILE_RACK_SMALL,x,y,z,0.0,0.0,rz,Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
			continue;
		}

		s_HouseWoodpileRacks[i] = CreateDynamicObject(HOUSE_WOODPILE_RACK,x,y,z,0.0,0.0,rz,Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
		s_HouseWoodpilePiles[i] = CreateDynamicObject(HOUSE_WOODPILE_PILE,x,y,z + HOUSE_WOODPILE_PILE_Z,0.0,0.0,rz,Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
	}
}

stock Houses_CountWoodpiles(house)
{
	new count = 0;

	for (new i = 0;i < HOUSE_WOODPILE_COUNT;i++)
	{
		if (IsValidDynamicObject(s_HouseWoodpileRacks[i]) && Houses_FindByKey(g_HouseWoodpileDefs[i][E_HOUSE_WOODPILE_DEF_HOUSE]) == house)
		{
			count++;
		}
	}

	return count;
}

stock STREAMER_TAG_OBJECT:Houses_GetWoodpileObject(index,bool:isPile)
{
	if (index < 0 || index >= HOUSE_WOODPILE_COUNT)
	{
		return STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	return isPile ? s_HouseWoodpilePiles[index] : s_HouseWoodpileRacks[index];
}
