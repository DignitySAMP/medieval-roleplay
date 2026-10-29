static bool:s_TalentOwned[MAX_PLAYERS][TALENT_NODE_MAX char];
static s_TalentEarned[MAX_PLAYERS];
static s_TalentSpent[MAX_PLAYERS];
static s_TalentPaid[MAX_PLAYERS];
static s_TalentMinutes[MAX_PLAYERS];
static s_TalentSeconds[MAX_PLAYERS];
static s_TalentCharacter[MAX_PLAYERS];

static Talent_Reset(playerid)
{
	for (new node = 0;node < Talent_GetNodeCount();node++)
	{
		s_TalentOwned[playerid]{node} = false;
	}

	s_TalentEarned[playerid] = 0;
	s_TalentSpent[playerid] = 0;
	s_TalentPaid[playerid] = 0;
	s_TalentMinutes[playerid] = 0;
	s_TalentSeconds[playerid] = 0;
	s_TalentCharacter[playerid] = 0;
}

stock bool:Talent_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TalentCharacter[playerid] > 0;
}

stock bool:Talent_Owns(playerid,node)
{
	if (!Talent_IsValidNode(node))
	{
		return false;
	}

	return Talent_IsFreeNode(node) || (Util_IsValidPlayer(playerid) && s_TalentOwned[playerid]{node});
}

stock bool:Talent_SeesKind(playerid,const kind[])
{
	for (new node = 0;node < Talent_GetNodeCount();node++)
	{
		if (Talent_NodeReveals(node,kind) && Talent_Owns(playerid,node))
		{
			return true;
		}
	}

	return false;
}

stock bool:Talent_OwnsKey(playerid,const key[])
{
	return Talent_Owns(playerid,Talent_FindNode(key));
}

stock Talent_GetPoints(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_TalentEarned[playerid] - s_TalentSpent[playerid] : 0;
}

stock Talent_GetActiveMinutes(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_TalentMinutes[playerid] : 0;
}

stock Talent_GetMinutesToNextPoint(playerid)
{
	return TALENT_MINUTES_PER_POINT - (Talent_GetActiveMinutes(playerid) % TALENT_MINUTES_PER_POINT);
}

stock Talent_GetNextCost(playerid)
{
	return TALENT_FIRST_COST + (Util_IsValidPlayer(playerid) ? s_TalentPaid[playerid] : 0);
}

stock Talent_CountInTrade(playerid,trade)
{
	new count = 0;

	for (new node = 0;node < Talent_GetNodeCount();node++)
	{
		if (Talent_GetNodeTrade(node) == trade && Talent_Owns(playerid,node))
		{
			count++;
		}
	}

	return count;
}

stock Talent_GetTradeLevelCap(playerid,trade)
{
	return min(TALENT_LEVEL_MAX,TALENT_LEVEL_BASE + TALENT_LEVEL_PER_NODE * Talent_CountInTrade(playerid,trade));
}

enum
{
	TALENT_UNLOCK_OK,
	TALENT_UNLOCK_OWNED,
	TALENT_UNLOCK_NEEDS_PARENT,
	TALENT_UNLOCK_POINTS,
	TALENT_UNLOCK_INVALID,
}

stock Talent_CheckUnlock(playerid,node)
{
	if (!Talent_IsValidNode(node) || !Talent_IsLoaded(playerid))
	{
		return TALENT_UNLOCK_INVALID;
	}

	if (Talent_Owns(playerid,node))
	{
		return TALENT_UNLOCK_OWNED;
	}

	new parent = Talent_GetNodeParent(node);

	if (parent != -1 && !Talent_Owns(playerid,parent))
	{
		return TALENT_UNLOCK_NEEDS_PARENT;
	}

	return Talent_GetPoints(playerid) >= Talent_GetNextCost(playerid) ? TALENT_UNLOCK_OK : TALENT_UNLOCK_POINTS;
}

static Talent_Save(playerid)
{
	if (s_TalentCharacter[playerid] <= 0)
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO talent_points (character_id, earned, spent, active_minutes) VALUES (%d, %d, %d, %d) ON DUPLICATE KEY UPDATE earned = VALUES(earned), spent = VALUES(spent), active_minutes = VALUES(active_minutes)",s_TalentCharacter[playerid],s_TalentEarned[playerid],s_TalentSpent[playerid],s_TalentMinutes[playerid]));
}

