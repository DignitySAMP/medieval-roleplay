#define FRIENDS_MAX (50)
#define FRIENDS_COLOUR (0x9FD49FFF)
#define FRIENDS_LIST_LEN (1024)

static s_Friends[MAX_PLAYERS][FRIENDS_MAX];
static s_FriendCount[MAX_PLAYERS];
static bool:s_FriendsLoaded[MAX_PLAYERS];

stock bool:Friends_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FriendsLoaded[playerid];
}

stock Friends_GetCount(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_FriendCount[playerid] : 0;
}

stock bool:Friends_Has(playerid,accountid)
{
	if (!Util_IsValidPlayer(playerid) || accountid <= 0)
	{
		return false;
	}

	for (new i = 0;i < s_FriendCount[playerid];i++)
	{
		if (s_Friends[playerid][i] == accountid)
		{
			return true;
		}
	}

	return false;
}

stock bool:Friends_Add(playerid,targetid)
{
	new accountid = Account_GetId(playerid), friendid = Account_GetId(targetid);

	if (!s_FriendsLoaded[playerid] || accountid <= 0 || friendid <= 0 || friendid == accountid || Friends_Has(playerid,friendid) || s_FriendCount[playerid] >= FRIENDS_MAX)
	{
		return false;
	}

	s_Friends[playerid][s_FriendCount[playerid]++] = friendid;
	mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO account_friends (account_id, friend_id) VALUES (%d, %d)",accountid,friendid));
	return true;
}

stock bool:Friends_Remove(playerid,friendid)
{
	for (new i = 0;i < s_FriendCount[playerid];i++)
	{
		if (s_Friends[playerid][i] != friendid)
		{
			continue;
		}

		s_Friends[playerid][i] = s_Friends[playerid][--s_FriendCount[playerid]];
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM account_friends WHERE account_id = %d AND friend_id = %d",Account_GetId(playerid),friendid));
		return true;
	}

	return false;
}

stock Friends_ShowOnline(playerid,bool:isLogin = false)
{
	new list[FRIENDS_LIST_LEN], name[ACCOUNT_USERNAME_MAX + 1], entry[ACCOUNT_USERNAME_MAX + 12], online = 0;
	list[0] = EOS;

	foreach(new i : Player)
	{
		if (i == playerid || !Friends_Has(playerid,Account_GetId(i)))
		{
			continue;
		}

		Account_GetName(i,name);
		format(entry,sizeof(entry),"%s%s (%d)",online > 0 ? (", ") : (""),name,i);
		strcat(list,entry);
		online++;
	}

	if (isLogin && online == 0)
	{
		return;
	}

	new line[FRIENDS_LIST_LEN + 96];

	if (s_FriendCount[playerid] == 0)
	{
		strcopy(line,"Your friends list is empty. Add someone with /addfriend <id or name>.");
	}
	else if (online == 0)
	{
		format(line,sizeof(line),"None of your %d friends are online.",s_FriendCount[playerid]);
	}
	else if (online == s_FriendCount[playerid])
	{
		format(line,sizeof(line),"Friends online: %s.",list);
	}
	else
	{
		format(line,sizeof(line),"Friends online: %s. %d more are offline.",list,s_FriendCount[playerid] - online);
	}

	MessageSplit_SendClientMessage(playerid,FRIENDS_COLOUR,line);
}

forward Friends_LoadDeferred(playerid,token);

public Friends_LoadDeferred(playerid,token)
{
	yield 1;

	new accountid = Account_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT friend_id FROM account_friends WHERE account_id = %d LIMIT %d",accountid,FRIENDS_MAX));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	s_FriendCount[playerid] = 0;

	for (new row = 0, rows = cache_num_rows();row < rows && s_FriendCount[playerid] < FRIENDS_MAX;row++)
	{
		cache_get_value_name_int(row,"friend_id",s_Friends[playerid][s_FriendCount[playerid]]);
		s_FriendCount[playerid]++;
	}

	s_FriendsLoaded[playerid] = true;
	Friends_ShowOnline(playerid,true);
}

