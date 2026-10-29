enum E_TABLE_REGULAR
{
	E_TABLE_REGULAR_ROW,
	E_TABLE_REGULAR_SKIN,
	E_TABLE_REGULAR_STYLE,
	E_TABLE_REGULAR_PURSE,
	E_TABLE_REGULAR_PURSE_DAY,
	E_TABLE_REGULAR_ACTOR,
	STREAMER_TAG_3D_TEXT_LABEL:E_TABLE_REGULAR_LABEL,
	E_TABLE_REGULAR_TABLE,
	Float:E_TABLE_REGULAR_X,
	Float:E_TABLE_REGULAR_Y,
	Float:E_TABLE_REGULAR_Z,
	Float:E_TABLE_REGULAR_A,
	Float:E_TABLE_REGULAR_SPOT_X,
	Float:E_TABLE_REGULAR_SPOT_Y,
	Float:E_TABLE_REGULAR_SPOT_Z,
	E_TABLE_REGULAR_WORLD,
	E_TABLE_REGULAR_INTERIOR,
	bool:E_TABLE_REGULAR_USED,
}

static s_TableRegulars[TABLE_REGULARS_MAX][E_TABLE_REGULAR];
static s_TableRegularNames[TABLE_REGULARS_MAX][TABLE_REGULAR_NAME_LEN];

stock bool:Table_IsValidRegular(regular)
{
	return regular >= 0 && regular < TABLE_REGULARS_MAX && s_TableRegulars[regular][E_TABLE_REGULAR_USED];
}

stock Table_GetRegularName(regular,dest[],size = sizeof(dest))
{
	if (!Table_IsValidRegular(regular))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_TableRegularNames[regular],size);
}

stock Table_GetRegularRow(regular)
{
	return Table_IsValidRegular(regular) ? s_TableRegulars[regular][E_TABLE_REGULAR_ROW] : 0;
}

stock Table_GetRegularStyle(regular)
{
	return Table_IsValidRegular(regular) ? s_TableRegulars[regular][E_TABLE_REGULAR_STYLE] : TABLE_STYLE_EVEN;
}

stock Table_GetRegularTable(regular)
{
	return Table_IsValidRegular(regular) ? s_TableRegulars[regular][E_TABLE_REGULAR_TABLE] : TABLE_EMPTY;
}

stock Table_SetRegularTable(regular,table)
{
	if (Table_IsValidRegular(regular))
	{
		s_TableRegulars[regular][E_TABLE_REGULAR_TABLE] = table;
	}
}

stock Table_GetRegularSpot(regular,&Float:x,&Float:y,&Float:z,&Float:angle)
{
	x = s_TableRegulars[regular][E_TABLE_REGULAR_SPOT_X];
	y = s_TableRegulars[regular][E_TABLE_REGULAR_SPOT_Y];
	z = s_TableRegulars[regular][E_TABLE_REGULAR_SPOT_Z];
	angle = s_TableRegulars[regular][E_TABLE_REGULAR_A];
}

stock Table_GetRegularWorld(regular)
{
	return s_TableRegulars[regular][E_TABLE_REGULAR_WORLD];
}

stock Table_GetRegularInterior(regular)
{
	return s_TableRegulars[regular][E_TABLE_REGULAR_INTERIOR];
}

stock Table_FindRegularByRow(row)
{
	for (new i = 0;i < TABLE_REGULARS_MAX;i++)
	{
		if (s_TableRegulars[i][E_TABLE_REGULAR_USED] && s_TableRegulars[i][E_TABLE_REGULAR_ROW] == row)
		{
			return i;
		}
	}

	return TABLE_EMPTY;
}

