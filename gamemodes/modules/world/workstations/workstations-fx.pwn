#define WORK_FX_EMITTER (1.611)
#define WORK_FX_RANGE (60.0)
#define WORK_FX_BURST_MS (1500)
#define WORK_FX_BURST_SLOW_MS (3500)
#define WORK_FX_BURST_MAX (64)
#define WORK_FX_STAGE_MAX (2)
#define WORK_FX_VERBS_LEN (48)
#define WORK_FX_AT_PART (-1.0)

#define WORK_FX_MODEL_FLAME (18693)
#define WORK_FX_MODEL_PUFF (18677)
#define WORK_FX_MODEL_STEAM (18735)
#define WORK_FX_MODEL_WISP (18736)
#define WORK_FX_MODEL_SMOKE_GREY (18726)
#define WORK_FX_MODEL_SMOKE_PALE (18727)
#define WORK_FX_MODEL_SPARKS (18717)
#define WORK_FX_MODEL_EMBERS (18718)

enum E_WORK_FX_MODE
{
	WORK_FX_BURST,
	WORK_FX_STAGE,
	WORK_FX_FUELLED,
}

enum E_WORK_FX_DEF
{
	E_WORK_FX_DEF_KIND[WORK_KIND_KEY_LEN],
	E_WORK_FX_DEF_VERBS[WORK_FX_VERBS_LEN],
	E_WORK_FX_DEF_MODEL,
	E_WORK_FX_MODE:E_WORK_FX_DEF_MODE,
	Float:E_WORK_FX_DEF_HEIGHT,
}

static const s_WorkFxDefs[][E_WORK_FX_DEF] = {
	{"anvil", "draw|shape|bend|forge|raise|punch|eye", WORK_FX_MODEL_SPARKS, WORK_FX_BURST, WORK_FX_AT_PART},
	{"anvil", "quench", WORK_FX_MODEL_STEAM, WORK_FX_BURST, WORK_FX_AT_PART},
	{"anvil", "grind", WORK_FX_MODEL_EMBERS, WORK_FX_BURST, WORK_FX_AT_PART},
	{"forge", "cast", WORK_FX_MODEL_EMBERS, WORK_FX_BURST, WORK_FX_AT_PART},
	{"forge", "cast", WORK_FX_MODEL_PUFF, WORK_FX_BURST, WORK_FX_AT_PART},
	{"bloomery", "hammer", WORK_FX_MODEL_SPARKS, WORK_FX_BURST, WORK_FX_AT_PART},
	{"bloomery", "charge", WORK_FX_MODEL_WISP, WORK_FX_BURST, 1.0},
	{"kiln", "fire", WORK_FX_MODEL_SMOKE_GREY, WORK_FX_STAGE, 1.0},
	{"kiln", "mould|strike", WORK_FX_MODEL_PUFF, WORK_FX_BURST, 1.1},
	{"clamp", "light|tend", WORK_FX_MODEL_SMOKE_GREY, WORK_FX_STAGE, 0.8},
	{"smokehouse", "smoke", WORK_FX_MODEL_SMOKE_PALE, WORK_FX_STAGE, 1.0},
	{"oven", "bake", WORK_FX_MODEL_SMOKE_PALE, WORK_FX_STAGE, 1.0},
	{"hearth", "stir|season|ladle|tip in", WORK_FX_MODEL_WISP, WORK_FX_BURST, WORK_FX_AT_PART},
	{"hearth", "brown|fry|turn|baste", WORK_FX_MODEL_WISP, WORK_FX_STAGE, 0.9},
	{"campfire", "turn", WORK_FX_MODEL_WISP, WORK_FX_BURST, WORK_FX_AT_PART},
	{"block", "split", WORK_FX_MODEL_PUFF, WORK_FX_BURST, WORK_FX_AT_PART},
	{"bench", "saw|plane|shave|hew", WORK_FX_MODEL_PUFF, WORK_FX_BURST, WORK_FX_AT_PART},
	{"mill", "set stones|mind the feed|cut furrows", WORK_FX_MODEL_PUFF, WORK_FX_BURST, 0.5},
	{"quern", "grind|sift", WORK_FX_MODEL_PUFF, WORK_FX_BURST, WORK_FX_AT_PART},
	{"frame", "scrape", WORK_FX_MODEL_PUFF, WORK_FX_BURST, 1.1},
	{"vat", "steep|mash|dissolve|stir", WORK_FX_MODEL_WISP, WORK_FX_BURST, 0.9},
	{"herbalist", "steep|boil|reduce", WORK_FX_MODEL_WISP, WORK_FX_BURST, 0.9},
	{"skep", "smoke", WORK_FX_MODEL_STEAM, WORK_FX_BURST, WORK_FX_AT_PART}
};

