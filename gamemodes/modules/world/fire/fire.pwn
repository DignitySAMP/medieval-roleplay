enum E_FIRE_BUILDING
{
	E_FIRE_STATE,
	E_FIRE_HEAT,
	E_FIRE_PEAK_TICKS,
	E_FIRE_CAUSE,
	E_FIRE_ARSONIST,
	E_FIRE_STARTED,
	E_FIRE_ROW,
	bool:E_FIRE_ALARMED,
	bool:E_FIRE_PAID,
	E_FIRE_BURNED_AT,
	STREAMER_TAG_OBJECT:E_FIRE_OBJECTS[FIRE_OBJECTS],
	STREAMER_TAG_3D_TEXT_LABEL:E_FIRE_LABEL,
}

static s_Fire[FIRE_SEED_BUILDINGS][E_FIRE_BUILDING];
static s_FireThrows[FIRE_SEED_BUILDINGS][FIRE_CHAIN_MAX + 1][2];
static bool:s_FireTiled[FIRE_SEED_BUILDINGS];
static s_FireFrailty[FIRE_SEED_BUILDINGS];
static s_FireDry;
static s_FireWind;
static s_FireDamp;

forward Task:Fire_Load();
forward Task:Fire_LogStart(building);

stock bool:Fire_IsValid(building)
{
	return building >= 0 && building < FIRE_SEED_BUILDINGS;
}

stock Fire_GetState(building)
{
	return Fire_IsValid(building) ? s_Fire[building][E_FIRE_STATE] : FIRE_STATE_SOUND;
}

stock Fire_GetHeat(building)
{
	return Fire_IsValid(building) ? s_Fire[building][E_FIRE_HEAT] : 0;
}

stock bool:Fire_IsBurning(building)
{
	return Fire_IsValid(building) && (s_Fire[building][E_FIRE_STATE] == FIRE_STATE_SMOKING || s_Fire[building][E_FIRE_STATE] == FIRE_STATE_BURNING);
}

stock bool:Fire_IsGutted(building)
{
	return Fire_IsValid(building) && s_Fire[building][E_FIRE_STATE] == FIRE_STATE_GUTTED;
}

stock bool:Fire_IsRebuildPaid(building)
{
	return Fire_IsValid(building) && s_Fire[building][E_FIRE_PAID];
}

stock Fire_GetCause(building)
{
	return Fire_IsValid(building) ? s_Fire[building][E_FIRE_CAUSE] : -1;
}

stock Fire_CountBurning()
{
	new count = 0;

	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		if (Fire_IsBurning(building))
		{
			count++;
		}
	}

	return count;
}

stock Fire_CountFlames(building)
{
	new count = 0;

	for (new flame = 0;Fire_IsValid(building) && flame < FIRE_FLAMES;flame++)
	{
		if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][1 + flame]) && Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_Fire[building][E_FIRE_OBJECTS][1 + flame],E_STREAMER_MODEL_ID) == LIGHT_FLAME_MODEL)
		{
			count++;
		}
	}

	return count;
}

stock Fire_GetGlowModel(building)
{
	if (!Fire_IsValid(building) || !IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][FIRE_SLOT_GLOW]))
	{
		return 0;
	}

	return Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_Fire[building][E_FIRE_OBJECTS][FIRE_SLOT_GLOW],E_STREAMER_MODEL_ID);
}

stock Fire_CountGutted()
{
	new count = 0;

	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		if (Fire_IsGutted(building))
		{
			count++;
		}
	}

	return count;
}

stock Fire_GetName(building,dest[],size = sizeof(dest))
{
	if (!Fire_IsValid(building))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_NAME],size);
}

stock Fire_FindByKey(const key[])
{
	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		if (!strcmp(g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_KEY],key,true))
		{
			return building;
		}
	}

	return -1;
}

stock Fire_FindByHouse(house)
{
	for (new building = 0;building < FIRE_SEED_BUILDINGS && house != -1;building++)
	{
		if (g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE] == house)
		{
			return building;
		}
	}

	return -1;
}

