enum E_BUILD_TURN
{
	E_BUILD_TURN_PROJECT,
	E_BUILD_TURN_INDEX,
	E_BUILD_TURN_STAGE,
	E_BUILD_TURN_STARTED,
	E_BUILD_TURN_BAR,
	E_BUILD_TURN_TIMER,
	E_BUILD_TURN_BUILDING,
}

static s_BuildTurn[MAX_PLAYERS][E_BUILD_TURN];
static s_BuildPrompt[MAX_PLAYERS] = {-1, ...};
static s_BuildInfobox[MAX_PLAYERS];

forward bool:Build_BeginTurn(playerid,project,index,reason[],size = sizeof(reason));

stock bool:Build_IsWorking(playerid)
{
	return Util_IsValidPlayer(playerid) && s_BuildTurn[playerid][E_BUILD_TURN_PROJECT] != -1;
}

stock Build_FindSite(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		return -1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		if (VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],0.0) <= BUILD_SITE_REACH && VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][1],0.0) > BUILD_SITE_DOOR_GAP && floatabs(z - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2]) < 6.0)
		{
			return building;
		}
	}

	return -1;
}

stock bool:Build_MayCommission(playerid,building)
{
	new house = g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_HOUSE];
	return Realm_IsRuler(playerid) || Realm_IsDuke(playerid) || Clergy_GetRank(playerid) >= CLERGY_PRIEST || (house != -1 && Houses_HoldsRoomIn(playerid,house));
}

static Build_ClearPrompt(playerid)
{
	if (s_BuildInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_BuildInfobox[playerid]);
	}

	s_BuildPrompt[playerid] = -1;
	s_BuildInfobox[playerid] = 0;
}

static bool:Build_PromptText(playerid,building,text[],size = sizeof(text))
{
	if (Fire_IsBurning(building) || Fire_IsGutted(building) || Light_HasTorchLit(playerid))
	{
		return false;
	}

	if (Build_FindProject(building) != -1)
	{
		strcopy(text,"Press ~y~Y~w~ for the building site.",size);
		return true;
	}

	if (Build_IsDamaged(building))
	{
		strcopy(text,"Press ~y~Y~w~ to see to the repairs.",size);
		return true;
	}

	if (!Build_IsTiled(building) && Build_MayCommission(playerid,building))
	{
		strcopy(text,"Press ~y~Y~w~ to see to the building.",size);
		return true;
	}

	return false;
}

static Build_PostNotice(playerid,building,kind)
{
	new name[28], title[48], text[144], needs[96], project = Build_FindProject(building), now = gettime();
	Fire_GetName(building,name);
	Build_DescribeNeeds(project,needs);
	format(title,sizeof(title),"Work wanted: %s",g_BuildKindNames[kind]);
	format(text,sizeof(text),"Building work at %s. Bring %s to the stockpile there and lend a hand.",name,needs);
	new E_NOTICE_TAB:tab = NOTICE_TAB_PLAYERS;

	if (Realm_IsRuler(playerid) || Realm_IsDuke(playerid))
	{
		tab = NOTICE_TAB_REALM;
	}
	else if (Clergy_GetRank(playerid) >= CLERGY_PRIEST)
	{
		tab = NOTICE_TAB_CHURCH;
	}

	Notices_Post(tab,Character_GetId(playerid),title,text,now,now + BUILD_NOTICE_DAYS * 86400);
}

stock Build_Commission(playerid,building,kind)
{
	new project = await Build_Start(building,kind,Character_GetId(playerid));

	if (project == -1 || !IsPlayerConnected(playerid))
	{
		Gui_Notify(playerid,"The work can't be started here now.");
		return;
	}

	new needs[96];
	Build_DescribeNeeds(project,needs);
	Build_PostNotice(playerid,building,kind);
	Gui_Notify(playerid,sprintf("The work is set out and posted on the boards. It needs %s.",needs));
}

