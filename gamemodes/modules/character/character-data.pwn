#define CHARACTER_NAME_MIN (3)
#define CHARACTER_NAME_MAX (20)
#define CHARACTER_SAVE_INTERVAL_MS (300000)
#define CHARACTER_SPAWN_DEFAULT_X (MAP_SPAWN_X)
#define CHARACTER_SPAWN_DEFAULT_Y (MAP_SPAWN_Y)
#define CHARACTER_SPAWN_DEFAULT_Z (MAP_SPAWN_Z)
#define CHARACTER_SPAWN_DEFAULT_A (MAP_SPAWN_A)
#define CHARACTER_SKIN_MALE (26)
#define CHARACTER_SKIN_FEMALE (56)
#define CHARACTER_LIMBO_WORLD (SCENE_WORLD_BASE)

enum E_CHARACTER
{
	E_CHARACTER_ID,
	E_CHARACTER_SLOT,
	E_CHARACTER_SEX,
	E_CHARACTER_SKIN,
	bool:E_CHARACTER_ALIVE,
	bool:E_CHARACTER_SAVE_PENDING,
	E_CHARACTER_NAME[CHARACTER_NAME_MAX + 1],
	E_CHARACTER_SURNAME[CHARACTER_NAME_MAX + 1],
	Float:E_CHARACTER_X,
	Float:E_CHARACTER_Y,
	Float:E_CHARACTER_Z,
	Float:E_CHARACTER_A,
	E_CHARACTER_INTERIOR,
	E_CHARACTER_WORLD,
	Float:E_CHARACTER_HEALTH,
	E_CHARACTER_AGE,
	E_CHARACTER_ORIGIN,
	E_CHARACTER_ATTR[5],
	E_CHARACTER_TRAIT_A,
	E_CHARACTER_TRAIT_B,
	E_CHARACTER_LIFESTYLE,
	E_CHARACTER_CULTURE,
	E_CHARACTER_WARMTH,
	E_CHARACTER_HUNGER,
	E_CHARACTER_THIRST,
	E_CHARACTER_HAND_WEAPON,
	E_CHARACTER_HAND_SHIELD,
	bool:E_CHARACTER_TUTORIAL_DONE,
	E_CHARACTER_TUTORIAL_STEP,
}

static s_Character[MAX_PLAYERS][E_CHARACTER];

stock Character_GetId(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Character[playerid][E_CHARACTER_ID];
}

stock Character_GetSlot(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return -1;
	}

	return s_Character[playerid][E_CHARACTER_SLOT];
}

stock Character_GetName(playerid,dest[],size = sizeof(dest))
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0)
	{
		dest[0] = EOS;
		return;
	}

	format(dest,size,"%s %s",s_Character[playerid][E_CHARACTER_NAME],s_Character[playerid][E_CHARACTER_SURNAME]);
}

stock Character_GetSurname(playerid,dest[],size = sizeof(dest))
{
	if (!Util_IsValidPlayer(playerid))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Character[playerid][E_CHARACTER_SURNAME],size);
}

stock Character_GetSex(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Character[playerid][E_CHARACTER_SEX];
}

stock Character_GetSkin(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return CHARACTER_SKIN_MALE;
	}

	return s_Character[playerid][E_CHARACTER_SKIN];
}

stock bool:Character_IsAlive(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Character[playerid][E_CHARACTER_ALIVE];
}

stock Character_GetSpawn(playerid,&Float:x,&Float:y,&Float:z,&Float:a,&interior,&world)
{
	x = s_Character[playerid][E_CHARACTER_X];
	y = s_Character[playerid][E_CHARACTER_Y];
	z = s_Character[playerid][E_CHARACTER_Z];
	a = s_Character[playerid][E_CHARACTER_A];
	interior = s_Character[playerid][E_CHARACTER_INTERIOR];
	world = s_Character[playerid][E_CHARACTER_WORLD];
}

stock Character_GetTrait(playerid,bool:isSecond)
{
	return Util_IsValidPlayer(playerid) ? (isSecond ? s_Character[playerid][E_CHARACTER_TRAIT_B] : s_Character[playerid][E_CHARACTER_TRAIT_A]) : -1;
}

stock Character_GetAge(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Character[playerid][E_CHARACTER_AGE];
}

stock Character_GetOrigin(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Character[playerid][E_CHARACTER_ORIGIN];
}

stock Character_GetAttribute(playerid,attr)
{
	if (!Util_IsValidPlayer(playerid) || attr < 0 || attr >= 5)
	{
		return 0;
	}

	return s_Character[playerid][E_CHARACTER_ATTR][attr];
}

