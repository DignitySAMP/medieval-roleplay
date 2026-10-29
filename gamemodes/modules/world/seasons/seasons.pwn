static STREAMER_TAG_OBJECT:s_SeasonsLodObjects[SEASONS_OVERLAY_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};

#define SEASONS_TICK_MS (1000)
#define SEASONS_STEP_TICKS (20)
#define SEASONS_OVERLAY_STEPS_PER_TICK (2)
#define SEASONS_FOLIAGE_PER_TICK (12)
#define SEASONS_SNOW_STAGE_1 (1)
#define SEASONS_SNOW_STAGE_2 (10)
#define SEASONS_SNOW_STAGE_3 (40)
#define SEASONS_SNOW_STAGE_4 (90)
#define SEASONS_SNOW_STAGE_5 (240)
#define SEASONS_WINTER_STAGES (5)
#define SEASONS_AUTUMN_STAGES (2)
#define SEASONS_DEEP_LEVEL (5)
#define SEASONS_AUTUMN_LATE_MONTH (11)
#define SEASONS_STREAM_DISTANCE (9999.0)

enum E_SEASONS_TREES
{
	SEASONS_TREES_WINTER,
	SEASONS_TREES_AUTUMN,
	SEASONS_TREES_AUTUMN_LATE,
	SEASONS_TREES_SETS,
}

enum E_SEASONS_LOOK
{
	SEASONS_LOOK_NONE,
	SEASONS_LOOK_AUTUMN,
	SEASONS_LOOK_WINTER,
}

static E_SEASONS_LOOK:s_SeasonsLook = SEASONS_LOOK_NONE;
static s_SeasonsStage = 0;
static bool:s_SeasonsForced = false;
static E_SEASONS_LOOK:s_SeasonsForcedLook = SEASONS_LOOK_NONE;
static s_SeasonsForcedStage = 0;
static s_SeasonsSnowMinutes = 0;
static bool:s_SeasonsLoaded = false;
static s_SeasonsSeconds = 0;
static s_SeasonsTicks = 0;
static s_SeasonsFoliageCursor = 0;
static STREAMER_TAG_OBJECT:s_SeasonsObjects[SEASONS_OVERLAY_COUNT] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static s_SeasonsLevels[SEASONS_OVERLAY_COUNT];
static s_SeasonsStepTicks[SEASONS_OVERLAY_COUNT];
static s_SeasonsFoliageModels[SEASONS_FOLIAGE_COUNT];
static bool:s_SeasonsTreeSets[SEASONS_TREES_SETS];

stock E_SEASONS_LOOK:Seasons_GetLook()
{
	return s_SeasonsLook;
}

stock Seasons_GetStage()
{
	return s_SeasonsStage;
}

stock Seasons_GetSnowMinutes()
{
	return s_SeasonsSnowMinutes;
}

stock Seasons_SetSnowMinutes(minutes)
{
	s_SeasonsSnowMinutes = minutes < 0 ? 0 : minutes;

	if (s_SeasonsLoaded)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE world_seasons SET snow_minutes = %d WHERE id = 1",s_SeasonsSnowMinutes));
	}
}

stock Seasons_GetSnowStage(minutes)
{
	if (minutes >= SEASONS_SNOW_STAGE_5)
	{
		return 5;
	}

	if (minutes >= SEASONS_SNOW_STAGE_4)
	{
		return 4;
	}

	if (minutes >= SEASONS_SNOW_STAGE_3)
	{
		return 3;
	}

	if (minutes >= SEASONS_SNOW_STAGE_2)
	{
		return 2;
	}

	if (minutes >= SEASONS_SNOW_STAGE_1)
	{
		return 1;
	}

	return 0;
}

stock Seasons_Force(E_SEASONS_LOOK:look,stage)
{
	s_SeasonsForced = true;
	s_SeasonsForcedLook = look;
	s_SeasonsForcedStage = stage;
}

stock Seasons_ClearForce()
{
	s_SeasonsForced = false;
}

stock bool:Seasons_IsForced()
{
	return s_SeasonsForced;
}

stock Seasons_GetObjectCount()
{
	new count = 0;

	for (new i = 0;i < SEASONS_OVERLAY_COUNT;i++)
	{
		if (IsValidDynamicObject(s_SeasonsObjects[i]))
		{
			count++;
		}
	}

	return count;
}

stock Seasons_GetOverlayLevel(index)
{
	return s_SeasonsLevels[index];
}

stock Seasons_GetOverlayModel(index)
{
	if (!IsValidDynamicObject(s_SeasonsObjects[index]))
	{
		return 0;
	}

	return Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_SeasonsObjects[index],E_STREAMER_MODEL_ID);
}

