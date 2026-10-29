#define ORDERS_LIST_MAX (128)
#define ORDERS_ENTRY_ORDER (0)
#define ORDERS_ENTRY_CONTRACT (1)
#define ORDERS_ENTRY_DUTY (2)
#define ORDERS_ENTRY_OWED (3)
#define ORDERS_ENTRY_GOAL (4)
#define ORDERS_ENTRY_SUGGESTION (5)
#define ORDERS_ENTRY_NOTE (6)
#define ORDERS_ENTRY_FAMILY (7)
#define ORDERS_LEDGER_TASKS (7100)
#define ORDERS_LEDGER_SUGGESTED (7101)
#define ORDERS_TASK_TEXT (160)
#define ORDERS_LEDGER_WIDTH (396.0)
#define ORDERS_PICK_ENTRY (100)

enum E_ORDERS_ENTRY
{
	E_ORDERS_ENTRY_KIND,
	E_ORDERS_ENTRY_REF,
}

static s_OrdersList[ORDERS_LIST_MAX][E_ORDERS_ENTRY];
static s_OrdersListCount;
static s_OrdersListOwner = INVALID_PLAYER_ID;
static s_OrdersListMode[MAX_PLAYERS];
static s_OrdersListActor[MAX_PLAYERS];

static Orders_ListReset(playerid,mode,actor = -1)
{
	s_OrdersListCount = 0;
	s_OrdersListOwner = playerid;
	s_OrdersListMode[playerid] = mode;
	s_OrdersListActor[playerid] = actor;
}

static Orders_ListAdd(kind,ref)
{
	new i = s_OrdersListCount;

	if (i >= ORDERS_LIST_MAX)
	{
		return;
	}

	s_OrdersList[i][E_ORDERS_ENTRY_KIND] = kind;
	s_OrdersList[i][E_ORDERS_ENTRY_REF] = ref;
	s_OrdersListCount++;
}

static Orders_ListEnsure(playerid)
{
	if (s_OrdersListOwner == playerid)
	{
		return;
	}

	switch (s_OrdersListMode[playerid])
	{
		case 0: Orders_BuildBoard(playerid);
		case 1: Orders_BuildErrands(playerid,s_OrdersListActor[playerid]);
		default: Orders_BuildLedger(playerid,s_OrdersListMode[playerid] == 3);
	}
}

stock Orders_GetListCount(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	Orders_ListEnsure(playerid);
	return s_OrdersListCount;
}

stock Orders_GetListEntry(playerid,i,&kind,&ref)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return false;
	}

	Orders_ListEnsure(playerid);

	if (i < 0 || i >= s_OrdersListCount)
	{
		return false;
	}

	kind = s_OrdersList[i][E_ORDERS_ENTRY_KIND];
	ref = s_OrdersList[i][E_ORDERS_ENTRY_REF];
	return true;
}

static Orders_ListSnapshot(playerid,entries[][E_ORDERS_ENTRY])
{
	new count = Orders_GetListCount(playerid);

	for (new i = 0;i < count;i++)
	{
		entries[i][E_ORDERS_ENTRY_KIND] = s_OrdersList[i][E_ORDERS_ENTRY_KIND];
		entries[i][E_ORDERS_ENTRY_REF] = s_OrdersList[i][E_ORDERS_ENTRY_REF];
	}

	return count;
}

static Orders_FormatListRow(playerid,kind,ref,bool:errands,label[],right[],&colour)
{
	new text[ORDERS_TEXT_LEN], characterid = Character_GetId(playerid);
	label[0] = EOS;
	right[0] = EOS;
	colour = KIT_COLOUR_TEXT;

	switch (kind)
	{
		case ORDERS_ENTRY_ORDER:
		{
			Orders_FormatText(ref,text);

			if (errands)
			{
				if (Orders_GetTaker(ref) == characterid)
				{
					format(label,72,"Hand over %s",text);
					colour = KIT_COLOUR_PENDING;
				}
				else
				{
					Orders_Capital(text);
					strcopy(label,text,72);
					new key[ACTORS_KEY_LEN];
					Orders_GetGiverKey(ref,key);
					colour = Orders_GetGoodwillByKey(playerid,key) >= Orders_GetGoodwillNeeded(ref) ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED;
				}

				Orders_Money(Orders_GetPay(ref),right,24);
			}
			else
			{
				new giver[16];
				strcopy(giver,g_OrderGiverNames[g_OrderDefs[Orders_GetDef(ref)][E_ORDER_DEF_GIVER]]);
				Orders_Capital(giver);
				format(label,72,"%s: %s",giver,text);
				colour = Orders_GetTaker(ref) == characterid ? KIT_COLOUR_PENDING : KIT_COLOUR_TEXT;

				if (Orders_GetTaker(ref) == characterid)
				{
					strcopy(right,"yours",24);
				}
				else
				{
					Orders_Money(Orders_GetPay(ref),right,24);
				}
			}
		}
		case ORDERS_ENTRY_CONTRACT:
		{
			new poster[ORDERS_POSTER_LEN];
			Contracts_FormatText(ref,text);
			Contracts_GetPosterName(ref,poster);
			format(label,72,"%s wants %s",poster,text);
			colour = Contracts_GetTaker(ref) == characterid ? KIT_COLOUR_PENDING : (Contracts_GetPoster(ref) == characterid ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT);

			if (Contracts_GetTaker(ref) == characterid)
			{
				strcopy(right,"yours",24);
			}
			else
			{
				Orders_Money(Contracts_GetPay(ref),right,24);
			}
		}
		case ORDERS_ENTRY_DUTY, ORDERS_ENTRY_OWED:
		{
			new goods[40];
			Orders_DutyGoods(ref,goods);
			format(label,72,kind == ORDERS_ENTRY_OWED ? ("Owed: %s (%s)") : ("Duty: %s (%s)"),g_OrderDutyDefs[ref][E_ORDER_DUTY_DEF_TEXT],goods);

			if (kind == ORDERS_ENTRY_OWED)
			{
				strcopy(right,"a debt",24);
				colour = KIT_COLOUR_BAD;
			}
			else
			{
				new bool:isDone = Orders_GetDutyState(playerid,ref) == ORDER_DUTY_DONE;
				strcopy(right,isDone ? ("done") : (Orders_IsDutyOpen(ref) ? ("due") : ("full moon")),24);
				colour = isDone ? KIT_COLOUR_MUTED : KIT_COLOUR_ACCENT;
			}
		}
	}
}