stock Fire_FindNear(Float:x,Float:y,Float:z,Float:range,&Float:distance = 0.0)
{
	new best = -1;
	distance = range;

	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		new Float:door = VectorSize(g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][0] - x,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][1] - y,0.0), Float:roof = VectorSize(g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0] - x,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1] - y,0.0), Float:d = door < roof ? door : roof;

		if (d <= distance && floatabs(g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2] - z) < 12.0)
		{
			distance = d;
			best = building;
		}
	}

	return best;
}

stock Fire_FindNearPlayer(playerid,Float:range)
{
	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		return -1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return Fire_FindNear(x,y,z,range);
}

stock Fire_SetTiled(building,bool:isTiled)
{
	if (Fire_IsValid(building))
	{
		s_FireTiled[building] = isTiled;
	}
}

stock bool:Fire_IsTiled(building)
{
	return Fire_IsValid(building) && s_FireTiled[building];
}

stock Fire_SetFrailty(building,percent)
{
	if (Fire_IsValid(building))
	{
		s_FireFrailty[building] = Util_ClampInt(percent,0,50);
	}
}

stock Fire_SetConditions(dry,wind,damp)
{
	s_FireDry = dry;
	s_FireWind = wind;
	s_FireDamp = damp;
}

stock Fire_GetGrowth()
{
	new growth = FIRE_GROWTH + s_FireDry + s_FireWind - s_FireDamp;

	if (Calendar_GetSeason() == SEASON_SUMMER)
	{
		growth += FIRE_GROWTH_DRY;
	}

	if (Weather_IsSnowing())
	{
		growth -= 3;
	}

	return growth;
}

static Fire_ClearObjects(building)
{
	for (new i = 0;i < FIRE_OBJECTS;i++)
	{
		if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][i]))
		{
			DestroyDynamicObject(s_Fire[building][E_FIRE_OBJECTS][i]);
		}

		s_Fire[building][E_FIRE_OBJECTS][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

static Fire_ShowObject(building,slot,model,Float:dx,Float:dy,Float:dz)
{
	if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]))
	{
		return;
	}

	s_Fire[building][E_FIRE_OBJECTS][slot] = CreateDynamicObject(model,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0] + dx,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1] + dy,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2] + dz,0.0,0.0,0.0,0,0,-1,FIRE_STREAM,FIRE_STREAM);
}

static bool:Fire_RoofAt(building,Float:x,Float:y,&Float:z)
{
	return Placement_FindSurface(x,y,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2] + FIRE_FLAME_SEEK,FIRE_FLAME_DROP,z);
}

static Fire_RidgeAxis(building,&Float:axisX,&Float:axisY)
{
	new Float:rx = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0], Float:ry = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1], Float:a, Float:b, Float:c, Float:d;
	new Float:roofZ = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2];

	if (!Fire_RoofAt(building,rx + FIRE_RIDGE_PROBE,ry,a))
	{
		a = roofZ - FIRE_RIDGE_PROBE;
	}

	if (!Fire_RoofAt(building,rx - FIRE_RIDGE_PROBE,ry,b))
	{
		b = roofZ - FIRE_RIDGE_PROBE;
	}

	if (!Fire_RoofAt(building,rx,ry + FIRE_RIDGE_PROBE,c))
	{
		c = roofZ - FIRE_RIDGE_PROBE;
	}

	if (!Fire_RoofAt(building,rx,ry - FIRE_RIDGE_PROBE,d))
	{
		d = roofZ - FIRE_RIDGE_PROBE;
	}

	axisX = (a + b) >= (c + d) ? 1.0 : 0.0;
	axisY = 1.0 - axisX;
}

static Fire_ShowBlaze(building,slot,model,Float:along)
{
	if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]))
	{
		if (Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_Fire[building][E_FIRE_OBJECTS][slot],E_STREAMER_MODEL_ID) == model)
		{
			return;
		}

		DestroyDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]);
	}

	new Float:axisX, Float:axisY;
	Fire_RidgeAxis(building,axisX,axisY);

	new Float:x = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0] + axisX * along, Float:y = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1] + axisY * along, Float:z;

	if (!Fire_RoofAt(building,x,y,z))
	{
		z = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2];
	}

	s_Fire[building][E_FIRE_OBJECTS][slot] = CreateDynamicObject(model,x,y,z - FIRE_EMITTER_LIFT,0.0,0.0,0.0,0,0,-1,FIRE_STREAM,FIRE_STREAM);
}

