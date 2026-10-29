#define WORK_DECOR_PER_NODE_MIN (3)
#define WORK_DECOR_PER_NODE_MAX (6)
#define WORK_DECOR_RING_MIN (0.9)
#define WORK_DECOR_RING_MAX (2.0)
#define WORK_DECOR_GAP (0.5)
#define WORK_DECOR_MIMIC_CHANCE (60)
#define WORK_DECOR_DRIFTS (24)
#define WORK_DECOR_DRIFT_MIN (5)
#define WORK_DECOR_DRIFT_MAX (9)
#define WORK_DECOR_DRIFT_RADIUS (1.75)
#define WORK_DECOR_DRIFT_GAP (0.6)
#define WORK_DECOR_TWIN_CLEAR (6.0)
#define WORK_DECOR_STREAM (60.0)
#define WORK_DECOR_PRIORITY (-1)
#define WORK_DECOR_TRIES (24)

enum E_WORK_HERB_DECOR_DEF
{
	E_WORK_HERB_DECOR_DEF_SPECIES,
	E_WORK_HERB_DECOR_DEF_MODELS[3],
	E_WORK_HERB_DECOR_DEF_DRIFT,
}

static const s_WorkHerbDecorDefs[][E_WORK_HERB_DECOR_DEF] = {
	{WORK_HERB_POPPY, {MODEL_HERBS_DEC_POPPY_A, MODEL_HERBS_DEC_POPPY_B, MODEL_HERBS_DEC_POPPY_C}, WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE},
	{WORK_HERB_FOXGLOVE, {MODEL_HERBS_DEC_FOXGLOVE_A, MODEL_HERBS_DEC_FOXGLOVE_B, MODEL_HERBS_DEC_FOXGLOVE_C}, WORK_HABITAT_EDGE},
	{WORK_HERB_STJOHNS, {MODEL_HERBS_DEC_STJOHNS_A, MODEL_HERBS_DEC_STJOHNS_B, MODEL_HERBS_DEC_STJOHNS_C}, WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE},
	{WORK_HERB_CHAMOMILE, {MODEL_HERBS_DEC_CHAMOMILE_A, MODEL_HERBS_DEC_CHAMOMILE_B, MODEL_HERBS_DEC_CHAMOMILE_C}, WORK_HABITAT_MEADOW | WORK_HABITAT_VILLAGE},
	{WORK_HERB_WOLFSBANE, {MODEL_HERBS_DEC_WOLFSBANE_A, MODEL_HERBS_DEC_WOLFSBANE_B, MODEL_HERBS_DEC_WOLFSBANE_C}, 0},
	{WORK_HERB_YARROW, {MODEL_HERBS_DEC_YARROW_A, MODEL_HERBS_DEC_YARROW_B, MODEL_HERBS_DEC_YARROW_C}, WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE},
	{WORK_HERB_VALERIAN, {MODEL_HERBS_DEC_VALERIAN_A, MODEL_HERBS_DEC_VALERIAN_B, MODEL_HERBS_DEC_VALERIAN_C}, WORK_HABITAT_WET},
	{WORK_HERB_AGRIMONY, {MODEL_HERBS_DEC_AGRIMONY_A, MODEL_HERBS_DEC_AGRIMONY_B, MODEL_HERBS_DEC_AGRIMONY_C}, WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE},
	{WORK_HERB_BETONY, {MODEL_HERBS_DEC_BETONY_A, MODEL_HERBS_DEC_BETONY_B, MODEL_HERBS_DEC_BETONY_C}, WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE}
};

enum E_WORK_DRIFT
{
	E_WORK_DRIFT_SPECIES,
	E_WORK_DRIFT_SPOT,
	E_WORK_DRIFT_COUNT,
	STREAMER_TAG_OBJECT:E_WORK_DRIFT_OBJECTS[WORK_DECOR_DRIFT_MAX],
}

static STREAMER_TAG_OBJECT:s_WorkNodeDecor[WORK_MAX_NODES][WORK_DECOR_PER_NODE_MAX];
static s_WorkDrifts[WORK_DECOR_DRIFTS][E_WORK_DRIFT];
static s_WorkDriftCount;