static Orders_Capital(dest[])
{
	if (dest[0] >= 'a' && dest[0] <= 'z')
	{
		dest[0] -= 32;
	}
}

static Orders_Money(pfennig,dest[],size = sizeof(dest))
{
	Economy_Format(pfennig,dest,size);
}

static Orders_Explain(playerid,result)
{
	if (result > ORDER_OK && result < sizeof(g_OrderResultTexts))
	{
		Gui_Notify(playerid,g_OrderResultTexts[result]);
	}
}

static bool:Orders_AskText(playerid,token,const title[],const prompt[],dest[],maxLength,size = sizeof(dest))
{
	new response[DIALOG_RESPONSE], body[256];
	format(body,sizeof(body),GUI_TEXT "%s\n\n" GUI_MUTED "At most %d letters.",prompt,maxLength);
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,title,body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
	{
		return false;
	}

	strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);

	if (strlen(dest) > maxLength)
	{
		dest[maxLength] = EOS;
	}

	Ledger_Clean(dest);
	return true;
}

static Orders_AskNumber(playerid,token,const title[],const prompt[],minValue,maxValue)
{
	new text[12];

	if (!Orders_AskText(playerid,token,title,prompt,text,10))
	{
		return cellmin;
	}

	new value = strval(text);
	return value < minValue || value > maxValue ? cellmin : value;
}

stock Orders_CountErrandsAt(playerid,index)
{
	new giver = Orders_GiverKindOf(index), key[ACTORS_KEY_LEN], count = 0, characterid = Character_GetId(playerid);

	if (giver == -1)
	{
		return 0;
	}

	Actors_GetKey(index,key);

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		new owner[ACTORS_KEY_LEN];
		Orders_GetGiverKey(slot,owner);

		if (Orders_IsValid(slot) && !strcmp(owner,key) && (Orders_GetTaker(slot) == 0 || Orders_GetTaker(slot) == characterid))
		{
			count++;
		}
	}

	for (new duty = 0;duty < Orders_DutyCount();duty++)
	{
		if (Orders_DutyGiver(duty) == giver && (Orders_IsDutyOwed(playerid,duty) || (Orders_IsDutyOpen(duty) && Orders_GetDutyState(playerid,duty) != ORDER_DUTY_DONE)))
		{
			count++;
		}
	}

	return count;
}

static Orders_BuildErrands(playerid,index)
{
	new giver = Orders_GiverKindOf(index), key[ACTORS_KEY_LEN], characterid = Character_GetId(playerid);
	Actors_GetKey(index,key);
	Orders_ListReset(playerid,1,index);

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		new owner[ACTORS_KEY_LEN];
		Orders_GetGiverKey(slot,owner);

		if (!Orders_IsValid(slot) || strcmp(owner,key) || Orders_GetTaker(slot) != characterid)
		{
			continue;
		}

		Orders_ListAdd(ORDERS_ENTRY_ORDER,slot);
	}

	for (new duty = 0;duty < Orders_DutyCount();duty++)
	{
		if (Orders_DutyGiver(duty) != giver)
		{
			continue;
		}

		if (Orders_IsDutyOwed(playerid,duty))
		{
			Orders_ListAdd(ORDERS_ENTRY_OWED,duty);
		}
		else if (Orders_IsDutyThisSeason(duty) && (!g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_FEAST] || Orders_IsDutyOpen(duty)))
		{
			Orders_ListAdd(ORDERS_ENTRY_DUTY,duty);
		}
	}

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		new owner[ACTORS_KEY_LEN];
		Orders_GetGiverKey(slot,owner);

		if (!Orders_IsValid(slot) || strcmp(owner,key) || Orders_GetTaker(slot) != 0)
		{
			continue;
		}

		Orders_ListAdd(ORDERS_ENTRY_ORDER,slot);
	}
}