static Fire_ShowGlow(building,model)
{
	new slot = FIRE_SLOT_GLOW;

	if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]))
	{
		if (Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_Fire[building][E_FIRE_OBJECTS][slot],E_STREAMER_MODEL_ID) == model)
		{
			return;
		}

		DestroyDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]);
	}

	s_Fire[building][E_FIRE_OBJECTS][slot] = Light_CreateGlow(model,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2] + FIRE_GLOW_LIFT,0,0,FIRE_STREAM);
}

static Fire_ShowFlame(building,flame)
{
	new slot = 1 + flame;

	if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]))
	{
		return;
	}

	new Float:x = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0] + g_FireFlameSpots[flame][0], Float:y = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1] + g_FireFlameSpots[flame][1], Float:z;

	if (Fire_RoofAt(building,x,y,z))
	{
		z += FIRE_FLAME_THATCH;
	}
	else
	{
		z = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2] - 0.1;
	}

	s_Fire[building][E_FIRE_OBJECTS][slot] = Light_CreateFlame(x,y,z,0,0,FIRE_STREAM);
}

static Fire_DropObject(building,slot)
{
	if (IsValidDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]))
	{
		DestroyDynamicObject(s_Fire[building][E_FIRE_OBJECTS][slot]);
	}

	s_Fire[building][E_FIRE_OBJECTS][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock Fire_RefreshLook(building)
{
	switch (s_Fire[building][E_FIRE_STATE])
	{
		case FIRE_STATE_SOUND:
		{
			Fire_ClearObjects(building);
		}
		case FIRE_STATE_SMOKING:
		{
			Fire_ShowObject(building,0,FIRE_SMOKE_MODEL,0.0,0.0,0.3 - FIRE_EMITTER_LIFT);

			for (new slot = 1;slot < FIRE_OBJECTS;slot++)
			{
				Fire_DropObject(building,slot);
			}
		}
		case FIRE_STATE_BURNING:
		{
			new bool:isRoaring = s_Fire[building][E_FIRE_HEAT] >= FIRE_ROARING_AT, flames = isRoaring ? FIRE_FLAMES : FIRE_FLAMES_BURNING;
			Fire_ShowObject(building,0,FIRE_SMOKE_MODEL,0.0,0.0,0.8 - FIRE_EMITTER_LIFT);

			for (new flame = 0;flame < FIRE_FLAMES;flame++)
			{
				if (flame < flames)
				{
					Fire_ShowFlame(building,flame);
				}
				else
				{
					Fire_DropObject(building,1 + flame);
				}
			}

			Fire_ShowBlaze(building,FIRE_SLOT_BLAZE,isRoaring ? FIRE_LARGE_MODEL : FIRE_MEDIUM_MODEL,0.0);

			if (isRoaring)
			{
				Fire_ShowBlaze(building,FIRE_SLOT_BLAZE + 1,FIRE_MEDIUM_MODEL,FIRE_BLAZE_ALONG);
				Fire_ShowBlaze(building,FIRE_SLOT_BLAZE + 2,FIRE_MEDIUM_MODEL,-FIRE_BLAZE_ALONG);
			}
			else
			{
				Fire_DropObject(building,FIRE_SLOT_BLAZE + 1);
				Fire_DropObject(building,FIRE_SLOT_BLAZE + 2);
			}

			Fire_ShowGlow(building,isRoaring ? MODEL_LIGHT_GLOW_L : MODEL_LIGHT_GLOW_M);
		}
		case FIRE_STATE_GUTTED:
		{
			Fire_ClearObjects(building);
			Fire_ShowObject(building,0,FIRE_RUIN_MODEL,0.0,0.0,-2.5);
		}
	}

	Nearby_StreamObjectsAt(g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2],0,0,FIRE_STREAM);

	if (IsValidDynamic3DTextLabel(s_Fire[building][E_FIRE_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Fire[building][E_FIRE_LABEL]);
	}

	s_Fire[building][E_FIRE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

	if (s_Fire[building][E_FIRE_STATE] == FIRE_STATE_GUTTED)
	{
		s_Fire[building][E_FIRE_LABEL] = CreateDynamic3DTextLabel(s_Fire[building][E_FIRE_PAID] ? ("A burnt-out shell. The carpenters come at dawn.") : ("A burnt-out shell"),0x9A8F80FF,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2] + 1.2,12.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
	}
}

static Fire_Save(building)
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO buildings (building_key, county_id, x, y, z, radius, flammable, state, burned_at, rebuild_paid) VALUES ('%e', %d, %f, %f, %f, %f, 1, %d, %d, %d) ON DUPLICATE KEY UPDATE state = VALUES(state), burned_at = VALUES(burned_at), rebuild_paid = VALUES(rebuild_paid)",g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_KEY],REALM_COUNTY,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_REACH],s_Fire[building][E_FIRE_STATE] == FIRE_STATE_GUTTED ? FIRE_STATE_GUTTED : FIRE_STATE_SOUND,s_Fire[building][E_FIRE_BURNED_AT],_:s_Fire[building][E_FIRE_PAID]));
}

stock bool:Fire_Start(building,cause,arsonist = 0)
{
	if (!Fire_IsValid(building) || s_Fire[building][E_FIRE_STATE] != FIRE_STATE_SOUND)
	{
		return false;
	}

	if (s_FireTiled[building] && (cause == FIRE_CAUSE_LIGHTNING || cause == FIRE_CAUSE_TORCH))
	{
		return false;
	}

	s_Fire[building][E_FIRE_STATE] = FIRE_STATE_SMOKING;
	s_Fire[building][E_FIRE_HEAT] = cause == FIRE_CAUSE_SPREAD ? FIRE_SPREAD_HEAT : FIRE_START_HEAT;
	s_Fire[building][E_FIRE_PEAK_TICKS] = 0;
	s_Fire[building][E_FIRE_CAUSE] = cause;
	s_Fire[building][E_FIRE_ARSONIST] = arsonist;
	s_Fire[building][E_FIRE_STARTED] = gettime();
	s_Fire[building][E_FIRE_ALARMED] = false;
	s_Fire[building][E_FIRE_ROW] = 0;
	Fire_RefreshLook(building);
	Fire_LogStart(building);
	pawn_call_public("Fire_OnStarted","dd",building,cause);
	return true;
}

#pragma warning push
#pragma warning disable 204
async Task:Fire_LogStart(building)
{
	new started = s_Fire[building][E_FIRE_STARTED];
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO fires (building_key, x, y, z, intensity, started_at, cause, arsonist, ended_at, outcome) VALUES ('%e', %f, %f, %f, %d, %d, %d, %d, 0, 0)",g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_KEY],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2],s_Fire[building][E_FIRE_HEAT],started,s_Fire[building][E_FIRE_CAUSE],s_Fire[building][E_FIRE_ARSONIST]));
	new id = cache_insert_id();

	if (s_Fire[building][E_FIRE_STARTED] != started)
	{
		return async 0;
	}

	if (Fire_IsBurning(building))
	{
		s_Fire[building][E_FIRE_ROW] = id;
	}
	else
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE fires SET ended_at = %d, outcome = %d WHERE id = %d",gettime(),Fire_IsGutted(building) ? 2 : 1,id));
	}

	return async id;
}
#pragma warning pop

