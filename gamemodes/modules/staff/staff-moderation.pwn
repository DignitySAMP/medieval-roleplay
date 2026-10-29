static s_JailUntil[MAX_PLAYERS];
static bool:s_JailTold[MAX_PLAYERS];
static s_SpecTarget[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};
static Float:s_SpecReturn[MAX_PLAYERS][4];
static s_SpecPlace[MAX_PLAYERS][2];

forward Task:Staff_CheckBan(playerid,accountid);
forward Task:Staff_LoadJail(playerid,accountid);
forward Task:Staff_Ban(staffid,targetid,hours,const reason[]);

stock Staff_Kick(staffid,targetid,const reason[])
{
	if (!IsPlayerConnected(targetid))
	{
		return;
	}

	new name[64];
	Staff_TargetName(targetid,name);
	SendClientMessage(targetid,COMMAND_COLOUR_ERROR,sprintf("You're kicked: %s",reason));
	Staff_Log(staffid,"kick",name,reason);
	Staff_Broadcast(sprintf("%s is kicked: %s",name,reason));
	SetTimerEx("Staff_KickDeferred",STAFF_KICK_DELAY_MS,false,"dd",targetid,Account_GetToken(targetid));
}

#pragma warning push
#pragma warning disable 204
async Task:Staff_Ban(staffid,targetid,hours,const reason[])
{
	if (!IsPlayerConnected(targetid) || Account_GetId(targetid) <= 0)
	{
		wait_ticks(1);
		return async 0;
	}

	new name[64], what[160], ip[16], accountid = Account_GetId(targetid), token = Account_GetToken(targetid);
	Staff_TargetName(targetid,name);

	if (hours <= 0 || hours > STAFF_REVIEW_HOURS)
	{
		format(what,sizeof(what),"ban %s %s (%s)",name,hours <= 0 ? ("for good") : sprintf("for %d hours",hours),reason);

		if (!Staff_SecondOpinion(staffid,what))
		{
			SendClientMessage(staffid,COMMAND_COLOUR_ERROR,"The second member of staff didn't agree.");
			wait_ticks(1);
			return async 0;
		}
	}

	GetPlayerIp(targetid,ip,sizeof(ip));
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO bans (account_id, ip, until, reason, staff_account_id, at, lifted) VALUES (%d, '%e', %d, '%e', %d, %d, 0)",accountid,ip,hours <= 0 ? 0 : gettime() + hours * 3600,reason,Util_IsValidPlayer(staffid) ? Account_GetId(staffid) : 0,gettime()));
	Staff_Log(staffid,"ban",name,sprintf("%d h: %s",hours,reason));
	Staff_Broadcast(sprintf("%s is banned %s: %s",name,hours <= 0 ? ("for good") : sprintf("for %d hours",hours),reason));

	if (IsPlayerConnected(targetid) && Account_GetToken(targetid) == token)
	{
		SendClientMessage(targetid,COMMAND_COLOUR_ERROR,sprintf("You're banned %s: %s",hours <= 0 ? ("for good") : sprintf("for %d hours",hours),reason));
		SetTimerEx("Staff_KickDeferred",STAFF_KICK_DELAY_MS,false,"dd",targetid,token);
	}

	return async 1;
}

async Task:Staff_CheckBan(playerid,accountid)
{
	new ip[16], token = Account_GetToken(playerid);
	GetPlayerIp(playerid,ip,sizeof(ip));
	await mysql_aquery_s(g_Mysql,str_format("SELECT until, reason FROM bans WHERE lifted = 0 AND (until = 0 OR until > %d) AND (%s ip = '%e') ORDER BY id DESC LIMIT 1",gettime(),accountid > 0 ? sprintf("account_id = %d OR",accountid) : (""),ip));

	if (cache_num_rows() == 0 || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return async 0;
	}

	new until, reason[144];
	cache_get_value_name_int(0,"until",until);
	cache_get_value_name(0,"reason",reason);

	if (until == 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,sprintf("You're banned for good: %s",reason));
	}
	else
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,sprintf("You're banned for %d more hours: %s",(until - gettime()) / 3600 + 1,reason));
	}

	SetTimerEx("Staff_KickDeferred",STAFF_KICK_DELAY_MS,false,"dd",playerid,token);
	return async 1;
}

async Task:Staff_LoadJail(playerid,accountid)
{
	s_JailUntil[playerid] = 0;
	await mysql_aquery_s(g_Mysql,str_format("SELECT until FROM staff_jail WHERE account_id = %d AND until > %d",accountid,gettime()));

	if (cache_num_rows() > 0 && IsPlayerConnected(playerid) && Account_GetId(playerid) == accountid)
	{
		cache_get_value_name_int(0,"until",s_JailUntil[playerid]);
	}

	return async s_JailUntil[playerid];
}
#pragma warning pop

