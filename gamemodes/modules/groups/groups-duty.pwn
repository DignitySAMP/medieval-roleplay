static s_GroupKits[GROUPS_MAX][GROUPS_RANKS][GROUPS_KIT_LINES][3];
static s_Duty[MAX_PLAYERS] = {GROUP_INVALID, ...};
static s_Livery[MAX_PLAYERS] = {GROUP_INVALID, ...};
static s_Issued[MAX_PLAYERS][GROUPS_ISSUED_MAX][3];
static s_IssuedGroup[MAX_PLAYERS] = {GROUP_INVALID, ...};
static Float:s_LiveryPose[9] = {0.06, 0.03, 0.0, 0.0, 90.0, 0.0, 1.0, 1.0, 1.0};

forward Task:Groups_LoadKits();
forward Task:Groups_ReclaimIssued(playerid,characterid);

stock Groups_GetDuty(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Duty[playerid] : GROUP_INVALID;
}

stock bool:Groups_IsOnDuty(playerid,group)
{
	return Util_IsValidPlayer(playerid) && group != GROUP_INVALID && s_Duty[playerid] == group;
}

stock Groups_CountOnDuty(group)
{
	new count = 0;

	foreach (new playerid : Player)
	{
		if (s_Duty[playerid] == group)
		{
			count++;
		}
	}

	return count;
}

stock Groups_GetKitLine(group,rank,line,&E_ITEM_KIND:kind,&param,&amount)
{
	if (!Groups_IsValid(group) || rank < 0 || rank >= GROUPS_RANKS || line < 0 || line >= GROUPS_KIT_LINES)
	{
		amount = 0;
		return;
	}

	kind = E_ITEM_KIND:s_GroupKits[group][rank][line][0];
	param = s_GroupKits[group][rank][line][1];
	amount = s_GroupKits[group][rank][line][2];
}

stock bool:Groups_SetKitLine(group,rank,line,E_ITEM_KIND:kind,param,amount)
{
	if (!Groups_IsValid(group) || rank < 0 || rank >= GROUPS_RANKS || line < 0 || line >= GROUPS_KIT_LINES)
	{
		return false;
	}

	s_GroupKits[group][rank][line][0] = _:kind;
	s_GroupKits[group][rank][line][1] = param;
	s_GroupKits[group][rank][line][2] = max(amount,0);

	if (amount <= 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_kits WHERE group_id = %d AND `rank` = %d AND line = %d",Groups_GetId(group),rank,line));
	}
	else
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO group_kits (group_id, `rank`, line, kind, param, amount) VALUES (%d, %d, %d, %d, %d, %d) ON DUPLICATE KEY UPDATE kind = VALUES(kind), param = VALUES(param), amount = VALUES(amount)",Groups_GetId(group),rank,line,_:kind,param,amount));
	}

	return true;
}

stock Groups_ClearKits(group)
{
	for (new rank = 0;rank < GROUPS_RANKS;rank++)
	{
		for (new line = 0;line < GROUPS_KIT_LINES;line++)
		{
			s_GroupKits[group][rank][line][2] = 0;
		}
	}
}

static Groups_IssueKit(playerid,group)
{
	new rank = Groups_GetRank(playerid,group), store = Groups_GetStore(group), count = 0, characterid = Character_GetId(playerid);
	s_IssuedGroup[playerid] = group;

	for (new line = 0;line < GROUPS_KIT_LINES && rank != -1;line++)
	{
		new E_ITEM_KIND:kind = E_ITEM_KIND:s_GroupKits[group][rank][line][0], param = s_GroupKits[group][rank][line][1], amount = s_GroupKits[group][rank][line][2];

		if (amount <= 0 || store == INVALID_CONTAINER_ID)
		{
			continue;
		}

		amount = min(amount,Container_Count(store,kind,param));

		if (amount <= 0 || !Inventory_CanGive(playerid,kind,param,amount) || !Container_Take(store,kind,param,amount))
		{
			continue;
		}

		Inventory_Give(playerid,kind,param,amount);

		for (new slot = 0;slot < GROUPS_ISSUED_MAX;slot++)
		{
			if (s_Issued[playerid][slot][2] == 0)
			{
				s_Issued[playerid][slot][0] = _:kind;
				s_Issued[playerid][slot][1] = param;
				s_Issued[playerid][slot][2] = amount;
				mysql_tquery_s(g_Mysql,str_format("INSERT INTO group_issued (character_id, group_id, kind, param, amount) VALUES (%d, %d, %d, %d, %d)",characterid,Groups_GetId(group),_:kind,param,amount));
				break;
			}
		}

		count += amount;
	}

	return count;
}

