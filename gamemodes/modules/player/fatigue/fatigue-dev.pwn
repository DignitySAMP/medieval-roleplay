CMD<ADMIN_LEVEL_TRIAL>:fatigue(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new target = playerid, Float:value;

	if (sscanf(params,"f",value))
	{
		new line[64];
		Fatigue_Describe(target,line);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Fatigue %.1f (%s). Stamina cap %.0f, work bands %d%%. /fatigue <0-100> sets it.",Fatigue_Get(target),line,Vitals_GetStaminaCap(target),Work_GetBandScale(target)));
		return 1;
	}

	Fatigue_Set(target,value);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Fatigue set to %.1f.",Fatigue_Get(target)));
	return 1;
}
