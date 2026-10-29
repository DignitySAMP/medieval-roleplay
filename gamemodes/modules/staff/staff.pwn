static bool:s_StaffFaction[MAX_PLAYERS];
static bool:s_StaffDuty[MAX_PLAYERS];
static bool:s_StaffFrozen[MAX_PLAYERS];

forward Task:Staff_LoadRoles(playerid,accountid);

stock bool:Staff_IsStaff(playerid)
{
	return Util_IsValidPlayer(playerid) && Account_GetAdminLevel(playerid) >= ADMIN_LEVEL_TRIAL;
}

stock bool:Staff_HasLevel(playerid,level)
{
	return Util_IsValidPlayer(playerid) && Account_GetAdminLevel(playerid) >= level;
}

stock bool:Staff_HasRole(playerid,role)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return false;
	}

	switch (role)
	{
		case STAFF_ROLE_LOREMASTER: return Account_IsLoremaster(playerid);
		case STAFF_ROLE_FACTION: return s_StaffFaction[playerid] || Account_GetAdminLevel(playerid) >= ADMIN_LEVEL_MANAGER;
	}

	return false;
}

stock Staff_SetRole(playerid,role,bool:isOn,byid = INVALID_PLAYER_ID)
{
	if (!Util_IsValidPlayer(playerid) || Account_GetId(playerid) <= 0)
	{
		return;
	}

	if (role == STAFF_ROLE_LOREMASTER)
	{
		Account_SetLoremaster(playerid,isOn);
	}
	else if (role == STAFF_ROLE_FACTION)
	{
		s_StaffFaction[playerid] = isOn;
	}

	if (isOn)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO staff_roles (account_id, role, granted_by, granted_at) VALUES (%d, %d, %d, %d)",Account_GetId(playerid),role,Util_IsValidPlayer(byid) ? Account_GetId(byid) : 0,gettime()));
	}
	else
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM staff_roles WHERE account_id = %d AND role = %d",Account_GetId(playerid),role));
	}
}

stock Staff_SetLevel(playerid,level)
{
	if (!Util_IsValidPlayer(playerid) || Account_GetId(playerid) <= 0)
	{
		return;
	}

	level = Util_ClampInt(level,ADMIN_LEVEL_NONE,ADMIN_LEVEL_MANAGER);
	Account_SetAdminLevel(playerid,level);
	mysql_tquery_s(g_Mysql,str_format("UPDATE accounts SET admin_level = %d WHERE id = %d",level,Account_GetId(playerid)));
}

stock bool:Staff_IsOnDuty(playerid)
{
	return Staff_IsStaff(playerid) && s_StaffDuty[playerid];
}

stock Staff_SetDuty(playerid,bool:isOn)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_StaffDuty[playerid] = isOn && Staff_IsStaff(playerid);
	}
}

stock bool:Staff_IsFrozen(playerid)
{
	return Util_IsValidPlayer(playerid) && s_StaffFrozen[playerid];
}

stock Staff_SetFrozen(playerid,bool:isFrozen)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_StaffFrozen[playerid] = isFrozen;
	TogglePlayerControllable(playerid,!isFrozen);
}

stock Staff_Log(staffid,const action[],const target[],const detail[] = "")
{
	new accountid = Util_IsValidPlayer(staffid) ? Account_GetId(staffid) : 0;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO staff_actions (staff_account_id, action, target, detail, at) VALUES (%d, '%e', '%e', '%e', %d)",accountid,action,target,detail,gettime()));
}

stock Staff_TargetName(playerid,dest[],size = sizeof(dest))
{
	new account[MAX_PLAYER_NAME], character[MAX_PLAYER_NAME];
	Account_GetName(playerid,account);
	Character_GetName(playerid,character);
	format(dest,size,"%s (%s, %d)",account,character[0] != EOS ? character : ("no character"),playerid);
}

stock Staff_Broadcast(const text[],level = ADMIN_LEVEL_TRIAL,colour = STAFF_NOTE_COLOUR)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Staff_HasLevel(playerid,level))
		{
			SendClientMessage(playerid,colour,text);
		}
	}
}

stock Staff_Chat(playerid,const text[])
{
	new account[MAX_PLAYER_NAME], line[160];
	Account_GetName(playerid,account);
	format(line,sizeof(line),"[Staff] %s (%d): %s",account,playerid,text);
	Staff_Broadcast(line,ADMIN_LEVEL_TRIAL,STAFF_CHAT_COLOUR);
}

stock bool:Staff_AskConsent(targetid,const title[],const text[])
{
	if (!IsPlayerConnected(targetid) || Gui_IsBusy(targetid))
	{
		return false;
	}

	new token = Account_GetToken(targetid), epoch = Gui_BeginFlow(targetid), Float:x, Float:y, Float:width;
	Kit_Begin(targetid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(targetid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(targetid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddChoice(targetid,x,y + KIT_ROW * 3.0,width * 0.48,"Agree",1,KIT_COLOUR_GOOD);
	Kit_AddChoice(targetid,x + width * 0.52,y + KIT_ROW * 3.0,width * 0.48,"Refuse",2,KIT_COLOUR_BAD);
	new pick = await Kit_Present(targetid);

	if (!IsPlayerConnected(targetid) || Account_GetToken(targetid) != token)
	{
		return false;
	}

	if (Gui_IsFlowCurrent(targetid,epoch))
	{
		Kit_Close(targetid);
	}

	return pick == 1;
}

stock bool:Staff_SecondOpinion(staffid,const what[])
{
	new level = Account_GetAdminLevel(staffid), second = INVALID_PLAYER_ID;

	foreach (new playerid : Player)
	{
		if (playerid != staffid && !IsPlayerNPC(playerid) && Account_GetAdminLevel(playerid) >= level && !Gui_IsBusy(playerid))
		{
			second = playerid;
			break;
		}
	}

	if (second == INVALID_PLAYER_ID)
	{
		Staff_Log(staffid,"unchecked",what,"no second member of staff online");
		return true;
	}

	new name[MAX_PLAYER_NAME], text[200];
	Account_GetName(staffid,name);
	format(text,sizeof(text),"%s asks you to agree: %s",name,what);
	SendClientMessage(staffid,STAFF_NOTE_COLOUR,"Waiting for a second member of staff to agree...");

	if (!Staff_AskConsent(second,"The two-person rule",text))
	{
		Staff_Log(second,"refused",what);
		return false;
	}

	Staff_Log(second,"seconded",what);
	return true;
}

#pragma warning push
#pragma warning disable 204
async Task:Staff_LoadRoles(playerid,accountid)
{
	s_StaffFaction[playerid] = false;
	await mysql_aquery_s(g_Mysql,str_format("SELECT role FROM staff_roles WHERE account_id = %d",accountid));

	if (!IsPlayerConnected(playerid) || Account_GetId(playerid) != accountid)
	{
		return async 0;
	}

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new role;
		cache_get_value_name_int(r,"role",role);

		if (role == STAFF_ROLE_FACTION)
		{
			s_StaffFaction[playerid] = true;
		}
	}

	return async 1;
}
#pragma warning pop

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_StaffFaction[playerid] = false;
	s_StaffDuty[playerid] = false;
	s_StaffFrozen[playerid] = false;
}

hook Account_OnAuthenticated(playerid,accountid)
{
	Staff_LoadRoles(playerid,accountid);
}