stock bool:Talent_Unlock(playerid,node)
{
	if (Talent_CheckUnlock(playerid,node) != TALENT_UNLOCK_OK)
	{
		return false;
	}

	new key[TALENT_KEY_LEN], cost = Talent_GetNextCost(playerid);
	Talent_GetNodeKey(node,key);
	s_TalentOwned[playerid]{node} = true;
	s_TalentSpent[playerid] += cost;
	s_TalentPaid[playerid]++;
	mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO talent_unlocks (character_id, node_key, cost) VALUES (%d, '%e', %d)",s_TalentCharacter[playerid],key,cost));
	Talent_Save(playerid);
	pawn_call_public("Talent_OnUnlocked","dd",playerid,node);
	return true;
}

stock Talent_GivePoints(playerid,points)
{
	if (!Talent_IsLoaded(playerid) || points == 0)
	{
		return;
	}

	s_TalentEarned[playerid] = max(s_TalentEarned[playerid] + points,s_TalentSpent[playerid]);
	Talent_Save(playerid);
}

stock Talent_MarkActive(playerid)
{
	Session_MarkActive(playerid);
}

stock Talent_AddActiveMinutes(playerid,minutes)
{
	if (!Talent_IsLoaded(playerid))
	{
		return;
	}

	for (new i = 0;i < minutes;i++)
	{
		s_TalentMinutes[playerid]++;

		if (s_TalentMinutes[playerid] % TALENT_MINUTES_PER_POINT == 0)
		{
			s_TalentEarned[playerid]++;
			pawn_call_public("Talent_OnPointEarned","dd",playerid,Talent_GetPoints(playerid));
		}
	}

	Talent_Save(playerid);
}

static Talent_Second(playerid)
{
	if (!Talent_IsLoaded(playerid) || !Session_IsPlaying(playerid))
	{
		return;
	}

	s_TalentSeconds[playerid]++;

	if (s_TalentSeconds[playerid] % 60 == 0 && Session_IsActive(playerid))
	{
		Talent_AddActiveMinutes(playerid,1);
	}
}

static Talent_Load(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT earned, spent, active_minutes FROM talent_points WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return;
	}

	if (cache_num_rows())
	{
		cache_get_value_name_int(0,"earned",s_TalentEarned[playerid]);
		cache_get_value_name_int(0,"spent",s_TalentSpent[playerid]);
		cache_get_value_name_int(0,"active_minutes",s_TalentMinutes[playerid]);
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT node_key FROM talent_unlocks WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return;
	}

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new key[TALENT_KEY_LEN], node;
		cache_get_value_name(r,"node_key",key);
		node = Talent_FindNode(key);

		if (node != -1 && !Talent_IsFreeNode(node))
		{
			s_TalentOwned[playerid]{node} = true;
			s_TalentPaid[playerid]++;
		}
	}

	s_TalentCharacter[playerid] = characterid;
	pawn_call_public("Talent_OnLoaded","d",playerid);
}

forward Talent_LoadDeferred(playerid,characterid);

public Talent_LoadDeferred(playerid,characterid)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid)
	{
		Talent_Load(playerid,characterid);
	}
}

forward Talent_OnLoaded(playerid);

public Talent_OnLoaded(playerid)
{
	return 1;
}

forward Talent_OnUnlocked(playerid,node);

public Talent_OnUnlocked(playerid,node)
{
	return 1;
}

forward Talent_OnPointEarned(playerid,points);

public Talent_OnPointEarned(playerid,points)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Talent_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	Talent_Reset(playerid);
	SetTimerEx("Talent_LoadDeferred",0,false,"dd",playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Talent_Save(playerid);
	Talent_Reset(playerid);
}

hook Tick_OnPlayerSecond(playerid)
{
	Talent_Second(playerid);
}

hook Talent_OnPointEarned(playerid,points)
{
	new message[96];
	format(message,sizeof(message),"You earned a talent point. You have %d to spend in your bag (N) > Crafting > Talents.",points);
	Gui_Notify(playerid,message);
}
