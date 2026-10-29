enum E_GRAVE
{
	bool:E_GRAVE_USED,
	E_GRAVE_ROW,
	E_GRAVE_YARD[GRAVES_KEY_LEN],
	E_GRAVE_PLOT,
	Float:E_GRAVE_POS[4],
	E_GRAVE_WORLD,
	E_GRAVE_INTERIOR,
	E_GRAVE_CHARACTER,
	E_GRAVE_MARKER,
	E_GRAVE_DUG_AT,
	bool:E_GRAVE_SETTLED,
	E_GRAVE_NAME[GRAVES_NAME_LEN],
	E_GRAVE_BORN_DAY,
	E_GRAVE_DIED_DAY,
	E_GRAVE_AGE,
	E_GRAVE_CAUSE[GRAVES_CAUSE_LEN],
	STREAMER_TAG_OBJECT:E_GRAVE_MOUND,
	STREAMER_TAG_OBJECT:E_GRAVE_MARK,
	STREAMER_TAG_3D_TEXT_LABEL:E_GRAVE_LABEL,
}

static s_Graves[GRAVES_PLOTS_MAX][E_GRAVE];

enum E_GRAVE_TRIBUTE
{
	bool:E_GRAVE_TRIBUTE_USED,
	E_GRAVE_TRIBUTE_GRAVE,
	E_GRAVE_TRIBUTE_CHARACTER,
	E_GRAVE_TRIBUTE_UNTIL,
	STREAMER_TAG_OBJECT:E_GRAVE_TRIBUTE_OBJECT,
}

static s_GraveTributes[GRAVES_TRIBUTES_MAX][E_GRAVE_TRIBUTE];

stock bool:Grave_IsValid(grave)
{
	return grave >= 0 && grave < GRAVES_PLOTS_MAX && s_Graves[grave][E_GRAVE_USED];
}

stock bool:Grave_IsTaken(grave)
{
	return Grave_IsValid(grave) && s_Graves[grave][E_GRAVE_CHARACTER] != 0;
}

stock Grave_GetCharacter(grave)
{
	return Grave_IsValid(grave) ? s_Graves[grave][E_GRAVE_CHARACTER] : 0;
}

stock Grave_GetMarker(grave)
{
	return Grave_IsValid(grave) ? s_Graves[grave][E_GRAVE_MARKER] : -1;
}

stock bool:Grave_IsSettled(grave)
{
	return Grave_IsValid(grave) && s_Graves[grave][E_GRAVE_SETTLED];
}

stock Grave_GetRow(grave)
{
	return Grave_IsValid(grave) ? s_Graves[grave][E_GRAVE_ROW] : 0;
}

stock Grave_GetName(grave,dest[],size = sizeof(dest))
{
	if (!Grave_IsValid(grave))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Graves[grave][E_GRAVE_NAME],size);
}

stock Grave_GetYard(grave,dest[],size = sizeof(dest))
{
	if (!Grave_IsValid(grave))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Graves[grave][E_GRAVE_YARD],size);
}

stock bool:Grave_GetPos(grave,&Float:x,&Float:y,&Float:z,&Float:a,&world,&interior)
{
	if (!Grave_IsValid(grave))
	{
		return false;
	}

	x = s_Graves[grave][E_GRAVE_POS][0];
	y = s_Graves[grave][E_GRAVE_POS][1];
	z = s_Graves[grave][E_GRAVE_POS][2];
	a = s_Graves[grave][E_GRAVE_POS][3];
	world = s_Graves[grave][E_GRAVE_WORLD];
	interior = s_Graves[grave][E_GRAVE_INTERIOR];
	return true;
}

stock Grave_GetHeadPos(grave,&Float:x,&Float:y,&Float:z)
{
	new Float:a = s_Graves[grave][E_GRAVE_POS][3];
	x = s_Graves[grave][E_GRAVE_POS][0] + GRAVES_MARKER_OFFSET * floatcos(a,degrees);
	y = s_Graves[grave][E_GRAVE_POS][1] + GRAVES_MARKER_OFFSET * floatsin(a,degrees);
	z = s_Graves[grave][E_GRAVE_POS][2];
}

