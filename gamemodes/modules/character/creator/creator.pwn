enum E_CREATE
{
	E_CREATE_SLOT,
	E_CREATE_SEX,
	E_CREATE_LOOK,
	E_CREATE_LOOK_OTHER,
	E_CREATE_AGE,
	E_CREATE_CULTURE,
	E_ORIGIN:E_CREATE_ORIGIN,
	E_CREATE_ATTR[E_ATTRIBUTE],
	E_TRAIT:E_CREATE_TRAIT_A,
	E_TRAIT:E_CREATE_TRAIT_B,
	E_LIFESTYLE:E_CREATE_LIFESTYLE,
	E_CREATE_NAME[CHARACTER_NAME_MAX + 1],
	E_CREATE_SURNAME[CHARACTER_NAME_MAX + 1],
}

new g_CreatorDraft[MAX_PLAYERS][E_CREATE];

stock bool:Creator_IsActive(playerid)
{
	return Session_GetState(playerid) == SESSION_CHARACTER_CREATE;
}

stock Creator_GetAttributeTotal(playerid)
{
	new total = 0;

	for (new E_ATTRIBUTE:a = ATTR_WILLPOWER;a < ATTR_COUNT;a++)
	{
		total += g_CreatorDraft[playerid][E_CREATE_ATTR][a];
	}

	return total;
}

stock Creator_GetSkin(playerid)
{
	return Skins_GetStarter(g_CreatorDraft[playerid][E_CREATE_SEX],g_CreatorDraft[playerid][E_CREATE_LOOK]);
}

stock Creator_ApplyLook(playerid)
{
	if (IsPlayerConnected(playerid) && !IsPlayerNPC(playerid) && !Scene_IsSpectating(playerid) && GetPlayerState(playerid) != PLAYER_STATE_SPECTATING)
	{
		SetPlayerSkin(playerid,Creator_GetSkin(playerid));
	}
}

stock Creator_SetSex(playerid,sex)
{
	if (sex != g_CreatorDraft[playerid][E_CREATE_SEX])
	{
		new look = g_CreatorDraft[playerid][E_CREATE_LOOK];
		g_CreatorDraft[playerid][E_CREATE_LOOK] = g_CreatorDraft[playerid][E_CREATE_LOOK_OTHER];
		g_CreatorDraft[playerid][E_CREATE_LOOK_OTHER] = look;
	}

	g_CreatorDraft[playerid][E_CREATE_SEX] = sex;

	if (g_CreatorDraft[playerid][E_CREATE_LOOK] >= Skins_CountStarter(sex))
	{
		g_CreatorDraft[playerid][E_CREATE_LOOK] = 0;
	}

	Creator_ApplyLook(playerid);
}

stock Creator_CycleLook(playerid,direction)
{
	new count = Skins_CountStarter(g_CreatorDraft[playerid][E_CREATE_SEX]);

	if (count <= 0)
	{
		return;
	}

	g_CreatorDraft[playerid][E_CREATE_LOOK] = (g_CreatorDraft[playerid][E_CREATE_LOOK] + direction + count) % count;
	Creator_ApplyLook(playerid);
}

stock Creator_BumpAttribute(playerid,E_ATTRIBUTE:attr)
{
	if (attr < ATTR_WILLPOWER || attr >= ATTR_COUNT)
	{
		return;
	}

	if (Creator_GetAttributeTotal(playerid) < CREATOR_ATTR_POOL && g_CreatorDraft[playerid][E_CREATE_ATTR][attr] < CREATOR_ATTR_MAX)
	{
		g_CreatorDraft[playerid][E_CREATE_ATTR][attr]++;
	}
	else if (g_CreatorDraft[playerid][E_CREATE_ATTR][attr] >= CREATOR_ATTR_MAX)
	{
		g_CreatorDraft[playerid][E_CREATE_ATTR][attr] = CREATOR_ATTR_MIN;
	}
}

stock Creator_ResetAttributes(playerid)
{
	for (new E_ATTRIBUTE:a = ATTR_WILLPOWER;a < ATTR_COUNT;a++)
	{
		g_CreatorDraft[playerid][E_CREATE_ATTR][a] = CREATOR_ATTR_MIN;
	}
}

stock bool:Creator_HasValidAttributes(playerid)
{
	new values[E_ATTRIBUTE];

	for (new E_ATTRIBUTE:a = ATTR_WILLPOWER;a < ATTR_COUNT;a++)
	{
		values[a] = g_CreatorDraft[playerid][E_CREATE_ATTR][a];
	}

	return Creator_ValidAttributes(values);
}

stock bool:Creator_HasTrait(playerid,E_TRAIT:trait)
{
	return g_CreatorDraft[playerid][E_CREATE_TRAIT_A] == trait || g_CreatorDraft[playerid][E_CREATE_TRAIT_B] == trait;
}

stock Creator_CountTraits(playerid)
{
	return (g_CreatorDraft[playerid][E_CREATE_TRAIT_A] != TRAIT_COUNT ? 1 : 0) + (g_CreatorDraft[playerid][E_CREATE_TRAIT_B] != TRAIT_COUNT ? 1 : 0);
}

stock Creator_ToggleTrait(playerid,E_TRAIT:trait)
{
	if (trait < TRAIT_HARDY || trait >= TRAIT_COUNT)
	{
		return;
	}

	if (g_CreatorDraft[playerid][E_CREATE_TRAIT_A] == trait)
	{
		g_CreatorDraft[playerid][E_CREATE_TRAIT_A] = TRAIT_COUNT;
	}
	else if (g_CreatorDraft[playerid][E_CREATE_TRAIT_B] == trait)
	{
		g_CreatorDraft[playerid][E_CREATE_TRAIT_B] = TRAIT_COUNT;
	}
	else if (g_CreatorDraft[playerid][E_CREATE_TRAIT_A] == TRAIT_COUNT)
	{
		g_CreatorDraft[playerid][E_CREATE_TRAIT_A] = trait;
	}
	else if (g_CreatorDraft[playerid][E_CREATE_TRAIT_B] == TRAIT_COUNT)
	{
		g_CreatorDraft[playerid][E_CREATE_TRAIT_B] = trait;
	}
}

