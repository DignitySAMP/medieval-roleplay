#define HELP_GUI_TITLE "Help"
#define HELP_GUI_WIDTH (400.0)
#define HELP_GUI_ROWS (15)
#define HELP_GUI_NAME_SHARE (0.27)
#define HELP_GUI_TEXT_MAX (71)
#define HELP_GUI_ANSWER_WIDTH (340.0)
#define HELP_GUI_ANSWER_CHARS (66)
#define HELP_GUI_ANSWER_LEN (HELP_ANSWER_LEN + 64)
#define HELP_GUI_PREV (1)
#define HELP_GUI_NEXT (2)
#define HELP_GUI_ROW (100)
#define HELP_GUI_UP (-1)
#define HELP_GUI_GONE (-2)
#define HELP_GUI_COMMAND (1000)
#define HELP_GUI_SECTION (2000)
#define HELP_GUI_COMMANDS (3000)
#define HELP_GUI_CATEGORY (4000)
#define HELP_GUI_ASKSTAFF (-3)
#define HELP_GUI_MAX_ITEMS (COMMANDS_MAX_DESCRIBED + HELP_MAX_TOPICS + 16)
#define HELP_GUI_MAX_CATEGORIES (12)

static s_HelpQuery[MAX_PLAYERS][COMMANDS_NAME_LEN];

static HelpGui_Wrap(const text[],dest[],size = sizeof(dest))
{
	new paragraph[HELP_ANSWER_LEN], wrapped[HELP_GUI_ANSWER_LEN], start = 0, length = strlen(text);
	dest[0] = EOS;

	while (start <= length)
	{
		new stop = strfind(text,"~n~",false,start);

		if (stop == -1)
		{
			stop = length;
		}

		strmid(paragraph,text,start,stop,sizeof(paragraph));
		Util_WrapText(paragraph,wrapped,sizeof(wrapped),HELP_GUI_ANSWER_CHARS,"~n~");

		if (start > 0)
		{
			strcat(dest,"~n~",size);
		}

		strcat(dest,wrapped,size);
		start = stop + 3;
	}
}

static HelpGui_CategoryIndex(const categories[][],count,const category[])
{
	for (new i = 0;i < count;i++)
	{
		if (!strcmp(categories[i],category))
		{
			return i;
		}
	}

	return -1;
}

static HelpGui_Categories(playerid,categories[][COMMANDS_CATEGORY_LEN])
{
	new count = 0, name[COMMANDS_NAME_LEN], category[COMMANDS_CATEGORY_LEN], level = Account_GetAdminLevel(playerid);

	for (new cmdid = 0, total = GetTotalCommandCount();cmdid < total && count < HELP_GUI_MAX_CATEGORIES;cmdid++)
	{
		if (!Commands_CanUse(playerid,level,cmdid))
		{
			continue;
		}

		GetCommandName(cmdid,name);
		Command_GetCategory(name,category);

		if (HelpGui_CategoryIndex(categories,count,category) == -1)
		{
			strcopy(categories[count++],category,COMMANDS_CATEGORY_LEN);
		}
	}

	return count;
}