stock Grave_CountPlots(bool:isFreeOnly = false)
{
	new count = 0;

	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (s_Graves[i][E_GRAVE_USED] && (!isFreeOnly || s_Graves[i][E_GRAVE_CHARACTER] == 0))
		{
			count++;
		}
	}

	return count;
}

stock Grave_CountYard(const yard[])
{
	new count = 0;

	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (s_Graves[i][E_GRAVE_USED] && !strcmp(s_Graves[i][E_GRAVE_YARD],yard,true))
		{
			count++;
		}
	}

	return count;
}

stock Grave_FormatInscription(grave,dest[],size = sizeof(dest))
{
	if (!Grave_IsTaken(grave))
	{
		strcopy(dest,"An empty plot.",size);
		return;
	}

	new born[24], died[24];
	Calendar_FormatDay(s_Graves[grave][E_GRAVE_BORN_DAY],born);
	Calendar_FormatDay(s_Graves[grave][E_GRAVE_DIED_DAY],died);

	if (s_Graves[grave][E_GRAVE_CAUSE][0] != EOS)
	{
		format(dest,size,"Here lies ~y~%s~w~.~n~Born %s, died %s at %d.~n~Taken by %s.",s_Graves[grave][E_GRAVE_NAME],born,died,s_Graves[grave][E_GRAVE_AGE],s_Graves[grave][E_GRAVE_CAUSE]);
	}
	else
	{
		format(dest,size,"Here lies ~y~%s~w~.~n~Born %s, died %s at %d.",s_Graves[grave][E_GRAVE_NAME],born,died,s_Graves[grave][E_GRAVE_AGE]);
	}
}

