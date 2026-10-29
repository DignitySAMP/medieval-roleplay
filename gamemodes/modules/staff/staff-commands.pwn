stock Staff_FindItem(const name[])
{
	for (new param = 0;param < ITEM_DEF_COUNT;param++)
	{
		if (param == ITEM_BOW || param == ITEM_CROSSBOW)
		{
			continue;
		}

		if (!strcmp(g_ItemDefs[param][E_ITEM_DEF_NAME],name,true))
		{
			return param;
		}
	}

	for (new param = 0;param < ITEM_DEF_COUNT;param++)
	{
		if (param == ITEM_BOW || param == ITEM_CROSSBOW)
		{
			continue;
		}

		if (strfind(g_ItemDefs[param][E_ITEM_DEF_NAME],name,true) != -1)
		{
			return param;
		}
	}

	return -1;
}

stock Staff_FindWeapon(const name[])
{
	new weaponName[32];

	for (new weapon = 0;weapon < WEAPON_COUNT;weapon++)
	{
		Weapon_GetName(weapon,weaponName);

		if (!strcmp(weaponName,name,true))
		{
			return weapon;
		}
	}

	return INVALID_WEAPON_INDEX;
}

stock Staff_FindGiveable(const name[],&E_ITEM_KIND:kind)
{
	new weapon = Staff_FindWeapon(name);

	if (weapon != INVALID_WEAPON_INDEX)
	{
		kind = ITEM_KIND_WEAPON;
		return weapon;
	}

	new param = Staff_FindItem(name);

	if (param != -1)
	{
		kind = g_ItemDefs[param][E_ITEM_DEF_KIND];
	}

	return param;
}

stock Staff_ShutdownIn(staffid,minutes)
{
	if (Maintenance_IsStopping())
	{
		return;
	}

	if (minutes <= 0)
	{
		Staff_Log(staffid,"shutdown","cancelled");
		Maintenance_Cancel();
		return;
	}

	minutes = min(minutes,STAFF_SHUTDOWN_MAX);
	new target[32];
	format(target,sizeof(target),"in %d minutes",minutes);
	Staff_Log(staffid,"shutdown",target);
	Maintenance_Cancel();
	Maintenance_Start(minutes);
}

forward Staff_OpenPanelDeferred(playerid);

public Staff_OpenPanelDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Staff_OpenPanel(playerid);
	}

	return 1;
}

forward Staff_OpenReportsDeferred(playerid);

