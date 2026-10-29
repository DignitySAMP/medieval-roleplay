CMD<ADMIN_LEVEL_ADMIN>:build(cmdid, playerid, params[])
{
	#pragma unused cmdid
	yield 1;

	new action[12], which[16], value;

	if (sscanf(params,"s[12]S(near)[16]I(0)",action,which,value))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/build list | condition <key or near> <0-100> | tile|thatch <key or near> | repair|tileroof <key or near> | turn <key or near> | finish|stop <key or near> | decay <amount>");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new damaged = 0, tiled = 0;

		for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
		{
			damaged += Build_IsDamaged(building) ? 1 : 0;
			tiled += Build_IsTiled(building) ? 1 : 0;
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d buildings: %d need repair, %d roofs tended, %d works under way.",FIRE_SEED_BUILDINGS,damaged,tiled,Build_CountProjects()));
		return 1;
	}

	if (!strcmp(action,"decay",true))
	{
		Build_Decay(max(value,1));
		SendClientMessage(playerid,0xFFFFFFFF,"Every building weathers.");
		return 1;
	}

	new building = !strcmp(which,"near",true) ? Fire_FindNearPlayer(playerid,20.0) : Fire_FindByKey(which);

	if (building == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No building there: stand by one or give its key.");
		return 1;
	}

	new project = Build_FindProject(building);

	if (!strcmp(action,"condition",true))
	{
		Build_SetCondition(building,value);
	}
	else if (!strcmp(action,"tile",true) || !strcmp(action,"thatch",true))
	{
		Build_SetTiled(building,!strcmp(action,"tile",true));
	}
	else if (!strcmp(action,"repair",true) || !strcmp(action,"tileroof",true))
	{
		await Build_Start(building,!strcmp(action,"repair",true) ? BUILD_KIND_REPAIR : BUILD_KIND_TILE_ROOF,Character_GetId(playerid));
	}
	else if (!strcmp(action,"turn",true) && project != -1)
	{
		for (new i = 0, count = Build_GetStageCount(project);i < count;i++)
		{
			new stage, need, done;
			Build_GetStage(project,i,stage,need,done);

			if (done < need)
			{
				Build_AddTurn(project,i,Character_GetId(playerid));
				break;
			}
		}
	}
	else if (!strcmp(action,"finish",true) && project != -1)
	{
		Build_Finish(project);
	}
	else if (!strcmp(action,"stop",true) && project != -1)
	{
		Build_Abandon(project);
	}

	new name[28], word[24], done, total;
	Fire_GetName(building,name);
	Build_ConditionWord(building,word);
	project = Build_FindProject(building);
	Build_GetProgress(project,done,total);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: %s (%d), roof care %s, work %s %d/%d.",name,word,Build_GetCondition(building),Build_IsTiled(building) ? ("done") : ("needed"),project == -1 ? ("none") : g_BuildKindNames[Build_GetKind(project)],done,total));
	return 1;
}
