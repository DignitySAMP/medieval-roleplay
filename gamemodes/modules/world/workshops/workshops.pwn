#define WORKSHOPS_PLACED (1)
#define WORKSHOPS_TICK_MS (1000)
#define WORKSHOPS_SHELL_RANGE (600.0)
#define WORKSHOPS_DECAL_RANGE (300.0)
#define WORKSHOPS_PROP_RANGE (250.0)
#define WORKSHOPS_TAILOR_HOUSE "tb_tailor"
#define WORKSHOPS_CLEAR_SHELL (6.0)
#define WORKSHOPS_CLEAR_PROP (2.0)

static STREAMER_TAG_OBJECT:s_WorkshopObjects[WORKSHOP_OBJECT_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static STREAMER_TAG_OBJECT:s_WorkshopTailor[WORKSHOP_TAILOR_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static s_WorkshopColliders[WORKSHOP_OBJECT_COUNT] = {-1, ...};
static s_WorkshopShellsLoaded = 0;
static s_WorkshopDecalModel[WORKSHOP_OBJECT_COUNT];
static E_SEASONS_LOOK:s_WorkshopLook = SEASONS_LOOK_NONE;
static s_WorkshopStage = 0;

stock bool:Workshops_IsPlaced(site)
{
	return site >= 0 && site < WORKSHOP_SITE_COUNT && WORKSHOPS_PLACED == 1;
}

stock Workshops_GetObjectCount()
{
	new count = 0;

	for (new i = 0;i < WORKSHOP_OBJECT_COUNT;i++)
	{
		if (IsValidDynamicObject(s_WorkshopObjects[i]))
		{
			count++;
		}
	}

	return count;
}

stock Workshops_GetTailorCount()
{
	new count = 0;

	for (new i = 0;i < WORKSHOP_TAILOR_COUNT;i++)
	{
		if (IsValidDynamicObject(s_WorkshopTailor[i]))
		{
			count++;
		}
	}

	return count;
}

stock Workshops_GetColliderCount()
{
	new count = 0;

	for (new i = 0;i < WORKSHOP_OBJECT_COUNT;i++)
	{
		if (s_WorkshopColliders[i] != -1)
		{
			count++;
		}
	}

	return count;
}

stock Workshops_GetShellsLoaded()
{
	return s_WorkshopShellsLoaded;
}

stock STREAMER_TAG_OBJECT:Workshops_GetObject(index)
{
	return index >= 0 && index < WORKSHOP_OBJECT_COUNT ? s_WorkshopObjects[index] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock STREAMER_TAG_OBJECT:Workshops_GetTailorObject(index)
{
	return index >= 0 && index < WORKSHOP_TAILOR_COUNT ? s_WorkshopTailor[index] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock bool:Workshops_IsWorkshopModel(model)
{
	for (new i = 0;i < WORKSHOP_MODEL_COUNT;i++)
	{
		if (g_WorkshopModels[i] == model)
		{
			return true;
		}
	}

	return false;
}

stock Workshops_FindSpot(site,const name[])
{
	for (new i = 0;i < WORKSHOP_SPOT_COUNT;i++)
	{
		if (g_WorkshopSpots[i][E_WORKSHOP_SPOT_SITE] == site && !strcmp(g_WorkshopSpots[i][E_WORKSHOP_SPOT_NAME],name))
		{
			return i;
		}
	}

	return -1;
}

stock Workshops_GetSpotSite(spot)
{
	return spot >= 0 && spot < WORKSHOP_SPOT_COUNT ? g_WorkshopSpots[spot][E_WORKSHOP_SPOT_SITE] : -1;
}

stock bool:Workshops_GetSpotPose(spot,&Float:x,&Float:y,&Float:z,&Float:a,&world,&interior)
{
	if (spot < 0 || spot >= WORKSHOP_SPOT_COUNT)
	{
		return false;
	}

	x = g_WorkshopSpots[spot][E_WORKSHOP_SPOT_POS][0];
	y = g_WorkshopSpots[spot][E_WORKSHOP_SPOT_POS][1];
	z = g_WorkshopSpots[spot][E_WORKSHOP_SPOT_POS][2];
	a = g_WorkshopSpots[spot][E_WORKSHOP_SPOT_POS][3];
	world = 0;
	interior = 0;

	if (g_WorkshopSites[g_WorkshopSpots[spot][E_WORKSHOP_SPOT_SITE]][E_WORKSHOP_SITE_INTERIOR])
	{
		new house = Houses_FindByKey(g_WorkshopSites[g_WorkshopSpots[spot][E_WORKSHOP_SPOT_SITE]][E_WORKSHOP_SITE_HOUSE]);

		if (house == -1)
		{
			return false;
		}

		Houses_LocalToWorld(x,y,z,x,y,z);
		world = Houses_GetWorld(house);
		interior = HOUSE_INTERIOR;
	}

	return true;
}

stock Workshops_GetDecalIndex(model)
{
	for (new d = 0;d < WORKSHOP_DECAL_COUNT;d++)
	{
		if (g_WorkshopDecals[d][E_WORKSHOP_DECAL_BASE] == model)
		{
			return d;
		}
	}

	return -1;
}

stock Workshops_GetDecalTarget(decal,E_SEASONS_LOOK:look,stage)
{
	if (look == SEASONS_LOOK_AUTUMN)
	{
		return stage >= 2 ? g_WorkshopDecals[decal][E_WORKSHOP_DECAL_AUTUMN_LATE] : g_WorkshopDecals[decal][E_WORKSHOP_DECAL_AUTUMN];
	}

	return g_WorkshopDecals[decal][E_WORKSHOP_DECAL_BASE];
}

stock Workshops_GetDecalModel(index)
{
	return index >= 0 && index < WORKSHOP_OBJECT_COUNT ? s_WorkshopDecalModel[index] : 0;
}

static Workshops_LoadShell(model)
{
	for (new i = 0;i < WORKSHOP_SHELL_COUNT;i++)
	{
		if (g_WorkshopShells[i][E_WORKSHOP_SHELL_MODEL] == model)
		{
			if (CA_LoadFromDff(model,g_WorkshopShells[i][E_WORKSHOP_SHELL_DFF]) == 1)
			{
				s_WorkshopShellsLoaded++;
				return 1;
			}

			Log_Warn("workshops","no collision for model %d (%s)",model,g_WorkshopShells[i][E_WORKSHOP_SHELL_DFF]);
			return 0;
		}
	}

	return -1;
}

stock Workshops_ApplyLook(E_SEASONS_LOOK:look,stage)
{
	for (new i = 0;i < WORKSHOP_OBJECT_COUNT;i++)
	{
		if (g_WorkshopObjects[i][E_WORKSHOP_OBJECT_CLASS] != WORKSHOP_CLASS_DECAL || !IsValidDynamicObject(s_WorkshopObjects[i]))
		{
			continue;
		}

		new decal = Workshops_GetDecalIndex(g_WorkshopObjects[i][E_WORKSHOP_OBJECT_MODEL]);

		if (decal == -1)
		{
			continue;
		}

		new target = Workshops_GetDecalTarget(decal,look,stage);

		if (target == s_WorkshopDecalModel[i])
		{
			continue;
		}

		s_WorkshopDecalModel[i] = target;
		Streamer_SetIntData(STREAMER_TYPE_OBJECT,s_WorkshopObjects[i],E_STREAMER_MODEL_ID,target);
		Nearby_QueueStream(STREAMER_TYPE_OBJECT,g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][0],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][1],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][2],-1,-1,-1,WORKSHOPS_DECAL_RANGE);
	}

	s_WorkshopLook = look;
	s_WorkshopStage = stage;
}

stock Workshops_Place()
{
	new loaded[WORKSHOP_SHELL_COUNT];

	for (new i = 0;i < WORKSHOP_SHELL_COUNT;i++)
	{
		loaded[i] = Workshops_LoadShell(g_WorkshopShells[i][E_WORKSHOP_SHELL_MODEL]);
	}

	for (new i = 0;i < WORKSHOP_OBJECT_COUNT;i++)
	{
		new class = g_WorkshopObjects[i][E_WORKSHOP_OBJECT_CLASS], model = g_WorkshopObjects[i][E_WORKSHOP_OBJECT_MODEL];
		new Float:range = class == WORKSHOP_CLASS_SHELL ? WORKSHOPS_SHELL_RANGE : (class == WORKSHOP_CLASS_DECAL ? WORKSHOPS_DECAL_RANGE : WORKSHOPS_PROP_RANGE);
		s_WorkshopObjects[i] = CreateDynamicObject(model,g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][0],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][1],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][2],0.0,0.0,g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][3],-1,-1,-1,range,range,STREAMER_TAG_AREA:-1,class == WORKSHOP_CLASS_DECAL ? MAP_DETAIL_PRIORITY : MAP_STREAM_PRIORITY);
		s_WorkshopDecalModel[i] = model;

		if (class != WORKSHOP_CLASS_DECAL)
		{
			Work_KeepSpotsClear(g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][0],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][1],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][2],class == WORKSHOP_CLASS_SHELL ? WORKSHOPS_CLEAR_SHELL : WORKSHOPS_CLEAR_PROP);
		}

		if (class == WORKSHOP_CLASS_SHELL)
		{
			for (new s = 0;s < WORKSHOP_SHELL_COUNT;s++)
			{
				if (g_WorkshopShells[s][E_WORKSHOP_SHELL_MODEL] == model && loaded[s] == 1)
				{
					new index = CA_CreateObject(model,g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][0],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][1],g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][2],0.0,0.0,g_WorkshopObjects[i][E_WORKSHOP_OBJECT_POS][3],true);
					s_WorkshopColliders[i] = index >= 0 && index != 0xFFFF ? index : -1;
				}
			}
		}
	}

	Workshops_PlaceTailor();
	Log_Info("workshops","%d object(s) placed, %d with collision, %d interior prop(s), %d work spot(s)",Workshops_GetObjectCount(),Workshops_GetColliderCount(),Workshops_GetTailorCount(),WORKSHOP_SPOT_COUNT);
}