stock Orders_OpenErrands(playerid,index)
{
	for (;;)
	{
		new giver = Orders_GiverKindOf(index);

		if (giver == -1 || !IsPlayerConnected(playerid))
		{
			return;
		}

		new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), key[ACTORS_KEY_LEN], name[32], title[48], words[40], Float:x, Float:y, Float:width, Float:top;
		Actors_GetKey(index,key);
		Actors_GetName(index,name);
		format(title,sizeof(title),"Errands for %s",name);
		Orders_GoodwillWords(Orders_GetGoodwillByKey(playerid,key),words);
		Orders_BuildErrands(playerid,index);
		new entries[ORDERS_LIST_MAX][E_ORDERS_ENTRY], count = Orders_ListSnapshot(playerid,entries);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,ORDERS_PANEL_WIDTH,float(ORDERS_BOARD_ROWS + 3) * KIT_ROW + 12.0,title,x,y,width);
		Kit_AddText(playerid,x,y,words,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		top = y + KIT_ROW * 1.2;

		if (Orders_MissedLastSeason(playerid,giver))
		{
			Kit_AddText(playerid,x,top,"They remember what you didn't bring last season.",KIT_COLOUR_BAD,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
			top += KIT_ROW;
		}

		if (count == 0)
		{
			Kit_AddText(playerid,x,top,"Nothing is asked of you just now. Come back tomorrow.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		for (new i = 0;i < count && i < ORDERS_BOARD_ROWS;i++)
		{
			new label[72], right[24], colour;
			Orders_FormatListRow(playerid,entries[i][E_ORDERS_ENTRY_KIND],entries[i][E_ORDERS_ENTRY_REF],true,label,right,colour);
			Kit_AddChoice(playerid,x,top + KIT_ROW * float(i),width,label,ORDERS_PICK_ENTRY + i,colour,right,KIT_COLOUR_ACCENT,0.72);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(ORDERS_BOARD_ROWS + 2) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		new chosen = pick - ORDERS_PICK_ENTRY;

		if (chosen < 0 || chosen >= count)
		{
			continue;
		}

		new kind = entries[chosen][E_ORDERS_ENTRY_KIND], ref = entries[chosen][E_ORDERS_ENTRY_REF];

		switch (kind)
		{
			case ORDERS_ENTRY_ORDER:
			{
				new text[ORDERS_TEXT_LEN], pay = Orders_GetPay(ref), result;
				Orders_FormatText(ref,text);

				if (Orders_GetTaker(ref) == Character_GetId(playerid))
				{
					result = Orders_Deliver(playerid,ref);

					if (result == ORDER_OK)
					{
						new money[24];
						Orders_Money(pay,money);
						Subtitle_Show(playerid,sprintf("~w~You hand over %s and are paid ~y~%s~w~.",text,money));
					}
				}
				else
				{
					result = Orders_Accept(playerid,ref);

					if (result == ORDER_OK)
					{
						Subtitle_Show(playerid,sprintf("~w~You take the errand: ~y~%s~w~. Bring it back here.",text));
					}
				}

				Orders_Explain(playerid,result);
			}
			case ORDERS_ENTRY_DUTY, ORDERS_ENTRY_OWED:
			{
				new result = Orders_DeliverDuty(playerid,ref);

				if (result == ORDER_OK)
				{
					new money[24];

					if (Orders_GetLastDutyPay(playerid) > 0)
					{
						Orders_Money(Orders_GetLastDutyPay(playerid),money);
						Subtitle_Show(playerid,sprintf("~w~You bring %s. The %s thanks you and pays ~y~%s~w~.",g_OrderDutyDefs[ref][E_ORDER_DUTY_DEF_TEXT],g_OrderGiverNames[giver],money));
					}
					else
					{
						Subtitle_Show(playerid,sprintf("~w~You bring %s. The %s thanks you.",g_OrderDutyDefs[ref][E_ORDER_DUTY_DEF_TEXT],g_OrderGiverNames[giver]));
					}
				}

				Orders_Explain(playerid,result);
			}
		}
	}
}

static Orders_BuildBoard(playerid)
{
	new characterid = Character_GetId(playerid);
	Orders_ListReset(playerid,0);

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (Orders_IsValid(slot) && (Orders_GetTaker(slot) == 0 || Orders_GetTaker(slot) == characterid))
		{
			Orders_ListAdd(ORDERS_ENTRY_ORDER,slot);
		}
	}

	for (new slot = 0;slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (Contracts_IsValid(slot) && (Contracts_GetTaker(slot) == 0 || Contracts_GetTaker(slot) == characterid || Contracts_GetPoster(slot) == characterid))
		{
			Orders_ListAdd(ORDERS_ENTRY_CONTRACT,slot);
		}
	}
}

stock Orders_OpenBoard(playerid,page = 0)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), Float:x, Float:y, Float:width, perPage = ORDERS_BOARD_ROWS - 1;
		Orders_BuildBoard(playerid);
		new entries[ORDERS_LIST_MAX][E_ORDERS_ENTRY], count = Orders_ListSnapshot(playerid,entries);
		new pages = max(1,(count + perPage - 1) / perPage);
		page = clamp(page,0,pages - 1);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Notice board: Work");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,ORDERS_PANEL_WIDTH,float(ORDERS_BOARD_ROWS + 3) * KIT_ROW + 12.0,"Notice board: Work",x,y,width);

		if (count == 0)
		{
			Kit_AddText(playerid,x,y,"Nothing is wanted today. The givers post at dawn.",KIT_COLOUR_MUTED);
		}

		for (new row = 0, i = page * perPage;row < perPage && i < count;row++, i++)
		{
			new label[72], right[24], colour;
			Orders_FormatListRow(playerid,entries[i][E_ORDERS_ENTRY_KIND],entries[i][E_ORDERS_ENTRY_REF],false,label,right,colour);
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(row),width,label,ORDERS_PICK_ENTRY + i,colour,right,KIT_COLOUR_ACCENT,0.72);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(ORDERS_BOARD_ROWS),width,"Post a contract: goods you want, paid from your purse",ORDERS_PICK_POST,KIT_COLOUR_GOOD);
		new Float:footY = y + float(ORDERS_BOARD_ROWS + 2) * KIT_ROW + 8.0;

		if (page > 0)
		{
			Kit_AddButton(playerid,x,footY,60.0,"Earlier",ORDERS_PICK_PREV);
		}

		if (page < pages - 1)
		{
			Kit_AddButton(playerid,x + width - 60.0,footY,60.0,"More",ORDERS_PICK_NEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,footY,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		switch (pick)
		{
			case KIT_BACK:
			{
				Notices_OpenBoard(playerid,NOTICE_TAB_REALM);
				return;
			}
			case ORDERS_PICK_PREV: page--;
			case ORDERS_PICK_NEXT: page++;
			case ORDERS_PICK_POST: Orders_ComposeContract(playerid);
			default:
			{
				new chosen = pick - ORDERS_PICK_ENTRY;

				if (chosen >= 0 && chosen < count)
				{
					new kind = entries[chosen][E_ORDERS_ENTRY_KIND], ref = entries[chosen][E_ORDERS_ENTRY_REF];

					if (kind == ORDERS_ENTRY_ORDER)
					{
						Orders_ReadOrder(playerid,ref);
					}
					else
					{
						Orders_ReadContract(playerid,ref);
					}
				}
			}
		}
	}
}