stock Seasons_GetFoliageCount()
{
    return SEASONS_FOLIAGE_COUNT;
}

stock Seasons_GetFoliageOriginal(row)
{
    return row >= 0 && row < SEASONS_FOLIAGE_COUNT ? g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_MODEL] : 0;
}

stock Seasons_GetFoliageModel(row)
{
	return s_SeasonsFoliageModels[row];
}

stock E_SEASONS_LOOK:Seasons_GetWantedLook(&stage)
{
	if (s_SeasonsForced)
	{
		stage = s_SeasonsForcedStage;
		return s_SeasonsForcedLook;
	}

	new E_SEASON:season = Calendar_GetSeason();

	if (season == SEASON_AUTUMN)
	{
		new day, month, year;
		Calendar_GetDate(day,month,year);
		stage = month == SEASONS_AUTUMN_LATE_MONTH ? 2 : 1;
		return SEASONS_LOOK_AUTUMN;
	}

	if (season == SEASON_WINTER)
	{
		stage = Seasons_GetSnowStage(s_SeasonsSnowMinutes);
		return SEASONS_LOOK_WINTER;
	}

	stage = 0;
	return SEASONS_LOOK_NONE;
}

stock Seasons_GetOverlayTarget(index,E_SEASONS_LOOK:look,stage)
{
	switch (g_SeasonsOverlays[index][E_SEASONS_OVERLAY_KIND])
	{
		case SEASONS_KIND_GROUND:
		{
			return look == SEASONS_LOOK_WINTER ? stage : 0;
		}
		case SEASONS_KIND_ROOF, SEASONS_KIND_PINE:
		{
			if (look != SEASONS_LOOK_WINTER)
			{
				return 0;
			}

			return stage > SEASONS_STEPS ? SEASONS_STEPS : stage;
		}
		case SEASONS_KIND_ROAD:
		{
			if (look != SEASONS_LOOK_AUTUMN || stage < 1)
			{
				return 0;
			}

			return stage >= 2 ? 3 : 2;
		}
	}

	return 0;
}

stock bool:Seasons_HasTreeSet(E_SEASONS_TREES:set)
{
	return s_SeasonsTreeSets[set];
}

stock Seasons_RegisterTrees()
{
	new count = 0;

	for (new E_SEASONS_TREES:set = SEASONS_TREES_WINTER;set < SEASONS_TREES_SETS;set++)
	{
		if (s_SeasonsTreeSets[set])
		{
			continue;
		}

		for (new i = 0;i < SEASONS_FOLIAGE_COUNT;i++)
		{
			switch (set)
			{
				case SEASONS_TREES_WINTER:
				{
					Models_AddObject(g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_WINTER],g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_FILE],g_SeasonsFoliageTxds[g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_WINTER_TXD]],g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_BASE]);
                    Map_RegisterLodVariant(g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_WINTER], g_SeasonsFoliageTxds[g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_WINTER_TXD]]);
				}
				case SEASONS_TREES_AUTUMN:
				{
					Models_AddObject(g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN],g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_FILE],g_SeasonsFoliageTxds[g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN_TXD]],g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_BASE]);
                    Map_RegisterLodVariant(g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN], g_SeasonsFoliageTxds[g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN_TXD]]);
				}
				default:
				{
					Models_AddObject(g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN_LATE],g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_FILE],g_SeasonsFoliageTxds[g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN_LATE_TXD]],g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_BASE]);
                    Map_RegisterLodVariant(g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN_LATE], g_SeasonsFoliageTxds[g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_AUTUMN_LATE_TXD]]);
				}
			}
		}

		s_SeasonsTreeSets[set] = true;
		count++;
	}

	return count;
}

stock Seasons_GetFoliageTarget(row,E_SEASONS_LOOK:look,stage)
{
	if (look == SEASONS_LOOK_WINTER && s_SeasonsTreeSets[SEASONS_TREES_WINTER])
	{
		return g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_WINTER];
	}

	if (look == SEASONS_LOOK_AUTUMN)
	{
		if (stage >= 2 && s_SeasonsTreeSets[SEASONS_TREES_AUTUMN_LATE])
		{
			return g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_AUTUMN_LATE];
		}

		if (s_SeasonsTreeSets[SEASONS_TREES_AUTUMN])
		{
			return g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_AUTUMN];
		}

		if (s_SeasonsTreeSets[SEASONS_TREES_AUTUMN_LATE])
		{
			return g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_AUTUMN_LATE];
		}
	}

	return g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_MODEL];
}