static HelpGui_DrawItem(playerid,Float:x,Float:y,Float:width,item,value,const categories[][COMMANDS_CATEGORY_LEN])
{
	new label[HELP_QUESTION_LEN], text[COMMANDS_TEXT_LEN];

	if (item == HELP_GUI_ASKSTAFF)
	{
		Kit_AddChoice(playerid,x,y,width,"Ask the staff, or report a problem",value,KIT_COLOUR_GOOD);
	}
	else if (item >= HELP_GUI_CATEGORY)
	{
		Kit_AddChoice(playerid,x,y,width,categories[item - HELP_GUI_CATEGORY],value);
	}
	else if (item == HELP_GUI_COMMANDS)
	{
		Kit_AddChoice(playerid,x,y,width,"Commands",value,KIT_COLOUR_ACCENT);
	}
	else if (item >= HELP_GUI_SECTION)
	{
		Help_GetSectionName(E_HELP_SECTION:(item - HELP_GUI_SECTION),label);
		Kit_AddChoice(playerid,x,y,width,label,value);
	}
	else if (item >= HELP_GUI_COMMAND)
	{
		new name[COMMANDS_NAME_LEN];
		GetCommandName(item - HELP_GUI_COMMAND,name);
		format(label,sizeof(label),"/%s",name);
		Command_GetDescription(name,text);

		if (strlen(text) > HELP_GUI_TEXT_MAX)
		{
			text[HELP_GUI_TEXT_MAX - 3] = EOS;
			strcat(text,"...");
		}

		Kit_AddHit(playerid,x - 3.0,y - 1.0,width + 6.0,KIT_ROW,value);
		Kit_AddText(playerid,x,y,label,KIT_COLOUR_ACCENT,KIT_TEXT_ROW);
		Kit_AddText(playerid,x + width * HELP_GUI_NAME_SHARE,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * (1.0 - HELP_GUI_NAME_SHARE));
	}
	else
	{
		new answer[2];
		Help_GetTopic(item,label,answer);
		Kit_AddChoice(playerid,x,y,width,label,value);
	}
}