stock Orders_ReadOrder(playerid,slot)
{
	if (!Orders_IsValid(slot))
	{
		Gui_Notify(playerid,g_OrderResultTexts[ORDER_GONE]);
		return;
	}

	new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), text[ORDERS_TEXT_LEN], giver[16], title[48], line[96], money[24], until[24], Float:x, Float:y, Float:width, characterid = Character_GetId(playerid);
	Orders_FormatText(slot,text);
	Orders_Capital(text);
	strcopy(giver,g_OrderGiverNames[g_OrderDefs[Orders_GetDef(slot)][E_ORDER_DEF_GIVER]]);
	format(title,sizeof(title),"The %s asks",giver);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,ORDERS_PANEL_WIDTH,8.0 * KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Orders_Money(Orders_GetPay(slot),money);
	Calendar_FormatDay(Orders_GetExpires(slot),until);
	format(line,sizeof(line),"Pays about %s, more for better stars. Wanted until %s.",money,until);
	Kit_AddText(playerid,x,y + KIT_ROW * 1.2,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	format(line,sizeof(line),"Hand it to the %s in person. Three errands at once at most.",giver);
	Kit_AddText(playerid,x,y + KIT_ROW * 2.2,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new key[ACTORS_KEY_LEN];
	Orders_GetGiverKey(slot,key);

	if (Orders_GetGoodwillByKey(playerid,key) < Orders_GetGoodwillNeeded(slot))
	{
		Kit_AddText(playerid,x,y + KIT_ROW * 3.2,"They give this one only to hands they know. Do smaller errands for them first.",KIT_COLOUR_BAD,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	if (Orders_GetTaker(slot) == characterid)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.6,width,"Drop this errand",ORDERS_PICK_DELIVER,KIT_COLOUR_BAD);
	}
	else if (Orders_GetTaker(slot) == 0)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.6,width,"Take this errand",ORDERS_PICK_TAKE,KIT_COLOUR_GOOD);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 6.5 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (pick == ORDERS_PICK_TAKE)
	{
		new result = Orders_Accept(playerid,slot);

		if (result == ORDER_OK)
		{
			Subtitle_Show(playerid,sprintf("~w~You take the errand. Bring it to the ~y~%s~w~.",giver));
		}

		Orders_Explain(playerid,result);
	}
	else if (pick == ORDERS_PICK_DELIVER)
	{
		Orders_Explain(playerid,Orders_Abandon(playerid,slot));
	}
}

stock Orders_ReadContract(playerid,slot)
{
	if (!Contracts_IsValid(slot))
	{
		Gui_Notify(playerid,g_OrderResultTexts[ORDER_GONE]);
		return;
	}

	new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), text[64], poster[ORDERS_POSTER_LEN], title[48], line[96], money[24], Float:x, Float:y, Float:width, characterid = Character_GetId(playerid), hours = max(0,(Contracts_GetExpires(slot) - gettime()) / 3600);
	Contracts_FormatText(slot,text);
	Contracts_GetPosterName(slot,poster);
	format(title,sizeof(title),"%s wants",poster);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,ORDERS_PANEL_WIDTH,8.0 * KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Orders_Money(Contracts_GetPay(slot),money);
	format(line,sizeof(line),"Pays %s, held by the board until it's done. Up for %d more hours.",money,hours);
	Kit_AddText(playerid,x,y + KIT_ROW * 1.2,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddText(playerid,x,y + KIT_ROW * 2.2,"Deliver at any notice board: the goods go to them, the coin to you.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (Contracts_GetPoster(slot) == characterid)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,Contracts_GetTaker(slot) == 0 ? ("Take it down and have your coin back") : ("Someone has taken it: it waits for them"),ORDERS_PICK_CONTRACT,Contracts_GetTaker(slot) == 0 ? KIT_COLOUR_BAD : KIT_COLOUR_MUTED);
	}
	else if (Contracts_GetTaker(slot) == characterid)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Deliver it here",ORDERS_PICK_DELIVER + 1,KIT_COLOUR_GOOD);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 5.0,width,"Drop this contract",ORDERS_PICK_DELIVER,KIT_COLOUR_BAD);
	}
	else if (Contracts_GetTaker(slot) == 0)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Take this contract",ORDERS_PICK_TAKE,KIT_COLOUR_GOOD);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 6.5 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	switch (pick)
	{
		case ORDERS_PICK_TAKE: Orders_Explain(playerid,Contracts_Take(playerid,slot));
		case ORDERS_PICK_DELIVER: Orders_Explain(playerid,Contracts_Drop(playerid,slot));
		case ORDERS_PICK_DELIVER + 1:
		{
			new result = Contracts_Deliver(playerid,slot);

			if (result == ORDER_OK)
			{
				Subtitle_Show(playerid,sprintf("~w~You deliver %s and take ~y~%s~w~ from the board.",text,money));
			}

			Orders_Explain(playerid,result);
		}
		case ORDERS_PICK_CONTRACT:
		{
			if (Contracts_GetTaker(slot) == 0)
			{
				Orders_Explain(playerid,Contracts_Cancel(playerid,slot));
			}
		}
	}
}

stock Orders_ComposeContract(playerid)
{
	new token = Account_GetToken(playerid), text[32], item, qty, pay;

	if (!Orders_AskText(playerid,token,"A contract","What do you want? Write the goods' name, like Charcoal or Wheat sack.",text,28))
	{
		return;
	}

	item = Contracts_FindItem(text);

	if (item == -1)
	{
		Gui_Notify(playerid,"No goods go by that name.");
		return;
	}

	new name[32], prompt[96];
	Item_GetName(Item_GetDefKind(item),item,name);
	format(prompt,sizeof(prompt),"How many %s? From 1 to %d.",name,ORDERS_CONTRACT_QTY_MAX);
	qty = Orders_AskNumber(playerid,token,"A contract",prompt,1,ORDERS_CONTRACT_QTY_MAX);

	if (qty == cellmin)
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"At what stars?");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,200.0,7.0 * KIT_ROW + 12.0,"At what stars?",x,y,width);

	for (new stars = ITEM_STARS_MIN;stars <= ITEM_STARS_MAX;stars++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(stars - 1),width,stars == ITEM_STARS_MIN ? ("Any") : sprintf("%d stars or better",stars),stars);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 5.5 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new stars = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || stars == KIT_BACK || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	new money[24];
	Orders_Money(qty * Item_GetPrice(Item_GetDefKind(item),item,stars),money);
	format(prompt,sizeof(prompt),"What do you pay, in pfennig? They're worth about %s. It leaves your purse now.",money);
	pay = Orders_AskNumber(playerid,token,"A contract",prompt,1,ORDERS_CONTRACT_PAY_MAX);

	if (pay == cellmin)
	{
		return;
	}

	new result = Contracts_Post(playerid,item,qty,stars,pay);

	if (result == ORDER_OK)
	{
		Orders_Money(pay,money);
		Subtitle_Show(playerid,sprintf("~w~Your contract is up for %d days. ~y~%s~w~ is held until it's done.",ORDERS_CONTRACT_DAYS,money));
		return;
	}

	Orders_Explain(playerid,result);
}

stock bool:Orders_TaskNear(playerid,actor)
{
	new Float:x, Float:y, Float:z;
	return actor != -1 && !Actors_IsDead(actor) && Actors_GetPos(actor,x,y,z) && GetPlayerVirtualWorld(playerid) == Actors_GetWorld(actor) && IsPlayerInRangeOfPoint(playerid,200.0,x,y,z);
}

