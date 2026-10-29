CMD<ADMIN_LEVEL_TRIAL>:dialogue(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[128];

	if (sscanf(params,"s[12]S()[128]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/dialogue status | reload | staffonly [0|1] | memory | camera [classic|fixed|scan]");
		return 1;
	}

	if (!strcmp(action,"status",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Dialogue: %s, %s, %s. Sent %d, model %d, canned %d, failed %d.",Dialogue_UsesModel(playerid) ? ("the model answers you") : ("canned lines for you"),s_DialogueEnabledText(),s_DialogueStaffOnlyText(),Dialogue_GetStat(DIALOGUE_STAT_SENT),Dialogue_GetStat(DIALOGUE_STAT_MODEL),Dialogue_GetStat(DIALOGUE_STAT_CANNED),Dialogue_GetStat(DIALOGUE_STAT_FAILED)));
		SendClientMessage(playerid,0xD8CCB2FF,sprintf("Last problem: %s",Dialogue_LastError()));
		return 1;
	}

	if (!strcmp(action,"reload",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Dialogue_LoadConfig() ? ("Read scriptfiles/dialogue.ini again.") : ("There's no scriptfiles/dialogue.ini: canned lines only."));
		return 1;
	}

	if (!strcmp(action,"staffonly",true))
	{
		Dialogue_SetStaffOnly(strval(rest) != 0);
		SendClientMessage(playerid,0xFFFFFFFF,strval(rest) != 0 ? ("Only staff get the model now.") : ("Everyone gets the model now."));
		return 1;
	}

	if (!strcmp(action,"memory",true))
	{
		new memory[DIALOGUE_MEMORY_LEN];
		Dialogue_GetMemory(playerid,memory);
		SendClientMessage(playerid,0xFFFFFFFF,memory[0] != EOS ? memory : ("They remember nothing about you."));
		return 1;
	}

	if (!strcmp(action,"camera",true))
	{
		if (!strcmp(rest,"classic",true) || !strcmp(rest,"fixed",true))
		{
			Dialogue_SetCameraClassic(!strcmp(rest,"classic",true));
			SendClientMessage(playerid,0xFFFFFFFF,Dialogue_IsCameraClassic() ? ("Talk camera: the old fixed spot in front of them, no wall or player checks.") : ("Talk camera: checked against walls and other players."));
			return 1;
		}

		if (!strcmp(rest,"scan",true))
		{
			Dialogue_CameraScan(playerid);
			return 1;
		}

		SendClientMessage(playerid,0xFFFFFFFF,Dialogue_IsCameraClassic() ? ("Talk camera: classic. /dialogue camera fixed | scan") : ("Talk camera: checked. /dialogue camera classic | scan"));
		return 1;
	}

	return 1;
}