public Staff_OpenReportsDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Staff_OpenReports(playerid);
	}

	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:staff(cmdid, playerid, params[])
{
	#pragma unused cmdid, params
	SetTimerEx("Staff_OpenPanelDeferred",0,false,"d",playerid);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:reports(cmdid, playerid, params[])
{
	#pragma unused cmdid, params
	SetTimerEx("Staff_OpenReportsDeferred",0,false,"d",playerid);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:a(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Staff_Chat(playerid,params);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:duty(cmdid, playerid, params[])
{
	#pragma unused cmdid, params
	Staff_SetDuty(playerid,!Staff_IsOnDuty(playerid));
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,Staff_IsOnDuty(playerid) ? ("You're on duty.") : ("You're off duty."));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:spec(cmdid, playerid, params[])
{
	new targetid;

	if (sscanf(params,"r",targetid))
	{
		if (Staff_IsSpectating(playerid))
		{
			Staff_StopSpectating(playerid);
			return 1;
		}

		Command_Usage(playerid,cmdid,"<player> (again to stop)");
		return 1;
	}

	if (Staff_IsSpectating(playerid) && Staff_GetSpecTarget(playerid) == targetid)
	{
		Staff_StopSpectating(playerid);
		return 1;
	}

	Staff_Spectate(playerid,targetid);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:inspect(cmdid, playerid, params[])
{
	new targetid;

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Staff_Inspect(playerid,targetid);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:warn(cmdid, playerid, params[])
{
	new targetid, reason[96];

	if (sscanf(params,"rs[96]",targetid,reason))
	{
		Command_Usage(playerid,cmdid,"<player> <reason>");
		return 1;
	}

	Staff_Warn(playerid,targetid,reason);
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,"Warned and recorded.");
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:warnings(cmdid, playerid, params[])
{
	yield 1;
	new targetid;

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT w.reason, w.at, a.name FROM warnings w LEFT JOIN accounts a ON a.id = w.staff_account_id WHERE w.account_id = %d ORDER BY w.id DESC LIMIT %d",Account_GetId(targetid),STAFF_WARNINGS_SHOWN));
	new rows = cache_num_rows(), now = gettime();

	if (rows == 1)
	{
		SendClientMessage(playerid,STAFF_NOTE_COLOUR,"1 warning on record:");
	}
	else
	{
		SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("%d warnings on record:",rows));
	}

	for (new r = 0;r < rows;r++)
	{
		new reason[144], who[MAX_PLAYER_NAME], at;
		cache_get_value_name(r,"reason",reason);
		cache_get_value_name(r,"name",who);
		cache_get_value_name_int(r,"at",at);
		new days = (now - at) / 86400, when[16];

		if (days <= 0)
		{
			strcopy(when,"Today");
		}
		else if (days == 1)
		{
			strcopy(when,"Yesterday");
		}
		else
		{
			format(when,sizeof(when),"%d days ago",days);
		}

		SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("%s, %s: %s",when,who,reason));
	}

	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:goto(cmdid, playerid, params[])
{
	new targetid;

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Staff_Goto(playerid,targetid);
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:gethere(cmdid, playerid, params[])
{
	new targetid;

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Staff_GetHere(playerid,targetid);
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:kick(cmdid, playerid, params[])
{
	new targetid, reason[96];

	if (sscanf(params,"rs[96]",targetid,reason))
	{
		Command_Usage(playerid,cmdid,"<player> <reason>");
		return 1;
	}

	Staff_Kick(playerid,targetid,reason);
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:ban(cmdid, playerid, params[])
{
	new targetid, hours, reason[96];

	if (sscanf(params,"ris[96]",targetid,hours,reason))
	{
		Command_Usage(playerid,cmdid,"<player> <hours, 0 for good> <reason>");
		return 1;
	}

	Staff_Ban(playerid,targetid,hours,reason);
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:unban(cmdid, playerid, params[])
{
	new name[MAX_PLAYER_NAME];

	if (sscanf(params,"s[24]",name))
	{
		Command_Usage(playerid,cmdid,"<account name>");
		return 1;
	}

	Staff_Unban(playerid,name);
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,"Any ban on that account is lifted.");
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:jail(cmdid, playerid, params[])
{
	new targetid, minutes, reason[96];

	if (sscanf(params,"ris[96]",targetid,minutes,reason))
	{
		Command_Usage(playerid,cmdid,"<player> <minutes> <reason>");
		return 1;
	}

	Staff_Jail(playerid,targetid,minutes,reason);
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:unjail(cmdid, playerid, params[])
{
	new targetid;

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Staff_Unjail(playerid,targetid);
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:freeze(cmdid, playerid, params[])
{
	new targetid, name[64];

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Staff_SetFrozen(targetid,true);
	Staff_TargetName(targetid,name);
	Staff_Log(playerid,"freeze",name);
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,"Frozen.");
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:unfreeze(cmdid, playerid, params[])
{
	new targetid, name[64];

	if (sscanf(params,"r",targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Staff_SetFrozen(targetid,false);
	Staff_TargetName(targetid,name);
	Staff_Log(playerid,"unfreeze",name);
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,"Unfrozen.");
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:logs(cmdid, playerid, params[])
{
	#pragma unused cmdid, params
	Staff_OpenLogs(playerid);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:crier(cmdid, playerid, params[])
{
	if (!Staff_HasRole(playerid,STAFF_ROLE_LOREMASTER) && !Staff_HasLevel(playerid,ADMIN_LEVEL_ADMIN))
	{
		return 0;
	}

	new title[48], text[144];

	if (sscanf(params,"p<|>s[48]s[144]",title,text))
	{
		Command_Usage(playerid,cmdid,"<title>|<text>");
		return 1;
	}

	new now = gettime();
	Notices_Post(NOTICE_TAB_EVENTS,Character_GetId(playerid),title,text,now,now + 3 * 86400);
	Staff_Log(playerid,"crier",title,text);
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,"Posted on the Events tab; the crier takes it round.");
	return 1;
}

CMD<ADMIN_LEVEL_MANAGER>:setstaff(cmdid, playerid, params[])
{
	new targetid, role[16], name[64];

	if (sscanf(params,"rs[16]",targetid,role))
	{
		Command_Usage(playerid,cmdid,"<player> <none|assistant|moderator|admin|management|loremaster|faction>");
		return 1;
	}

	Staff_TargetName(targetid,name);

	for (new level = ADMIN_LEVEL_NONE;level <= ADMIN_LEVEL_MANAGER;level++)
	{
		if (!strcmp(role,g_StaffLevelNames[level],true) || (level == ADMIN_LEVEL_NONE && !strcmp(role,"none",true)))
		{
			Staff_SetLevel(targetid,level);
			Staff_Log(playerid,"setstaff",name,g_StaffLevelNames[level]);
			SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("%s is %s now.",name,g_StaffLevelNames[level]));
			return 1;
		}
	}

	new which = !strcmp(role,"loremaster",true) ? STAFF_ROLE_LOREMASTER : (!strcmp(role,"faction",true) ? STAFF_ROLE_FACTION : -1);

	if (which == -1)
	{
		Command_Usage(playerid,cmdid,"<player> <none|assistant|moderator|admin|management|loremaster|faction>");
		return 1;
	}

	new bool:has = Staff_HasRole(targetid,which);
	Staff_SetRole(targetid,which,!has,playerid);
	Staff_Log(playerid,"setstaff",name,sprintf("%s %s",has ? ("took") : ("gave"),g_StaffRoleNames[which]));
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("%s %s the %s role.",name,has ? ("loses") : ("has"),g_StaffRoleNames[which]));
	return 1;
}

CMD<ADMIN_LEVEL_MANAGER>:giveitem(cmdid, playerid, params[])
{
	new targetid, amount, stars, item[32];

	if (sscanf(params,"riis[32]",targetid,amount,stars,item))
	{
		Command_Usage(playerid,cmdid,"<player> <amount> <stars 1-5> <item name>");
		return 1;
	}

	new E_ITEM_KIND:kind, param = Staff_FindGiveable(item,kind), name[64], itemName[ITEM_NAME_LEN];

	if (param == -1)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"No item by that name.");
		return 1;
	}

	Item_GetName(kind,param,itemName);
	Staff_TargetName(targetid,name);

	if (!Inventory_Give(targetid,kind,param,Util_ClampInt(amount,1,100),Util_ClampInt(stars,ITEM_STARS_MIN,ITEM_STARS_MAX)))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"It doesn't fit in their bag.");
		return 1;
	}

	Staff_Log(playerid,"giveitem",name,sprintf("%d %s",amount,itemName));
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("Gave %d %s.",amount,itemName));
	return 1;
}

CMD<ADMIN_LEVEL_MANAGER>:givecoin(cmdid, playerid, params[])
{
	new targetid, pfennig, name[64];

	if (sscanf(params,"ri",targetid,pfennig) || pfennig <= 0)
	{
		Command_Usage(playerid,cmdid,"<player> <pfennig>");
		return 1;
	}

	Staff_TargetName(targetid,name);

	if (!Economy_Give(targetid,pfennig,"staff"))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"It doesn't fit in their purse.");
		return 1;
	}

	Staff_Log(playerid,"givecoin",name,sprintf("%d pf",pfennig));
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,"Coin given.");
	return 1;
}

CMD<ADMIN_LEVEL_MANAGER>:shutdown(cmdid, playerid, params[])
{
	new minutes;

	if (sscanf(params,"i",minutes))
	{
		Command_Usage(playerid,cmdid,"<minutes, 0 to call it off>");
		return 1;
	}

	Staff_ShutdownIn(playerid,minutes);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:seat(cmdid, playerid, params[])
{
	if (!Staff_HasRole(playerid,STAFF_ROLE_FACTION))
	{
		return 0;
	}

	new targetid, title[12];

	if (sscanf(params,"s[12]I(-1)",title,targetid))
	{
		Command_Usage(playerid,cmdid,"<duke|count|regent> [player id] (no player strips the title)");
		return 1;
	}

	new office = !strcmp(title,"duke",true) ? 0 : (!strcmp(title,"count",true) ? 1 : (!strcmp(title,"regent",true) ? 2 : -1)), name[64], what[96];

	if (office == -1)
	{
		Command_Usage(playerid,cmdid,"<duke|count|regent> [player]");
		return 1;
	}

	if (targetid != -1 && IsPlayerConnected(targetid))
	{
		Staff_TargetName(targetid,name);
	}
	else
	{
		strcopy(name,"nobody");
	}

	format(what,sizeof(what),"seat %s as %s",name,title);

	if (!Staff_SecondOpinion(playerid,what))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"The second member of staff didn't agree.");
		return 1;
	}

	Realm_SetOffice(office,targetid != -1 && IsPlayerConnected(targetid) ? Character_GetId(targetid) : 0);
	Staff_Log(playerid,"seat",name,title);
	SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("The %s's seat: %s.",title,name));
	return 1;
}
