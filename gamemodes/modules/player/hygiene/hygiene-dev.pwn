CMD<ADMIN_LEVEL_TRIAL>:dirt(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new value;

	if (sscanf(params,"i",value))
	{
		new text[64];
		Hygiene_Describe(playerid,text);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Your dirt is %d of %d: %s. /dirt [0-100] sets it.",Hygiene_GetDirt(playerid),HYGIENE_MAX,text));
		return 1;
	}

	Hygiene_SetDirt(playerid,value);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Your dirt is now %d (%s).",Hygiene_GetDirt(playerid),g_HygieneLevelNames[Hygiene_GetLevel(playerid)]));
	return 1;
}
