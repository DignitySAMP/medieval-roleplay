CMD<ADMIN_LEVEL_ADMIN>:disaster(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], key[12], severity, minutes, lead;

	if (sscanf(params,"s[12]S()[12]I(2)I(30)I(0)",action,key,severity,minutes,lead))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/disaster info | start <storm|flood|drought|pestilence> [severity 1-3] [minutes] [warning minutes] | stop | strike | sicken");
		return 1;
	}

	if (!strcmp(action,"start",true))
	{
		new kind = Disasters_FindKind(key);

		if (kind == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"storm, flood, drought or pestilence.");
			return 1;
		}

		SendClientMessage(playerid,0xFFFFFFFF,Disasters_Schedule(kind,severity,lead,minutes) ? ("Scheduled.") : ("One is already under way: /disaster stop first."));
		return 1;
	}

	if (!strcmp(action,"stop",true))
	{
		Disasters_End();
		SendClientMessage(playerid,0xFFFFFFFF,"Stopped.");
		return 1;
	}

	if (!strcmp(action,"strike",true))
	{
		new building = Disasters_Strike(), name[28];
		Fire_GetName(building,name);
		SendClientMessage(playerid,0xFFFFFFFF,building == -1 ? ("Nothing left standing to strike.") : sprintf("Lightning strikes %s.",name));
		return 1;
	}

	if (!strcmp(action,"sicken",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d fall sick.",Disasters_Sicken()));
		return 1;
	}

	new name[20];
	Disasters_GetName(Disasters_GetKind(),name);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s, severity %d, %s, starts in %d s, ends in %d s. Weather override %d, scarcity %d%%, fire growth %d.",name,Disasters_GetSeverity(),Disasters_IsWarned() ? ("warned") : ("under way"),max(Disasters_GetStartsAt() - gettime(),0),Disasters_GetEndsAt() == 0 ? 0 : max(Disasters_GetEndsAt() - gettime(),0),Calendar_GetWeatherOverride(),Trader_GetScarcity(),Fire_GetGrowth()));
	return 1;
}
