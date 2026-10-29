enum E_LIGHT_SOURCE
{
	bool:E_LIGHT_SOURCE_USED,
	E_LIGHT_SOURCE_ROW,
	E_LIGHT_SOURCE_KIND,
	Float:E_LIGHT_SOURCE_POS[4],
	E_LIGHT_SOURCE_WORLD,
	E_LIGHT_SOURCE_INTERIOR,
	E_LIGHT_SOURCE_SECONDS,
	E_LIGHT_SOURCE_TOTAL,
	E_LIGHT_SOURCE_GONE_AT,
	E_LIGHT_SOURCE_MODEL,
	STREAMER_TAG_OBJECT:E_LIGHT_SOURCE_OBJECT,
	STREAMER_TAG_OBJECT:E_LIGHT_SOURCE_FIRE[LIGHT_FIRE_MAX],
}

static s_LightSources[LIGHT_SOURCES_MAX][E_LIGHT_SOURCE];
static s_LightSaveCountdown;

stock bool:Light_IsValidSource(source)
{
	return source >= 0 && source < LIGHT_SOURCES_MAX && s_LightSources[source][E_LIGHT_SOURCE_USED];
}

stock bool:Light_IsSourceLit(source)
{
	return Light_IsValidSource(source) && s_LightSources[source][E_LIGHT_SOURCE_SECONDS] > 0;
}

stock bool:Light_IsSourceKept(source)
{
	return Light_IsValidSource(source) && s_LightSources[source][E_LIGHT_SOURCE_ROW] > 0;
}

stock Light_GetSourceKind(source)
{
	return Light_IsValidSource(source) ? s_LightSources[source][E_LIGHT_SOURCE_KIND] : -1;
}

stock Light_GetSourceModel(source)
{
	return Light_IsValidSource(source) ? s_LightSources[source][E_LIGHT_SOURCE_MODEL] : 0;
}

stock Light_GetSourceGoneAt(source)
{
	return Light_IsValidSource(source) ? s_LightSources[source][E_LIGHT_SOURCE_GONE_AT] : 0;
}

stock Light_GetSourceSeconds(source)
{
	return Light_IsValidSource(source) ? s_LightSources[source][E_LIGHT_SOURCE_SECONDS] : 0;
}

stock bool:Light_GetSourcePos(source,&Float:x,&Float:y,&Float:z,&world)
{
	if (!Light_IsValidSource(source))
	{
		return false;
	}

	x = s_LightSources[source][E_LIGHT_SOURCE_POS][0];
	y = s_LightSources[source][E_LIGHT_SOURCE_POS][1];
	z = s_LightSources[source][E_LIGHT_SOURCE_POS][2];
	world = s_LightSources[source][E_LIGHT_SOURCE_WORLD];
	return true;
}

stock Light_GetKindName(kind,dest[],size = sizeof(dest))
{
	if (kind < 0 || kind >= LIGHT_SOURCE_KIND_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,g_LightKindDefs[kind][E_LIGHT_KIND_DEF_NAME],size);
}

stock Light_CountSources(bool:isKeptOnly = false)
{
	new count = 0;

	for (new i = 0;i < LIGHT_SOURCES_MAX;i++)
	{
		if (s_LightSources[i][E_LIGHT_SOURCE_USED] && (!isKeptOnly || s_LightSources[i][E_LIGHT_SOURCE_ROW] > 0))
		{
			count++;
		}
	}

	return count;
}

static Light_SourceModel(source)
{
	new kind = s_LightSources[source][E_LIGHT_SOURCE_KIND];

	if (s_LightSources[source][E_LIGHT_SOURCE_SECONDS] <= 0)
	{
		return g_LightKindDefs[kind][E_LIGHT_KIND_DEF_OUT_MODEL];
	}

	new stub = g_LightKindDefs[kind][E_LIGHT_KIND_DEF_STUB_MODEL];

	if (stub != 0 && s_LightSources[source][E_LIGHT_SOURCE_SECONDS] * 100 <= s_LightSources[source][E_LIGHT_SOURCE_TOTAL] * LIGHT_CANDLE_STUB_PERCENT)
	{
		return stub;
	}

	return g_LightKindDefs[kind][E_LIGHT_KIND_DEF_LIT_MODEL];
}