enum E_WORK_FX_BURST
{
	STREAMER_TAG_OBJECT:E_WORK_FX_BURST_OBJECT,
	E_WORK_FX_BURST_STATION,
	E_WORK_FX_BURST_TOKEN,
}

static s_WorkFxBursts[WORK_FX_BURST_MAX][E_WORK_FX_BURST];
static STREAMER_TAG_OBJECT:s_WorkFxStage[WORK_MAX_STATIONS][WORK_FX_STAGE_MAX];
static STREAMER_TAG_OBJECT:s_WorkFxFuelled[WORK_MAX_STATIONS];
static s_WorkFxToken;

static bool:Work_FxMatches(def,kind,const stageName[])
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);

	if (strcmp(s_WorkFxDefs[def][E_WORK_FX_DEF_KIND],key))
	{
		return false;
	}

	return s_WorkFxDefs[def][E_WORK_FX_DEF_VERBS][0] == EOS || Work_VerbsMatchText(s_WorkFxDefs[def][E_WORK_FX_DEF_VERBS],stageName);
}

static Float:Work_FxBodyHeight(kind)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);

	for (new i = 0;i < WORK_PART_KIND_COUNT;i++)
	{
		if (!strcmp(g_WorkPartKindDefs[i][E_WORK_PART_KIND_DEF_KIND],key))
		{
			return g_WorkPartKindDefs[i][E_WORK_PART_KIND_DEF_SIZE][2];
		}
	}

	return 1.0;
}

static Work_FxBurstMs(model)
{
	return model == WORK_FX_MODEL_SPARKS || model == WORK_FX_MODEL_EMBERS ? WORK_FX_BURST_MS : WORK_FX_BURST_SLOW_MS;
}

static STREAMER_TAG_OBJECT:Work_FxCreate(stationid,model,Float:x,Float:y,Float:z)
{
	new STREAMER_TAG_OBJECT:objectid = CreateDynamicObject(model,x,y,z - WORK_FX_EMITTER,0.0,0.0,0.0,g_WorkStations[stationid][E_WORK_STATION_WORLD],g_WorkStations[stationid][E_WORK_STATION_INTERIOR],-1,WORK_FX_RANGE,WORK_FX_RANGE,STREAMER_TAG_AREA:-1,WORK_PART_PRIORITY);
	Work_StreamNear(x,y,z,g_WorkStations[stationid][E_WORK_STATION_WORLD]);
	return objectid;
}

static Work_FxBodyPoint(stationid,def,&Float:x,&Float:y,&Float:z)
{
	x = g_WorkStations[stationid][E_WORK_STATION_POS][0];
	y = g_WorkStations[stationid][E_WORK_STATION_POS][1];
	z = g_WorkStations[stationid][E_WORK_STATION_POS][2] + Work_FxBodyHeight(g_WorkStations[stationid][E_WORK_STATION_KIND]) * (s_WorkFxDefs[def][E_WORK_FX_DEF_HEIGHT] < 0.0 ? 0.6 : s_WorkFxDefs[def][E_WORK_FX_DEF_HEIGHT]);
}

stock Work_FxBurst(stationid,const stageName[],bool:hasPart,Float:partX,Float:partY,Float:partZ)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	for (new def = 0;def < sizeof(s_WorkFxDefs);def++)
	{
		if (s_WorkFxDefs[def][E_WORK_FX_DEF_MODE] != WORK_FX_BURST || !Work_FxMatches(def,g_WorkStations[stationid][E_WORK_STATION_KIND],stageName))
		{
			continue;
		}

		new Float:x = partX, Float:y = partY, Float:z = partZ;

		if (!hasPart || s_WorkFxDefs[def][E_WORK_FX_DEF_HEIGHT] >= 0.0)
		{
			Work_FxBodyPoint(stationid,def,x,y,z);
		}

		new slot = -1;

		for (new i = 0;i < WORK_FX_BURST_MAX;i++)
		{
			if (!IsValidDynamicObject(s_WorkFxBursts[i][E_WORK_FX_BURST_OBJECT]))
			{
				slot = i;
				break;
			}
		}

		if (slot == -1)
		{
			return;
		}

		s_WorkFxBursts[slot][E_WORK_FX_BURST_OBJECT] = Work_FxCreate(stationid,s_WorkFxDefs[def][E_WORK_FX_DEF_MODEL],x,y,z);
		s_WorkFxBursts[slot][E_WORK_FX_BURST_STATION] = stationid;
		s_WorkFxBursts[slot][E_WORK_FX_BURST_TOKEN] = ++s_WorkFxToken;
		SetTimerEx("Work_FxBurstEnd",Work_FxBurstMs(s_WorkFxDefs[def][E_WORK_FX_DEF_MODEL]),false,"dd",slot,s_WorkFxToken);
	}
}