forward Friends_UnfriendByNameDeferred(playerid,token,const name[]);

public Friends_UnfriendByNameDeferred(playerid,token,const name[])
{
	yield 1;

	new wanted[ACCOUNT_USERNAME_MAX + 1];
	strcopy(wanted,name);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, name FROM accounts WHERE name = '%e' LIMIT 1",wanted));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	new friendid = 0, line[96];

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"id",friendid);
		cache_get_value_name(0,"name",wanted);
	}

	if (friendid <= 0 || !Friends_Remove(playerid,friendid))
	{
		format(line,sizeof(line),"%s isn't on your friends list. /friends shows who is.",wanted);
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,line);
		return;
	}

	format(line,sizeof(line),"%s is off your friends list.",wanted);
	SendClientMessage(playerid,FRIENDS_COLOUR,line);
}

CMD<ADMIN_LEVEL_NONE>:friends(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	if (!s_FriendsLoaded[playerid])
	{
		return 1;
	}

	Friends_ShowOnline(playerid);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:addfriend(cmdid, playerid, params[])
{
	new targetid = INVALID_PLAYER_ID;

	if (sscanf(params,"u",targetid))
	{
		Command_Usage(playerid,cmdid,"<id or name>");
		return 1;
	}

	if (targetid == INVALID_PLAYER_ID || !IsPlayerConnected(targetid) || Account_GetId(targetid) <= 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"That player isn't online. You can only add someone who is.");
		return 1;
	}

	if (targetid == playerid)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't add yourself.");
		return 1;
	}

	new name[ACCOUNT_USERNAME_MAX + 1], line[128];
	Account_GetName(targetid,name);

	if (Friends_Has(playerid,Account_GetId(targetid)))
	{
		format(line,sizeof(line),"%s is already on your friends list.",name);
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,line);
		return 1;
	}

	if (s_FriendCount[playerid] >= FRIENDS_MAX)
	{
		format(line,sizeof(line),"Your friends list is full at %d. Remove someone with /unfriend first.",FRIENDS_MAX);
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,line);
		return 1;
	}

	if (!Friends_Add(playerid,targetid))
	{
		return 1;
	}

	format(line,sizeof(line),"%s is on your friends list now. /friends shows which of your friends are online.",name);
	SendClientMessage(playerid,FRIENDS_COLOUR,line);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:unfriend(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<name, or id if they're online>");
		return 1;
	}

	new targetid = INVALID_PLAYER_ID, name[ACCOUNT_USERNAME_MAX + 1], line[96];

	if (!sscanf(params,"u",targetid) && targetid != INVALID_PLAYER_ID && Account_GetId(targetid) > 0 && Friends_Has(playerid,Account_GetId(targetid)))
	{
		Account_GetName(targetid,name);
		Friends_Remove(playerid,Account_GetId(targetid));
		format(line,sizeof(line),"%s is off your friends list.",name);
		SendClientMessage(playerid,FRIENDS_COLOUR,line);
		return 1;
	}

	strcopy(name,params);
	SetTimerEx("Friends_UnfriendByNameDeferred",0,false,"dds",playerid,Account_GetToken(playerid),name);
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_FriendCount[playerid] = 0;
	s_FriendsLoaded[playerid] = false;
}

hook Account_OnAuthenticated(playerid,accountid)
{
	new name[ACCOUNT_USERNAME_MAX + 1], line[96];
	Account_GetName(playerid,name);
	format(line,sizeof(line),"Your friend %s (%d) is online.",name,playerid);

	foreach(new i : Player)
	{
		if (i != playerid && Friends_Has(i,accountid))
		{
			SendClientMessage(i,FRIENDS_COLOUR,line);
		}
	}

	SetTimerEx("Friends_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}