static Fire_LogEnd(building,outcome)
{
	if (s_Fire[building][E_FIRE_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE fires SET ended_at = %d, outcome = %d WHERE id = %d",gettime(),outcome,s_Fire[building][E_FIRE_ROW]));
	}

	s_Fire[building][E_FIRE_ROW] = 0;
}

stock bool:Fire_Douse(building,amount)
{
	if (!Fire_IsBurning(building) || amount <= 0)
	{
		return false;
	}

	s_Fire[building][E_FIRE_HEAT] -= amount;

	if (s_Fire[building][E_FIRE_HEAT] <= 0)
	{
		Fire_PutOut(building);
		return true;
	}

	if (s_Fire[building][E_FIRE_STATE] == FIRE_STATE_BURNING && s_Fire[building][E_FIRE_HEAT] < FIRE_BURNING_AT)
	{
		s_Fire[building][E_FIRE_STATE] = FIRE_STATE_SMOKING;
	}

	s_Fire[building][E_FIRE_PEAK_TICKS] = 0;
	Fire_RefreshLook(building);
	return false;
}

stock Fire_PutOut(building)
{
	if (!Fire_IsBurning(building))
	{
		return;
	}

	s_Fire[building][E_FIRE_STATE] = FIRE_STATE_SOUND;
	s_Fire[building][E_FIRE_HEAT] = 0;
	Fire_RefreshLook(building);
	Fire_LogEnd(building,1);
	Fire_TakeDownAlarm(building);
	pawn_call_public("Fire_OnOut","d",building);
}

stock Fire_Gut(building)
{
	if (!Fire_IsValid(building) || s_Fire[building][E_FIRE_STATE] == FIRE_STATE_GUTTED)
	{
		return;
	}

	new house = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE];
	s_Fire[building][E_FIRE_STATE] = FIRE_STATE_GUTTED;
	s_Fire[building][E_FIRE_HEAT] = 0;
	s_Fire[building][E_FIRE_PAID] = false;
	s_Fire[building][E_FIRE_BURNED_AT] = gettime();

	if (house != -1)
	{
		Houses_SetGutted(house,true);

		for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
		{
			if (Houses_GetRoomHouse(room) == house)
			{
				Fire_EmptyContainer(Houses_GetRoomChest(room));
			}
		}
	}

	Fire_RuinStations(building,true);
	Fire_RefreshLook(building);
	Fire_LogEnd(building,2);
	Fire_Save(building);
	Fire_TakeDownAlarm(building);
	pawn_call_public("Fire_OnGutted","d",building);
}

