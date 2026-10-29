static s_NoticePrompt[MAX_PLAYERS] = {-1, ...};
static s_NoticeInfobox[MAX_PLAYERS];

static Notices_ClearPrompt(playerid)
{
	if (s_NoticeInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_NoticeInfobox[playerid]);
	}

	s_NoticePrompt[playerid] = -1;
	s_NoticeInfobox[playerid] = 0;
}

static Notices_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Notices_ClearPrompt(playerid);
		return;
	}

	new board = Notices_FindBoardNear(playerid);

	if (board == -1)
	{
		Notices_ClearPrompt(playerid);
		return;
	}

	if (board == s_NoticePrompt[playerid] && Infobox_IsShown(playerid,s_NoticeInfobox[playerid]))
	{
		return;
	}

	new text[96], count = Notices_CountOnBoard();

	if (count == 0)
	{
		strcopy(text,"Nothing is pinned up.~n~Press ~y~Y~w~ to look or pin your own.");
	}
	else if (count == 1)
	{
		strcopy(text,"One notice is pinned up.~n~Press ~y~Y~w~ to read it or pin your own.");
	}
	else
	{
		format(text,sizeof(text),"%d notices are pinned up.~n~Press ~y~Y~w~ to read them or pin your own.",count);
	}

	s_NoticePrompt[playerid] = board;
	s_NoticeInfobox[playerid] = Infobox_ShowPrompt(playerid,s_NoticeInfobox[playerid],"Notice board",text,3);
}

static Notices_FormatAge(id,dest[],size = sizeof(dest))
{
	new slot = Notices_FindSlotPublic(id), now = gettime();

	if (slot == -1)
	{
		dest[0] = EOS;
		return;
	}

    if (Notices_IsPermanent(id))
    {
        strcopy(dest,"Permanent",size);
        return;
    }

    new left = Notices_GetExpires(id) - now, starts = Notices_GetStarts(id) - now;

	if (starts > 0)
	{
		format(dest,size,"in %d h",starts / 3600 + 1);
		return;
	}

	format(dest,size,left > 86400 ? ("%d days left") : ("%d h left"),left > 86400 ? left / 86400 : left / 3600 + 1);
}

stock Notices_OpenBoard(playerid,E_NOTICE_TAB:tab = NOTICE_TAB_REALM)
{
	new page = 0;

	for (;;)
	{
		new pages = max(1,(Notices_Count(tab) + NOTICES_LIST_ROWS - 1) / NOTICES_LIST_ROWS);
		page = clamp(page,0,pages - 1);
		new epoch = Gui_BeginFlow(playerid), ids[NOTICES_LIST_ROWS], count = Notices_List(tab,ids,sizeof(ids),page * NOTICES_LIST_ROWS), Float:x, Float:y, Float:width, title[32];
		format(title,sizeof(title),"Notice board: %s",g_NoticeTabNames[tab]);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,NOTICES_PANEL_WIDTH,float(NOTICES_LIST_ROWS + 3) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		new Float:tabWidth = width / float(_:NOTICE_TAB_COUNT);

		for (new E_NOTICE_TAB:t = NOTICE_TAB_REALM;t < NOTICE_TAB_COUNT;t++)
		{
			Kit_AddButton(playerid,x + tabWidth * float(_:t),y,tabWidth - 4.0,g_NoticeTabNames[t],NOTICES_PICK_TAB + _:t,t == tab ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		}

		if (count == 0)
		{
			Kit_AddText(playerid,x,y + KIT_ROW * 1.5,"Nothing is pinned here.",KIT_COLOUR_MUTED);
		}

		for (new i = 0;i < count;i++)
		{
			new name[NOTICES_TITLE_LEN], age[24];
			Notices_GetTitle(ids[i],name);
			Notices_FormatAge(ids[i],age);
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1) + 6.0,width,name,NOTICES_PICK_ROW + i,KIT_COLOUR_TEXT,age,KIT_COLOUR_MUTED);
		}

		if (tab == NOTICE_TAB_PLAYERS)
		{
			new label[48], money[24];
			Economy_Format(NOTICES_FEE,money);
			format(label,sizeof(label),"Pin a notice (%s for %d days)",money,NOTICES_PLAYER_DAYS);
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(NOTICES_LIST_ROWS + 2),width,label,NOTICES_PICK_POST,KIT_COLOUR_GOOD);
		}

		new Float:footY = y + float(NOTICES_LIST_ROWS + 3) * KIT_ROW + 8.0;

		if (page > 0)
		{
			Kit_AddButton(playerid,x,footY,60.0,"Earlier",NOTICES_PICK_PREV);
		}

		if (page < pages - 1)
		{
			Kit_AddButton(playerid,x + width - 60.0,footY,60.0,"More",NOTICES_PICK_NEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,footY,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !IsPlayerConnected(playerid))
		{
			return;
		}

		if (pick >= NOTICES_PICK_TAB && pick < NOTICES_PICK_TAB + _:NOTICE_TAB_COUNT)
		{
			tab = E_NOTICE_TAB:(pick - NOTICES_PICK_TAB);
			page = 0;

			if (tab == NOTICE_TAB_WORK)
			{
				pawn_call_public("Notices_OnWorkTab","d",playerid);
				return;
			}

			continue;
		}

		if (pick == NOTICES_PICK_POST)
		{
			Notices_Compose(playerid);
			continue;
		}

		if (pick == NOTICES_PICK_PREV || pick == NOTICES_PICK_NEXT)
		{
			page += pick == NOTICES_PICK_NEXT ? 1 : -1;
			continue;
		}

		if (pick >= NOTICES_PICK_ROW && pick < NOTICES_PICK_ROW + count)
		{
			Notices_Read(playerid,ids[pick - NOTICES_PICK_ROW]);
		}
	}
}