stock bool:Staff_Unban(staffid,const name[])
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE bans SET lifted = 1 WHERE lifted = 0 AND account_id = (SELECT id FROM accounts WHERE name = '%e' LIMIT 1)",name));
	Staff_Log(staffid,"unban",name);
	return true;
}

stock Staff_Warn(staffid,targetid,const reason[])
{
	new name[64];
	Staff_TargetName(targetid,name);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO warnings (account_id, staff_account_id, reason, at) VALUES (%d, %d, '%e', %d)",Account_GetId(targetid),Util_IsValidPlayer(staffid) ? Account_GetId(staffid) : 0,reason,gettime()));
	Staff_Log(staffid,"warn",name,reason);
	SendClientMessage(targetid,COMMAND_COLOUR_ERROR,sprintf("A warning from the staff, on your record: %s",reason));
}

stock bool:Staff_IsJailed(playerid)
{
	return Util_IsValidPlayer(playerid) && s_JailUntil[playerid] > gettime();
}

stock Staff_GetJailLeft(playerid)
{
	return Staff_IsJailed(playerid) ? s_JailUntil[playerid] - gettime() : 0;
}

static Staff_SendToJail(playerid)
{
	Gaol_HoldInWorld(playerid,STAFF_JAIL_WORLD + playerid);
}

static bool:Staff_IsInJailWorld(playerid)
{
	new world = GetPlayerVirtualWorld(playerid);
	return world >= STAFF_JAIL_WORLD && world < STAFF_JAIL_WORLD + MAX_PLAYERS;
}

static Staff_LeaveJail(playerid)
{
	Gaol_ReleaseHold(playerid);

	if (Staff_IsInJailWorld(playerid))
	{
		Gaol_Leave(playerid);
	}
}

stock Staff_Jail(staffid,targetid,minutes,const reason[])
{
	if (!IsPlayerConnected(targetid) || Account_GetId(targetid) <= 0)
	{
		return;
	}

	new name[64];
	Staff_TargetName(targetid,name);
	s_JailUntil[targetid] = gettime() + max(minutes,1) * 60;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO staff_jail (account_id, until, reason, staff_account_id) VALUES (%d, %d, '%e', %d) ON DUPLICATE KEY UPDATE until = VALUES(until), reason = VALUES(reason), staff_account_id = VALUES(staff_account_id)",Account_GetId(targetid),s_JailUntil[targetid],reason,Util_IsValidPlayer(staffid) ? Account_GetId(staffid) : 0));
	Staff_Log(staffid,"jail",name,sprintf("%d min: %s",minutes,reason));
	Staff_SendToJail(targetid);
	s_JailTold[targetid] = true;
	SendClientMessage(targetid,COMMAND_COLOUR_ERROR,sprintf("You're in OOC jail for %d minutes: %s",minutes,reason));
}

stock Staff_Unjail(staffid,targetid)
{
	if (!IsPlayerConnected(targetid))
	{
		return;
	}

	new name[64];
	Staff_TargetName(targetid,name);
	s_JailUntil[targetid] = 0;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM staff_jail WHERE account_id = %d",Account_GetId(targetid)));
	Staff_Log(staffid,"unjail",name);
	Staff_LeaveJail(targetid);
	SendClientMessage(targetid,STAFF_NOTE_COLOUR,"You're out of OOC jail.");
}

stock bool:Staff_IsSpectating(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SpecTarget[playerid] != INVALID_PLAYER_ID;
}

stock Staff_GetSpecTarget(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_SpecTarget[playerid] : INVALID_PLAYER_ID;
}

stock bool:Staff_Spectate(playerid,targetid)
{
	if (!IsPlayerConnected(targetid) || targetid == playerid)
	{
		return false;
	}

	if (!Staff_IsSpectating(playerid))
	{
		GetPlayerPos(playerid,s_SpecReturn[playerid][0],s_SpecReturn[playerid][1],s_SpecReturn[playerid][2]);
		GetPlayerFacingAngle(playerid,s_SpecReturn[playerid][3]);
		s_SpecPlace[playerid][0] = GetPlayerVirtualWorld(playerid);
		s_SpecPlace[playerid][1] = GetPlayerInterior(playerid);
	}

	s_SpecTarget[playerid] = targetid;
	SetPlayerVirtualWorld(playerid,GetPlayerVirtualWorld(targetid));
	SetPlayerInterior(playerid,GetPlayerInterior(targetid));
	TogglePlayerSpectating(playerid,true);
	PlayerSpectatePlayer(playerid,targetid);
	new name[64];
	Staff_TargetName(targetid,name);
	Staff_Log(playerid,"spec",name);
	return true;
}