stock bool:Seasons_IsSettled()
{
	for (new i = 0;i < SEASONS_OVERLAY_COUNT;i++)
	{
		if (s_SeasonsLevels[i] != Seasons_GetOverlayTarget(i,s_SeasonsLook,s_SeasonsStage))
		{
			return false;
		}
	}

	for (new i = 0;i < SEASONS_FOLIAGE_COUNT;i++)
	{
		if (s_SeasonsFoliageModels[i] != Seasons_GetFoliageTarget(i,s_SeasonsLook,s_SeasonsStage))
		{
			return false;
		}
	}

	return true;
}

static Seasons_ShowLevel(index,level)
{
    if (IsValidDynamicObject(s_SeasonsLodObjects[index]))
    {
        Map_DestroyLodObject(s_SeasonsLodObjects[index]);
    }

    s_SeasonsLodObjects[index] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

	if (level == 0)
	{
		if (IsValidDynamicObject(s_SeasonsObjects[index]))
		{
			DestroyDynamicObject(s_SeasonsObjects[index]);
		}

		s_SeasonsObjects[index] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		return;
	}

	new modelid, Float:x, Float:y, Float:z;

	if (level == SEASONS_DEEP_LEVEL)
	{
		modelid = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_DEEP_MODEL];
		x = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_DEEP_X];
		y = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_DEEP_Y];
		z = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_DEEP_Z];
	}
	else
	{
		modelid = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_MODELS][level - 1];
		x = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_X];
		y = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_Y];
		z = g_SeasonsOverlays[index][E_SEASONS_OVERLAY_Z];
	}

	new Float:distance = Map_GetModelDistance(modelid);

    if (distance == 0.0)
    {
        distance = SEASONS_STREAM_DISTANCE;
    }

    s_SeasonsLodObjects[index] = Map_CreateLod(modelid, x, y, z, 0.0, 0.0, 0.0);

	if (!IsValidDynamicObject(s_SeasonsObjects[index]))
	{
		s_SeasonsObjects[index] = Nearby_CreateDynamicObject(modelid,x,y,z,0.0,0.0,0.0,-1,-1,-1,distance,distance,STREAMER_TAG_AREA:-1,MAP_STREAM_PRIORITY);
		return;
	}

	Streamer_SetIntData(STREAMER_TYPE_OBJECT,s_SeasonsObjects[index],E_STREAMER_MODEL_ID,modelid);
	SetDynamicObjectPos(s_SeasonsObjects[index],x,y,z);
    Streamer_SetFloatData(STREAMER_TYPE_OBJECT, s_SeasonsObjects[index], E_STREAMER_STREAM_DISTANCE, distance);
    Streamer_SetFloatData(STREAMER_TYPE_OBJECT, s_SeasonsObjects[index], E_STREAMER_DRAW_DISTANCE, distance);
    Nearby_QueueStream(STREAMER_TYPE_OBJECT, x, y, z, -1, -1, -1, distance);
}

static Seasons_StepOverlays()
{
	new steps = 0;

	for (new i = 0;i < SEASONS_OVERLAY_COUNT && steps < SEASONS_OVERLAY_STEPS_PER_TICK;i++)
	{
		new target = Seasons_GetOverlayTarget(i,s_SeasonsLook,s_SeasonsStage), level = s_SeasonsLevels[i];

		if (level == target || s_SeasonsTicks - s_SeasonsStepTicks[i] < SEASONS_STEP_TICKS)
		{
			continue;
		}

		level += level < target ? 1 : -1;
		s_SeasonsLevels[i] = level;
		s_SeasonsStepTicks[i] = s_SeasonsTicks;
		Seasons_ShowLevel(i,level);
		steps++;
	}
}

static Seasons_StepFoliage()
{
	for (new done = 0, looked = 0;done < SEASONS_FOLIAGE_PER_TICK && looked < SEASONS_FOLIAGE_COUNT;looked++)
	{
		new row = s_SeasonsFoliageCursor;
		s_SeasonsFoliageCursor = (s_SeasonsFoliageCursor + 1) % SEASONS_FOLIAGE_COUNT;

		new target = Seasons_GetFoliageTarget(row,s_SeasonsLook,s_SeasonsStage);

		if (target == s_SeasonsFoliageModels[row])
		{
			continue;
		}

		new STREAMER_TAG_OBJECT:objectid = Map_GetModelObject(g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_MODEL]);

		if (IsValidDynamicObject(objectid))
		{
			Streamer_SetIntData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_MODEL_ID,target);
            new Float:x, Float:y, Float:z, Float:distance;
            GetDynamicObjectPos(objectid, x, y, z);
            Streamer_GetFloatData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_STREAM_DISTANCE, distance);
            Nearby_QueueStream(STREAMER_TYPE_OBJECT, x, y, z, -1, -1, -1, distance);
		}

		Map_SetLodModel(g_SeasonsFoliage[row][E_SEASONS_FOLIAGE_MODEL], target);

		s_SeasonsFoliageModels[row] = target;
		done++;
	}
}