stock Build_OpenSite(playerid,building)
{
	for (;;)
	{
		new project = Build_FindProject(building), epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[28], word[24], line[160], rows = 0, picks[6], labels[6][44];
		Fire_GetName(building,title);
		title[0] = toupper(title[0]);
		Build_ConditionWord(building,word);
		format(line,sizeof(line),"It's %s (%d in a hundred). Roof care: %s.",word,Build_GetCondition(building),Build_IsTiled(building) ? ("done") : ("needed"));

		if (project != -1 && !Build_IsFinished(project))
		{
			new done, total, needs[96];
			Build_GetProgress(project,done,total);
			Build_DescribeNeeds(project,needs);
			format(line,sizeof(line),"%s~n~%s: %d of %d turns done. Still wanted: %s.",line,g_BuildKindNames[Build_GetKind(project)],done,total,needs);
			picks[rows] = 1;
			labels[rows++] = "Bring materials to the stockpile";
			picks[rows] = 2;
			labels[rows++] = "Do a turn of work";
			picks[rows] = 3;
			labels[rows++] = "Who has worked here";

			if (Build_GetCommissioner(project) == Character_GetId(playerid) || Realm_IsRuler(playerid))
			{
				picks[rows] = 4;
				labels[rows++] = "Stop the work";
			}
		}
		else if (project != -1)
		{
			strcat(line,"~n~The work is done. Something is left in the stockpile.");
			picks[rows] = 1;
			labels[rows++] = "Take what's left over";
		}
		else
		{
			if (Build_IsDamaged(building))
			{
				picks[rows] = 5;
				labels[rows++] = "Set out the repairs";
			}

			if (!Build_IsTiled(building) && Build_MayCommission(playerid,building))
			{
				picks[rows] = 6;
				labels[rows++] = "Tend the roof";
			}
		}

		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,BUILD_PANEL_WIDTH + 40.0,KIT_ROW * 3.0 + float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new i = 0;i < rows;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(3 + i),width,labels[i],picks[i],picks[i] == 4 ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * float(3 + rows) + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || Build_FindSite(playerid) != building)
		{
			return;
		}

		switch (pick)
		{
			case 1:
			{
				ContainerGui_Show(playerid,Build_GetStockpile(project));
				return;
			}
			case 2:
			{
				Build_PickTurn(playerid,project);
				return;
			}
			case 3: Build_ShowLabour(playerid,project);
			case 4: Build_Abandon(project);
			case 5:
			{
				Build_Commission(playerid,building,BUILD_KIND_REPAIR);
				return;
			}
			case 6:
			{
				Build_Commission(playerid,building,BUILD_KIND_TILE_ROOF);
				return;
			}
		}
	}
}

stock Build_ShowLabour(playerid,project)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT CONCAT(c.name, ' ', c.surname) AS who, l.scenes FROM project_labour l LEFT JOIN characters c ON c.id = l.character_id WHERE l.project_id = %d ORDER BY l.scenes DESC LIMIT 8",Build_GetRow(project)));

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	new rows = cache_num_rows(), lines[8][64];

	for (new r = 0;r < rows && r < 8;r++)
	{
		new who[44], scenes;
		cache_get_value_name(r,"who",who);
		cache_get_value_name_int(r,"scenes",scenes);
		format(lines[r],64,"%s: %d %s",who,scenes,scenes == 1 ? ("turn") : ("turns"));
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, shown = max(min(rows,8),1);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"The workers");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,BUILD_PANEL_WIDTH,float(shown) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"The workers",x,y,width);

	if (rows == 0)
	{
		Kit_AddText(playerid,x,y,"Nobody has lifted a hand yet.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	for (new r = 0;r < rows && r < 8;r++)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * float(r),lines[r],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(shown) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

stock Build_PickTurn(playerid,project)
{
	new count = Build_GetStageCount(project), epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"A turn of work");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,BUILD_PANEL_WIDTH + 80.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"A turn of work",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new stage, need, done, detail[64], uses[48];
		Build_GetStage(project,i,stage,need,done);
		Build_DescribeTurn(stage,uses);

		if (done >= need)
		{
			format(detail,sizeof(detail),"done");
		}
		else
		{
			format(detail,sizeof(detail),"%d/%d, %s",done,need,uses);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_NAME],i,done >= need ? KIT_COLOUR_MUTED : (Build_StageReady(project,i) ? KIT_COLOUR_TEXT : KIT_COLOUR_BAD),detail,KIT_COLOUR_MUTED,0.55);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return;
	}

	new reason[96];

	if (!Build_BeginTurn(playerid,project,pick,reason))
	{
		Gui_Notify(playerid,reason);
	}
}