stock Fire_Rebuild(building)
{
	if (!Fire_IsGutted(building))
	{
		return;
	}

	new house = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE];
	s_Fire[building][E_FIRE_STATE] = FIRE_STATE_SOUND;
	s_Fire[building][E_FIRE_PAID] = false;

	if (house != -1)
	{
		Houses_SetGutted(house,false);
	}

	Fire_RuinStations(building,false);
	Fire_RefreshLook(building);
	Fire_Save(building);
	pawn_call_public("Fire_OnRebuilt","d",building);
}

stock Fire_SetRebuildPaid(building)
{
	if (Fire_IsGutted(building))
	{
		s_Fire[building][E_FIRE_PAID] = true;
		Fire_RefreshLook(building);
		Fire_Save(building);
	}
}

stock Fire_GetRebuildFee(building)
{
	return Fire_IsValid(building) && g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE] == -1 ? FIRE_REBUILD_FEE_STABLE : FIRE_REBUILD_FEE;
}

stock Fire_EmptyContainer(containerid)
{
	if (containerid == INVALID_CONTAINER_ID || !Container_IsLoaded(containerid))
	{
		return 0;
	}

	new lost = 0;

	for (new slot = Container_GetSlots(containerid) - 1;slot >= 0;slot--)
	{
		new E_ITEM_KIND:kind, param, amount, stars;

		if (Container_GetSlot(containerid,slot,kind,param,amount,stars) && amount > 0 && Container_TakeStars(containerid,kind,param,amount,stars))
		{
			lost += amount;
		}
	}

	return lost;
}

stock Fire_RuinStations(building,bool:isRuined)
{
	new count = 0;

	for (new station = 0;station < WORK_MAX_STATIONS;station++)
	{
		new Float:x, Float:y, Float:z, world;

		if (Work_GetStationPos(station,x,y,z,world) && world == 0 && VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],0.0) <= g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_REACH] && floatabs(z - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2]) < 6.0)
		{
			Work_SetStationRuined(station,isRuined);
			count++;
		}
	}

	return count;
}

stock Fire_RecordThrow(building,playerid)
{
	new now = GetTickCount(), others = 0, oldest = 0;

	for (new i = 0;i <= FIRE_CHAIN_MAX;i++)
	{
		if (s_FireThrows[building][i][1] != 0 && now - s_FireThrows[building][i][0] <= FIRE_CHAIN_MS && s_FireThrows[building][i][1] - 1 != playerid)
		{
			others++;
		}

		if (s_FireThrows[building][i][0] < s_FireThrows[building][oldest][0])
		{
			oldest = i;
		}
	}

	s_FireThrows[building][oldest][0] = now;
	s_FireThrows[building][oldest][1] = playerid + 1;
	return min(others,FIRE_CHAIN_MAX);
}