stock Work_FindHerbDecor(species)
{
	for (new i = 0;i < sizeof(s_WorkHerbDecorDefs);i++)
	{
		if (s_WorkHerbDecorDefs[i][E_WORK_HERB_DECOR_DEF_SPECIES] == species)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Work_IsHerbMimicked(species)
{
	for (new other = 0;other < WORK_HERB_COUNT;other++)
	{
		if (other != species && Work_GetHerbTwin(other) == species)
		{
			return true;
		}
	}

	return false;
}

static bool:Work_AreHerbTwins(a,b)
{
	return a != b && (Work_GetHerbTwin(a) == b || Work_GetHerbTwin(b) == a);
}

static STREAMER_TAG_OBJECT:Work_CreateDecor(model,Float:x,Float:y,Float:z,world,interior)
{
	new Float:hx, Float:hy, Float:hz;

	if (CA_RayCastLine(x,y,z + 1.5,x,y,z - 2.0,hx,hy,hz) != 0)
	{
		z = hz;
	}

	return CreateDynamicObject(model,x,y,z,0.0,0.0,float(random(360)),world,interior,-1,WORK_DECOR_STREAM,WORK_DECOR_STREAM,STREAMER_TAG_AREA:-1,WORK_DECOR_PRIORITY);
}

static bool:Work_IsDecorClear(const Float:taken[][2],count,Float:x,Float:y,Float:gap)
{
	for (new i = 0;i < count;i++)
	{
		if (VectorSize(taken[i][0] - x,taken[i][1] - y,0.0) < gap)
		{
			return false;
		}
	}

	return true;
}

static Work_ScatterDecor(decor,Float:cx,Float:cy,Float:cz,world,interior,Float:inner,Float:outer,Float:gap,want,STREAMER_TAG_OBJECT:out[])
{
	new Float:taken[WORK_DECOR_DRIFT_MAX][2], count = 0;

	for (new try = 0;try < WORK_DECOR_TRIES && count < want;try++)
	{
		new Float:angle = float(random(360)), Float:radius = inner + (outer - inner) * float(random(1001)) / 1000.0;
		new Float:x = cx + radius * floatcos(angle,degrees), Float:y = cy + radius * floatsin(angle,degrees);

		if (!Work_IsDecorClear(taken,count,x,y,gap))
		{
			continue;
		}

		new variant = count == 0 ? 2 : random(2);
		out[count] = Work_CreateDecor(s_WorkHerbDecorDefs[decor][E_WORK_HERB_DECOR_DEF_MODELS][variant],x,y,cz,world,interior);
		taken[count][0] = x;
		taken[count][1] = y;
		count++;
	}

	return count;
}

stock Work_PlaceNodeDecor(nodeid)
{
	Work_ClearNodeDecor(nodeid);

	new species = Work_GetNodeHerb(nodeid), decor = Work_FindHerbDecor(species);

	if (decor == -1 || (Work_IsHerbMimicked(species) && random(100) >= WORK_DECOR_MIMIC_CHANCE))
	{
		return 0;
	}

	new Float:x, Float:y, Float:z;
	Work_GetNodePos(nodeid,x,y,z);
	return Work_ScatterDecor(decor,x,y,z,Work_GetNodeWorld(nodeid),Work_GetNodeInterior(nodeid),WORK_DECOR_RING_MIN,WORK_DECOR_RING_MAX,WORK_DECOR_GAP,Util_RandomRange(WORK_DECOR_PER_NODE_MIN,WORK_DECOR_PER_NODE_MAX),s_WorkNodeDecor[nodeid]);
}

stock Work_ClearNodeDecor(nodeid)
{
	if (nodeid < 0 || nodeid >= WORK_MAX_NODES)
	{
		return;
	}

	for (new i = 0;i < WORK_DECOR_PER_NODE_MAX;i++)
	{
		if (IsValidDynamicObject(s_WorkNodeDecor[nodeid][i]))
		{
			DestroyDynamicObject(s_WorkNodeDecor[nodeid][i]);
		}

		s_WorkNodeDecor[nodeid][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

stock Work_CountNodeDecor(nodeid)
{
	new count = 0;

	for (new i = 0;nodeid >= 0 && nodeid < WORK_MAX_NODES && i < WORK_DECOR_PER_NODE_MAX;i++)
	{
		if (IsValidDynamicObject(s_WorkNodeDecor[nodeid][i]))
		{
			count++;
		}
	}

	return count;
}

stock Work_ClearHerbDrifts()
{
	for (new d = 0;d < s_WorkDriftCount;d++)
	{
		for (new i = 0;i < s_WorkDrifts[d][E_WORK_DRIFT_COUNT];i++)
		{
			if (IsValidDynamicObject(s_WorkDrifts[d][E_WORK_DRIFT_OBJECTS][i]))
			{
				DestroyDynamicObject(s_WorkDrifts[d][E_WORK_DRIFT_OBJECTS][i]);
			}
		}

		Work_FreeWildSpot(s_WorkDrifts[d][E_WORK_DRIFT_SPOT]);
	}

	s_WorkDriftCount = 0;
}

static bool:Work_IsNearHerbTwin(species,Float:x,Float:y,Float:z)
{
	for (new nodeid = 0;nodeid < WORK_MAX_NODES;nodeid++)
	{
		new other = Work_GetNodeHerb(nodeid), Float:nx, Float:ny, Float:nz;

		if (other == -1 || !Work_AreHerbTwins(species,other) || !Work_GetNodePos(nodeid,nx,ny,nz))
		{
			continue;
		}

		if (Util_GetDistance3D(x,y,z,nx,ny,nz) < WORK_DECOR_TWIN_CLEAR + WORK_DECOR_DRIFT_RADIUS)
		{
			return true;
		}
	}

	return false;
}

static Work_PickDriftHerb(habitat,E_SEASON:season)
{
	new choices[sizeof(s_WorkHerbDecorDefs)], count = 0;

	for (new i = 0;i < sizeof(s_WorkHerbDecorDefs);i++)
	{
		new species = s_WorkHerbDecorDefs[i][E_WORK_HERB_DECOR_DEF_SPECIES];

		if ((s_WorkHerbDecorDefs[i][E_WORK_HERB_DECOR_DEF_DRIFT] & habitat) != 0 && Work_IsHerbInSeason(species,season))
		{
			choices[count++] = i;
		}
	}

	return count == 0 ? -1 : choices[random(count)];
}

stock Work_ScatterHerbDrifts()
{
	Work_ClearHerbDrifts();

	new E_SEASON:season = Calendar_GetSeason();

	for (new try = 0;try < WORK_WILD_PICK_TRIES && s_WorkDriftCount < WORK_DECOR_DRIFTS;try++)
	{
		new spot = Work_TakeDriftSpot();

		if (spot == -1)
		{
			break;
		}

		new Float:x, Float:y, Float:z, habitat = Work_GetSpotInfo(spot,x,y,z), decor = Work_PickDriftHerb(habitat,season);

		if (decor == -1 || Work_IsNearHerbTwin(s_WorkHerbDecorDefs[decor][E_WORK_HERB_DECOR_DEF_SPECIES],x,y,z))
		{
			Work_FreeWildSpot(spot);
			continue;
		}

		new d = s_WorkDriftCount++;
		s_WorkDrifts[d][E_WORK_DRIFT_SPECIES] = s_WorkHerbDecorDefs[decor][E_WORK_HERB_DECOR_DEF_SPECIES];
		s_WorkDrifts[d][E_WORK_DRIFT_SPOT] = spot;
		s_WorkDrifts[d][E_WORK_DRIFT_COUNT] = Work_ScatterDecor(decor,x,y,z,0,0,0.0,WORK_DECOR_DRIFT_RADIUS,WORK_DECOR_DRIFT_GAP,Util_RandomRange(WORK_DECOR_DRIFT_MIN,WORK_DECOR_DRIFT_MAX),s_WorkDrifts[d][E_WORK_DRIFT_OBJECTS]);
	}

	return s_WorkDriftCount;
}

stock Work_GetHerbDriftCount()
{
	return s_WorkDriftCount;
}

stock Work_GetHerbDrift(index,&species,&Float:x,&Float:y,&Float:z)
{
	if (index < 0 || index >= s_WorkDriftCount)
	{
		return 0;
	}

	species = s_WorkDrifts[index][E_WORK_DRIFT_SPECIES];
	Work_GetSpotInfo(s_WorkDrifts[index][E_WORK_DRIFT_SPOT],x,y,z);
	return s_WorkDrifts[index][E_WORK_DRIFT_COUNT];
}

forward Work_LoadHerbDriftsOnBoot();

public Work_LoadHerbDriftsOnBoot()
{
	yield 1;

	new drifts = Work_ScatterHerbDrifts(), decorated = 0;

	for (new nodeid = 0;nodeid < WORK_MAX_NODES;nodeid++)
	{
		if (Work_CountNodeDecor(nodeid) > 0)
		{
			decorated++;
		}
	}

	Log_Info("workstations","%d herb node(s) in flower, %d meadow drift(s)",decorated,drifts);
	Boot_LoaderDone();
}