stock Workshops_PlaceTailor()
{
	new house = Houses_FindByKey(WORKSHOPS_TAILOR_HOUSE);

	if (house == -1)
	{
		Log_Warn("workshops","the tailor's house is not in the house table, its props wait");
		return;
	}

	for (new i = 0;i < WORKSHOP_TAILOR_COUNT;i++)
	{
		new Float:x, Float:y, Float:z;
		Houses_LocalToWorld(g_WorkshopTailor[i][E_WORKSHOP_OBJECT_POS][0],g_WorkshopTailor[i][E_WORKSHOP_OBJECT_POS][1],g_WorkshopTailor[i][E_WORKSHOP_OBJECT_POS][2],x,y,z);
		s_WorkshopTailor[i] = CreateDynamicObject(g_WorkshopTailor[i][E_WORKSHOP_OBJECT_MODEL],x,y,z,0.0,0.0,g_WorkshopTailor[i][E_WORKSHOP_OBJECT_POS][3],Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
	}
}

forward Workshops_Tick();

public Workshops_Tick()
{
	new E_SEASONS_LOOK:look = Seasons_GetLook(), stage = Seasons_GetStage();

	if (look != s_WorkshopLook || stage != s_WorkshopStage)
	{
		Workshops_ApplyLook(look,stage);
	}

	return 1;
}
