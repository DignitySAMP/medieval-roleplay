CMD<ADMIN_LEVEL_NONE>:g(cmdid, playerid, params[])
{
	new group = Groups_GetChatGroup(playerid);

	if (group == GROUP_INVALID)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You belong to no group.");
		return 1;
	}

	if (isnull(params))
	{
		new name[GROUPS_NAME_LEN];
		Groups_GetName(group,name);
		Command_Usage(playerid,cmdid,sprintf("<text> (to %s; choose another in your group's panel)",name));
		return 1;
	}

	Groups_Word(playerid,group,params);
	return 1;
}