static Fire_FormatAlarm(building,text[],size = sizeof(text))
{
	new name[28];
	Fire_GetName(building,name);
	format(text,size,"Fire at %s! Bring buckets: fill them at the troughs, the wells and the river.",name);
}

static Fire_TakeDownAlarm(building)
{
	new text[144];
	Fire_FormatAlarm(building,text);
	Notices_TakeDown(Notices_TabOfKind(FIRE_CRIER_KIND),FIRE_ALARM_TITLE,text);
}

static Fire_Alarm(building)
{
	new name[28], text[144];
	Fire_GetName(building,name);
	Fire_FormatAlarm(building,text);
	Crier_Announce(FIRE_CRIER_KIND,FIRE_ALARM_TITLE,text);

	foreach (new playerid : Player)
	{
		if (Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,FIRE_ALARM_RANGE,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2]))
		{
			Gui_Notify(playerid,sprintf("The church bell rings out of time: %s is on fire.",name));
		}
	}
}

static Fire_HurtNear(building)
{
	new house = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE], Float:rx = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0], Float:ry = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1], Float:rz = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2];

	foreach (new playerid : Player)
	{
		if (!Session_IsPlaying(playerid))
		{
			continue;
		}

		if (house != -1 && Houses_GetInside(playerid) == house)
		{
			Vitals_Damage(playerid,FIRE_SMOKE_DAMAGE,"smoke");
			Gui_Notify(playerid,"Smoke fills the house. Get out!");
			continue;
		}

		if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		new Float:d = VectorSize(x - rx,y - ry,0.0);

		if (floatabs(z - rz) > 8.0)
		{
			continue;
		}

		if (s_Fire[building][E_FIRE_STATE] == FIRE_STATE_BURNING && d < g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_REACH] * 0.45)
		{
			Vitals_Damage(playerid,FIRE_BURN_DAMAGE,"fire");
			Gui_Notify(playerid,"The flames scorch you.");
		}
		else if (d < FIRE_SMOKE_RANGE && random(100) < FIRE_COUGH_PERCENT)
		{
			Chat_Annotate(playerid,"coughs in the smoke.");
		}
	}
}

stock Fire_Step(building)
{
	if (!Fire_IsBurning(building))
	{
		return;
	}

	s_Fire[building][E_FIRE_HEAT] = Util_ClampInt(s_Fire[building][E_FIRE_HEAT] + Fire_GetGrowth(),0,FIRE_HEAT_MAX);

	if (s_Fire[building][E_FIRE_HEAT] <= 0)
	{
		Fire_PutOut(building);
		return;
	}

	new wasState = s_Fire[building][E_FIRE_STATE];
	s_Fire[building][E_FIRE_STATE] = s_Fire[building][E_FIRE_HEAT] >= FIRE_BURNING_AT ? FIRE_STATE_BURNING : FIRE_STATE_SMOKING;

	if (s_Fire[building][E_FIRE_STATE] == FIRE_STATE_BURNING && !s_Fire[building][E_FIRE_ALARMED])
	{
		s_Fire[building][E_FIRE_ALARMED] = true;
		Fire_Alarm(building);
	}

	if (s_Fire[building][E_FIRE_HEAT] >= FIRE_HEAT_MAX && ++s_Fire[building][E_FIRE_PEAK_TICKS] >= FIRE_GUT_TICKS)
	{
		Fire_Gut(building);
		return;
	}

	if (wasState != s_Fire[building][E_FIRE_STATE] || s_Fire[building][E_FIRE_STATE] == FIRE_STATE_BURNING)
	{
		Fire_RefreshLook(building);
	}

	Fire_HurtNear(building);

	if (s_Fire[building][E_FIRE_HEAT] < FIRE_SPREAD_AT)
	{
		return;
	}

	for (new other = 0;other < FIRE_SEED_BUILDINGS;other++)
	{
		if (other != building && s_Fire[other][E_FIRE_STATE] == FIRE_STATE_SOUND && VectorSize(g_FireBuildingDefs[other][E_FIRE_BUILDING_DEF_ROOF][0] - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[other][E_FIRE_BUILDING_DEF_ROOF][1] - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],0.0) <= FIRE_SPREAD_RANGE && random(s_FireTiled[other] ? 200 : 100) < FIRE_SPREAD_PERCENT + s_FireDry * 2 + s_FireWind * 2 + s_FireFrailty[other])
		{
			Fire_Start(other,FIRE_CAUSE_SPREAD,s_Fire[building][E_FIRE_ARSONIST]);
		}
	}
}