static Groups_ReturnKit(playerid)
{
	new group = s_IssuedGroup[playerid], store = Groups_GetStore(group), missing = 0, characterid = Character_GetId(playerid);

	for (new slot = 0;slot < GROUPS_ISSUED_MAX;slot++)
	{
		new E_ITEM_KIND:kind = E_ITEM_KIND:s_Issued[playerid][slot][0], param = s_Issued[playerid][slot][1], amount = s_Issued[playerid][slot][2];

		if (amount <= 0)
		{
			continue;
		}

		new have = min(amount,Inventory_Count(playerid,kind,param));

		if (have > 0 && Inventory_Take(playerid,kind,param,have) && store != INVALID_CONTAINER_ID)
		{
			Container_Add(store,kind,param,have);
		}

		if (have < amount)
		{
			new name[ITEM_NAME_LEN];
			Item_GetName(kind,param,name);
			Groups_Log(group,characterid,sprintf("did not hand back %d %s",amount - have,name));
			missing += amount - have;
		}

		s_Issued[playerid][slot][2] = 0;
	}

	if (characterid > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_issued WHERE character_id = %d",characterid));
	}

	s_IssuedGroup[playerid] = GROUP_INVALID;
	return missing;
}

stock bool:Groups_SetDuty(playerid,group,bool:isOn)
{
	if (!Util_IsValidPlayer(playerid) || (isOn && (!Groups_IsMember(playerid,group) || !Groups_HasFeature(group,GROUP_FEATURE_DUTY))))
	{
		return false;
	}

	if (!isOn)
	{
		new was = s_Duty[playerid];

		if (was == GROUP_INVALID)
		{
			return false;
		}

		s_Duty[playerid] = GROUP_INVALID;
		new missing = s_IssuedGroup[playerid] != GROUP_INVALID ? Groups_ReturnKit(playerid) : 0;

		if (missing > 0)
		{
			Gui_Notify(playerid,"You go off duty. Some of the kit you were issued is missing, and it's written in the book.");
		}
		else
		{
			Gui_Notify(playerid,"You go off duty.");
		}

		Groups_UpdateLivery(playerid);
		pawn_call_public("Groups_OnDuty","ddd",playerid,was,0);
		return true;
	}

	if (s_Duty[playerid] != GROUP_INVALID)
	{
		Groups_SetDuty(playerid,s_Duty[playerid],false);
	}

	s_Duty[playerid] = group;
	new issued = Groups_HasFeature(group,GROUP_FEATURE_ARMOURY) && Groups_IsAtSeat(playerid,group) ? Groups_IssueKit(playerid,group) : 0, name[GROUPS_NAME_LEN];
	Groups_GetName(group,name);

	if (issued > 0)
	{
		Gui_Notify(playerid,sprintf("You draw your kit from the storehouse and go on duty for %s.",name));
	}
	else
	{
		Gui_Notify(playerid,sprintf("You go on duty for %s.",name));
	}

	Groups_UpdateLivery(playerid);
	pawn_call_public("Groups_OnDuty","ddd",playerid,group,1);
	return true;
}

stock Groups_SetWearing(playerid,group,bool:isOn)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Livery[playerid] = isOn && Groups_IsMember(playerid,group) && Groups_HasFeature(group,GROUP_FEATURE_UNIFORM) ? group : GROUP_INVALID;
	Groups_UpdateLivery(playerid);
}

stock Groups_GetWearing(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return GROUP_INVALID;
	}

	new duty = s_Duty[playerid];

	if (duty != GROUP_INVALID && Groups_HasFeature(duty,GROUP_FEATURE_UNIFORM))
	{
		return duty;
	}

	return Groups_HasFeature(s_Livery[playerid],GROUP_FEATURE_UNIFORM) && Groups_IsMember(playerid,s_Livery[playerid]) ? s_Livery[playerid] : GROUP_INVALID;
}

stock Groups_UpdateLivery(playerid)
{
	new group = Groups_GetWearing(playerid);

	if (group == GROUP_INVALID)
	{
		if (IsPlayerAttachedObjectSlotUsed(playerid,GROUPS_LIVERY_SLOT))
		{
			RemovePlayerAttachedObject(playerid,GROUPS_LIVERY_SLOT);
		}

		Nametag_SetCue(playerid,NAMETAG_CUE_LIVERY,"");
		return;
	}

	new colour = g_GroupLiveryColours[Groups_GetLivery(group)], cue[NAMETAG_CUE_LEN], name[GROUPS_NAME_LEN];
	SetPlayerAttachedObject(playerid,GROUPS_LIVERY_SLOT,MODEL_CLOTHING_TABARD,ATTACH_BONE_SPINE,s_LiveryPose[0],s_LiveryPose[1],s_LiveryPose[2],s_LiveryPose[3],s_LiveryPose[4],s_LiveryPose[5],s_LiveryPose[6],s_LiveryPose[7],s_LiveryPose[8],colour,colour);
	Groups_GetName(group,name);
	format(cue,sizeof(cue),"in the %s of %s",Groups_GetKind(group) == GROUP_KIND_ORDER || Groups_GetKind(group) == GROUP_KIND_CHURCH ? ("habit") : ("livery"),name);
	Nametag_SetCue(playerid,NAMETAG_CUE_LIVERY,cue);
}