stock Seasons_Update()
{
	if (!s_SeasonsLoaded || !Calendar_IsLoaded())
	{
		return;
	}

	s_SeasonsTicks++;

	new stage, E_SEASONS_LOOK:look = Seasons_GetWantedLook(stage);

	if (look != s_SeasonsLook || stage != s_SeasonsStage)
	{
		s_SeasonsLook = look;
		s_SeasonsStage = stage;
		Log_Info("seasons","look %d stage %d (snow %d min)",_:look,stage,s_SeasonsSnowMinutes);
	}

    Seasons_UpdateWater();
    Map_SetRadarSeason(look == SEASONS_LOOK_AUTUMN ? stage : 0, look == SEASONS_LOOK_WINTER ? stage : 0, Seasons_IsWaterFrozen());

	Seasons_StepOverlays();
	Seasons_StepFoliage();
}

stock Seasons_RunMinute()
{
	if (Calendar_GetSeason() != SEASON_WINTER)
	{
		if (s_SeasonsSnowMinutes != 0)
		{
			Seasons_SetSnowMinutes(0);
		}

		return;
	}

	if (Weather_IsSnowing())
	{
		Seasons_SetSnowMinutes(s_SeasonsSnowMinutes + 1);
	}
}

stock Seasons_ResetFoliage()
{
	for (new i = 0;i < SEASONS_FOLIAGE_COUNT;i++)
	{
		s_SeasonsFoliageModels[i] = g_SeasonsFoliage[i][E_SEASONS_FOLIAGE_MODEL];
	}
}

forward Seasons_Tick();

public Seasons_Tick()
{
	if (++s_SeasonsSeconds >= 60)
	{
		s_SeasonsSeconds = 0;
		Seasons_RunMinute();
	}

	Seasons_Update();
	return 1;
}

forward Seasons_LoadOnBoot();

public Seasons_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT snow_minutes FROM world_seasons WHERE id = 1"));

	if (cache_num_rows() == 0)
	{
		s_SeasonsSnowMinutes = 0;
		await mysql_aquery_s(g_Mysql,str_new("INSERT INTO world_seasons (id, snow_minutes) VALUES (1, 0)"));
	}
	else
	{
		cache_get_value_name_int(0,"snow_minutes",s_SeasonsSnowMinutes);
	}

	new sets = Seasons_RegisterTrees();
	Seasons_ResetFoliage();
	s_SeasonsLoaded = true;
	Log_Info("seasons","%d minute(s) of snow lie on the ground, %d tree set(s) registered for live swaps",s_SeasonsSnowMinutes,sets);
	Boot_LoaderDone();
}

CMD<ADMIN_LEVEL_TRIAL>:season(cmdid, playerid, params[])
{
	new look[8], stage = 0;

	if (isnull(params))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("Seasons: look %d, stage %d, %d minute(s) of snow, %d overlay object(s)%s.",_:s_SeasonsLook,s_SeasonsStage,s_SeasonsSnowMinutes,Seasons_GetObjectCount(),s_SeasonsForced ? (", forced") : ("")));
		return 1;
	}

	if (sscanf(params,"s[8]I(0)",look,stage))
	{
		Command_Usage(playerid,cmdid,"<auto|none|autumn 1-2|winter 0-5>");
		return 1;
	}

	if (!strcmp(look,"auto",true))
	{
		Seasons_ClearForce();
	}
	else if (!strcmp(look,"none",true))
	{
		Seasons_Force(SEASONS_LOOK_NONE,0);
	}
	else if (!strcmp(look,"autumn",true) && stage >= 1 && stage <= SEASONS_AUTUMN_STAGES)
	{
		Seasons_Force(SEASONS_LOOK_AUTUMN,stage);
	}
	else if (!strcmp(look,"winter",true) && stage >= 0 && stage <= SEASONS_WINTER_STAGES)
	{
		Seasons_Force(SEASONS_LOOK_WINTER,stage);
	}
	else
	{
		Command_Usage(playerid,cmdid,"<auto|none|autumn 1-2|winter 0-5>");
		return 1;
	}

	SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("The season turns to %s%s.",look,s_SeasonsForced ? ("") : (" (following the calendar)")));
	return 1;
}