stock Light_CountFirePoints(kind)
{
	new count = 0;

	for (new i = 0;i < sizeof(g_LightFirePoints);i++)
	{
		if (g_LightFirePoints[i][E_LIGHT_FIRE_POINT_KIND] == kind)
		{
			count++;
		}
	}

	return count;
}

stock Light_CountSourceFire(source)
{
	new count = 0;

	if (!Light_IsValidSource(source))
	{
		return 0;
	}

	for (new i = 0;i < LIGHT_FIRE_MAX;i++)
	{
		if (IsValidDynamicObject(s_LightSources[source][E_LIGHT_SOURCE_FIRE][i]))
		{
			count++;
		}
	}

	return count;
}

stock STREAMER_TAG_OBJECT:Light_CreateFlame(Float:x,Float:y,Float:z,world = -1,interior = -1,Float:range = LIGHT_STREAM_RANGE)
{
	return CreateDynamicObject(LIGHT_FLAME_MODEL,x,y,z - LIGHT_FLAME_LIFT,0.0,0.0,0.0,world,interior,-1,range,range,STREAMER_TAG_AREA:-1,LIGHT_STREAM_PRIORITY);
}

stock STREAMER_TAG_OBJECT:Light_CreateGlow(model,Float:x,Float:y,Float:z,world = -1,interior = -1,Float:range = LIGHT_STREAM_RANGE)
{
	return CreateDynamicObject(model,x,y,z,0.0,0.0,0.0,world,interior,-1,range,range,STREAMER_TAG_AREA:-1,LIGHT_STREAM_PRIORITY);
}

stock STREAMER_TAG_OBJECT:Light_CreateFlameAt(Float:x,Float:y,Float:z,Float:heading,Float:localX,Float:localY,Float:localZ,world = -1,interior = -1,Float:range = LIGHT_STREAM_RANGE)
{
	return Light_CreateFlame(x + localX * floatcos(heading,degrees) - localY * floatsin(heading,degrees),y + localX * floatsin(heading,degrees) + localY * floatcos(heading,degrees),z + localZ,world,interior,range);
}

