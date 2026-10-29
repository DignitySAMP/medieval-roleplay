#define MAP_STRIP_RADIUS (2500.0)
#define MAP_EDGE_STRIP_X (1075.0)
#define MAP_EDGE_STRIP_Y (-2500.0)
#define MAP_EDGE_STRIP_Z (0.0)
#define MAP_EDGE_STRIP_RADIUS (1750.0)

#define MAP_MODEL_FIRST (-2001)
#define MAP_MODEL_SLOTS (1000)
#define MAP_MAINLAND_MODEL_FIRST (-12001)
#define MAP_MAINLAND_MODEL_SLOTS (999)
#define MAP_SPLIT_MODEL_FIRST (-13300)
#define MAP_SPLIT_MODEL_SLOTS (700)
#define MAP_EDGE_MODEL_FIRST (-12101)
#define MAP_EDGE_MODEL_LAST (-12399)
#define MAP_STREAM_PRIORITY (1)
#define MAP_VEGETATION_BASE (16403)
#define MAP_DECAL_BASE (16014)
#define MAP_DETAIL_PRIORITY (-2)
#define MAP_DECAL_DISTANCE (300.0)
#define MAP_BUILT_DISTANCE (600.0)
#define MAP_VEGETATION_DISTANCE (400.0)
#define MAP_MODEL_NAME_LENGTH (64)

static s_MapColModels = 0;
static s_MapColObjects = 0;

static STREAMER_TAG_OBJECT:s_MapModelObjects[MAP_MODEL_SLOTS + MAP_MAINLAND_MODEL_SLOTS + MAP_SPLIT_MODEL_SLOTS] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static bool:s_MapModelIsVegetation[MAP_MODEL_SLOTS + MAP_MAINLAND_MODEL_SLOTS + MAP_SPLIT_MODEL_SLOTS];
static bool:s_MapModelIsBackfill[MAP_MODEL_SLOTS + MAP_MAINLAND_MODEL_SLOTS + MAP_SPLIT_MODEL_SLOTS];
static Float:s_MapModelDistances[MAP_MODEL_SLOTS + MAP_MAINLAND_MODEL_SLOTS + MAP_SPLIT_MODEL_SLOTS];

static Map_GetModelSlot(modelid)
{
	if (modelid <= MAP_MODEL_FIRST && modelid > MAP_MODEL_FIRST - MAP_MODEL_SLOTS)
	{
		return MAP_MODEL_FIRST - modelid;
	}

	if (modelid <= MAP_MAINLAND_MODEL_FIRST && modelid > MAP_MAINLAND_MODEL_FIRST - MAP_MAINLAND_MODEL_SLOTS)
	{
		return MAP_MODEL_SLOTS + MAP_MAINLAND_MODEL_FIRST - modelid;
	}

	if (modelid <= MAP_SPLIT_MODEL_FIRST && modelid > MAP_SPLIT_MODEL_FIRST - MAP_SPLIT_MODEL_SLOTS)
	{
		return MAP_MODEL_SLOTS + MAP_MAINLAND_MODEL_SLOTS + MAP_SPLIT_MODEL_FIRST - modelid;
	}

	return -1;
}

stock bool:Map_IsLodModel(modelid)
{
    return (modelid <= MAP_LOD_FIRST && modelid >= MAP_LOD_LAST) || (modelid <= -12812 && modelid >= -12814);
}

stock bool:Map_IsMapModel(modelid)
{
	return Map_GetModelSlot(modelid) != -1 || Map_IsLodModel(modelid);
}

stock Map_GetOriginalModel(modelid)
{
    new low = 0, high = sizeof(g_MapSeasonalModels) - 1;

    while (low <= high)
    {
        new middle = (low + high) / 2;

        if (g_MapSeasonalModels[middle][0] == modelid)
        {
            return g_MapSeasonalModels[middle][1];
        }

        if (g_MapSeasonalModels[middle][0] < modelid)
        {
            low = middle + 1;
        }
        else
        {
            high = middle - 1;
        }
    }

    return modelid;
}

stock bool:Map_IsEdgeRingModel(modelid)
{
    modelid = Map_GetOriginalModel(modelid);
	return modelid <= MAP_EDGE_MODEL_FIRST && modelid >= MAP_EDGE_MODEL_LAST;
}

stock bool:Map_IsVegetationModel(modelid)
{
	new slot = Map_GetModelSlot(modelid);
	return slot != -1 && s_MapModelIsVegetation[slot];
}

static bool:Map_IsListed(const list[][],count,const name[])
{
	new low = 0, high = count - 1;

	while (low <= high)
	{
		new middle = (low + high) / 2, order = strcmp(list[middle],name);

		if (order == 0)
		{
			return true;
		}

		if (order < 0)
		{
			low = middle + 1;
		}
		else
		{
			high = middle - 1;
		}
	}

	return false;
}