static HelpGui_List(playerid,epoch,const heading[],const items[],count,const categories[][COMMANDS_CATEGORY_LEN],bool:isRoot)
{
	new page = 0;

	for (;;)
	{
		new pages = (count + HELP_GUI_ROWS - 1) / HELP_GUI_ROWS, rows = pages > 1 ? HELP_GUI_ROWS : count, first = page * HELP_GUI_ROWS, last = min(first + HELP_GUI_ROWS,count), extra = isRoot ? 1 : 0, Float:x, Float:y, Float:width;

		Kit_Begin(playerid,KIT_LAYER_SCREEN,HELP_GUI_TITLE);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HELP_GUI_WIDTH,float(rows + extra) * KIT_ROW + 6.0 + KIT_ROW + 12.0,heading,x,y,width);

		for (new i = first;i < last;i++)
		{
			HelpGui_DrawItem(playerid,x,y + float(i - first) * KIT_ROW,width,items[i],HELP_GUI_ROW + i - first,categories);
		}

		if (isRoot)
		{
			Kit_AddText(playerid,x,y + float(rows) * KIT_ROW,"Type /help and a word to search, like /help whisper.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		new Float:footerY = y + float(rows + extra) * KIT_ROW + 8.0, pageLabel[16];

		if (pages > 1)
		{
			format(pageLabel,sizeof(pageLabel),"%d of %d",page + 1,pages);
			Kit_AddText(playerid,x,footerY + 1.5,pageLabel,KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		}

		if (page > 0)
		{
			Kit_AddButton(playerid,x + width / 2.0 - 124.0,footerY,74.0,"< Back",HELP_GUI_PREV);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,footerY,80.0,isRoot ? (GUI_BUTTON_CLOSE) : ("Up"),KIT_BACK);

		if (page < pages - 1)
		{
			Kit_AddButton(playerid,x + width / 2.0 + 50.0,footerY,74.0,"More >",HELP_GUI_NEXT);
		}

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return HELP_GUI_GONE;
		}

		if (pick == HELP_GUI_PREV)
		{
			page = max(page - 1,0);
		}
		else if (pick == HELP_GUI_NEXT)
		{
			page = min(page + 1,pages - 1);
		}
		else if (pick >= HELP_GUI_ROW && pick < HELP_GUI_ROW + (last - first))
		{
			return items[first + pick - HELP_GUI_ROW];
		}
		else
		{
			return HELP_GUI_UP;
		}
	}
}

static bool:HelpGui_ShowItem(playerid,epoch,item)
{
	new title[HELP_QUESTION_LEN], answer[HELP_ANSWER_LEN], wrapped[HELP_GUI_ANSWER_LEN];

	if (item >= HELP_GUI_COMMAND)
	{
		new name[COMMANDS_NAME_LEN], category[COMMANDS_CATEGORY_LEN];
		GetCommandName(item - HELP_GUI_COMMAND,name);
		format(title,sizeof(title),"/%s",name);
		Command_GetDescription(name,answer);
		Command_GetCategory(name,category);
		format(answer,sizeof(answer),"%s~n~~n~~y~%s~w~ command. Type ~y~/%s~w~ on its own to see how it's used.",answer,category,name);
	}
	else if (!Help_GetTopic(item,title,answer))
	{
		return Gui_IsFlowCurrent(playerid,epoch);
	}

	HelpGui_Wrap(answer,wrapped);
	Gui_ShowMessage(playerid,title,wrapped,GUI_BUTTON_BACK,HELP_GUI_ANSWER_WIDTH);
	return Gui_IsFlowCurrent(playerid,epoch);
}

static bool:HelpGui_Section(playerid,epoch,E_HELP_SECTION:section)
{
	new items[HELP_MAX_TOPICS], count = 0, heading[HELP_SECTION_NAME_LEN], categories[1][COMMANDS_CATEGORY_LEN];
	Help_GetSectionName(section,heading);

	for (new i = 0, total = Help_GetTopicCount();i < total;i++)
	{
		if (Help_GetTopicSection(i) == section)
		{
			items[count++] = i;
		}
	}

	for (;;)
	{
		new pick = HelpGui_List(playerid,epoch,heading,items,count,categories,false);

		if (pick == HELP_GUI_GONE)
		{
			return false;
		}

		if (pick == HELP_GUI_UP)
		{
			return true;
		}

		if (!HelpGui_ShowItem(playerid,epoch,pick))
		{
			return false;
		}
	}
}

static bool:HelpGui_Commands(playerid,epoch)
{
	new categories[HELP_GUI_MAX_CATEGORIES][COMMANDS_CATEGORY_LEN], categoryCount = HelpGui_Categories(playerid,categories), items[HELP_GUI_MAX_CATEGORIES];

	for (new i = 0;i < categoryCount;i++)
	{
		items[i] = HELP_GUI_CATEGORY + i;
	}

	for (;;)
	{
		new pick = HelpGui_List(playerid,epoch,"Commands",items,categoryCount,categories,false);

		if (pick == HELP_GUI_GONE)
		{
			return false;
		}

		if (pick == HELP_GUI_UP)
		{
			return true;
		}

		new results[COMMANDS_MAX_DESCRIBED], found = Commands_Find(playerid,Account_GetAdminLevel(playerid),"",results), commands[COMMANDS_MAX_DESCRIBED], count = 0, name[COMMANDS_NAME_LEN], category[COMMANDS_CATEGORY_LEN];

		for (new i = 0;i < found;i++)
		{
			GetCommandName(results[i],name);
			Command_GetCategory(name,category);

			if (!strcmp(category,categories[pick - HELP_GUI_CATEGORY]))
			{
				commands[count++] = HELP_GUI_COMMAND + results[i];
			}
		}

		for (;;)
		{
			new chosen = HelpGui_List(playerid,epoch,categories[pick - HELP_GUI_CATEGORY],commands,count,categories,false);

			if (chosen == HELP_GUI_GONE)
			{
				return false;
			}

			if (chosen == HELP_GUI_UP)
			{
				break;
			}

			if (!HelpGui_ShowItem(playerid,epoch,chosen))
			{
				return false;
			}
		}
	}
}

static HelpGui_Browse(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), items[_:HELP_SECTION_COUNT + 1], count = 0, categories[1][COMMANDS_CATEGORY_LEN];

	for (new E_HELP_SECTION:section = HELP_SECTION_START;section < HELP_SECTION_COUNT;section++)
	{
		if (Help_CountInSection(section) > 0)
		{
			items[count++] = HELP_GUI_SECTION + _:section;
		}
	}

	items[count++] = HELP_GUI_COMMANDS;
	items[count++] = HELP_GUI_ASKSTAFF;

	for (;;)
	{
		new pick = HelpGui_List(playerid,epoch,HELP_GUI_TITLE,items,count,categories,true), bool:isCurrent = true;

		if (pick == HELP_GUI_GONE)
		{
			return;
		}

		if (pick == HELP_GUI_UP)
		{
			Kit_Close(playerid);
			return;
		}

		if (pick == HELP_GUI_ASKSTAFF)
		{
			Kit_Close(playerid);
			pawn_call_public("Help_OnAskStaff","d",playerid);
			return;
		}

		if (pick == HELP_GUI_COMMANDS)
		{
			isCurrent = HelpGui_Commands(playerid,epoch);
		}
		else
		{
			isCurrent = HelpGui_Section(playerid,epoch,E_HELP_SECTION:(pick - HELP_GUI_SECTION));
		}

		if (!isCurrent)
		{
			return;
		}
	}
}