stock bool:Character_HasTrait(playerid,trait)
{
	return Util_IsValidPlayer(playerid) && (s_Character[playerid][E_CHARACTER_TRAIT_A] == trait || s_Character[playerid][E_CHARACTER_TRAIT_B] == trait);
}

stock Character_GetLifestyle(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Character[playerid][E_CHARACTER_LIFESTYLE];
}

stock Character_GetCulture(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Character[playerid][E_CHARACTER_CULTURE] : 0;
}

stock Character_GetStoredWarmth(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Character[playerid][E_CHARACTER_WARMTH] : 0;
}

stock Character_SetStoredWarmth(playerid,warmth)
{
	if (Util_IsValidPlayer(playerid) && s_Character[playerid][E_CHARACTER_ID] != 0)
	{
		s_Character[playerid][E_CHARACTER_WARMTH] = warmth;
	}
}

stock Character_GetStoredNeed(playerid,bool:thirst)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return thirst ? s_Character[playerid][E_CHARACTER_THIRST] : s_Character[playerid][E_CHARACTER_HUNGER];
}

stock Character_SetStoredNeed(playerid,bool:thirst,value)
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0)
	{
		return;
	}

	if (thirst)
	{
		s_Character[playerid][E_CHARACTER_THIRST] = value;
	}
	else
	{
		s_Character[playerid][E_CHARACTER_HUNGER] = value;
	}
}

stock Character_GetStoredHand(playerid,bool:shield)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return -1;
	}

	return shield ? s_Character[playerid][E_CHARACTER_HAND_SHIELD] : s_Character[playerid][E_CHARACTER_HAND_WEAPON];
}

stock Character_SetStoredHand(playerid,bool:shield,value)
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0)
	{
		return;
	}

	if (shield)
	{
		s_Character[playerid][E_CHARACTER_HAND_SHIELD] = value;
	}
	else
	{
		s_Character[playerid][E_CHARACTER_HAND_WEAPON] = value;
	}

	s_Character[playerid][E_CHARACTER_SAVE_PENDING] = true;
}

stock Float:Character_GetStoredHealth(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 100.0;
	}

	return s_Character[playerid][E_CHARACTER_HEALTH];
}

stock Character_SetStoredHealth(playerid,Float:health)
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0)
	{
		return;
	}

	s_Character[playerid][E_CHARACTER_HEALTH] = health;
}

stock Character_RequestSave(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0)
	{
		return;
	}

	s_Character[playerid][E_CHARACTER_SAVE_PENDING] = true;
}

stock Character_Unload(playerid)
{
	if (Character_GetId(playerid) > 0)
	{
		Character_Save(playerid,true);
		pawn_call_public("Character_OnUnloaded","d",playerid);
	}

	Character_Reset(playerid);
}

stock Character_SetAlive(playerid,bool:isAlive)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_Character[playerid][E_CHARACTER_ALIVE] = isAlive;
	}
}

Character_Reset(playerid)
{
	s_Character[playerid][E_CHARACTER_ID] = 0;
	s_Character[playerid][E_CHARACTER_SLOT] = -1;
	s_Character[playerid][E_CHARACTER_SEX] = 0;
	s_Character[playerid][E_CHARACTER_SKIN] = CHARACTER_SKIN_MALE;
	s_Character[playerid][E_CHARACTER_ALIVE] = true;
	s_Character[playerid][E_CHARACTER_SAVE_PENDING] = false;
	s_Character[playerid][E_CHARACTER_NAME][0] = EOS;
	s_Character[playerid][E_CHARACTER_SURNAME][0] = EOS;
	s_Character[playerid][E_CHARACTER_X] = CHARACTER_SPAWN_DEFAULT_X;
	s_Character[playerid][E_CHARACTER_Y] = CHARACTER_SPAWN_DEFAULT_Y;
	s_Character[playerid][E_CHARACTER_Z] = CHARACTER_SPAWN_DEFAULT_Z;
	s_Character[playerid][E_CHARACTER_A] = CHARACTER_SPAWN_DEFAULT_A;
	s_Character[playerid][E_CHARACTER_INTERIOR] = 0;
	s_Character[playerid][E_CHARACTER_WORLD] = 0;
	s_Character[playerid][E_CHARACTER_HEALTH] = 100.0;
	s_Character[playerid][E_CHARACTER_AGE] = 20;
	s_Character[playerid][E_CHARACTER_ORIGIN] = 0;
	for (new i = 0; i < 5; i++)
	{
		s_Character[playerid][E_CHARACTER_ATTR][i] = 1;
	}
	s_Character[playerid][E_CHARACTER_TRAIT_A] = 16;
	s_Character[playerid][E_CHARACTER_TRAIT_B] = 16;
	s_Character[playerid][E_CHARACTER_LIFESTYLE] = 0;
	s_Character[playerid][E_CHARACTER_CULTURE] = 0;
	s_Character[playerid][E_CHARACTER_WARMTH] = 0;
	s_Character[playerid][E_CHARACTER_HUNGER] = 100000;
	s_Character[playerid][E_CHARACTER_THIRST] = 100000;
	s_Character[playerid][E_CHARACTER_HAND_WEAPON] = -1;
	s_Character[playerid][E_CHARACTER_HAND_SHIELD] = -1;
	s_Character[playerid][E_CHARACTER_TUTORIAL_DONE] = false;
	s_Character[playerid][E_CHARACTER_TUTORIAL_STEP] = 0;
}

