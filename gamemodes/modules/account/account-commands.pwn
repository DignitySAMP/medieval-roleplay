CMD<ADMIN_LEVEL_MANAGER>:loremaster(cmdid, playerid, params[])
{
	new targetid;

	if (sscanf(params,"u",targetid) || !IsPlayerConnected(targetid) || Account_GetId(targetid) <= 0)
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	new bool:isLoremaster = !Account_HasLoremasterRank(targetid);
	Account_SetLoremaster(targetid,isLoremaster);
	SendClientMessage(playerid,0xFFFFFFFF,isLoremaster ? ("They're a loremaster now. They can give out culture unlock points with /cultureunlock.") : ("They're no longer a loremaster."));
	return 1;
}

CMD<ADMIN_LEVEL_MANAGER>:quizreset(cmdid, playerid, params[])
{
	new name[ACCOUNT_USERNAME_MAX + 1];

	if (sscanf(params,"s[21]",name) || !Account_ValidateUsername(name))
	{
		Command_Usage(playerid,cmdid,"<name>");
		return 1;
	}

	SetTimerEx("Account_QuizResetDeferred",0,false,"ds",playerid,name);
	return 1;
}

forward Account_QuizResetDeferred(playerid,const name[]);

public Account_QuizResetDeferred(playerid,const name[])
{
	Account_QuizReset(playerid,name);
	return 1;
}

static Account_QuizReset(playerid,const target[])
{
	yield 1;

	new name[ACCOUNT_USERNAME_MAX + 1], addresses[8][17], count = 0;
	strcopy(name,target);
	await mysql_aquery_s(g_Mysql,str_format("SELECT DISTINCT ip FROM account_quiz_attempts WHERE name = '%e' LIMIT %d",name,sizeof(addresses)));

	for (new row = 0, rows = cache_num_rows();row < rows && count < sizeof(addresses);row++)
	{
		cache_get_value_name(row,"ip",addresses[count++],17);
	}

	await Account_QuizClear(name);

	for (new i = 0;i < count;i++)
	{
		pawn_call_public("Account_OnQuizReset","dss",playerid,name,addresses[i]);
	}

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	if (count == 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,sprintf("Nobody called %s has taken the roleplay quiz.",name));
		return;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s can take the roleplay quiz again. Their failed tries are cleared and any quiz ban on their address is lifted.",name));
}