static Grave_ClearObjects(grave)
{
	if (IsValidDynamicObject(s_Graves[grave][E_GRAVE_MOUND]))
	{
		DestroyDynamicObject(s_Graves[grave][E_GRAVE_MOUND]);
	}

	if (IsValidDynamicObject(s_Graves[grave][E_GRAVE_MARK]))
	{
		DestroyDynamicObject(s_Graves[grave][E_GRAVE_MARK]);
	}

	if (IsValidDynamic3DTextLabel(s_Graves[grave][E_GRAVE_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Graves[grave][E_GRAVE_LABEL]);
	}

	s_Graves[grave][E_GRAVE_MOUND] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Graves[grave][E_GRAVE_MARK] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Graves[grave][E_GRAVE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock Grave_Refresh(grave)
{
	if (!Grave_IsValid(grave))
	{
		return;
	}

	Grave_ClearObjects(grave);

	if (s_Graves[grave][E_GRAVE_CHARACTER] == 0)
	{
		return;
	}

	new Float:x = s_Graves[grave][E_GRAVE_POS][0], Float:y = s_Graves[grave][E_GRAVE_POS][1], Float:z = s_Graves[grave][E_GRAVE_POS][2], Float:a = s_Graves[grave][E_GRAVE_POS][3];
	new world = s_Graves[grave][E_GRAVE_WORLD], interior = s_Graves[grave][E_GRAVE_INTERIOR], Float:headX, Float:headY, Float:headZ;
	s_Graves[grave][E_GRAVE_MOUND] = CreateDynamicObject(s_Graves[grave][E_GRAVE_SETTLED] ? MODEL_VILLAGE_GRAVE_SETTLED : MODEL_VILLAGE_GRAVE_FRESH,x,y,z,0.0,0.0,a,world,interior,-1,GRAVES_STREAM_RANGE,GRAVES_STREAM_RANGE);
	Grave_GetHeadPos(grave,headX,headY,headZ);
	s_Graves[grave][E_GRAVE_MARK] = CreateDynamicObject(g_GraveMarkerModels[Util_ClampInt(s_Graves[grave][E_GRAVE_MARKER],0,GRAVE_MARKER_COUNT - 1)],headX,headY,headZ,0.0,0.0,a,world,interior,-1,GRAVES_STREAM_RANGE,GRAVES_STREAM_RANGE);

	new label[GRAVES_NAME_LEN + 16];
	format(label,sizeof(label),"%s",s_Graves[grave][E_GRAVE_NAME]);
	s_Graves[grave][E_GRAVE_LABEL] = CreateDynamic3DTextLabel(label,GRAVES_LABEL_COLOUR,headX,headY,headZ + 1.2,GRAVES_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,true,world,interior);
	Nearby_StreamObjectsAt(x,y,z,world,interior,GRAVES_STREAM_RANGE);
}

stock Grave_Add(row,const yard[],plot,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (s_Graves[i][E_GRAVE_USED])
		{
			continue;
		}

		s_Graves[i][E_GRAVE_USED] = true;
		s_Graves[i][E_GRAVE_ROW] = row;
		strcopy(s_Graves[i][E_GRAVE_YARD],yard,GRAVES_KEY_LEN);
		s_Graves[i][E_GRAVE_PLOT] = plot;
		s_Graves[i][E_GRAVE_POS][0] = x;
		s_Graves[i][E_GRAVE_POS][1] = y;
		s_Graves[i][E_GRAVE_POS][2] = z;
		s_Graves[i][E_GRAVE_POS][3] = a;
		s_Graves[i][E_GRAVE_WORLD] = world;
		s_Graves[i][E_GRAVE_INTERIOR] = interior;
		s_Graves[i][E_GRAVE_CHARACTER] = 0;
		s_Graves[i][E_GRAVE_MARKER] = GRAVE_MARKER_WOOD;
		s_Graves[i][E_GRAVE_DUG_AT] = 0;
		s_Graves[i][E_GRAVE_SETTLED] = false;
		s_Graves[i][E_GRAVE_NAME][0] = EOS;
		s_Graves[i][E_GRAVE_CAUSE][0] = EOS;
		s_Graves[i][E_GRAVE_MOUND] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_Graves[i][E_GRAVE_MARK] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_Graves[i][E_GRAVE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
		return i;
	}

	return -1;
}

stock Grave_SetOccupant(grave,characterid,const name[],bornDay,diedDay,age,const cause[],marker,dugAt,bool:isSettled)
{
	if (!Grave_IsValid(grave))
	{
		return;
	}

	s_Graves[grave][E_GRAVE_CHARACTER] = characterid;
	strcopy(s_Graves[grave][E_GRAVE_NAME],name,GRAVES_NAME_LEN);
	strcopy(s_Graves[grave][E_GRAVE_CAUSE],cause,GRAVES_CAUSE_LEN);
	s_Graves[grave][E_GRAVE_BORN_DAY] = bornDay;
	s_Graves[grave][E_GRAVE_DIED_DAY] = diedDay;
	s_Graves[grave][E_GRAVE_AGE] = age;
	s_Graves[grave][E_GRAVE_MARKER] = marker;
	s_Graves[grave][E_GRAVE_DUG_AT] = dugAt;
	s_Graves[grave][E_GRAVE_SETTLED] = isSettled;
	Grave_Refresh(grave);
}

stock Grave_FindFree(Float:x,Float:y,Float:z)
{
	new best = -1, Float:bestDistance = 1.0e9;

	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (!s_Graves[i][E_GRAVE_USED] || s_Graves[i][E_GRAVE_CHARACTER] != 0)
		{
			continue;
		}

		new Float:distance = Util_GetDistance3D(x,y,z,s_Graves[i][E_GRAVE_POS][0],s_Graves[i][E_GRAVE_POS][1],s_Graves[i][E_GRAVE_POS][2]);

		if (distance < bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Grave_FindNear(Float:x,Float:y,Float:z,world,Float:range,bool:isTakenOnly = false)
{
	new best = -1, Float:bestDistance = range;

	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (!s_Graves[i][E_GRAVE_USED] || s_Graves[i][E_GRAVE_WORLD] != world || (isTakenOnly && s_Graves[i][E_GRAVE_CHARACTER] == 0))
		{
			continue;
		}

		new Float:distance = Util_GetDistance3D(x,y,z,s_Graves[i][E_GRAVE_POS][0],s_Graves[i][E_GRAVE_POS][1],s_Graves[i][E_GRAVE_POS][2]);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Grave_FindForPlayer(playerid,Float:range,bool:isTakenOnly = false)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return Grave_FindNear(x,y,z - 0.9,GetPlayerVirtualWorld(playerid),range,isTakenOnly);
}

stock Grave_FindByCharacter(characterid)
{
	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (s_Graves[i][E_GRAVE_USED] && s_Graves[i][E_GRAVE_CHARACTER] == characterid)
		{
			return i;
		}
	}

	return -1;
}

stock Grave_FindByRow(row)
{
	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (s_Graves[i][E_GRAVE_USED] && s_Graves[i][E_GRAVE_ROW] == row)
		{
			return i;
		}
	}

	return -1;
}

stock Grave_Save(grave)
{
	if (!Grave_IsValid(grave) || s_Graves[grave][E_GRAVE_ROW] <= 0)
	{
		return;
	}

	if (s_Graves[grave][E_GRAVE_CHARACTER] == 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE graves SET character_id = NULL, marker = %d, dug_at = 0, settled = 0 WHERE id = %d",s_Graves[grave][E_GRAVE_MARKER],s_Graves[grave][E_GRAVE_ROW]));
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE graves SET character_id = %d, marker = %d, dug_at = %d, settled = %d WHERE id = %d",s_Graves[grave][E_GRAVE_CHARACTER],s_Graves[grave][E_GRAVE_MARKER],s_Graves[grave][E_GRAVE_DUG_AT],_:s_Graves[grave][E_GRAVE_SETTLED],s_Graves[grave][E_GRAVE_ROW]));
}

stock Grave_SetMarker(grave,marker)
{
	if (!Grave_IsValid(grave) || marker < 0 || marker >= GRAVE_MARKER_COUNT)
	{
		return;
	}

	s_Graves[grave][E_GRAVE_MARKER] = marker;
	Grave_Save(grave);
	Grave_Refresh(grave);
}

stock Grave_Settle(grave)
{
	if (!Grave_IsTaken(grave) || s_Graves[grave][E_GRAVE_SETTLED])
	{
		return;
	}

	s_Graves[grave][E_GRAVE_SETTLED] = true;
	Grave_Save(grave);
	Grave_Refresh(grave);
}

static Grave_ClearTributes(grave)
{
	for (new i = 0;i < GRAVES_TRIBUTES_MAX;i++)
	{
		if (s_GraveTributes[i][E_GRAVE_TRIBUTE_USED] && s_GraveTributes[i][E_GRAVE_TRIBUTE_GRAVE] == grave)
		{
			Grave_RemoveTribute(i);
		}
	}
}

stock Grave_RemovePlot(grave)
{
	if (!Grave_IsValid(grave))
	{
		return;
	}

	Grave_ClearObjects(grave);
	Grave_ClearTributes(grave);

	if (s_Graves[grave][E_GRAVE_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM graves WHERE id = %d",s_Graves[grave][E_GRAVE_ROW]));
	}

	s_Graves[grave][E_GRAVE_USED] = false;
}

stock Grave_Exhume(grave)
{
	if (!Grave_IsTaken(grave))
	{
		return;
	}

	s_Graves[grave][E_GRAVE_CHARACTER] = 0;
	s_Graves[grave][E_GRAVE_NAME][0] = EOS;
	s_Graves[grave][E_GRAVE_SETTLED] = false;
	Grave_ClearTributes(grave);
	Grave_Save(grave);
	Grave_Refresh(grave);
}

stock Grave_SettleTick()
{
	new now = gettime();

	for (new i = 0;i < GRAVES_PLOTS_MAX;i++)
	{
		if (s_Graves[i][E_GRAVE_USED] && s_Graves[i][E_GRAVE_CHARACTER] != 0 && !s_Graves[i][E_GRAVE_SETTLED] && s_Graves[i][E_GRAVE_DUG_AT] > 0 && now - s_Graves[i][E_GRAVE_DUG_AT] >= GRAVES_SETTLE_SECONDS)
		{
			Grave_Settle(i);
		}
	}

	for (new i = 0;i < GRAVES_TRIBUTES_MAX;i++)
	{
		if (s_GraveTributes[i][E_GRAVE_TRIBUTE_USED] && now >= s_GraveTributes[i][E_GRAVE_TRIBUTE_UNTIL])
		{
			Grave_RemoveTribute(i);
		}
	}
}

stock Grave_RemoveTribute(tribute)
{
	if (IsValidDynamicObject(s_GraveTributes[tribute][E_GRAVE_TRIBUTE_OBJECT]))
	{
		DestroyDynamicObject(s_GraveTributes[tribute][E_GRAVE_TRIBUTE_OBJECT]);
	}

	s_GraveTributes[tribute][E_GRAVE_TRIBUTE_USED] = false;
	s_GraveTributes[tribute][E_GRAVE_TRIBUTE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock bool:Grave_HasLaidFlowers(grave,characterid)
{
	for (new i = 0;i < GRAVES_TRIBUTES_MAX;i++)
	{
		if (s_GraveTributes[i][E_GRAVE_TRIBUTE_USED] && s_GraveTributes[i][E_GRAVE_TRIBUTE_GRAVE] == grave && s_GraveTributes[i][E_GRAVE_TRIBUTE_CHARACTER] == characterid)
		{
			return true;
		}
	}

	return false;
}

stock bool:Grave_LayFlowers(grave,characterid)
{
	if (!Grave_IsTaken(grave) || Grave_HasLaidFlowers(grave,characterid))
	{
		return false;
	}

	for (new i = 0;i < GRAVES_TRIBUTES_MAX;i++)
	{
		if (s_GraveTributes[i][E_GRAVE_TRIBUTE_USED])
		{
			continue;
		}

		new Float:a = s_Graves[grave][E_GRAVE_POS][3], Float:spread = float(random(30) - 15) / 100.0;
		new Float:x = s_Graves[grave][E_GRAVE_POS][0] + GRAVES_POSY_OFFSET * floatcos(a,degrees) - spread * floatsin(a,degrees);
		new Float:y = s_Graves[grave][E_GRAVE_POS][1] + GRAVES_POSY_OFFSET * floatsin(a,degrees) + spread * floatcos(a,degrees);
		new Float:z = s_Graves[grave][E_GRAVE_POS][2] + (s_Graves[grave][E_GRAVE_SETTLED] ? GRAVES_POSY_SETTLED_Z : GRAVES_POSY_FRESH_Z);
		s_GraveTributes[i][E_GRAVE_TRIBUTE_USED] = true;
		s_GraveTributes[i][E_GRAVE_TRIBUTE_GRAVE] = grave;
		s_GraveTributes[i][E_GRAVE_TRIBUTE_CHARACTER] = characterid;
		s_GraveTributes[i][E_GRAVE_TRIBUTE_UNTIL] = gettime() + GRAVES_TRIBUTE_SECONDS;
		s_GraveTributes[i][E_GRAVE_TRIBUTE_OBJECT] = CreateDynamicObject(MODEL_VILLAGE_FLOWER_POSY,x,y,z,0.0,0.0,a + float(random(20) - 10),s_Graves[grave][E_GRAVE_WORLD],s_Graves[grave][E_GRAVE_INTERIOR],-1,GRAVES_STREAM_RANGE,GRAVES_STREAM_RANGE);
		Nearby_StreamObjectsAt(x,y,z,s_Graves[grave][E_GRAVE_WORLD],s_Graves[grave][E_GRAVE_INTERIOR],GRAVES_STREAM_RANGE);
		return true;
	}

	return false;
}

stock bool:Grave_LightCandle(grave,bool:isWax)
{
	if (!Grave_IsTaken(grave))
	{
		return false;
	}

	new Float:a = s_Graves[grave][E_GRAVE_POS][3], Float:headX, Float:headY, Float:headZ;
	Grave_GetHeadPos(grave,headX,headY,headZ);
	headX -= 0.25 * floatcos(a,degrees);
	headY -= 0.25 * floatsin(a,degrees);
	return Light_PlaceCandle(isWax,headX,headY,headZ + (s_Graves[grave][E_GRAVE_SETTLED] ? 0.12 : 0.2),a,s_Graves[grave][E_GRAVE_WORLD],s_Graves[grave][E_GRAVE_INTERIOR]) != -1;
}

#pragma warning push
#pragma warning disable 204
forward Task:Grave_CreatePlot(const yard[],Float:x,Float:y,Float:z,Float:a,world,interior);

async Task:Grave_CreatePlot(const yard[],Float:x,Float:y,Float:z,Float:a,world,interior)
{
	new plot = Grave_CountYard(yard) + 1;
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO graves (yard_key, plot, x, y, z, a, world, interior) VALUES ('%e', %d, %f, %f, %f, %f, %d, %d)",yard,plot,x,y,z,a,world,interior));

	new row = cache_insert_id();
	return async row > 0 ? Grave_Add(row,yard,plot,x,y,z,a,world,interior) : -1;
}

forward Task:Graves_Bury(characterid,Float:x,Float:y,Float:z);

async Task:Graves_Bury(characterid,Float:x,Float:y,Float:z)
{
	if (Grave_FindByCharacter(characterid) != -1 || Crypt_FindNicheByCharacter(characterid) != -1)
	{
		wait_ticks(1);
		return async -1;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT name, surname, IFNULL(born_day, 0) AS born_day, IFNULL(died_day, 0) AS died_day, IFNULL(died_age, 0) AS died_age, IFNULL(death_cause, '') AS death_cause FROM characters WHERE id = %d",characterid));

	if (!cache_num_rows())
	{
		return async -1;
	}

	new first[24], surname[24], name[GRAVES_NAME_LEN], cause[GRAVES_CAUSE_LEN], bornDay, diedDay, age;
	cache_get_value_name(0,"name",first);
	cache_get_value_name(0,"surname",surname);
	cache_get_value_name_int(0,"born_day",bornDay);
	cache_get_value_name_int(0,"died_day",diedDay);
	cache_get_value_name_int(0,"died_age",age);
	cache_get_value_name(0,"death_cause",cause);
	format(name,sizeof(name),"%s %s",first,surname);

	new grave = Grave_FindFree(x,y,z);

	if (grave != -1)
	{
		Grave_SetOccupant(grave,characterid,name,bornDay,diedDay,age,cause,GRAVE_MARKER_WOOD,gettime(),false);
		Grave_Save(grave);
		Funeral_Schedule(characterid,s_Graves[grave][E_GRAVE_ROW],0,name,s_Graves[grave][E_GRAVE_YARD]);
		pawn_call_public("Graves_OnBuried","dd",characterid,grave);
		return async grave;
	}

	new niche = await Crypt_Inter(characterid,name,bornDay,diedDay,age,cause);

	if (niche == -1)
	{
		Log_Warn("graves","no free plot or crypt niche for character %d (%s)",characterid,name);
	}

	return async -1;
}
#pragma warning pop

forward Graves_OnBuried(characterid,grave);

public Graves_OnBuried(characterid,grave)
{
	return 1;
}

forward Graves_BuryDeferred(characterid,Float:x,Float:y,Float:z);

public Graves_BuryDeferred(characterid,Float:x,Float:y,Float:z)
{
	yield 1;

	await Graves_Bury(characterid,x,y,z);
}

forward Graves_LoadOnBoot();

public Graves_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT 1 FROM seeders WHERE seeder_key = 'graves-map-1'"));

	if (!cache_num_rows())
	{
		new String:plots = str_new("INSERT INTO graves (yard_key, plot, x, y, z, a) VALUES ");

		for (new i = 0;i < GRAVES_SEED_PLOTS;i++)
		{
			str_append_format(plots,"%s('%e', %d, %f, %f, %f, %f)",i == 0 ? ("") : (", "),GRAVES_SEED_YARD,i + 1,g_GravesSeedPlots[i][0],g_GravesSeedPlots[i][1],g_GravesSeedPlots[i][2],g_GravesSeedPlots[i][3]);
		}

		await mysql_aquery_s(g_Mysql,plots);
		await mysql_aquery_s(g_Mysql,str_format("INSERT INTO crypts (crypt_key, door_x, door_y, door_z, door_a, chambers) VALUES ('%e', %f, %f, %f, %f, 1)",GRAVES_SEED_CRYPT_KEY,g_GravesSeedCrypt[0],g_GravesSeedCrypt[1],g_GravesSeedCrypt[2],g_GravesSeedCrypt[3]));
		await mysql_aquery_s(g_Mysql,str_new("INSERT IGNORE INTO seeders (seeder_key) VALUES ('graves-map-1')"));
		Log_Info("graves","%d churchyard plot(s) and the crypt door seeded from the map",GRAVES_SEED_PLOTS);
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT g.id, g.yard_key, g.plot, g.x, g.y, g.z, g.a, g.world, g.interior, IFNULL(g.character_id, 0) AS character_id, g.marker, g.dug_at, g.settled, IFNULL(c.name, '') AS name, IFNULL(c.surname, '') AS surname, IFNULL(c.born_day, 0) AS born_day, IFNULL(c.died_day, 0) AS died_day, IFNULL(c.died_age, 0) AS died_age, IFNULL(c.death_cause, '') AS death_cause FROM graves g LEFT JOIN characters c ON c.id = g.character_id ORDER BY g.id"));

	new placed = 0, taken = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, yard[GRAVES_KEY_LEN], plot, Float:pos[4], world, interior, characterid, marker, dugAt, settled;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"yard_key",yard);
		cache_get_value_name_int(r,"plot",plot);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);
		cache_get_value_name_int(r,"character_id",characterid);
		cache_get_value_name_int(r,"marker",marker);
		cache_get_value_name_int(r,"dug_at",dugAt);
		cache_get_value_name_int(r,"settled",settled);

		new grave = Grave_Add(row,yard,plot,pos[0],pos[1],pos[2],pos[3],world,interior);

		if (grave == -1)
		{
			continue;
		}

		placed++;

		if (characterid != 0)
		{
			new first[24], surname[24], name[GRAVES_NAME_LEN], cause[GRAVES_CAUSE_LEN], bornDay, diedDay, age;
			cache_get_value_name(r,"name",first);
			cache_get_value_name(r,"surname",surname);
			cache_get_value_name_int(r,"born_day",bornDay);
			cache_get_value_name_int(r,"died_day",diedDay);
			cache_get_value_name_int(r,"died_age",age);
			cache_get_value_name(r,"death_cause",cause);
			format(name,sizeof(name),"%s %s",first,surname);
			Grave_SetOccupant(grave,characterid,name,bornDay,diedDay,age,cause,marker,dugAt,settled != 0);
			taken++;
		}
	}

	Log_Info("graves","%d plot(s), %d grave(s) taken",placed,taken);
	Boot_LoaderDone();
}

#include <pp-hooks>

hook Lineage_OnDeceased(characterid)
{
	new Float:x = 0.0, Float:y = 0.0, Float:z = 0.0;

	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == characterid)
		{
			GetPlayerPos(playerid,x,y,z);
			break;
		}
	}

	SetTimerEx("Graves_BuryDeferred",1000,false,"dfff",characterid,x,y,z);
}