Character_LoadFromCache(playerid,row)
{
	cache_get_value_name_int(row,"id",s_Character[playerid][E_CHARACTER_ID]);
	cache_get_value_name_int(row,"slot",s_Character[playerid][E_CHARACTER_SLOT]);
	cache_get_value_name_int(row,"sex",s_Character[playerid][E_CHARACTER_SEX]);
	cache_get_value_name_int(row,"skin",s_Character[playerid][E_CHARACTER_SKIN]);
	new alive;
	cache_get_value_name_int(row,"alive",alive);
	s_Character[playerid][E_CHARACTER_ALIVE] = alive != 0;
	cache_get_value_name(row,"name",s_Character[playerid][E_CHARACTER_NAME],CHARACTER_NAME_MAX + 1);
	cache_get_value_name(row,"surname",s_Character[playerid][E_CHARACTER_SURNAME],CHARACTER_NAME_MAX + 1);
	cache_get_value_name_float(row,"pos_x",s_Character[playerid][E_CHARACTER_X]);
	cache_get_value_name_float(row,"pos_y",s_Character[playerid][E_CHARACTER_Y]);
	cache_get_value_name_float(row,"pos_z",s_Character[playerid][E_CHARACTER_Z]);
	cache_get_value_name_float(row,"angle",s_Character[playerid][E_CHARACTER_A]);
	cache_get_value_name_int(row,"interior",s_Character[playerid][E_CHARACTER_INTERIOR]);
	cache_get_value_name_int(row,"world",s_Character[playerid][E_CHARACTER_WORLD]);
	cache_get_value_name_float(row,"health",s_Character[playerid][E_CHARACTER_HEALTH]);
	cache_get_value_name_int(row,"age",s_Character[playerid][E_CHARACTER_AGE]);
	cache_get_value_name_int(row,"origin",s_Character[playerid][E_CHARACTER_ORIGIN]);
	cache_get_value_name_int(row,"willpower",s_Character[playerid][E_CHARACTER_ATTR][0]);
	cache_get_value_name_int(row,"craftmanship",s_Character[playerid][E_CHARACTER_ATTR][1]);
	cache_get_value_name_int(row,"intelligence",s_Character[playerid][E_CHARACTER_ATTR][2]);
	cache_get_value_name_int(row,"honor_grace",s_Character[playerid][E_CHARACTER_ATTR][3]);
	cache_get_value_name_int(row,"piety",s_Character[playerid][E_CHARACTER_ATTR][4]);
	cache_get_value_name_int(row,"trait_a",s_Character[playerid][E_CHARACTER_TRAIT_A]);
	cache_get_value_name_int(row,"trait_b",s_Character[playerid][E_CHARACTER_TRAIT_B]);
	cache_get_value_name_int(row,"lifestyle",s_Character[playerid][E_CHARACTER_LIFESTYLE]);
	cache_get_value_name_int(row,"culture",s_Character[playerid][E_CHARACTER_CULTURE]);
	cache_get_value_name_int(row,"warmth",s_Character[playerid][E_CHARACTER_WARMTH]);
	cache_get_value_name_int(row,"hunger",s_Character[playerid][E_CHARACTER_HUNGER]);
	cache_get_value_name_int(row,"thirst",s_Character[playerid][E_CHARACTER_THIRST]);
	cache_get_value_name_int(row,"hand_weapon",s_Character[playerid][E_CHARACTER_HAND_WEAPON]);
	cache_get_value_name_int(row,"hand_shield",s_Character[playerid][E_CHARACTER_HAND_SHIELD]);

	new done;
	cache_get_value_name_int(row,"tutorial_done",done);
	s_Character[playerid][E_CHARACTER_TUTORIAL_DONE] = done != 0;
	cache_get_value_name_int(row,"tutorial_step",s_Character[playerid][E_CHARACTER_TUTORIAL_STEP]);
	s_Character[playerid][E_CHARACTER_SAVE_PENDING] = false;
}