static HelpGui_Search(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), items[HELP_GUI_MAX_ITEMS], count = 0, question[HELP_QUESTION_LEN], answer[HELP_ANSWER_LEN], results[COMMANDS_MAX_DESCRIBED], categories[1][COMMANDS_CATEGORY_LEN], heading[KIT_TITLE_LEN];

	for (new i = 0, total = Help_GetTopicCount();i < total && count < HELP_GUI_MAX_ITEMS;i++)
	{
		Help_GetTopic(i,question,answer);

		if (strfind(question,s_HelpQuery[playerid],true) != -1 || strfind(answer,s_HelpQuery[playerid],true) != -1)
		{
			items[count++] = i;
		}
	}

	for (new i = 0, found = Commands_Find(playerid,Account_GetAdminLevel(playerid),s_HelpQuery[playerid],results);i < found && count < HELP_GUI_MAX_ITEMS;i++)
	{
		items[count++] = HELP_GUI_COMMAND + results[i];
	}

	if (count == 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf(COMMAND_REPLY_NOTHING_FOUND,s_HelpQuery[playerid]));
		return;
	}

	format(heading,sizeof(heading),"Help: %s",s_HelpQuery[playerid]);

	for (;;)
	{
		new pick = HelpGui_List(playerid,epoch,heading,items,count,categories,true);

		if (pick == HELP_GUI_GONE)
		{
			return;
		}

		if (pick == HELP_GUI_UP)
		{
			Kit_Close(playerid);
			return;
		}

		if (!HelpGui_ShowItem(playerid,epoch,pick))
		{
			return;
		}
	}
}

static HelpGui_ReadQuery(playerid,const params[])
{
	new length = 0, i = 0;

	while (params[i] == ' ' || params[i] == '/')
	{
		i++;
	}

	while (params[i] != EOS && length < COMMANDS_NAME_LEN - 1)
	{
		s_HelpQuery[playerid][length++] = params[i++];
	}

	while (length > 0 && s_HelpQuery[playerid][length - 1] <= ' ')
	{
		length--;
	}

	s_HelpQuery[playerid][length] = EOS;
}

CMD<ADMIN_LEVEL_NONE>:help(cmdid, playerid, params[])
{
	#pragma unused cmdid

	if (!Session_IsPlaying(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,COMMAND_REPLY_NOT_SPAWNED);
		return 1;
	}

	HelpGui_ReadQuery(playerid,params);
	SetTimerEx("HelpGui_Deferred",0,false,"d",playerid);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:searchcmd(cmdid, playerid, params[])
{
	#pragma unused cmdid

	if (!Session_IsPlaying(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,COMMAND_REPLY_NOT_SPAWNED);
		return 1;
	}

	HelpGui_ReadQuery(playerid,params);
	SetTimerEx("HelpGui_Deferred",0,false,"d",playerid);
	return 1;
}

forward HelpGui_Deferred(playerid);

public HelpGui_Deferred(playerid)
{
	if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid))
	{
		return 1;
	}

	if (s_HelpQuery[playerid][0] == EOS)
	{
		HelpGui_Browse(playerid);
	}
	else
	{
		HelpGui_Search(playerid);
	}

	return 1;
}

forward Help_OnAskStaff(playerid);

public Help_OnAskStaff(playerid)
{
	return 1;
}