stock bool:Creator_HasIdentity(playerid)
{
	return g_CreatorDraft[playerid][E_CREATE_NAME][0] != EOS && g_CreatorDraft[playerid][E_CREATE_SURNAME][0] != EOS && Culture_IsValid(g_CreatorDraft[playerid][E_CREATE_CULTURE]);
}

stock bool:Creator_IsNameTaken(playerid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS taken FROM characters WHERE name = '%e' AND surname = '%e'",g_CreatorDraft[playerid][E_CREATE_NAME],g_CreatorDraft[playerid][E_CREATE_SURNAME]));

	new taken = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"taken",taken);
	}

	return taken > 0;
}

Creator_Start(playerid,slot)
{
	g_CreatorDraft[playerid][E_CREATE_SLOT] = slot;
	g_CreatorDraft[playerid][E_CREATE_SEX] = 0;
	g_CreatorDraft[playerid][E_CREATE_LOOK] = 0;
	g_CreatorDraft[playerid][E_CREATE_LOOK_OTHER] = 0;
	g_CreatorDraft[playerid][E_CREATE_AGE] = 20;
	CreatorGui_ResetWarning(playerid);
	g_CreatorDraft[playerid][E_CREATE_CULTURE] = -1;
	g_CreatorDraft[playerid][E_CREATE_ORIGIN] = ORIGIN_VILLAGE;
	Creator_ResetAttributes(playerid);
	g_CreatorDraft[playerid][E_CREATE_TRAIT_A] = TRAIT_COUNT;
	g_CreatorDraft[playerid][E_CREATE_TRAIT_B] = TRAIT_COUNT;
	g_CreatorDraft[playerid][E_CREATE_LIFESTYLE] = LIFESTYLE_FARMHAND;
	g_CreatorDraft[playerid][E_CREATE_NAME][0] = EOS;
	g_CreatorDraft[playerid][E_CREATE_SURNAME][0] = EOS;
	Session_SetState(playerid,SESSION_CHARACTER_CREATE);
	Scene_ShowCreator(playerid,Creator_GetSkin(playerid));
	CreatorGui_ShowIdentity(playerid);
}

stock E_ORIGIN:Creator_GetOrigin(playerid)
{
	return Util_IsValidPlayer(playerid) ? g_CreatorDraft[playerid][E_CREATE_ORIGIN] : ORIGIN_COUNT;
}

Creator_Insert(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid);
	new E_ATTRIBUTE:bonus = Creator_OriginBonus(g_CreatorDraft[playerid][E_CREATE_ORIGIN]);
	new attr[E_ATTRIBUTE], Float:spawn[4];

	for (new E_ATTRIBUTE:a = ATTR_WILLPOWER;a < ATTR_COUNT;a++)
	{
		attr[a] = g_CreatorDraft[playerid][E_CREATE_ATTR][a] + (a == bonus ? 1 : 0);
	}

	Creator_GetLifestyleSpawn(g_CreatorDraft[playerid][E_CREATE_LIFESTYLE],spawn[0],spawn[1],spawn[2],spawn[3]);

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO characters (account_id, slot, name, surname, sex, skin, age, origin, culture, willpower, craftmanship, intelligence, honor_grace, piety, trait_a, trait_b, lifestyle, pos_x, pos_y, pos_z, angle) VALUES (%d, %d, '%e', '%e', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %f, %f, %f, %f)",
		Account_GetId(playerid),g_CreatorDraft[playerid][E_CREATE_SLOT],g_CreatorDraft[playerid][E_CREATE_NAME],g_CreatorDraft[playerid][E_CREATE_SURNAME],g_CreatorDraft[playerid][E_CREATE_SEX],Creator_GetSkin(playerid),
		g_CreatorDraft[playerid][E_CREATE_AGE],_:g_CreatorDraft[playerid][E_CREATE_ORIGIN],g_CreatorDraft[playerid][E_CREATE_CULTURE],attr[ATTR_WILLPOWER],attr[ATTR_CRAFTMANSHIP],attr[ATTR_INTELLIGENCE],attr[ATTR_HONOR_GRACE],attr[ATTR_PIETY],
		_:g_CreatorDraft[playerid][E_CREATE_TRAIT_A],_:g_CreatorDraft[playerid][E_CREATE_TRAIT_B],_:g_CreatorDraft[playerid][E_CREATE_LIFESTYLE],
		spawn[0],spawn[1],spawn[2],spawn[3]));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (mysql_errno(g_Mysql) != 0)
	{
		Gui_Notify(playerid,"The scribe dropped his quill. Your character wasn't saved, please try again.");
		Character_ShowSelect(playerid);
		return;
	}

	new characterid = cache_insert_id();
	Log_Info("character","player %d created character %d (%s %s) in slot %d",playerid,characterid,g_CreatorDraft[playerid][E_CREATE_NAME],g_CreatorDraft[playerid][E_CREATE_SURNAME],g_CreatorDraft[playerid][E_CREATE_SLOT]);
	pawn_call_public("Character_OnCreated","dd",playerid,characterid);
	Character_Load(playerid,characterid);
}

forward Character_OnCreated(playerid,characterid);

public Character_OnCreated(playerid,characterid)
{
	return 1;
}
