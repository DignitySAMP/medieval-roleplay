#define GROUPS_PROMPT_HIDEOUT (100)
#define GROUPS_PROMPT_CHURCH (200)

static s_GroupsPrompt[MAX_PLAYERS] = {-1, ...};
static s_GroupsInfobox[MAX_PLAYERS];

forward Task:Groups_PostNotice(group,author,const text[],bool:isPublic);

stock bool:Groups_AskText(playerid,const title[],const prompt[],dest[],size)
{
	new token = Account_GetToken(playerid), response[DIALOG_RESPONSE], body[256];
	format(body,sizeof(body),GUI_TEXT "%s",prompt);
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,title,body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
	{
		return false;
	}

	strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);
	return true;
}

stock bool:Groups_CanSetHall(playerid,group)
{
	if (!Groups_HasFeature(group,GROUP_FEATURE_HALL) || !Groups_HasPerm(playerid,group,GROUP_PERM_HALL))
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new other = 0;other < GROUPS_MAX;other++)
	{
		new Float:hx, Float:hy, Float:hz, Float:ha, world, interior;

		if (other != group && Groups_GetHall(other,hx,hy,hz,ha,world,interior) && world == GetPlayerVirtualWorld(playerid) && VectorSize(hx - x,hy - y,hz - z) < 15.0)
		{
			return false;
		}
	}

	return true;
}

stock Groups_GetPromptBox(playerid)
{
	return s_GroupsPrompt[playerid] == -1 ? 0 : s_GroupsInfobox[playerid];
}

stock Groups_ForgetHideoutPrompt(hideout)
{
	foreach (new playerid : Player)
	{
		if (s_GroupsPrompt[playerid] == GROUPS_PROMPT_HIDEOUT + hideout)
		{
			s_GroupsPrompt[playerid] = -1;
		}
	}
}

static Groups_ClearPrompt(playerid)
{
	if (s_GroupsInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_GroupsInfobox[playerid]);
	}

	s_GroupsPrompt[playerid] = -1;
	s_GroupsInfobox[playerid] = 0;
}

static Groups_PromptAt(playerid)
{
	new world = GetPlayerVirtualWorld(playerid);

	for (new group = 0;group < GROUPS_MAX;group++)
	{
		new Float:x, Float:y, Float:z, Float:a, hallWorld, interior;

		if (Groups_HasFeature(group,GROUP_FEATURE_HALL) && Groups_GetHall(group,x,y,z,a,hallWorld,interior) && hallWorld == world && IsPlayerInRangeOfPoint(playerid,GROUPS_HALL_REACH,x,y,z))
		{
			return group;
		}
	}

	for (new hideout = 0;hideout < GROUPS_SEED_HIDEOUTS && world == 0;hideout++)
	{
		if (IsPlayerInRangeOfPoint(playerid,GROUPS_HIDEOUT_REACH,g_GroupsHideouts[hideout][0],g_GroupsHideouts[hideout][1],g_GroupsHideouts[hideout][2] + 1.0))
		{
			return GROUPS_PROMPT_HIDEOUT + hideout;
		}
	}

	if (world == 0 && IsPlayerInRangeOfPoint(playerid,GROUPS_HALL_REACH,g_GroupsChurchDoor[0],g_GroupsChurchDoor[1],g_GroupsChurchDoor[2] + 1.0) && (Clergy_GetRank(playerid) >= CLERGY_PRIOR || Groups_FindMineOfKind(playerid,GROUP_KIND_ORDER) != GROUP_INVALID))
	{
		return GROUPS_PROMPT_CHURCH;
	}

	return -1;
}

static Groups_PromptText(playerid,prompt,title[],text[],titleSize = sizeof(title),textSize = sizeof(text))
{
	if (prompt >= GROUPS_PROMPT_CHURCH)
	{
		strcopy(title,"The church door",titleSize);
		strcopy(text,Groups_FindMineOfKind(playerid,GROUP_KIND_ORDER) != GROUP_INVALID ? ("Press ~y~Y~w~ for your order.") : ("Press ~y~Y~w~ to found a religious order."),textSize);
		return;
	}

	if (prompt >= GROUPS_PROMPT_HIDEOUT)
	{
		new holder = Groups_HideoutHolder(prompt - GROUPS_PROMPT_HIDEOUT);
		strcopy(title,holder != GROUP_INVALID ? ("A camp fire") : ("A cold fire pit"),titleSize);

		if (holder != GROUP_INVALID && Groups_IsMember(playerid,holder))
		{
			strcopy(text,"Press ~y~Y~w~ for your band's camp.",textSize);
		}
		else if (holder != GROUP_INVALID)
		{
			strcopy(text,"Someone keeps this fire going. Another band camps here.",textSize);
		}
		else
		{
			strcopy(text,"Press ~y~Y~w~ to make camp here with a band of your own.",textSize);
		}

		return;
	}

	Groups_GetName(prompt,title,titleSize);
	strcopy(text,Groups_IsMember(playerid,prompt) ? ("Press ~y~Y~w~ for the hall.") : ("Press ~y~Y~w~ to read the hall's board."),textSize);
}