stock Build_DescribeTurn(stage,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	for (new m = 0;m < 2;m++)
	{
		new item = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ITEM][m], name[ITEM_NAME_LEN];

		if (item != -1)
		{
			Item_GetName(Item_GetDefKind(item),item,name);
			format(dest,size,"%s%s%d %s",dest,dest[0] != EOS ? (" and ") : (""),g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_AMOUNT][m],name);
		}
	}

	new tool = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_TOOL];

	if (tool != -1)
	{
		new name[ITEM_NAME_LEN];
		Item_GetName(Item_GetDefKind(tool),tool,name);
		format(dest,size,"%s%s%s",dest,dest[0] != EOS ? (", with a ") : ("with a "),name);
	}

	if (dest[0] == EOS)
	{
		strcopy(dest,"bare hands",size);
	}
}

stock bool:Build_BeginTurn(playerid,project,index,reason[],size = sizeof(reason))
{
	new stage, need, done;
	Build_GetStage(project,index,stage,need,done);
	reason[0] = EOS;

	if (stage == -1 || done >= need || Build_IsFinished(project))
	{
		strcopy(reason,"That part is done.",size);
		return false;
	}

	if (Build_IsWorking(playerid))
	{
		strcopy(reason,"You're at work already.",size);
		return false;
	}

	new tool = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_TOOL];

	if (tool != -1 && Inventory_Count(playerid,Item_GetDefKind(tool),tool) <= 0)
	{
		new name[ITEM_NAME_LEN];
		Item_GetName(Item_GetDefKind(tool),tool,name);
		format(reason,size,"You need a %s for that.",name);
		return false;
	}

	if (Vitals_GetStamina(playerid) < BUILD_SCENE_STAMINA)
	{
		strcopy(reason,"You're too spent to work. Rest a while.",size);
		return false;
	}

	if (!Build_TakeMaterials(project,stage))
	{
		new uses[48];
		Build_DescribeTurn(stage,uses);
		format(reason,size,"The stockpile is short: a turn takes %s.",uses);
		return false;
	}

	s_BuildTurn[playerid][E_BUILD_TURN_PROJECT] = project;
	s_BuildTurn[playerid][E_BUILD_TURN_INDEX] = index;
	s_BuildTurn[playerid][E_BUILD_TURN_STAGE] = stage;
	s_BuildTurn[playerid][E_BUILD_TURN_STARTED] = GetTickCount();
	s_BuildTurn[playerid][E_BUILD_TURN_BUILDING] = Build_GetBuilding(project);
	s_BuildTurn[playerid][E_BUILD_TURN_BAR] = PBar_Create(playerid,270.0,372.0,100.0,2.0,0xC9B27CFF);
	PBar_SetValue(playerid,s_BuildTurn[playerid][E_BUILD_TURN_BAR],0.0,0xC9B27CFF);
	PBar_Show(playerid,s_BuildTurn[playerid][E_BUILD_TURN_BAR]);
	ApplyAnimation(playerid,g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ANIM_LIB],g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ANIM],4.1,true,false,false,false,0,SYNC_ALL);
	Chat_Annotate(playerid,g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ME]);
	s_BuildTurn[playerid][E_BUILD_TURN_TIMER] = SetTimerEx("Build_TurnTick",BUILD_SCENE_TICK_MS,true,"dd",playerid,Account_GetToken(playerid));
	return true;
}