stock bool:Character_IsTutorialDone(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Character[playerid][E_CHARACTER_TUTORIAL_DONE];
}

stock Character_SetTutorialDone(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0)
	{
		return;
	}

	s_Character[playerid][E_CHARACTER_TUTORIAL_DONE] = true;
	mysql_tquery_s(g_Mysql,str_format("UPDATE characters SET tutorial_done = 1 WHERE id = %d",s_Character[playerid][E_CHARACTER_ID]));
}

stock Character_GetTutorialStep(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Character[playerid][E_CHARACTER_TUTORIAL_STEP] : 0;
}

stock Character_SetTutorialStep(playerid,step)
{
	if (!Util_IsValidPlayer(playerid) || s_Character[playerid][E_CHARACTER_ID] == 0 || s_Character[playerid][E_CHARACTER_TUTORIAL_STEP] == step)
	{
		return;
	}

	s_Character[playerid][E_CHARACTER_TUTORIAL_STEP] = step;
	mysql_tquery_s(g_Mysql,str_format("UPDATE characters SET tutorial_step = %d WHERE id = %d",step,s_Character[playerid][E_CHARACTER_ID]));
}

Character_CapturePosition(playerid)
{
	if (s_Character[playerid][E_CHARACTER_ID] == 0 || GetPlayerState(playerid) == PLAYER_STATE_WASTED)
	{
		return;
	}

	if (GetPlayerVirtualWorld(playerid) >= CHARACTER_LIMBO_WORLD)
	{
		return;
	}

	GetPlayerPos(playerid,s_Character[playerid][E_CHARACTER_X],s_Character[playerid][E_CHARACTER_Y],s_Character[playerid][E_CHARACTER_Z]);
	GetPlayerFacingAngle(playerid,s_Character[playerid][E_CHARACTER_A]);
	s_Character[playerid][E_CHARACTER_INTERIOR] = GetPlayerInterior(playerid);
	s_Character[playerid][E_CHARACTER_WORLD] = GetPlayerVirtualWorld(playerid);
}

Character_Save(playerid,bool:force)
{
	if (s_Character[playerid][E_CHARACTER_ID] == 0 || !IsDatabaseReady())
	{
		return;
	}

	if (!force && !s_Character[playerid][E_CHARACTER_SAVE_PENDING])
	{
		return;
	}

	if (GetPlayerState(playerid) != PLAYER_STATE_NONE)
	{
		Character_CapturePosition(playerid);
	}

	s_Character[playerid][E_CHARACTER_SAVE_PENDING] = false;
	mysql_tquery_s(g_Mysql,str_format("UPDATE characters SET pos_x = %f, pos_y = %f, pos_z = %f, angle = %f, interior = %d, world = %d, health = %f, warmth = %d, hunger = %d, thirst = %d, hand_weapon = %d, hand_shield = %d, last_played_at = NOW() WHERE id = %d",
		s_Character[playerid][E_CHARACTER_X],s_Character[playerid][E_CHARACTER_Y],s_Character[playerid][E_CHARACTER_Z],s_Character[playerid][E_CHARACTER_A],
		s_Character[playerid][E_CHARACTER_INTERIOR],s_Character[playerid][E_CHARACTER_WORLD],s_Character[playerid][E_CHARACTER_HEALTH],s_Character[playerid][E_CHARACTER_WARMTH],s_Character[playerid][E_CHARACTER_HUNGER],s_Character[playerid][E_CHARACTER_THIRST],s_Character[playerid][E_CHARACTER_HAND_WEAPON],s_Character[playerid][E_CHARACTER_HAND_SHIELD],s_Character[playerid][E_CHARACTER_ID]));
	pawn_call_public("Character_OnSaved","d",playerid);
}

stock bool:Character_ValidateName(const name[])
{
	new len = strlen(name);
	if (len < CHARACTER_NAME_MIN || len > CHARACTER_NAME_MAX)
	{
		return false;
	}

	if (name[0] < 'A' || name[0] > 'Z')
	{
		return false;
	}

	for (new i = 1; i < len; i++)
	{
		if ((name[i] < 'a' || name[i] > 'z') && (name[i] < 'A' || name[i] > 'Z'))
		{
			return false;
		}
	}

	return true;
}

forward Character_OnLoaded(playerid,characterid);

public Character_OnLoaded(playerid,characterid)
{
	return 1;
}

forward Character_OnSaved(playerid);

public Character_OnSaved(playerid)
{
	return 1;
}

forward Character_OnUnloaded(playerid);

public Character_OnUnloaded(playerid)
{
	return 1;
}
