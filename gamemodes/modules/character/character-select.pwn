#define CHARACTER_SLOT_PLAYED_LEN (16)

enum E_SLOT_ROW
{
	E_SLOT_ID,
	bool:E_SLOT_ALIVE,
	E_SLOT_NAME[CHARACTER_NAME_MAX * 2 + 2],
	E_SLOT_PLAYED[CHARACTER_SLOT_PLAYED_LEN],
}

static s_Slots[MAX_PLAYERS][ACCOUNT_CHARACTER_SLOTS][E_SLOT_ROW];
static s_GraveCount[MAX_PLAYERS];

static Character_ClearSlots(playerid)
{
	s_GraveCount[playerid] = 0;

	for (new slot = 0; slot < ACCOUNT_CHARACTER_SLOTS; slot++)
	{
		s_Slots[playerid][slot][E_SLOT_ID] = 0;
		s_Slots[playerid][slot][E_SLOT_ALIVE] = false;
		s_Slots[playerid][slot][E_SLOT_NAME][0] = EOS;
		s_Slots[playerid][slot][E_SLOT_PLAYED][0] = EOS;
	}
}

stock Character_ShowSelect(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid), accountid = Account_GetId(playerid);
	Character_ClearSlots(playerid);

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, slot, name, surname, alive, IFNULL(DATE_FORMAT(last_played_at, '%%e %%b'), 'never') AS played FROM characters WHERE account_id = %d AND slot IS NOT NULL ORDER BY slot",accountid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (mysql_errno(g_Mysql) != 0)
	{
		Gui_Notify(playerid,"The server couldn't load your account. Reconnect in a minute.");
		Account_KickDelayed(playerid);
		return;
	}

	new rows = cache_num_rows();
	for (new r = 0; r < rows; r++)
	{
		new slot, alive, name[CHARACTER_NAME_MAX + 1], surname[CHARACTER_NAME_MAX + 1];
		cache_get_value_name_int(r,"slot",slot);
		if (slot < 0 || slot >= ACCOUNT_CHARACTER_SLOTS)
		{
			continue;
		}

		cache_get_value_name_int(r,"id",s_Slots[playerid][slot][E_SLOT_ID]);
		cache_get_value_name_int(r,"alive",alive);
		cache_get_value_name(r,"name",name);
		cache_get_value_name(r,"surname",surname);
		cache_get_value_name(r,"played",s_Slots[playerid][slot][E_SLOT_PLAYED],CHARACTER_SLOT_PLAYED_LEN);
		s_Slots[playerid][slot][E_SLOT_ALIVE] = alive != 0;
		format(s_Slots[playerid][slot][E_SLOT_NAME],CHARACTER_NAME_MAX * 2 + 2,"%s %s",name,surname);
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS graves FROM characters WHERE account_id = %d AND alive = 0",accountid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (mysql_errno(g_Mysql) == 0 && cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"graves",s_GraveCount[playerid]);
	}

	Session_SetState(playerid,SESSION_CHARACTER_SELECT);
	CharacterGui_ShowSelect(playerid);
}

stock Character_GetGraveCount(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_GraveCount[playerid] : 0;
}

stock Character_GetSlotId(playerid,slot)
{
	return (slot < 0 || slot >= ACCOUNT_CHARACTER_SLOTS) ? 0 : s_Slots[playerid][slot][E_SLOT_ID];
}

stock bool:Character_IsSlotAlive(playerid,slot)
{
	return slot >= 0 && slot < ACCOUNT_CHARACTER_SLOTS && s_Slots[playerid][slot][E_SLOT_ALIVE];
}

stock Character_GetSlotName(playerid,slot,dest[],size = sizeof(dest))
{
	if (slot < 0 || slot >= ACCOUNT_CHARACTER_SLOTS)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Slots[playerid][slot][E_SLOT_NAME],size);
}

stock Character_GetSlotPlayed(playerid,slot,dest[],size = sizeof(dest))
{
	if (slot < 0 || slot >= ACCOUNT_CHARACTER_SLOTS)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Slots[playerid][slot][E_SLOT_PLAYED],size);
}

Character_Load(playerid,characterid)
{
	yield 1;

	new token = Account_GetToken(playerid);
	Session_SetState(playerid,SESSION_SPAWNING);

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, slot, sex, skin, alive, name, surname, pos_x, pos_y, pos_z, angle, interior, world, health, age, origin, willpower, craftmanship, intelligence, honor_grace, piety, trait_a, trait_b, lifestyle, culture, warmth, hunger, thirst, hand_weapon, hand_shield, tutorial_done, tutorial_step FROM characters WHERE id = %d AND account_id = %d LIMIT 1",characterid,Account_GetId(playerid)));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (mysql_errno(g_Mysql) != 0 || cache_num_rows() == 0)
	{
		Gui_Notify(playerid,"That character couldn't be loaded. Try again, or reconnect if it keeps happening.");
		Character_ShowSelect(playerid);
		return;
	}

	Character_LoadFromCache(playerid,0);
	SetTimerEx("Character_FireLoaded",0,false,"dd",playerid,token);
}

forward Character_FireLoaded(playerid,token);

public Character_FireLoaded(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 1;
	}

	new name[CHARACTER_NAME_MAX * 2 + 2];
	Character_GetName(playerid,name);
	Log_Info("character","player %d loaded character %d (%s)",playerid,Character_GetId(playerid),name);
	Account_RefreshAdminLevel(playerid);
	pawn_call_public("Character_OnLoaded","dd",playerid,Character_GetId(playerid));
	Character_Spawn(playerid);
	return 1;
}

forward Character_OnGraveyard(playerid);

public Character_OnGraveyard(playerid)
{
	return 1;
}

forward Character_ShowSelectDeferred(playerid,token);

public Character_ShowSelectDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Character_ShowSelect(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook Account_OnAuthenticated(playerid,accountid)
{
	#pragma unused accountid

	SetTimerEx("Character_ShowSelectDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook OnPlayerConnect(playerid)
{
	Character_ClearSlots(playerid);
}