stock Fire_SetHeat(building,heat)
{
	if (!Fire_IsBurning(building))
	{
		return;
	}

	s_Fire[building][E_FIRE_HEAT] = Util_ClampInt(heat,1,FIRE_HEAT_MAX);
	s_Fire[building][E_FIRE_STATE] = s_Fire[building][E_FIRE_HEAT] >= FIRE_BURNING_AT ? FIRE_STATE_BURNING : FIRE_STATE_SMOKING;
	Fire_RefreshLook(building);
}

stock Fire_Reset()
{
	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		Fire_ClearObjects(building);

		if (IsValidDynamic3DTextLabel(s_Fire[building][E_FIRE_LABEL]))
		{
			DestroyDynamic3DTextLabel(s_Fire[building][E_FIRE_LABEL]);
		}

		s_Fire[building][E_FIRE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
		s_Fire[building][E_FIRE_STATE] = FIRE_STATE_SOUND;
		s_Fire[building][E_FIRE_HEAT] = 0;
		s_Fire[building][E_FIRE_PAID] = false;
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Fire_Load()
{
	Fire_Reset();
	Notices_TakeDown(Notices_TabOfKind(FIRE_CRIER_KIND),FIRE_ALARM_TITLE);
	await mysql_aquery_s(g_Mysql,str_new("SELECT building_key, state, burned_at, rebuild_paid FROM buildings WHERE state = 3"));
	new count = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new key[16], burnedAt, paid;
		cache_get_value_name(r,"building_key",key);
		cache_get_value_name_int(r,"burned_at",burnedAt);
		cache_get_value_name_int(r,"rebuild_paid",paid);
		new building = Fire_FindByKey(key);

		if (building == -1)
		{
			continue;
		}

		new house = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE];
		s_Fire[building][E_FIRE_STATE] = FIRE_STATE_GUTTED;
		s_Fire[building][E_FIRE_BURNED_AT] = burnedAt;
		s_Fire[building][E_FIRE_PAID] = paid != 0;

		if (house != -1)
		{
			Houses_SetGutted(house,true);
		}

		Fire_RuinStations(building,true);
		Fire_RefreshLook(building);
		count++;
	}

	return async count;
}
#pragma warning pop

Timer_Declare(Fire_Tick)
{
	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		Fire_Step(building);
	}

	return 1;
}

forward Fire_OnStarted(building,cause);

public Fire_OnStarted(building,cause)
{
	return 1;
}

forward Fire_OnOut(building);

public Fire_OnOut(building)
{
	return 1;
}

forward Fire_OnGutted(building);

public Fire_OnGutted(building)
{
	return 1;
}

forward Fire_OnRebuilt(building);

public Fire_OnRebuilt(building)
{
	return 1;
}

#include <pp-hooks>

hook Calendar_OnDawn()
{
	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		if (Fire_IsGutted(building) && s_Fire[building][E_FIRE_PAID])
		{
			Fire_Rebuild(building);
		}
	}
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour

	for (new house = 0;house < HOUSE_SEED_COUNT;house++)
	{
		if (!Houses_IsFireLit(house) || random(FIRE_HEARTH_ODDS) != 0)
		{
			continue;
		}

		new bool:watched = false;

		foreach (new playerid : Player)
		{
			if (Houses_GetInside(playerid) == house)
			{
				watched = true;
				break;
			}
		}

		if (!watched)
		{
			Fire_Start(Fire_FindByHouse(house),FIRE_CAUSE_HEARTH);
		}
	}
}

hook Inventory_OnDropped(playerid,kind,param)
{
	if (E_ITEM_KIND:kind != ITEM_KIND_MISC || param != ITEM_TORCH_LIT || random(100) >= FIRE_TORCH_PERCENT)
	{
		return;
	}

	new building = Fire_FindNearPlayer(playerid,FIRE_TORCH_REACH);

	if (building != -1 && Fire_Start(building,FIRE_CAUSE_TORCH,Character_GetId(playerid)))
	{
		Gui_Notify(playerid,"The torch rolls against the wall and the thatch catches.");
	}
}