stock Light_DestroyFlame(&STREAMER_TAG_OBJECT:flame)
{
	if (IsValidDynamicObject(flame))
	{
		DestroyDynamicObject(flame);
	}

	flame = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Light_DestroyFire(source)
{
	for (new i = 0;i < LIGHT_FIRE_MAX;i++)
	{
		Light_DestroyFlame(s_LightSources[source][E_LIGHT_SOURCE_FIRE][i]);
	}
}

static Light_CreateFire(source)
{
	new slot = 0, kind = s_LightSources[source][E_LIGHT_SOURCE_KIND];

	for (new i = 0;i < sizeof(g_LightFirePoints) && slot < LIGHT_FIRE_MAX;i++)
	{
		if (g_LightFirePoints[i][E_LIGHT_FIRE_POINT_KIND] != kind)
		{
			continue;
		}

		s_LightSources[source][E_LIGHT_SOURCE_FIRE][slot++] = Light_CreateFlameAt(s_LightSources[source][E_LIGHT_SOURCE_POS][0],s_LightSources[source][E_LIGHT_SOURCE_POS][1],s_LightSources[source][E_LIGHT_SOURCE_POS][2],s_LightSources[source][E_LIGHT_SOURCE_POS][3],g_LightFirePoints[i][E_LIGHT_FIRE_POINT_OFFSET][0],g_LightFirePoints[i][E_LIGHT_FIRE_POINT_OFFSET][1],g_LightFirePoints[i][E_LIGHT_FIRE_POINT_OFFSET][2],s_LightSources[source][E_LIGHT_SOURCE_WORLD],s_LightSources[source][E_LIGHT_SOURCE_INTERIOR]);
	}
}

static Light_RefreshSource(source)
{
	new model = Light_SourceModel(source);

	if (model == s_LightSources[source][E_LIGHT_SOURCE_MODEL] && IsValidDynamicObject(s_LightSources[source][E_LIGHT_SOURCE_OBJECT]))
	{
		return;
	}

	if (IsValidDynamicObject(s_LightSources[source][E_LIGHT_SOURCE_OBJECT]))
	{
		DestroyDynamicObject(s_LightSources[source][E_LIGHT_SOURCE_OBJECT]);
	}

	Light_DestroyFire(source);

	s_LightSources[source][E_LIGHT_SOURCE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_LightSources[source][E_LIGHT_SOURCE_MODEL] = model;

	if (model == 0)
	{
		return;
	}

	s_LightSources[source][E_LIGHT_SOURCE_OBJECT] = CreateDynamicObject(model,s_LightSources[source][E_LIGHT_SOURCE_POS][0],s_LightSources[source][E_LIGHT_SOURCE_POS][1],s_LightSources[source][E_LIGHT_SOURCE_POS][2],0.0,0.0,s_LightSources[source][E_LIGHT_SOURCE_POS][3],s_LightSources[source][E_LIGHT_SOURCE_WORLD],s_LightSources[source][E_LIGHT_SOURCE_INTERIOR],-1,LIGHT_STREAM_RANGE,LIGHT_STREAM_RANGE,STREAMER_TAG_AREA:-1,LIGHT_STREAM_PRIORITY);
	if (s_LightSources[source][E_LIGHT_SOURCE_SECONDS] > 0)
	{
		Light_CreateFire(source);
	}

	Nearby_StreamObjectsAt(s_LightSources[source][E_LIGHT_SOURCE_POS][0],s_LightSources[source][E_LIGHT_SOURCE_POS][1],s_LightSources[source][E_LIGHT_SOURCE_POS][2],s_LightSources[source][E_LIGHT_SOURCE_WORLD],s_LightSources[source][E_LIGHT_SOURCE_INTERIOR],LIGHT_STREAM_RANGE);
}

stock Light_AddSource(row,kind,Float:x,Float:y,Float:z,Float:a,world,interior,seconds)
{
	if (kind < 0 || kind >= LIGHT_SOURCE_KIND_COUNT)
	{
		return -1;
	}

	for (new i = 0;i < LIGHT_SOURCES_MAX;i++)
	{
		if (s_LightSources[i][E_LIGHT_SOURCE_USED])
		{
			continue;
		}

		s_LightSources[i][E_LIGHT_SOURCE_USED] = true;
		s_LightSources[i][E_LIGHT_SOURCE_ROW] = row;
		s_LightSources[i][E_LIGHT_SOURCE_KIND] = kind;
		s_LightSources[i][E_LIGHT_SOURCE_POS][0] = x;
		s_LightSources[i][E_LIGHT_SOURCE_POS][1] = y;
		s_LightSources[i][E_LIGHT_SOURCE_POS][2] = z;
		s_LightSources[i][E_LIGHT_SOURCE_POS][3] = a;
		s_LightSources[i][E_LIGHT_SOURCE_WORLD] = world;
		s_LightSources[i][E_LIGHT_SOURCE_INTERIOR] = interior;
		s_LightSources[i][E_LIGHT_SOURCE_SECONDS] = max(seconds,0);
		s_LightSources[i][E_LIGHT_SOURCE_TOTAL] = max(seconds,1);
		s_LightSources[i][E_LIGHT_SOURCE_GONE_AT] = 0;
		s_LightSources[i][E_LIGHT_SOURCE_MODEL] = 0;
		s_LightSources[i][E_LIGHT_SOURCE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

		for (new f = 0;f < LIGHT_FIRE_MAX;f++)
		{
			s_LightSources[i][E_LIGHT_SOURCE_FIRE][f] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		}

		Light_RefreshSource(i);
		return i;
	}

	return -1;
}

stock Light_PlaceCandle(bool:isWax,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	return Light_AddSource(0,isWax ? LIGHT_SOURCE_CANDLE_WAX : LIGHT_SOURCE_CANDLE_TALLOW,x,y,z,a,world,interior,isWax ? LIGHT_CANDLE_WAX_SECONDS : LIGHT_CANDLE_TALLOW_SECONDS);
}

stock Light_RemoveSource(source)
{
	if (!Light_IsValidSource(source))
	{
		return;
	}

	if (IsValidDynamicObject(s_LightSources[source][E_LIGHT_SOURCE_OBJECT]))
	{
		DestroyDynamicObject(s_LightSources[source][E_LIGHT_SOURCE_OBJECT]);
	}

	Light_DestroyFire(source);

	if (s_LightSources[source][E_LIGHT_SOURCE_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM light_sources WHERE id = %d",s_LightSources[source][E_LIGHT_SOURCE_ROW]));
	}

	s_LightSources[source][E_LIGHT_SOURCE_USED] = false;
	s_LightSources[source][E_LIGHT_SOURCE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Light_SaveSource(source)
{
	if (s_LightSources[source][E_LIGHT_SOURCE_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE light_sources SET fuel = %d WHERE id = %d",s_LightSources[source][E_LIGHT_SOURCE_SECONDS],s_LightSources[source][E_LIGHT_SOURCE_ROW]));
	}
}

stock Light_SetSourceSeconds(source,seconds)
{
	if (!Light_IsValidSource(source))
	{
		return;
	}

	new bool:wasLit = s_LightSources[source][E_LIGHT_SOURCE_SECONDS] > 0;
	s_LightSources[source][E_LIGHT_SOURCE_SECONDS] = Util_ClampInt(seconds,0,LIGHT_FUEL_CAP_SECONDS);

	if (!wasLit || s_LightSources[source][E_LIGHT_SOURCE_SECONDS] > s_LightSources[source][E_LIGHT_SOURCE_TOTAL])
	{
		s_LightSources[source][E_LIGHT_SOURCE_TOTAL] = max(s_LightSources[source][E_LIGHT_SOURCE_SECONDS],1);
	}

	s_LightSources[source][E_LIGHT_SOURCE_GONE_AT] = 0;

	if (wasLit && s_LightSources[source][E_LIGHT_SOURCE_SECONDS] == 0)
	{
		pawn_call_public("Light_OnSourceOut","d",source);

		if (s_LightSources[source][E_LIGHT_SOURCE_ROW] == 0)
		{
			s_LightSources[source][E_LIGHT_SOURCE_GONE_AT] = gettime() + (g_LightKindDefs[s_LightSources[source][E_LIGHT_SOURCE_KIND]][E_LIGHT_KIND_DEF_OUT_MODEL] != 0 ? LIGHT_ASH_SECONDS : 0);
		}
	}

	Light_RefreshSource(source);
	Light_SaveSource(source);
}

stock Light_GetFuelSeconds(kind,item)
{
	switch (kind)
	{
		case LIGHT_SOURCE_BRAZIER:
		{
			if (item == ITEM_CHARCOAL)
			{
				return LIGHT_BRAZIER_CHARCOAL_SECONDS;
			}

			if (item == ITEM_FIREWOOD)
			{
				return LIGHT_BRAZIER_FIREWOOD_SECONDS;
			}
		}
		case LIGHT_SOURCE_BONFIRE:
		{
			if (item == ITEM_FIREWOOD)
			{
				return LIGHT_BONFIRE_FIREWOOD_SECONDS;
			}
		}
	}

	return 0;
}

stock Light_FindSourceNear(Float:x,Float:y,Float:z,world,Float:range,bool:isLitOnly = false,kind = -1)
{
	new best = -1, Float:bestDistance = range;

	for (new i = 0;i < LIGHT_SOURCES_MAX;i++)
	{
		if (!s_LightSources[i][E_LIGHT_SOURCE_USED] || s_LightSources[i][E_LIGHT_SOURCE_WORLD] != world || (isLitOnly && s_LightSources[i][E_LIGHT_SOURCE_SECONDS] <= 0) || (kind != -1 && s_LightSources[i][E_LIGHT_SOURCE_KIND] != kind))
		{
			continue;
		}

		new Float:distance = Util_GetDistance3D(x,y,z,s_LightSources[i][E_LIGHT_SOURCE_POS][0],s_LightSources[i][E_LIGHT_SOURCE_POS][1],s_LightSources[i][E_LIGHT_SOURCE_POS][2]);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Light_FindSourceForPlayer(playerid,Float:range,bool:isLitOnly = false,kind = -1)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return Light_FindSourceNear(x,y,z - 0.9,GetPlayerVirtualWorld(playerid),range,isLitOnly,kind);
}

stock Light_SourceTick(seconds)
{
	new now = gettime();
	s_LightSaveCountdown -= seconds;

	for (new i = 0;i < LIGHT_SOURCES_MAX;i++)
	{
		if (!s_LightSources[i][E_LIGHT_SOURCE_USED])
		{
			continue;
		}

		if (s_LightSources[i][E_LIGHT_SOURCE_SECONDS] > 0)
		{
			s_LightSources[i][E_LIGHT_SOURCE_SECONDS] = max(s_LightSources[i][E_LIGHT_SOURCE_SECONDS] - seconds,0);

			if (s_LightSources[i][E_LIGHT_SOURCE_SECONDS] == 0)
			{
				pawn_call_public("Light_OnSourceOut","d",i);

				if (s_LightSources[i][E_LIGHT_SOURCE_ROW] == 0)
				{
					s_LightSources[i][E_LIGHT_SOURCE_GONE_AT] = now + (g_LightKindDefs[s_LightSources[i][E_LIGHT_SOURCE_KIND]][E_LIGHT_KIND_DEF_OUT_MODEL] != 0 ? LIGHT_ASH_SECONDS : 0);
				}
				else
				{
					Light_SaveSource(i);
				}
			}

			Light_RefreshSource(i);
			continue;
		}

		if (s_LightSources[i][E_LIGHT_SOURCE_ROW] == 0 && s_LightSources[i][E_LIGHT_SOURCE_GONE_AT] != 0 && now >= s_LightSources[i][E_LIGHT_SOURCE_GONE_AT])
		{
			Light_RemoveSource(i);
		}
	}

	if (s_LightSaveCountdown <= 0)
	{
		s_LightSaveCountdown = LIGHT_SAVE_SECONDS;

		for (new i = 0;i < LIGHT_SOURCES_MAX;i++)
		{
			if (s_LightSources[i][E_LIGHT_SOURCE_USED] && s_LightSources[i][E_LIGHT_SOURCE_ROW] > 0 && s_LightSources[i][E_LIGHT_SOURCE_SECONDS] > 0)
			{
				Light_SaveSource(i);
			}
		}
	}
}

stock bool:Light_IsLitNear(Float:x,Float:y,Float:z,world,Float:range = LIGHT_GLOW_RANGE)
{
	if (Light_FindSourceNear(x,y,z,world,range,true) != -1)
	{
		return true;
	}

	foreach (new i : Player)
	{
		if (GetPlayerVirtualWorld(i) == world && Light_HasLight(i) && GetPlayerDistanceFromPoint(i,x,y,z) <= range)
		{
			return true;
		}
	}

	return false;
}

stock bool:Light_IsHeatNear(Float:x,Float:y,Float:z,world,Float:range)
{
	for (new i = 0;i < LIGHT_SOURCES_MAX;i++)
	{
		if (!s_LightSources[i][E_LIGHT_SOURCE_USED] || s_LightSources[i][E_LIGHT_SOURCE_SECONDS] <= 0 || s_LightSources[i][E_LIGHT_SOURCE_WORLD] != world || !g_LightKindDefs[s_LightSources[i][E_LIGHT_SOURCE_KIND]][E_LIGHT_KIND_DEF_IS_FUELLED])
		{
			continue;
		}

		if (Util_GetDistance3D(x,y,z,s_LightSources[i][E_LIGHT_SOURCE_POS][0],s_LightSources[i][E_LIGHT_SOURCE_POS][1],s_LightSources[i][E_LIGHT_SOURCE_POS][2]) <= range)
		{
			return true;
		}
	}

	return false;
}

stock bool:Light_IsPlayerWarmed(playerid)
{
	new Float:x, Float:y, Float:z, world = GetPlayerVirtualWorld(playerid);
	GetPlayerPos(playerid,x,y,z);

	if (Light_IsHeatNear(x,y,z,world,LIGHT_WARM_REACH))
	{
		return true;
	}

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		new Float:stationX, Float:stationY, Float:stationZ, Float:stationA, stationWorld, stationInterior;

		if (Work_IsValidStation(i) && Work_IsStationAlight(i) && Work_GetStationPlace(i,stationX,stationY,stationZ,stationA,stationWorld,stationInterior) && stationWorld == world && Util_GetDistance3D(x,y,z,stationX,stationY,stationZ) <= LIGHT_WARM_STATION_REACH)
		{
			return true;
		}
	}

	new house = Houses_GetInside(playerid);

	if (house != -1 && Houses_IsFireLit(house))
	{
		new Float:hearthX, Float:hearthY, Float:hearthZ;
		Houses_LocalToWorld(0.0,0.0,0.0,hearthX,hearthY,hearthZ);
		return Util_GetDistance3D(x,y,z,hearthX,hearthY,hearthZ) <= LIGHT_WARM_HOUSE_REACH;
	}

	return false;
}

#pragma warning push
#pragma warning disable 204
forward Task:Light_CreateKept(kind,Float:x,Float:y,Float:z,Float:a,world,interior);

async Task:Light_CreateKept(kind,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO light_sources (kind, x, y, z, a, world, interior, fuel) VALUES (%d, %f, %f, %f, %f, %d, %d, 0)",kind,x,y,z,a,world,interior));

	new row = cache_insert_id();
	return async row > 0 ? Light_AddSource(row,kind,x,y,z,a,world,interior,0) : -1;
}
#pragma warning pop

Timer_Declare(Light_Tick)
{
	Light_SourceTick(LIGHT_TICK_MS / 1000);

	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Light_HandTick(playerid,LIGHT_TICK_MS / 1000);
		}
	}

	return 1;
}

forward Light_OnSourceOut(source);

public Light_OnSourceOut(source)
{
	return 1;
}

forward Light_LoadOnBoot();

public Light_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT 1 FROM seeders WHERE seeder_key = 'light-map-1'"));

	if (!cache_num_rows())
	{
		new String:sources = str_new("INSERT INTO light_sources (kind, x, y, z, a, fuel) VALUES ");

		for (new i = 0;i < LIGHT_SEED_COUNT;i++)
		{
			str_append_format(sources,"%s(%d, %f, %f, %f, %f, 0)",i == 0 ? ("") : (", "),g_LightSeeds[i][E_LIGHT_SEED_KIND],g_LightSeeds[i][E_LIGHT_SEED_POS][0],g_LightSeeds[i][E_LIGHT_SEED_POS][1],g_LightSeeds[i][E_LIGHT_SEED_POS][2],g_LightSeeds[i][E_LIGHT_SEED_POS][3]);
		}

		await mysql_aquery_s(g_Mysql,sources);
		await mysql_aquery_s(g_Mysql,str_new("INSERT IGNORE INTO seeders (seeder_key) VALUES ('light-map-1')"));
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, x, y, z, a, world, interior, fuel FROM light_sources ORDER BY id"));

	new placed = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, kind, Float:pos[4], world, interior, fuel;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);
		cache_get_value_name_int(r,"fuel",fuel);

		if (Light_AddSource(row,kind,pos[0],pos[1],pos[2],pos[3],world,interior,fuel) != -1)
		{
			placed++;
		}
	}

	s_LightSaveCountdown = LIGHT_SAVE_SECONDS;
	Log_Info("light","%d brazier(s) and bonfire(s) placed",placed);
	Boot_LoaderDone();
}
