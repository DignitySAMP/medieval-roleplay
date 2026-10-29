CMD<ADMIN_LEVEL_TRIAL>:notice(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[200];

	if (sscanf(params,"s[12]S()[200]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/notice realm|church|events [heading]: [text] | list | cancel [id] | board");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Notices up: %d (realm %d, church %d, players %d, events %d).",Notices_Count(),Notices_Count(NOTICE_TAB_REALM),Notices_Count(NOTICE_TAB_CHURCH),Notices_Count(NOTICE_TAB_PLAYERS),Notices_Count(NOTICE_TAB_EVENTS)));
		return 1;
	}

	if (!strcmp(action,"cancel",true))
	{
		Notices_Cancel(strval(rest));
		SendClientMessage(playerid,0xFFFFFFFF,"The notice comes down.");
		return 1;
	}

	if (!strcmp(action,"board",true))
	{
		SetTimerEx("Notices_BoardDeferred",0,false,"d",playerid);
		return 1;
	}

	new E_NOTICE_TAB:tab = NOTICE_TAB_COUNT;

	if (!strcmp(action,"realm",true)) tab = NOTICE_TAB_REALM;
	else if (!strcmp(action,"church",true)) tab = NOTICE_TAB_CHURCH;
	else if (!strcmp(action,"events",true)) tab = NOTICE_TAB_EVENTS;

	new colon = strfind(rest,":");

	if (tab == NOTICE_TAB_COUNT || colon <= 0)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Write it as: /notice realm The new tax: Every house pays two groschen at Martinmas.");
		return 1;
	}

	new heading[NOTICES_TITLE_LEN], text[NOTICES_TEXT_LEN], now = gettime();
	strmid(heading,rest,0,colon);
	strmid(text,rest,colon + 1,strlen(rest));

	while (text[0] == ' ')
	{
		strdel(text,0,1);
	}

	Notices_Post(tab,Character_GetId(playerid),heading,text,now,now + NOTICES_NEWS_DAYS * NOTICES_DAY_SECONDS);
	SendClientMessage(playerid,0xFFFFFFFF,"Pinned to every board. The crier calls it next.");
	return 1;
}
