static Map:s_FishingWaterGrid;

static Fishing_WaterKey(Float:x,Float:y)
{
	return (floatround(x / FISHING_WATER_CELL,floatround_floor) + FISHING_WATER_GRID_SPAN) * (FISHING_WATER_GRID_SPAN * 2) + floatround(y / FISHING_WATER_CELL,floatround_floor) + FISHING_WATER_GRID_SPAN;
}

static Fishing_BuildWaterGrid()
{
	s_FishingWaterGrid = map_new();

	for (new i = 0;i < sizeof(g_FishingWaterCells);i++)
	{
		if (g_FishingWaterCells[i][E_FISHING_WATER_TYPE] != FISHING_WATER_NONE)
		{
			map_add(s_FishingWaterGrid,Fishing_WaterKey(g_FishingWaterCells[i][E_FISHING_WATER_X],g_FishingWaterCells[i][E_FISHING_WATER_Y]),i);
		}
	}
}

stock Fishing_WaterAt(Float:x,Float:y,&Float:level = 0.0)
{
	if (s_FishingWaterGrid == Map:0)
	{
		Fishing_BuildWaterGrid();
	}

	new key = Fishing_WaterKey(x,y);

	if (map_has_key(s_FishingWaterGrid,key))
	{
		new i = map_get(s_FishingWaterGrid,key);
		level = g_FishingWaterCells[i][E_FISHING_WATER_Z];
		return g_FishingWaterCells[i][E_FISHING_WATER_TYPE];
	}

	new Float:hitX, Float:hitY, Float:hitZ;

	if (CA_RayCastLine(x,y,300.0,x,y,-50.0,hitX,hitY,hitZ) == WATER_OBJECT)
	{
		level = hitZ;
		return FISHING_WATER_SEA;
	}

	return FISHING_WATER_NONE;
}

stock Fishing_FindWaterAhead(Float:x,Float:y,Float:angle,&Float:waterX,&Float:waterY,&Float:level)
{
	for (new Float:reach = FISHING_CAST_MIN;reach <= FISHING_CAST_MAX;reach += FISHING_CAST_STEP)
	{
		Util_GetOffsetPoint(x,y,angle,reach,waterX,waterY);
		new type = Fishing_WaterAt(waterX,waterY,level);

		if (type != FISHING_WATER_NONE && (type == FISHING_WATER_SEA || !Seasons_IsWaterFrozen()))
		{
			return type;
		}
	}

	return FISHING_WATER_NONE;
}

#pragma warning push
#pragma warning disable 204
forward Task:Fishing_SeedSpots();

async Task:Fishing_SeedSpots()
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT 1 FROM seeders WHERE seeder_key = '%e'",FISHING_SEED_KEY));

	if (cache_num_rows())
	{
		return async 0;
	}

	new sown = 0, kind = Work_FindKind(FISHING_NODE_KIND);

	for (new i = 0;i < FISHING_SEED_SPOTS && kind != -1;i++)
	{
		if (Work_FindNearestNode(g_FishingSeedSpots[i][0],g_FishingSeedSpots[i][1],g_FishingSeedSpots[i][2],0,FISHING_SEED_GAP) != -1)
		{
			continue;
		}

		new nodeid = await Work_CreateNode(kind,g_FishingSeedSpots[i][0],g_FishingSeedSpots[i][1],g_FishingSeedSpots[i][2],g_FishingSeedSpots[i][3],0,0);

		if (nodeid != -1)
		{
			sown++;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT IGNORE INTO seeders (seeder_key) VALUES ('%e')",FISHING_SEED_KEY));
	return async sown;
}
#pragma warning pop