#pragma warning push
#pragma warning disable 204
async Task:Groups_PostNotice(group,author,const text[],bool:isPublic)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO group_notices (group_id, author_character_id, text, public, posted_at) VALUES (%d, %d, '%e', %d, %d)",Groups_GetId(group),author,text,_:isPublic,gettime()));
	return async cache_insert_id();
}
#pragma warning pop

stock Groups_OpenBoard(playerid,group)
{
	for (;;)
	{
		new bool:member = Groups_IsMember(playerid,group), bool:canPost = Groups_HasPerm(playerid,group,GROUP_PERM_BOARD) && Groups_HasFeature(group,GROUP_FEATURE_BOARD);
		await mysql_aquery_s(g_Mysql,str_format("SELECT n.id, n.text, n.public, n.posted_at, n.author_character_id, CONCAT(c.name, ' ', c.surname) AS author FROM group_notices n LEFT JOIN characters c ON c.id = n.author_character_id WHERE n.group_id = %d %s ORDER BY n.id DESC LIMIT %d",Groups_GetId(group),member ? ("") : ("AND n.public = 1"),GROUPS_BOARD_SHOWN));

		if (!IsPlayerConnected(playerid))
		{
			return;
		}

		new rows = cache_num_rows(), ids[GROUPS_BOARD_SHOWN], authors[GROUPS_BOARD_SHOWN], texts[GROUPS_BOARD_SHOWN][GROUPS_NOTICE_LEN], names[GROUPS_BOARD_SHOWN][44], publics[GROUPS_BOARD_SHOWN];

		for (new r = 0;r < rows && r < GROUPS_BOARD_SHOWN;r++)
		{
			cache_get_value_name_int(r,"id",ids[r]);
			cache_get_value_name(r,"text",texts[r]);
			cache_get_value_name_int(r,"public",publics[r]);
			cache_get_value_name_int(r,"author_character_id",authors[r]);
			cache_get_value_name(r,"author",names[r]);
		}

		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[48], extra = canPost ? 2 : 0;
		Groups_GetName(group,title);
		strcat(title,"'s board");
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 60.0,float(max(rows,1) * 2 + extra) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		if (rows == 0)
		{
			Kit_AddText(playerid,x,y,"Nothing is pinned up.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		for (new r = 0;r < rows && r < GROUPS_BOARD_SHOWN;r++)
		{
			new line[64];
			format(line,sizeof(line),"%s%s",names[r][0] != EOS ? names[r] : ("Unsigned"),publics[r] ? (", for all to read") : (""));
			Kit_AddText(playerid,x,y + KIT_ROW * float(r * 2),line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

			if (canPost || authors[r] == Character_GetId(playerid))
			{
				Kit_AddChoice(playerid,x,y + KIT_ROW * float(r * 2 + 1),width,texts[r],1000 + r,KIT_COLOUR_TEXT,"take down",KIT_COLOUR_BAD,0.2);
			}
			else
			{
				Kit_AddText(playerid,x,y + KIT_ROW * float(r * 2 + 1),texts[r],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
			}
		}

		new Float:footer = y + float(max(rows,1) * 2) * KIT_ROW;

		if (canPost)
		{
			Kit_AddChoice(playerid,x,footer,width,"Pin up a notice for the members",1,KIT_COLOUR_GOOD);
			Kit_AddChoice(playerid,x,footer + KIT_ROW,width,"Pin up a notice for all to read",2,KIT_COLOUR_GOOD);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,footer + float(extra) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0)
		{
			return;
		}

		if (pick >= 1000 && pick < 1000 + rows)
		{
			mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_notices WHERE id = %d",ids[pick - 1000]));
			continue;
		}

		new text[GROUPS_NOTICE_LEN];

		if ((pick == 1 || pick == 2) && Groups_AskText(playerid,"A notice","Write the notice as it will hang on the board.",text,sizeof(text)) && strlen(text) >= 4)
		{
			await Groups_PostNotice(group,Character_GetId(playerid),text,pick == 2);
		}
	}
}

stock Groups_OpenHall(playerid,group)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[GROUPS_NAME_LEN], row = 0, picks[10], labels[10][40];
		Groups_GetName(group,title);

		if (Groups_HasPerm(playerid,group,GROUP_PERM_STORE))
		{
			picks[row] = 1;
			labels[row++] = "The storehouse";
		}

		if (Groups_HasPerm(playerid,group,GROUP_PERM_TREASURY))
		{
			picks[row] = 2;
			labels[row++] = "The treasury";
		}

		if (Groups_HasFeature(group,GROUP_FEATURE_BOARD))
		{
			picks[row] = 3;
			labels[row++] = "The board";
		}

		if (Groups_HasFeature(group,GROUP_FEATURE_DUTY))
		{
			picks[row] = 4;
			labels[row++] = Groups_IsOnDuty(playerid,group) ? ("Go off duty") : ("Go on duty");
		}

		if (Groups_HasFeature(group,GROUP_FEATURE_SPAWN) && Groups_HasHall(group) && !Groups_IsSystem(group))
		{
			picks[row] = 5;
			labels[row++] = Groups_WantsHallSpawn(playerid,group) ? ("Stop waking here") : ("Wake here when you come back");
		}

		picks[row] = 6;
		labels[row++] = "The group";

		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(row) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		for (new i = 0;i < row;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i],KIT_COLOUR_TEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(row) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Groups_IsMember(playerid,group))
		{
			return;
		}

		switch (pick)
		{
			case 1:
			{
				ContainerGui_Show(playerid,Groups_GetStore(group));
				return;
			}
			case 2:
			{
				ContainerGui_Show(playerid,Groups_GetTreasury(group));
				return;
			}
			case 3: Groups_OpenBoard(playerid,group);
			case 4: Groups_SetDuty(playerid,group,!Groups_IsOnDuty(playerid,group));
			case 5: Groups_SetHallSpawn(playerid,group,!Groups_WantsHallSpawn(playerid,group));
			case 6:
			{
				Groups_OpenGroup(playerid,group);
				return;
			}
		}
	}
}

Timer_Declare(Groups_Tick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		new prompt = Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT ? Groups_PromptAt(playerid) : -1;

		if (prompt == -1)
		{
			Groups_ClearPrompt(playerid);
			continue;
		}

		if (prompt == s_GroupsPrompt[playerid] && Infobox_IsShown(playerid,s_GroupsInfobox[playerid]))
		{
			continue;
		}

		new title[GROUPS_NAME_LEN], text[96];
		Groups_PromptText(playerid,prompt,title,text);
		s_GroupsPrompt[playerid] = prompt;
		s_GroupsInfobox[playerid] = Infobox_ShowPrompt(playerid,s_GroupsInfobox[playerid],title,text,3);
	}

	return 1;
}