stock Build_EndTurn(playerid,bool:isDone)
{
	if (!Build_IsWorking(playerid))
	{
		return;
	}

	new project = s_BuildTurn[playerid][E_BUILD_TURN_PROJECT], stage = s_BuildTurn[playerid][E_BUILD_TURN_STAGE], index = s_BuildTurn[playerid][E_BUILD_TURN_INDEX];
	KillTimer(s_BuildTurn[playerid][E_BUILD_TURN_TIMER]);

	if (s_BuildTurn[playerid][E_BUILD_TURN_BAR] != INVALID_PLAYER_BAR)
	{
		PBar_Destroy(playerid,s_BuildTurn[playerid][E_BUILD_TURN_BAR]);
	}

	s_BuildTurn[playerid][E_BUILD_TURN_PROJECT] = -1;
	s_BuildTurn[playerid][E_BUILD_TURN_BAR] = INVALID_PLAYER_BAR;

	if (IsPlayerConnected(playerid))
	{
		ClearAnimations(playerid);
	}

	if (!isDone)
	{
		if (Build_IsProject(project) && !Build_IsFinished(project))
		{
			Build_ReturnMaterials(project,stage);
		}

		return;
	}

	if (!Build_AddTurn(project,index,Character_GetId(playerid)))
	{
		Build_ReturnMaterials(project,stage);
		return;
	}

	new trade = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_TRADE];

	if (trade != -1)
	{
		Work_AddPractice(playerid,trade,BUILD_PRACTICE);
	}

	Vitals_DrainStamina(playerid,BUILD_SCENE_STAMINA);
	Fatigue_Add(playerid,BUILD_SCENE_FATIGUE);

	if (Build_IsFinished(project) || !Build_IsProject(project))
	{
		Gui_Notify(playerid,"That's the last of it: the work is done.");
		return;
	}

	new done, total;
	Build_GetProgress(project,done,total);
	Gui_Notify(playerid,sprintf("A turn done. %d of %d turns of the work are finished.",done,total));
}

forward Build_TurnTick(playerid,token);

public Build_TurnTick(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Build_IsWorking(playerid))
	{
		return 0;
	}

	new building = s_BuildTurn[playerid][E_BUILD_TURN_BUILDING], Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	if (VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],0.0) > BUILD_WORK_REACH || Fire_IsBurning(building) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Gui_Notify(playerid,"You leave the work unfinished; the materials go back on the stockpile.");
		Build_EndTurn(playerid,false);
		return 0;
	}

	new elapsed = GetTickCount() - s_BuildTurn[playerid][E_BUILD_TURN_STARTED];
	PBar_SetValue(playerid,s_BuildTurn[playerid][E_BUILD_TURN_BAR],float(min(elapsed,BUILD_SCENE_MS)) * 100.0 / float(BUILD_SCENE_MS),0xC9B27CFF);

	if (elapsed >= BUILD_SCENE_MS)
	{
		Build_EndTurn(playerid,true);
	}

	return 1;
}

Timer_Declare(Build_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		new building = Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Build_IsWorking(playerid) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT ? Build_FindSite(playerid) : -1, text[64];

		if (building == -1 || !Build_PromptText(playerid,building,text) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
		{
			Build_ClearPrompt(playerid);
			continue;
		}

		if (building == s_BuildPrompt[playerid] && Infobox_IsShown(playerid,s_BuildInfobox[playerid]))
		{
			continue;
		}

		new title[28];
		Fire_GetName(building,title);
		title[0] = toupper(title[0]);
		s_BuildPrompt[playerid] = building;
		s_BuildInfobox[playerid] = Infobox_ShowPrompt(playerid,s_BuildInfobox[playerid],title,text,3);
	}

	return 1;
}

forward bool:Build_PromptContext(playerid);

public bool:Build_PromptContext(playerid)
{
	return s_BuildPrompt[playerid] != -1;
}

forward Build_OpenSiteDeferred(playerid,building);

public Build_OpenSiteDeferred(playerid,building)
{
	if (IsPlayerConnected(playerid))
	{
		Build_OpenSite(playerid,building);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_BuildTurn[playerid][E_BUILD_TURN_PROJECT] = -1;
	s_BuildTurn[playerid][E_BUILD_TURN_BAR] = INVALID_PLAYER_BAR;
	s_BuildPrompt[playerid] = -1;
	s_BuildInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason
	Build_EndTurn(playerid,false);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || (newkeys & KEY_WALK) || s_BuildPrompt[playerid] == -1 || Infobox_IsPromptBlocked(playerid,s_BuildInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new building = s_BuildPrompt[playerid];
	Build_ClearPrompt(playerid);
	SetTimerEx("Build_OpenSiteDeferred",0,false,"dd",playerid,building);
}