stock Notices_Read(playerid,id)
{
	new title[NOTICES_TITLE_LEN], text[NOTICES_TEXT_LEN], lines[8][44], count = 0, Float:x, Float:y, Float:width;
	Notices_GetTitle(id,title);
	Notices_GetText(id,text);
	new length = strlen(text), start = 0;

	while (start < length && count < sizeof(lines))
	{
		new end = start + 40;

		if (end >= length)
		{
			end = length;
		}
		else
		{
			new cut = end;

			while (cut > start && text[cut] != ' ' && text[cut] != '|')
			{
				cut--;
			}

			if (cut > start)
			{
				end = cut;
			}
		}

		strmid(lines[count],text,start,end,sizeof(lines[]));

		for (new i = 0;lines[count][i] != EOS;i++)
		{
			if (lines[count][i] == '|')
			{
				lines[count][i] = ' ';
			}
		}

		count++;
		start = end;

		while (start < length && (text[start] == ' ' || text[start] == '|'))
		{
			start++;
		}
	}

	new epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,NOTICES_PANEL_WIDTH,float(count + 1) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * float(i),lines[i]);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count + 1) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

static bool:Notices_AskLine(playerid,token,const prompt[],dest[],maxLength,size = sizeof(dest))
{
	new response[DIALOG_RESPONSE], body[256];
	format(body,sizeof(body),GUI_TEXT "%s\n\n" GUI_MUTED "At most %d letters. Leave it empty to clear the line.",prompt,maxLength);
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,"A notice",body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
	{
		return false;
	}

	strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);

	if (strlen(dest) > maxLength)
	{
		dest[maxLength] = EOS;
	}

	for (new i = 0;dest[i] != EOS;i++)
	{
		if (dest[i] == '~' || dest[i] == '{' || dest[i] == '}' || dest[i] == '|')
		{
			dest[i] = ' ';
		}
	}

	return true;
}

stock Notices_Compose(playerid)
{
	new token = Account_GetToken(playerid), title[NOTICES_TITLE_LEN], lines[NOTICES_LINES][NOTICES_LINE_LEN];
	title[0] = EOS;

	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, used = 0, money[24], fold[48];

		for (new i = 0;i < NOTICES_LINES;i++)
		{
			if (lines[i][0] != EOS)
			{
				used++;
			}
		}

		Economy_Format(NOTICES_FEE,money);
		format(fold,sizeof(fold),"Pin it up (%s)",money);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"A notice");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,NOTICES_PANEL_WIDTH,float(NOTICES_LINES + 3) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"A notice",x,y,width);
		Kit_AddChoice(playerid,x,y,width,title[0] != EOS ? title : ("Heading (click to write)"),100,title[0] != EOS ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);

		for (new i = 0;i < NOTICES_LINES;i++)
		{
			new label[NOTICES_LINE_LEN + 16];

			if (lines[i][0] != EOS)
			{
				strcopy(label,lines[i]);
			}
			else
			{
				format(label,sizeof(label),"line %d: click to write",i + 1);
			}

			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1) + 4.0,width,label,i,lines[i][0] != EOS ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(NOTICES_LINES + 2),width,fold,200,title[0] != EOS && used > 0 ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(NOTICES_LINES + 3) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		if (pick == 100)
		{
			Notices_AskLine(playerid,token,"The heading: a sale, goods wanted, hands wanted, a lost horse, a celebration.",title,NOTICES_TITLE_LEN - 1);
			continue;
		}

		if (pick >= 0 && pick < NOTICES_LINES)
		{
			Notices_AskLine(playerid,token,"A line of your notice. Don't name anyone who hasn't agreed to it.",lines[pick],NOTICES_LINE_LEN - 1);
			continue;
		}

		if (title[0] == EOS || used == 0)
		{
			Gui_Notify(playerid,"Give the notice a heading and at least one line.");
			continue;
		}

		break;
	}

	if (Economy_Pay(playerid,NOTICES_FEE,INVALID_CONTAINER_ID,"notice") != PAY_OK)
	{
		Gui_Notify(playerid,"You don't have the fee for a notice.");
		return;
	}

	new text[NOTICES_TEXT_LEN], now = gettime();
	text[0] = EOS;

	for (new i = 0;i < NOTICES_LINES;i++)
	{
		if (lines[i][0] == EOS)
		{
			continue;
		}

		if (text[0] != EOS)
		{
			strcat(text,"|");
		}

		strcat(text,lines[i]);
	}

	await Notices_Post(NOTICE_TAB_PLAYERS,Character_GetId(playerid),title,text,now,now + NOTICES_PLAYER_DAYS * NOTICES_DAY_SECONDS);

	if (IsPlayerConnected(playerid))
	{
		Gui_Notify(playerid,"You pin the notice up. The crier will call it out.");
	}
}

Timer_Declare(Notices_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Notices_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward Notices_OnWorkTab(playerid);

public Notices_OnWorkTab(playerid)
{
	return 1;
}

forward Notices_BoardDeferred(playerid);

public Notices_BoardDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Notices_OpenBoard(playerid);
	}

	return 1;
}

forward bool:Notices_PromptContext(playerid);

public bool:Notices_PromptContext(playerid)
{
	return s_NoticePrompt[playerid] != -1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_NoticePrompt[playerid] = -1;
	s_NoticeInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_NoticePrompt[playerid] == -1 || Infobox_IsPromptBlocked(playerid,s_NoticeInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	Notices_ClearPrompt(playerid);
	SetTimerEx("Notices_BoardDeferred",0,false,"d",playerid);
}