stock Orders_TaskDestination(playerid,actor,dest[],size = sizeof(dest))
{
	new name[ACTORS_NAME_LEN], Float:x, Float:y, Float:z, Float:px, Float:py, Float:pz, way[12];
	Actors_GetName(actor,name);

	if (!Actors_GetPos(actor,x,y,z))
	{
		strcopy(dest,"Return to the person who asked you.",size);
		return;
	}

	GetPlayerPos(playerid,px,py,pz);
	Ledger_Compass(px,py,x,y,way);
	format(dest,size,"To %s | %.0f m %s",name,VectorSize(x - px,y - py,0.0),way);
}

stock bool:Orders_FormatTask(playerid,kind,ref,text[],destination[],reward[],size = ORDERS_TASK_TEXT)
{
	text[0] = EOS;
	destination[0] = EOS;
	reward[0] = EOS;
	new money[32], goods[ORDERS_LEDGER_LEN], name[ACTORS_NAME_LEN];

	switch (kind)
	{
		case ORDERS_ENTRY_ORDER:
		{
			if (!Orders_IsValid(ref) || Orders_GetExpires(ref) < Orders_Today())
			{
				return false;
			}

			Orders_FormatText(ref,goods);
			Actors_GetName(Orders_GetGiver(ref),name);
			format(text,size,"%s for %s",goods,name);
			Orders_TaskDestination(playerid,Orders_GetGiver(ref),destination,size);
			Economy_Format(Orders_GetPay(ref),money);
			format(reward,size,"%d stars or better | About %s | %d game days left",Orders_GetStars(ref),money,max(0,Orders_GetExpires(ref) - Orders_Today()));
		}
		case ORDERS_ENTRY_CONTRACT:
		{
			if (!Contracts_IsValid(ref) || Contracts_GetExpires(ref) <= gettime())
			{
				return false;
			}

			Contracts_FormatText(ref,goods);
			Contracts_GetPosterName(ref,name);
			format(text,size,"%s for %s",goods,name);
			strcopy(destination,"Deliver at any notice board.",size);
			Economy_Format(Contracts_GetPay(ref),money);
			format(reward,size,"%s | %d h %d min left",money,max(0,Contracts_GetExpires(ref) - gettime()) / 3600,max(0,Contracts_GetExpires(ref) - gettime()) / 60 % 60);
		}
		case ORDERS_ENTRY_FAMILY:
		{
			Families_FormatLedger(playerid,ref,text,destination,reward,size);
		}
		case ORDERS_ENTRY_DUTY, ORDERS_ENTRY_OWED:
		{
			Orders_DutyText(ref,text,size);
			strcopy(destination,"Bring the goods to the giver in person.",size);
			Economy_Format(Orders_DutyPay(ref),money);
			if (kind == ORDERS_ENTRY_OWED)
			{
				strcopy(reward,"No pay | Unpaid tax from an earlier season",size);
			}
			else
			{
				format(reward,size,"Up to %s + goodwill | This season",money);
			}
		}
		case ORDERS_ENTRY_NOTE:
		{
			Trade_GetName(ref,goods);
			format(text,size,"Steward's trial: %s (%d of %d)",goods,min(Orders_GetTrial(playerid,ref),ORDERS_TRIAL_NEEDED),ORDERS_TRIAL_NEEDED);
			strcopy(destination,"Steward at the ducal fortress. Deliver three-star orders.",size);
			format(reward,size,"Craftsman's warrant | Level %d and petition fee required",ORDERS_TRIAL_LEVEL);
		}
		case ORDERS_ENTRY_GOAL, ORDERS_ENTRY_SUGGESTION:
		{
			if (!Ledger_IsValid(playerid,ref))
			{
				return false;
			}

			Ledger_GetText(playerid,ref,text,size);
			strcopy(destination,"Your own goal or a suggestion from someone you've met.",size);
			strcopy(reward,"No promised reward or deadline.",size);

			if (Ledger_GetDue(playerid,ref) >= 0)
			{
				format(reward,size,"%d game days left",max(0,Ledger_GetDue(playerid,ref) - Orders_Today()));
			}
		}
		default:
		{
			return false;
		}
	}

	return text[0] != EOS;
}

stock Orders_BuildLedger(playerid,bool:suggested = false)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	Orders_ListReset(playerid,suggested ? 3 : 2);

	if (Character_GetId(playerid) <= 0)
	{
		return;
	}

	new characterid = Character_GetId(playerid);
	new family = Families_GetErrand(playerid);

	if (!suggested && family != -1)
	{
		Orders_ListAdd(ORDERS_ENTRY_FAMILY,family);
	}

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		new taker = Orders_GetTaker(slot), key[ACTORS_KEY_LEN];
		Orders_GetGiverKey(slot,key);

		if (!Orders_IsValid(slot) || Orders_GetExpires(slot) < Orders_Today() || (suggested ? taker != 0 : taker != characterid))
		{
			continue;
		}

		if (suggested && (!Orders_TaskNear(playerid,Orders_GetGiver(slot)) || Orders_GetGoodwillByKey(playerid,key) < Orders_GetGoodwillNeeded(slot)))
		{
			continue;
		}

		Orders_ListAdd(ORDERS_ENTRY_ORDER,slot);
	}

	for (new slot = 0;slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (!Contracts_IsValid(slot) || Contracts_GetExpires(slot) <= gettime() || (suggested ? (Contracts_GetTaker(slot) != 0 || Contracts_GetPoster(slot) == characterid) : Contracts_GetTaker(slot) != characterid))
		{
			continue;
		}

		Orders_ListAdd(ORDERS_ENTRY_CONTRACT,slot);
	}

	for (new duty = 0;duty < Orders_DutyCount();duty++)
	{
		if (!suggested && Orders_IsDutyOwed(playerid,duty))
		{
			Orders_ListAdd(ORDERS_ENTRY_OWED,duty);
		}
		else if (suggested && Orders_IsDutyOpen(duty) && Orders_GetDutyState(playerid,duty) != ORDER_DUTY_DONE && !Orders_IsDutyOwed(playerid,duty))
		{
			Orders_ListAdd(ORDERS_ENTRY_DUTY,duty);
		}
	}

	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		if (!Orders_HasWarrant(playerid,trade) && Orders_GetTrial(playerid,trade) > 0 && !suggested)
		{
			Orders_ListAdd(ORDERS_ENTRY_NOTE,trade);
		}
	}

	for (new row = 0;row < LEDGER_ROWS;row++)
	{
		if (Ledger_GetKind(playerid,row) == (suggested ? LEDGER_SUGGESTION : LEDGER_GOAL) && !Ledger_IsDone(playerid,row))
		{
			Orders_ListAdd(suggested ? ORDERS_ENTRY_SUGGESTION : ORDERS_ENTRY_GOAL,row);
		}
	}

	for (new errand = 0;suggested && errand < FAMILY_SEED_ERRANDS;errand++)
	{
		if (Families_IsErrandAvailable(playerid,errand) && Orders_TaskNear(playerid,Families_GetErrandGiver(errand)))
		{
			Orders_ListAdd(ORDERS_ENTRY_FAMILY,errand);
		}
	}
}

