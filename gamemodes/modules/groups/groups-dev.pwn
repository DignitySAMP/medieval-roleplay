CMD<ADMIN_LEVEL_ADMIN>:group(cmdid, playerid, params[])
{
	#pragma unused cmdid
	yield 1;

	new action[12], rest[64];

	if (sscanf(params,"s[12]S()[64]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/group list | info <id> | settings <id> | review <id> | create <player> <kind 0-4> <name> | add <id> <player> [rank] | remove <id> <player> | disband <id> | piece <masterpiece id> pass|fail | contract <id> fulfilled|released | pose x y z rx ry rz");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		for (new group = 0;group < GROUPS_MAX;group++)
		{
			if (Groups_IsValid(group))
			{
				new name[GROUPS_NAME_LEN];
				Groups_GetName(group,name);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d: %s (%s), %d sworn, features %d%s",Groups_GetId(group),name,g_GroupKindNames[Groups_GetKind(group)],Groups_GetMemberCount(group),Groups_GetFeatures(group),Groups_IsReviewed(group) ? ("") : (", not reviewed")));
			}
		}

		return 1;
	}

	if (!strcmp(action,"pose",true))
	{
		new Float:pose[9] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0};

		if (sscanf(rest,"ffffff",pose[0],pose[1],pose[2],pose[3],pose[4],pose[5]))
		{
			Groups_GetLiveryPose(pose);
			SendClientMessage(playerid,0xFFFFFFFF,sprintf("Tabard pose: %.3f %.3f %.3f %.1f %.1f %.1f",pose[0],pose[1],pose[2],pose[3],pose[4],pose[5]));
			return 1;
		}

		Groups_SetLiveryPose(pose);
		SendClientMessage(playerid,0xFFFFFFFF,"Tabard pose set for everyone wearing a livery.");
		return 1;
	}

	if (!strcmp(action,"create",true))
	{
		new target, kind, name[GROUPS_NAME_LEN];

		if (Account_GetAdminLevel(playerid) < ADMIN_LEVEL_MANAGER || sscanf(rest,"ris[32]",target,kind,name) || kind < 0 || kind > GROUP_KIND_ORDER || !Groups_IsGoodName(name))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Manager: /group create <player> <kind 0 guild, 1 household, 2 band, 3 outlaws, 4 order> <name>");
			return 1;
		}

		new group = await Groups_Create(kind,name,Character_GetId(target),kind == GROUP_KIND_GUILD ? 0 : -1);

		if (group == GROUP_INVALID)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Couldn't create it (name taken or no room).");
			return 1;
		}

		await Groups_AddMember(group,Character_GetId(target),0);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Created group %d.",Groups_GetId(group)));
		return 1;
	}

	if (!strcmp(action,"piece",true))
	{
		new id, verdict[8];

		if (sscanf(rest,"is[8]",id,verdict))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"/group piece <masterpiece id> pass|fail");
			return 1;
		}

		await mysql_aquery_s(g_Mysql,str_format("SELECT group_id FROM group_masterpieces WHERE id = %d",id));
		new groupId = 0;

		if (cache_num_rows() > 0)
		{
			cache_get_value_name_int(0,"group_id",groupId);
		}

		new group = Groups_FindById(groupId), bool:passes = !strcmp(verdict,"pass",true);

		if (group == GROUP_INVALID)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No such masterpiece.");
			return 1;
		}

		new verdictState = await Groups_JudgePiece(INVALID_PLAYER_ID,group,id,passes);
		SendClientMessage(playerid,0xFFFFFFFF,verdictState == GROUP_PIECE_PASSED ? ("Passed by the staff.") : (verdictState == GROUP_PIECE_FAILED ? ("Failed by the staff; the piece goes back to its maker.") : ("It isn't waiting for judgement.")));
		return 1;
	}

	if (!strcmp(action,"contract",true))
	{
		new id, verdict[12];

		if (sscanf(rest,"is[12]",id,verdict))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"/group contract <id> fulfilled|released");
			return 1;
		}

		Groups_SetContractState(id,!strcmp(verdict,"fulfilled",true) ? GROUP_CONTRACT_FULFILLED : GROUP_CONTRACT_CANCELLED);
		SendClientMessage(playerid,0xFFFFFFFF,"The contract is closed.");
		return 1;
	}

	new id, group;

	if (sscanf(rest,"i",id) || (group = Groups_FindById(id)) == GROUP_INVALID)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No group with that id: /group list.");
		return 1;
	}

	if (!strcmp(action,"info",true))
	{
		new name[GROUPS_NAME_LEN], minStars, floorPercent, ceilingPercent;
		Groups_GetName(group,name);
		Groups_GetRules(group,minStars,floorPercent,ceilingPercent);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: %s, %d/%d sworn, %d on duty, treasury %d pf, hall %d, hideout %d, chartered %d, trade %d (%d stars, %d-%d%%), livery %s.",name,g_GroupKindNames[Groups_GetKind(group)],Groups_GetMemberCount(group),Groups_GetCap(group),Groups_CountOnDuty(group),Groups_TreasuryWorth(group),Groups_HasHall(group),Groups_GetHideout(group),Groups_IsChartered(group),Groups_GetTrade(group),minStars,floorPercent,ceilingPercent,g_GroupLiveryNames[Groups_GetLivery(group)]));
		return 1;
	}

	if (!strcmp(action,"settings",true))
	{
		Groups_OpenSettings(playerid,group);
		return 1;
	}

	if (!strcmp(action,"review",true))
	{
		Groups_SetReviewed(group,!Groups_IsReviewed(group));
		SendClientMessage(playerid,0xFFFFFFFF,Groups_IsReviewed(group) ? ("Reviewed: it may grow to its cap.") : ("Review withdrawn: eight members at most."));
		return 1;
	}

	if (!strcmp(action,"disband",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Account_GetAdminLevel(playerid) >= ADMIN_LEVEL_MANAGER && Groups_Disband(group) ? ("Disbanded.") : ("Empty its stores first (managers only)."));
		return 1;
	}

	new target, rank = -1;

	if (sscanf(rest,"{i}rI(-1)",target,rank) || !IsPlayerConnected(target))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/group add|remove <id> <player> [rank]");
		return 1;
	}

	if (!strcmp(action,"add",true))
	{
		new added = await Groups_AddMember(group,Character_GetId(target),rank == -1 ? Groups_CountRanks(group) - 1 : rank);
		SendClientMessage(playerid,0xFFFFFFFF,added ? ("Added.") : ("Already on the roll."));
		return 1;
	}

	if (!strcmp(action,"remove",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Groups_RemoveMember(group,Character_GetId(target)) ? ("Removed.") : ("Not on the roll."));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Unknown: /group for the list.");
	return 1;
}