stock Work_FxClearStage(stationid)
{
	if (stationid < 0 || stationid >= WORK_MAX_STATIONS)
	{
		return;
	}

	for (new i = 0;i < WORK_FX_STAGE_MAX;i++)
	{
		if (IsValidDynamicObject(s_WorkFxStage[stationid][i]))
		{
			DestroyDynamicObject(s_WorkFxStage[stationid][i]);
		}

		s_WorkFxStage[stationid][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

stock Work_FxStageBegin(stationid,const stageName[])
{
	Work_FxClearStage(stationid);

	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	for (new def = 0, used = 0;def < sizeof(s_WorkFxDefs) && used < WORK_FX_STAGE_MAX;def++)
	{
		if (s_WorkFxDefs[def][E_WORK_FX_DEF_MODE] != WORK_FX_STAGE || !Work_FxMatches(def,g_WorkStations[stationid][E_WORK_STATION_KIND],stageName))
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Work_FxBodyPoint(stationid,def,x,y,z);
		s_WorkFxStage[stationid][used++] = Work_FxCreate(stationid,s_WorkFxDefs[def][E_WORK_FX_DEF_MODEL],x,y,z);
	}
}

stock Work_FxClearStation(stationid)
{
	if (stationid < 0 || stationid >= WORK_MAX_STATIONS)
	{
		return;
	}

	Work_FxClearStage(stationid);

	if (IsValidDynamicObject(s_WorkFxFuelled[stationid]))
	{
		DestroyDynamicObject(s_WorkFxFuelled[stationid]);
	}

	s_WorkFxFuelled[stationid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

	for (new i = 0;i < WORK_FX_BURST_MAX;i++)
	{
		if (s_WorkFxBursts[i][E_WORK_FX_BURST_STATION] == stationid && IsValidDynamicObject(s_WorkFxBursts[i][E_WORK_FX_BURST_OBJECT]))
		{
			DestroyDynamicObject(s_WorkFxBursts[i][E_WORK_FX_BURST_OBJECT]);
			s_WorkFxBursts[i][E_WORK_FX_BURST_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		}
	}
}

stock Work_FxStationBuilt(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	if (IsValidDynamicObject(s_WorkFxFuelled[stationid]))
	{
		DestroyDynamicObject(s_WorkFxFuelled[stationid]);
	}

	s_WorkFxFuelled[stationid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

	for (new def = 0;def < sizeof(s_WorkFxDefs);def++)
	{
		if (s_WorkFxDefs[def][E_WORK_FX_DEF_MODE] != WORK_FX_FUELLED || !Work_FxMatches(def,g_WorkStations[stationid][E_WORK_STATION_KIND],""))
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Work_FxBodyPoint(stationid,def,x,y,z);
		s_WorkFxFuelled[stationid] = Work_FxCreate(stationid,s_WorkFxDefs[def][E_WORK_FX_DEF_MODEL],x,y,z);
		return;
	}
}

stock Work_CountStationFx(stationid)
{
	new count = 0;

	if (stationid < 0 || stationid >= WORK_MAX_STATIONS)
	{
		return 0;
	}

	for (new i = 0;i < WORK_FX_STAGE_MAX;i++)
	{
		if (IsValidDynamicObject(s_WorkFxStage[stationid][i]))
		{
			count++;
		}
	}

	if (IsValidDynamicObject(s_WorkFxFuelled[stationid]))
	{
		count++;
	}

	for (new i = 0;i < WORK_FX_BURST_MAX;i++)
	{
		if (s_WorkFxBursts[i][E_WORK_FX_BURST_STATION] == stationid && IsValidDynamicObject(s_WorkFxBursts[i][E_WORK_FX_BURST_OBJECT]))
		{
			count++;
		}
	}

	return count;
}

forward Work_FxBurstEnd(slot,token);

public Work_FxBurstEnd(slot,token)
{
	if (slot < 0 || slot >= WORK_FX_BURST_MAX || s_WorkFxBursts[slot][E_WORK_FX_BURST_TOKEN] != token)
	{
		return 1;
	}

	if (IsValidDynamicObject(s_WorkFxBursts[slot][E_WORK_FX_BURST_OBJECT]))
	{
		DestroyDynamicObject(s_WorkFxBursts[slot][E_WORK_FX_BURST_OBJECT]);
	}

	s_WorkFxBursts[slot][E_WORK_FX_BURST_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	return 1;
}