stock bool:Orders_LedgerHas(playerid,kind,ref,bool:suggested = false)
{
	Orders_BuildLedger(playerid,suggested);

	for (new i = 0;i < Orders_GetListCount(playerid);i++)
	{
		new foundKind, foundRef;
		Orders_GetListEntry(playerid,i,foundKind,foundRef);

		if (kind == foundKind && ref == foundRef)
		{
			return true;
		}
	}

	return false;
}

stock Orders_ReadTask(playerid,kind,ref,bool:suggested)
{
	new text[ORDERS_TASK_TEXT], destination[ORDERS_TASK_TEXT], reward[ORDERS_TASK_TEXT];

	if (!Orders_LedgerHas(playerid,kind,ref,suggested) || !Orders_FormatTask(playerid,kind,ref,text,destination,reward))
	{
		Gui_Notify(playerid,"That task has ended or is no longer available. Check the Ledger again.");
		return;
	}

	if (kind == ORDERS_ENTRY_GOAL || kind == ORDERS_ENTRY_SUGGESTION)
	{
		Orders_EditLedgerRow(playerid,ref);
		return;
	}

	new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), identity = 0, Float:x, Float:y, Float:width;

	if (kind == ORDERS_ENTRY_ORDER)
	{
		identity = Orders_GetId(ref);
	}
	else if (kind == ORDERS_ENTRY_CONTRACT)
	{
		identity = Contracts_GetId(ref);
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Task details");
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,ORDERS_LEDGER_WIDTH,122.0,"Task details",x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddText(playerid,x,y + 24.0,destination,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddText(playerid,x,y + 48.0,reward,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (suggested)
	{
		if (kind == ORDERS_ENTRY_FAMILY)
		{
			Orders_TaskDestination(playerid,Families_GetErrandGiver(ref),destination);
			format(text,sizeof(text),"Press ~y~Y~w~ to ask. %s",destination);
		}
		else if (kind == ORDERS_ENTRY_NOTE)
		{
			strcopy(text,"Press ~y~Y~w~ at the steward and choose a craftsman's warrant.");
		}
		else if (kind == ORDERS_ENTRY_DUTY)
		{
			strcopy(text,"Press ~y~Y~w~ at the giver and choose Errands to hand it in.");
		}
		else
		{
			strcopy(text,"Take this task here. Bring the goods to the destination above.");
		}

		Kit_AddText(playerid,x,y + 72.0,text,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		if (kind == ORDERS_ENTRY_ORDER || kind == ORDERS_ENTRY_CONTRACT)
		{
			Kit_AddChoice(playerid,x,y + 96.0,width,"Take this task",1,KIT_COLOUR_GOOD);
		}
	}
	else if (kind == ORDERS_ENTRY_ORDER || kind == ORDERS_ENTRY_CONTRACT || kind == ORDERS_ENTRY_FAMILY)
	{
		Kit_AddText(playerid,x,y + 72.0,kind == ORDERS_ENTRY_FAMILY ? ("Giving up pays nothing. Your parcel is removed if you are carrying one.") : ("Giving up pays nothing. This task becomes available to other players."),KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		Kit_AddChoice(playerid,x,y + 96.0,width,"Give up this task",2,KIT_COLOUR_BAD);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 114.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	Kit_Close(playerid);

	if (!Orders_LedgerHas(playerid,kind,ref,suggested) || (kind == ORDERS_ENTRY_ORDER && Orders_GetId(ref) != identity) || (kind == ORDERS_ENTRY_CONTRACT && Contracts_GetId(ref) != identity))
	{
		return;
	}

	if (pick == 1 && suggested)
	{
		new result = ORDER_BAD_INPUT;

		if (kind == ORDERS_ENTRY_ORDER)
		{
			result = Orders_Accept(playerid,ref);
		}
		else if (kind == ORDERS_ENTRY_CONTRACT)
		{
			result = Contracts_Take(playerid,ref);
		}

		Orders_Explain(playerid,result);

		if (result == ORDER_OK)
		{
			Gui_Notify(playerid,"Task accepted. You'll find it in Ledger > Your tasks.");
		}
	}
	else if (pick == 2 && !suggested)
	{
		switch (kind)
		{
			case ORDERS_ENTRY_ORDER: Orders_Explain(playerid,Orders_Abandon(playerid,ref));
			case ORDERS_ENTRY_CONTRACT: Orders_Explain(playerid,Contracts_Drop(playerid,ref));
			case ORDERS_ENTRY_FAMILY: Families_GiveUpErrand(playerid);
		}
	}
}

stock Orders_OpenLedger(playerid,page = 0)
{
	new bool:suggested = false, sessionToken = Account_GetToken(playerid), characterid = Character_GetId(playerid);

	for (;;)
	{
		if (!Session_IsPlaying(playerid) || Account_GetToken(playerid) != sessionToken || Character_GetId(playerid) != characterid)
		{
			return;
		}

		new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), Float:x, Float:y, Float:width, perPage = 2;
		Orders_BuildLedger(playerid,suggested);
		new entries[ORDERS_LIST_MAX][E_ORDERS_ENTRY], count = Orders_ListSnapshot(playerid,entries);
		new pages = max(1,(count + perPage - 1) / perPage);
		page = clamp(page,0,pages - 1);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Ledger");
		Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,ORDERS_LEDGER_WIDTH,148.0,"Ledger",x,y,width);
		Kit_AddButton(playerid,x,y,100.0,"Your tasks",ORDERS_LEDGER_TASKS,suggested ? KIT_COLOUR_MUTED : KIT_COLOUR_ACCENT);
		Kit_AddButton(playerid,x + 110.0,y,100.0,"Suggested",ORDERS_LEDGER_SUGGESTED,suggested ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		new Float:top = y + 18.0;

		if (count == 0)
		{
			Kit_AddText(playerid,x,top,suggested ? ("No open tasks nearby. Visit a household, innkeeper or notice board.") : ("You haven't accepted any tasks. Click Suggested to find work, or speak to a household or innkeeper with Y."),KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		for (new row = 0, i = page * perPage;row < perPage && i < count;row++, i++)
		{
			new kind = entries[i][E_ORDERS_ENTRY_KIND], ref = entries[i][E_ORDERS_ENTRY_REF], text[ORDERS_TASK_TEXT], destination[ORDERS_TASK_TEXT], reward[ORDERS_TASK_TEXT];
			Orders_FormatTask(playerid,kind,ref,text,destination,reward);
			new Float:rowY = top + 56.0 * float(row);
			Kit_AddHit(playerid,x - 3.0,rowY - 1.0,width + 6.0,52.0,ORDERS_PICK_ENTRY + i);
			Kit_AddText(playerid,x,rowY,text,KIT_COLOUR_ACCENT,0.72,TEXT_DRAW_FONT_1,false,width);
			Kit_AddText(playerid,x,rowY + 20.0,destination,KIT_COLOUR_TEXT,0.72,TEXT_DRAW_FONT_1,false,width);
			Kit_AddText(playerid,x,rowY + 40.0,reward,KIT_COLOUR_MUTED,0.72,TEXT_DRAW_FONT_1,false,width);
		}

		new Float:footY = y + 136.0;

		if (page > 0)
		{
			Kit_AddButton(playerid,x,footY,45.0,"Earlier",ORDERS_PICK_PREV);
		}

		if (page < pages - 1)
		{
			Kit_AddButton(playerid,x + width - 45.0,footY,45.0,"More",ORDERS_PICK_NEXT);
		}

		Kit_AddButton(playerid,x + 55.0,footY,85.0,"Your goals",ORDERS_PICK_WRITE);
		Kit_AddButton(playerid,x + 150.0,footY,55.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		Kit_Close(playerid);

		switch (pick)
		{
			case KIT_BACK:
			{
				return;
			}
			case ORDERS_LEDGER_TASKS: { suggested = false; page = 0; }
			case ORDERS_LEDGER_SUGGESTED: { suggested = true; page = 0; }
			case ORDERS_PICK_PREV: page--;
			case ORDERS_PICK_NEXT: page++;
			case ORDERS_PICK_WRITE: Orders_OpenGoals(playerid);
			default:
			{
				new chosen = pick - ORDERS_PICK_ENTRY;

				if (chosen >= 0 && chosen < count)
				{
					Orders_ReadTask(playerid,entries[chosen][E_ORDERS_ENTRY_KIND],entries[chosen][E_ORDERS_ENTRY_REF],suggested);
				}
			}
		}
	}
}

stock Orders_OpenGoals(playerid,page = 0)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), rows[ORDERS_LEDGER_MAX], count = 0, Float:x, Float:y, Float:width;

		for (new row = 0;row < LEDGER_ROWS;row++)
		{
			if (Ledger_GetKind(playerid,row) == LEDGER_GOAL && count < sizeof(rows))
			{
				rows[count++] = row;
			}
		}

		page = clamp(page,0,max(0,(count - 1) / 4));
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your goals");
		Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,ORDERS_LEDGER_WIDTH,148.0,"Your goals",x,y,width);
		new chores[128], moon[72];
		Ledger_FormatChores(playerid,chores);
		Ledger_FormatMoon(moon);
		Kit_AddText(playerid,x,y,chores,KIT_COLOUR_MUTED,0.72,TEXT_DRAW_FONT_1,false,width);
		Kit_AddText(playerid,x,y + 20.0,moon,KIT_COLOUR_MUTED,0.72,TEXT_DRAW_FONT_1,false,width);

		if (count == 0)
		{
			Kit_AddText(playerid,x,y + 40.0,"Click Write a goal to keep a note of something you want to do.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		for (new i = page * 4;i < count && i < page * 4 + 4;i++)
		{
			new text[ORDERS_LEDGER_LEN], line[ORDERS_LEDGER_LEN + 16], row = rows[i], Float:rowY = y + 40.0 + float(i % 4) * 20.0;
			Ledger_GetText(playerid,row,text);
			format(line,sizeof(line),"%s %s",Ledger_IsDone(playerid,row) ? ("[done]") : ("[ ]"),text);
			Kit_AddHit(playerid,x,rowY,width,18.0,row);
			Kit_AddText(playerid,x,rowY,line,KIT_COLOUR_TEXT,0.72,TEXT_DRAW_FONT_1,false,width);
		}

		Kit_AddButton(playerid,x + 50.0,y + 130.0,90.0,"Write a goal",ORDERS_PICK_WRITE);
		Kit_AddButton(playerid,x + 155.0,y + 130.0,50.0,GUI_BUTTON_BACK,KIT_BACK);

		if (page > 0)
		{
			Kit_AddButton(playerid,x,y + 130.0,45.0,"Earlier",ORDERS_PICK_PREV);
		}

		if ((page + 1) * 4 < count)
		{
			Kit_AddButton(playerid,x + width - 45.0,y + 130.0,45.0,"More",ORDERS_PICK_NEXT);
		}

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		Kit_Close(playerid);

		switch (pick)
		{
			case KIT_BACK: return;
			case ORDERS_PICK_PREV: page--;
			case ORDERS_PICK_NEXT: page++;
			case ORDERS_PICK_WRITE: Orders_WriteGoal(playerid);
			default: Orders_EditLedgerRow(playerid,pick);
		}
	}
}

stock Orders_WriteGoal(playerid)
{
	new token = Account_GetToken(playerid), text[ORDERS_LEDGER_LEN];

	if (Ledger_Count(playerid,LEDGER_GOAL) >= ORDERS_LEDGER_MAX)
	{
		Gui_Notify(playerid,"Eight goals are saved. Remove one under Your goals to write another.");
		return;
	}

	if (!Orders_AskText(playerid,token,"A goal","Write a goal in your own words: save for a mare, bake for the feast.",text,ORDERS_LEDGER_LEN - 1) || text[0] == EOS)
	{
		return;
	}

	new days = Orders_AskNumber(playerid,token,"A goal","By when, in days from today? Leave it empty for no date.",1,365);
	Ledger_Add(playerid,text,days == cellmin ? -1 : Orders_Today() + days);
}

stock Orders_EditLedgerRow(playerid,row)
{
	if (!Ledger_IsValid(playerid,row))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), text[ORDERS_LEDGER_LEN], Float:x, Float:y, Float:width, bool:isGoal = Ledger_GetKind(playerid,row) == LEDGER_GOAL;
	Ledger_GetText(playerid,row,text);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,isGoal ? ("A goal") : ("A suggestion"));
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,ORDERS_LEDGER_WIDTH,8.0 * KIT_ROW + 12.0,isGoal ? ("A goal") : ("A suggestion"),x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (isGoal)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,Ledger_IsDone(playerid,row) ? ("Not done after all") : ("Tick it off"),1,KIT_COLOUR_GOOD);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Remove it",2,KIT_COLOUR_BAD);
	}
	else
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,"Keep it as a goal",3,KIT_COLOUR_GOOD);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Dismiss it",2,KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 6.5 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	switch (pick)
	{
		case 1: Ledger_Tick(playerid,row);
		case 2: Ledger_Remove(playerid,row);
		case 3:
		{
			if (!Ledger_Keep(playerid,row))
			{
				Gui_Notify(playerid,"Eight goals are saved. Remove one under Your goals to write another.");
			}
		}
	}
}

