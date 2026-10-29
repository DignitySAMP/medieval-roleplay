CMD<ADMIN_LEVEL_TRIAL>:emote(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new emote;

	if (sscanf(params,"i",emote))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("/emote <0-%d> plays an emote by number (Walk + N opens the panel). Playing: %d.",Emotes_Count() - 1,Emotes_GetPlaying(playerid)));
		return 1;
	}

	if (!Emotes_Play(playerid,emote))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Can't play that here.");
	}

	return 1;
}