static Float:Map_GetListedDistance(const dff[])
{
	new start = 0, length = strlen(dff), name[MAP_MODEL_NAME_LENGTH];

	for (new i = 0; i < length; i++)
	{
		if (dff[i] == '/')
		{
			start = i + 1;
		}
	}

	strmid(name,dff,start,length - 4);

	if (Map_IsListed(g_MapDecalModels,sizeof(g_MapDecalModels),name))
	{
		return MAP_DECAL_DISTANCE;
	}

	if (Map_IsListed(g_MapBuiltModels,sizeof(g_MapBuiltModels),name))
	{
		return MAP_BUILT_DISTANCE;
	}

	if (Map_IsListed(g_MapVegetationModels,sizeof(g_MapVegetationModels),name))
	{
		return MAP_VEGETATION_DISTANCE;
	}

	return 0.0;
}

stock Map_GetCollisionModelCount()
{
	return s_MapColModels;
}

stock Map_GetCollisionObjectCount()
{
	return s_MapColObjects;
}

stock Float:Map_GetDetailLodDistance(modelid)
{
    new low = 0, high = sizeof(g_MapLodDetailModels) - 1;

    while (low <= high)
    {
        new middle = (low + high) / 2;

        if (g_MapLodDetailModels[middle] == modelid)
        {
            return g_MapLodDetailDistances[middle];
        }

        if (g_MapLodDetailModels[middle] < modelid)
        {
            low = middle + 1;
        }
        else
        {
            high = middle - 1;
        }
    }

    return 0.0;
}

stock Float:Map_GetModelDistance(modelid)
{
    if (Map_IsLodModel(modelid))
    {
        return MAP_LOD_DISTANCE;
    }

    new Float:detail = Map_GetDetailLodDistance(modelid);

    if (detail > 0.0)
    {
        return detail;
    }

    modelid = Map_GetOriginalModel(modelid);

	new slot = Map_GetModelSlot(modelid);

	if (slot == -1)
	{
		return 0.0;
	}

	return s_MapModelDistances[slot];
}

stock STREAMER_TAG_OBJECT:Map_GetModelObject(modelid)
{
	new slot = Map_GetModelSlot(modelid);

	if (slot == -1)
	{
		return STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	return s_MapModelObjects[slot];
}

bool:Map_AddSimpleModel(virtualWorld,baseid,newid,const dff[],const textureLibrary[])
{
	if (CA_LoadFromDff(newid,dff) == 1)
	{
		s_MapColModels++;
	}
	else
	{
		Log_Warn("map","no collision for model %d (%s)",newid,dff);
	}

	new slot = Map_GetModelSlot(newid);

	if (slot != -1)
	{
		s_MapModelDistances[slot] = Map_GetDetailLodDistance(newid);

        if (s_MapModelDistances[slot] == 0.0)
        {
            s_MapModelDistances[slot] = Map_IsEdgeRingModel(newid) ? 0.0 : Map_GetListedDistance(dff);
        }
		s_MapModelIsVegetation[slot] = baseid == MAP_VEGETATION_BASE;
		s_MapModelIsBackfill[slot] = (baseid == MAP_VEGETATION_BASE || baseid == MAP_DECAL_BASE) && !Map_IsEdgeRingModel(newid);
	}

	return AddSimpleModel(virtualWorld,baseid,newid,dff,textureLibrary);
}

STREAMER_TAG_OBJECT:Map_CreateDynamicObject(modelid,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz,worldid = -1,interiorid = -1,playerid = -1,Float:streamdistance = STREAMER_OBJECT_SD,Float:drawdistance = STREAMER_OBJECT_DD,STREAMER_TAG_AREA:areaid = STREAMER_TAG_AREA:-1,priority = MAP_STREAM_PRIORITY)
{
	new index = CA_CreateObject(modelid,x,y,z,rx,ry,rz,true);

	if (index >= 0 && index != 0xFFFF)
	{
		s_MapColObjects++;
	}

	new slot = Map_GetModelSlot(modelid);
    new Float:detailDistance = Map_GetDetailLodDistance(modelid);

    if (detailDistance > 0.0)
    {
        streamdistance = detailDistance;
        drawdistance = detailDistance;
    }

	if (slot != -1 && s_MapModelDistances[slot] > 0.0)
	{
		if (streamdistance > s_MapModelDistances[slot])
		{
			streamdistance = s_MapModelDistances[slot];
		}

		if (drawdistance > s_MapModelDistances[slot])
		{
			drawdistance = s_MapModelDistances[slot];
		}
	}

	if (slot != -1 && priority == MAP_STREAM_PRIORITY && s_MapModelIsBackfill[slot])
	{
		priority = MAP_DETAIL_PRIORITY;
	}

	new STREAMER_TAG_OBJECT:objectid = CreateDynamicObject(modelid,x,y,z,rx,ry,rz,worldid,interiorid,playerid,streamdistance,drawdistance,areaid,priority);

	if (slot != -1)
	{
		s_MapModelObjects[slot] = objectid;
	}

	return objectid;
}