stock Staff_StopSpectating(playerid)
{
	if (!Staff_IsSpectating(playerid))
	{
		return;
	}

	s_SpecTarget[playerid] = INVALID_PLAYER_ID;
	SetSpawnInfo(playerid,NO_TEAM,Character_GetSkin(playerid),s_SpecReturn[playerid][0],s_SpecReturn[playerid][1],s_SpecReturn[playerid][2],s_SpecReturn[playerid][3],WEAPON:0,0,WEAPON:0,0,WEAPON:0,0);
	TogglePlayerSpectating(playerid,false);
	SetTimerEx("Staff_SpecReturn",500,false,"dd",playerid,Account_GetToken(playerid));
}

stock Staff_Goto(staffid,targetid)
{
	new Float:x, Float:y, Float:z, Float:a, name[64];
	GetPlayerPos(targetid,x,y,z);
	GetPlayerFacingAngle(targetid,a);
	Util_SafeTeleport(staffid,x + floatsin(-a,degrees) * 1.5,y + floatcos(-a,degrees) * 1.5,z,a + 180.0,GetPlayerVirtualWorld(targetid),GetPlayerInterior(targetid));
	Staff_TargetName(targetid,name);
	Staff_Log(staffid,"goto",name);
}

stock Staff_GetHere(staffid,targetid)
{
	new Float:x, Float:y, Float:z, Float:a, name[64];
	GetPlayerPos(staffid,x,y,z);
	GetPlayerFacingAngle(staffid,a);
	Util_SafeTeleport(targetid,x + floatsin(-a,degrees) * 1.5,y + floatcos(-a,degrees) * 1.5,z,a + 180.0,GetPlayerVirtualWorld(staffid),GetPlayerInterior(staffid));
	Staff_TargetName(targetid,name);
	Staff_Log(staffid,"gethere",name);
	SendClientMessage(targetid,STAFF_NOTE_COLOUR,"A member of staff brings you to them.");
}

forward Staff_KickDeferred(playerid,token);

public Staff_KickDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Kick(playerid);
	}

	return 1;
}

forward Staff_SpecReturn(playerid,token);

public Staff_SpecReturn(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Util_SafeTeleport(playerid,s_SpecReturn[playerid][0],s_SpecReturn[playerid][1],s_SpecReturn[playerid][2],s_SpecReturn[playerid][3],s_SpecPlace[playerid][0],s_SpecPlace[playerid][1]);
	}

	return 1;
}

Timer_Declare(Staff_JailTick)
{
	new now = gettime();

	foreach (new playerid : Player)
	{
		if (!Session_IsPlaying(playerid))
		{
			continue;
		}

		if (s_JailUntil[playerid] == 0)
		{
			if (Staff_IsInJailWorld(playerid))
			{
				Staff_LeaveJail(playerid);
			}
		}
		else if (now >= s_JailUntil[playerid])
		{
			Staff_Unjail(INVALID_PLAYER_ID,playerid);
		}
		else
		{
			if (GetPlayerVirtualWorld(playerid) != STAFF_JAIL_WORLD + playerid || !Gaol_IsInHold(playerid))
			{
				Staff_SendToJail(playerid);
			}

			if (!s_JailTold[playerid])
			{
				new minutes = Staff_GetJailLeft(playerid) / 60 + 1;
				s_JailTold[playerid] = true;
				SendClientMessage(playerid,COMMAND_COLOUR_ERROR,sprintf("You're still in OOC jail for %d more %s.",minutes,minutes == 1 ? ("minute") : ("minutes")));
			}
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_JailUntil[playerid] = 0;
	s_JailTold[playerid] = false;
	s_SpecTarget[playerid] = INVALID_PLAYER_ID;

	if (!IsPlayerNPC(playerid))
	{
		Staff_CheckBan(playerid,0);
	}
}

hook Account_OnAuthenticated(playerid,accountid)
{
	Staff_CheckBan(playerid,accountid);
	Staff_LoadJail(playerid,accountid);
}

hook Account_OnQuizFailedOut(playerid,const ip[],const reason[])
{
	new name[MAX_PLAYER_NAME + 1];
	GetPlayerName(playerid,name,sizeof(name));
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO bans (account_id, ip, until, reason, staff_account_id, at, lifted) VALUES (NULL, '%e', 0, '%e', 0, %d, 0)",ip,reason,gettime()));
	Staff_Log(INVALID_PLAYER_ID,"quizban",name,ip);
	Staff_Broadcast(sprintf("%s is banned for good: failed the roleplay quiz %d times within %d hours. /quizreset lifts it.",name,ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_CAP_HOURS));
}

hook Account_OnQuizReset(staffid,const name[],const ip[])
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE bans SET lifted = 1 WHERE lifted = 0 AND account_id IS NULL AND ip = '%e'",ip));
	Staff_Log(staffid,"quizreset",name,ip);
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	foreach (new other : Player)
	{
		if (s_SpecTarget[other] == playerid)
		{
			Staff_StopSpectating(other);
			SendClientMessage(other,STAFF_NOTE_COLOUR,"The player you were watching left.");
		}
	}
}