stock Orders_OpenWarrant(playerid)
{
	new epoch = Gui_BeginFlow(playerid), token = Account_GetToken(playerid), Float:x, Float:y, Float:width, row = 0, line[160], right[24], money[24];
	Orders_Money(Orders_WarrantFee(),money);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"A craftsman's warrant");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,ORDERS_PANEL_WIDTH,float(ORDERS_BOARD_ROWS + 4) * KIT_ROW + 12.0,"A craftsman's warrant",x,y,width);

	if (!Realm_IsVacant())
	{
		Kit_AddText(playerid,x,y,"The count grants craftsmen's titles while he sits. Petition him.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}
	else
	{
		format(line,sizeof(line),"With no count, I grant a warrant by trial: three errands of the trade at three stars this season, level %d, and %s.",ORDERS_TRIAL_LEVEL,money);
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new trade = 0;trade < TRADE_COUNT && row < ORDERS_BOARD_ROWS;trade++)
		{
			new occupation = Orders_CraftOccupation(trade);

			if (occupation == -1 || (Orders_GetTrial(playerid,trade) == 0 && !Orders_HasWarrant(playerid,trade)))
			{
				continue;
			}

			new name[24];
			Occupation_GetName(occupation,name);

			if (Orders_HasWarrant(playerid,trade))
			{
				strcopy(right,"granted");
			}
			else
			{
				format(right,sizeof(right),"%d of %d, level %d",min(Orders_GetTrial(playerid,trade),ORDERS_TRIAL_NEEDED),ORDERS_TRIAL_NEEDED,Work_GetLevel(playerid,trade));
			}

			Kit_AddChoice(playerid,x,y + KIT_ROW * float(row + 2),width,name,ORDERS_PICK_WARRANT + trade,Orders_CanAskWarrant(playerid,trade) == ORDER_OK ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,right,KIT_COLOUR_ACCENT,0.35);
			row++;
		}

		if (row == 0)
		{
			Kit_AddText(playerid,x,y + KIT_ROW * 2.0,"You haven't delivered an errand at three stars this season.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(ORDERS_BOARD_ROWS + 3) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	new trade = pick - ORDERS_PICK_WARRANT, result = Orders_GrantWarrant(playerid,trade);

	if (result == ORDER_OK)
	{
		new name[24];
		Occupation_GetName(Orders_CraftOccupation(trade),name);
		Subtitle_Show(playerid,sprintf("~w~The steward writes you a warrant as a ~y~%s~w~.",name));
		return;
	}

	if (result == ORDER_GOODWILL)
	{
		Gui_Notify(playerid,sprintf("Not yet: three errands of the trade at three stars this season, and level %d.",ORDERS_TRIAL_LEVEL));
		return;
	}

	Orders_Explain(playerid,result);
}

forward Orders_MenuErrands(playerid,index,data);

public Orders_MenuErrands(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && Orders_GiverKindOf(index) != -1)
	{
		Orders_OpenErrands(playerid,index);
	}

	return 1;
}

forward Orders_MenuWarrant(playerid,index,data);

public Orders_MenuWarrant(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && index == Realm_GetSteward())
	{
		Orders_OpenWarrant(playerid);
	}

	return 1;
}

forward Orders_BoardDeferred(playerid);

public Orders_BoardDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Orders_OpenBoard(playerid,0);
	}

	return 1;
}

forward Orders_LedgerDeferred(playerid);

public Orders_LedgerDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Orders_OpenLedger(playerid,0);
	}

	return 1;
}

forward Orders_TutorialTipDeferred(playerid,token);

public Orders_TutorialTipDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Ledger_Suggest(playerid,"Read the Work tab of a notice board and take one errand.");
	}

	return 1;
}

#include <pp-hooks>

hook Actors_OnMenuBuild(playerid,index)
{
	if (index == -1 || Actors_IsDead(index))
	{
		return;
	}

	if (Orders_IsGiver(index))
	{
		new count = Orders_CountErrandsAt(playerid,index);
		Actors_MenuAdd(playerid,count > 0 ? sprintf("Errands (%d)",count) : ("Errands"),"Orders_MenuErrands",0,count > 0 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT);
	}

	if (index == Realm_GetSteward())
	{
		Actors_MenuAdd(playerid,"A craftsman's warrant","Orders_MenuWarrant");
	}
}

hook Notices_OnWorkTab(playerid)
{
	SetTimerEx("Orders_BoardDeferred",0,false,"d",playerid);
}

hook CharPanel_OnLedger(playerid)
{
	SetTimerEx("Orders_LedgerDeferred",0,false,"d",playerid);
}