stock Table_FindRegularNear(playerid,Float:range = TABLE_REGULAR_REACH)
{
	new best = TABLE_EMPTY, Float:bestDistance = range, world = GetPlayerVirtualWorld(playerid), interior = GetPlayerInterior(playerid);

	for (new i = 0;i < TABLE_REGULARS_MAX;i++)
	{
		if (!s_TableRegulars[i][E_TABLE_REGULAR_USED] || s_TableRegulars[i][E_TABLE_REGULAR_WORLD] != world || s_TableRegulars[i][E_TABLE_REGULAR_INTERIOR] != interior)
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(playerid,s_TableRegulars[i][E_TABLE_REGULAR_X],s_TableRegulars[i][E_TABLE_REGULAR_Y],s_TableRegulars[i][E_TABLE_REGULAR_Z]);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

static Table_RegularToday()
{
	return gettime() / TABLE_REGULAR_DAY_SECONDS;
}

static Table_SaveRegularPurse(regular)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE games_regulars SET purse = %d, purse_day = %d WHERE id = %d",s_TableRegulars[regular][E_TABLE_REGULAR_PURSE],s_TableRegulars[regular][E_TABLE_REGULAR_PURSE_DAY],s_TableRegulars[regular][E_TABLE_REGULAR_ROW]));
}

static Table_RefreshRegularPurse(regular)
{
	new today = Table_RegularToday();

	if (s_TableRegulars[regular][E_TABLE_REGULAR_PURSE_DAY] != today)
	{
		s_TableRegulars[regular][E_TABLE_REGULAR_PURSE] = g_TableStylePurses[s_TableRegulars[regular][E_TABLE_REGULAR_STYLE]];
		s_TableRegulars[regular][E_TABLE_REGULAR_PURSE_DAY] = today;
		Table_SaveRegularPurse(regular);
	}
}

stock Table_GetRegularPurse(regular)
{
	if (!Table_IsValidRegular(regular))
	{
		return 0;
	}

	Table_RefreshRegularPurse(regular);
	return s_TableRegulars[regular][E_TABLE_REGULAR_PURSE];
}

stock bool:Table_TakeRegularPurse(regular,amount)
{
	if (!Table_IsValidRegular(regular) || amount <= 0 || Table_GetRegularPurse(regular) < amount)
	{
		return false;
	}

	s_TableRegulars[regular][E_TABLE_REGULAR_PURSE] -= amount;
	Table_SaveRegularPurse(regular);
	return true;
}

stock Table_GiveRegularPurse(regular,amount)
{
	if (!Table_IsValidRegular(regular) || amount <= 0)
	{
		return;
	}

	Table_RefreshRegularPurse(regular);
	s_TableRegulars[regular][E_TABLE_REGULAR_PURSE] += amount;
	Table_SaveRegularPurse(regular);
}

stock Table_SeatRegularActor(regular)
{
	if (IsValidActor(s_TableRegulars[regular][E_TABLE_REGULAR_ACTOR]))
	{
		ApplyActorAnimation(s_TableRegulars[regular][E_TABLE_REGULAR_ACTOR],"PED","SEAT_idle",4.1,true,false,false,true,0);
	}
}

stock Table_AddRegular(row,const name[],skin,style,purse,purseDay,Float:x,Float:y,Float:z,Float:a,Float:spotX,Float:spotY,Float:spotZ,world,interior)
{
	new regular = TABLE_EMPTY;

	for (new i = 0;i < TABLE_REGULARS_MAX;i++)
	{
		if (!s_TableRegulars[i][E_TABLE_REGULAR_USED])
		{
			regular = i;
			break;
		}
	}

	if (regular == TABLE_EMPTY)
	{
		return TABLE_EMPTY;
	}

	s_TableRegulars[regular][E_TABLE_REGULAR_USED] = true;
	s_TableRegulars[regular][E_TABLE_REGULAR_ROW] = row;
	s_TableRegulars[regular][E_TABLE_REGULAR_SKIN] = skin;
	s_TableRegulars[regular][E_TABLE_REGULAR_STYLE] = style >= 0 && style < TABLE_STYLE_COUNT ? style : TABLE_STYLE_EVEN;
	s_TableRegulars[regular][E_TABLE_REGULAR_PURSE] = purse;
	s_TableRegulars[regular][E_TABLE_REGULAR_PURSE_DAY] = purseDay;
	s_TableRegulars[regular][E_TABLE_REGULAR_TABLE] = TABLE_EMPTY;
	s_TableRegulars[regular][E_TABLE_REGULAR_X] = x;
	s_TableRegulars[regular][E_TABLE_REGULAR_Y] = y;
	s_TableRegulars[regular][E_TABLE_REGULAR_Z] = z;
	s_TableRegulars[regular][E_TABLE_REGULAR_A] = a;
	s_TableRegulars[regular][E_TABLE_REGULAR_SPOT_X] = spotX;
	s_TableRegulars[regular][E_TABLE_REGULAR_SPOT_Y] = spotY;
	s_TableRegulars[regular][E_TABLE_REGULAR_SPOT_Z] = spotZ;
	s_TableRegulars[regular][E_TABLE_REGULAR_WORLD] = world;
	s_TableRegulars[regular][E_TABLE_REGULAR_INTERIOR] = interior;
	strcopy(s_TableRegularNames[regular],name,TABLE_REGULAR_NAME_LEN);

	new actor = CreateActor(skin,x,y,z,a), label[TABLE_REGULAR_NAME_LEN + 12];
	s_TableRegulars[regular][E_TABLE_REGULAR_ACTOR] = actor;
	format(label,sizeof(label),"%s, regular",name);
	s_TableRegulars[regular][E_TABLE_REGULAR_LABEL] = CreateDynamic3DTextLabel(label,TABLE_REGULAR_LABEL_COLOUR,x,y,z + 0.7,TABLE_REGULAR_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,world,interior);

	if (IsValidActor(actor))
	{
		SetActorVirtualWorld(actor,world);
		Actors_RegisterBody(sprintf("regular:%d",regular),actor,0,name,"Tavern regular",world,interior);
		SetActorInvulnerable(actor,true);
		Table_SeatRegularActor(regular);
	}

	return regular;
}

stock Table_RemoveRegular(regular)
{
	if (!Table_IsValidRegular(regular))
	{
		return;
	}

	if (IsValidActor(s_TableRegulars[regular][E_TABLE_REGULAR_ACTOR]))
	{
		Actors_UnregisterBody(s_TableRegulars[regular][E_TABLE_REGULAR_ACTOR]);
		DestroyActor(s_TableRegulars[regular][E_TABLE_REGULAR_ACTOR]);
	}

	if (IsValidDynamic3DTextLabel(s_TableRegulars[regular][E_TABLE_REGULAR_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_TableRegulars[regular][E_TABLE_REGULAR_LABEL]);
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM games_regulars WHERE id = %d",s_TableRegulars[regular][E_TABLE_REGULAR_ROW]));
	s_TableRegulars[regular][E_TABLE_REGULAR_USED] = false;
	s_TableRegularNames[regular][0] = EOS;
}

#pragma warning push
#pragma warning disable 204
forward Task:Table_CreateRegular(const name[],skin,style,Float:x,Float:y,Float:z,Float:a,Float:spotX,Float:spotY,Float:spotZ,world,interior);

async Task:Table_CreateRegular(const name[],skin,style,Float:x,Float:y,Float:z,Float:a,Float:spotX,Float:spotY,Float:spotZ,world,interior)
{
	new purse = g_TableStylePurses[style], today = Table_RegularToday();

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO games_regulars (name, skin, style, purse, purse_day, x, y, z, a, spot_x, spot_y, spot_z, world, interior) VALUES ('%e', %d, %d, %d, %d, %f, %f, %f, %f, %f, %f, %f, %d, %d)",name,skin,style,purse,today,x,y,z,a,spotX,spotY,spotZ,world,interior));

	new row = cache_insert_id();
	return async row > 0 ? Table_AddRegular(row,name,skin,style,purse,today,x,y,z,a,spotX,spotY,spotZ,world,interior) : TABLE_EMPTY;
}

forward Task:Table_LoadRegulars();

async Task:Table_LoadRegulars()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, name, skin, style, purse, purse_day, x, y, z, a, spot_x, spot_y, spot_z, world, interior FROM games_regulars ORDER BY id"));

	new placed = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, name[TABLE_REGULAR_NAME_LEN], skin, style, purse, purseDay, Float:pos[4], Float:spot[3], world, interior;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"name",name);
		cache_get_value_name_int(r,"skin",skin);
		cache_get_value_name_int(r,"style",style);
		cache_get_value_name_int(r,"purse",purse);
		cache_get_value_name_int(r,"purse_day",purseDay);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_float(r,"spot_x",spot[0]);
		cache_get_value_name_float(r,"spot_y",spot[1]);
		cache_get_value_name_float(r,"spot_z",spot[2]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);

		if (Table_AddRegular(row,name,skin,style,purse,purseDay,pos[0],pos[1],pos[2],pos[3],spot[0],spot[1],spot[2],world,interior) != TABLE_EMPTY)
		{
			placed++;
		}
	}

	return async placed;
}

forward Task:Table_WonFromRegularsToday(characterid);

async Task:Table_WonFromRegularsToday(characterid)
{
	new since = gettime() - gettime() % TABLE_REGULAR_DAY_SECONDS, won = 0;

	await mysql_aquery_s(g_Mysql,str_format("SELECT IFNULL(SUM(s.result), 0) AS won FROM games_seats s JOIN games_played p ON p.id = s.game_id WHERE s.character_id = %d AND p.with_regular = 1 AND p.ended_at >= %d",characterid,since));

	if (cache_num_rows())
	{
		cache_get_value_name_int(0,"won",won);
	}

	return async won;
}
#pragma warning pop