forward bool:Groups_PromptContext(playerid);

public bool:Groups_PromptContext(playerid)
{
	return s_GroupsPrompt[playerid] != -1;
}

forward Groups_PromptDeferred(playerid,prompt);

public Groups_PromptDeferred(playerid,prompt)
{
	if (!IsPlayerConnected(playerid))
	{
		return 1;
	}

	if (prompt >= GROUPS_PROMPT_CHURCH)
	{
		new order = Groups_FindMineOfKind(playerid,GROUP_KIND_ORDER);

		if (order != GROUP_INVALID)
		{
			Groups_OpenHall(playerid,order);
		}
		else
		{
			Groups_StartFounding(playerid,GROUP_KIND_ORDER,-1);
		}

		return 1;
	}

	if (prompt >= GROUPS_PROMPT_HIDEOUT)
	{
		new hideout = prompt - GROUPS_PROMPT_HIDEOUT, holder = Groups_HideoutHolder(hideout);

		if (holder != GROUP_INVALID && Groups_IsMember(playerid,holder))
		{
			Groups_OpenHall(playerid,holder);
		}
		else if (holder == GROUP_INVALID)
		{
			Groups_StartFounding(playerid,GROUP_KIND_OUTLAW,hideout);
		}

		return 1;
	}

	if (Groups_IsMember(playerid,prompt))
	{
		Groups_OpenHall(playerid,prompt);
	}
	else
	{
		Groups_OpenBoard(playerid,prompt);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_GroupsPrompt[playerid] = -1;
	s_GroupsInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || (newkeys & KEY_WALK) || s_GroupsPrompt[playerid] == -1 || Infobox_IsPromptBlocked(playerid,s_GroupsInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new prompt = s_GroupsPrompt[playerid];
	Groups_ClearPrompt(playerid);
	SetTimerEx("Groups_PromptDeferred",0,false,"dd",playerid,prompt);
}

hook Character_OnSpawning(playerid)
{
	if (IsPlayerNPC(playerid) || Character_HasNextSpawn(playerid) || !Character_IsTutorialDone(playerid))
	{
		return;
	}

	new list[GROUPS_PER_CHARACTER + 2], count = Groups_GetMine(playerid,list);

	for (new i = 0;i < count;i++)
	{
		new group = list[i], Float:x, Float:y, Float:z, Float:a, world, interior;

		if (Groups_WantsHallSpawn(playerid,group) && Groups_HasFeature(group,GROUP_FEATURE_SPAWN) && Groups_HasFeature(group,GROUP_FEATURE_HALL) && Groups_GetHall(group,x,y,z,a,world,interior))
		{
			Character_SetNextSpawn(playerid,x + floatsin(-a,degrees) * 1.5,y + floatcos(-a,degrees) * 1.5,z,a,interior,world);
			return;
		}
	}
}