stock Groups_SetLiveryPose(const Float:pose[9])
{
	for (new i = 0;i < 9;i++)
	{
		s_LiveryPose[i] = pose[i];
	}

	foreach (new playerid : Player)
	{
		Groups_UpdateLivery(playerid);
	}
}

stock Groups_GetLiveryPose(Float:pose[9])
{
	for (new i = 0;i < 9;i++)
	{
		pose[i] = s_LiveryPose[i];
	}
}

stock Groups_ClearDuty(playerid)
{
	s_Duty[playerid] = GROUP_INVALID;
	s_Livery[playerid] = GROUP_INVALID;
	s_IssuedGroup[playerid] = GROUP_INVALID;

	for (new slot = 0;slot < GROUPS_ISSUED_MAX;slot++)
	{
		s_Issued[playerid][slot][2] = 0;
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Groups_LoadKits()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT group_id, `rank`, line, kind, param, amount FROM group_kits"));
	new count = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new id, rank, line, kind, param, amount;
		cache_get_value_name_int(r,"group_id",id);
		cache_get_value_name_int(r,"rank",rank);
		cache_get_value_name_int(r,"line",line);
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_int(r,"param",param);
		cache_get_value_name_int(r,"amount",amount);
		new group = Groups_FindById(id);

		if (group != GROUP_INVALID && rank >= 0 && rank < GROUPS_RANKS && line >= 0 && line < GROUPS_KIT_LINES)
		{
			s_GroupKits[group][rank][line][0] = kind;
			s_GroupKits[group][rank][line][1] = param;
			s_GroupKits[group][rank][line][2] = amount;
			count++;
		}
	}

	return async count;
}

async Task:Groups_ReclaimIssued(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT group_id, kind, param, amount FROM group_issued WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	new rows = cache_num_rows(), returned = 0, ids[GROUPS_ISSUED_MAX], lines[GROUPS_ISSUED_MAX][3];

	for (new r = 0;r < rows && r < GROUPS_ISSUED_MAX;r++)
	{
		cache_get_value_name_int(r,"group_id",ids[r]);
		cache_get_value_name_int(r,"kind",lines[r][0]);
		cache_get_value_name_int(r,"param",lines[r][1]);
		cache_get_value_name_int(r,"amount",lines[r][2]);
	}

	for (new wait = 0;wait < 20 && rows > 0 && IsPlayerConnected(playerid) && !Inventory_IsLoaded(playerid);wait++)
	{
		await task_ms(500);
	}

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new r = 0;r < rows && r < GROUPS_ISSUED_MAX;r++)
	{
		new id = ids[r], kind = lines[r][0], param = lines[r][1], amount = lines[r][2];
		s_IssuedGroup[playerid] = Groups_FindById(id);
		s_Issued[playerid][r][0] = kind;
		s_Issued[playerid][r][1] = param;
		s_Issued[playerid][r][2] = amount;
		returned += amount;
	}

	if (rows > 0)
	{
		if (s_IssuedGroup[playerid] == GROUP_INVALID)
		{
			mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_issued WHERE character_id = %d",characterid));
			Groups_ClearDuty(playerid);
			return async 0;
		}

		Groups_ReturnKit(playerid);
		Gui_Notify(playerid,"The kit you were issued last time goes back to the storehouse.");
	}

	return async returned;
}
#pragma warning pop

forward Groups_OnDuty(playerid,group,isOn);

public Groups_OnDuty(playerid,group,isOn)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Groups_ClearDuty(playerid);
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_Duty[playerid] != GROUP_INVALID)
	{
		pawn_call_public("Groups_OnDuty","ddd",playerid,s_Duty[playerid],0);
	}

	Groups_ClearDuty(playerid);
}

hook Groups_OnMemberLoaded(playerid)
{
	Groups_ReclaimIssued(playerid,Character_GetId(playerid));
}

hook Groups_OnLeft(playerid,group)
{
	if (s_Duty[playerid] == group)
	{
		Groups_SetDuty(playerid,group,false);
	}

	if (s_Livery[playerid] == group)
	{
		s_Livery[playerid] = GROUP_INVALID;
	}

	Groups_UpdateLivery(playerid);
}

hook Groups_OnFeatures(group)
{
	foreach (new playerid : Player)
	{
		if (s_Duty[playerid] == group && !Groups_HasFeature(group,GROUP_FEATURE_DUTY))
		{
			Groups_SetDuty(playerid,group,false);
		}

		if (s_Duty[playerid] == group || s_Livery[playerid] == group)
		{
			Groups_UpdateLivery(playerid);
		}
	}
}

hook OnPlayerSpawn(playerid)
{
	if (Groups_GetWearing(playerid) != GROUP_INVALID)
	{
		Groups_UpdateLivery(playerid);
	}

	Groups_RefreshPlayer(playerid);
}
