#define CRAFT_WIDTH (400.0)
#define CRAFT_TOP (112.0)
#define CRAFT_LIST_SHARE (0.36)
#define CRAFT_BUILD (900)
#define CRAFT_LEARN (901)
#define CRAFT_TAB_STATIONS (902)
#define CRAFT_TAB_TALENTS (903)
#define CRAFT_TAB_BY_HAND (904)
#define CRAFT_MAKE (905)
#define CRAFT_PAGE_PREV (906)
#define CRAFT_PAGE_NEXT (907)
#define CRAFT_PROPS (908)
#define CRAFT_DETAIL_ROWS (14)
#define CRAFT_LIST_ROWS (CRAFT_DETAIL_ROWS + 1)

enum
{
	CRAFT_TAB_BUILD,
	CRAFT_TAB_TREE,
	CRAFT_TAB_HAND,
}

static s_CraftOpenGate[MAX_PLAYERS][32];

static Craft_KindOfNode(node)
{
	new key[TALENT_KEY_LEN];
	Talent_GetNodeKey(node,key);
	return Work_FindKind(key);
}

static Craft_JoinFuels(kind,dest[],size)
{
	new name[ITEM_NAME_LEN];
	dest[0] = EOS;

	for (new i = 0;i < WORK_FUEL_MAX;i++)
	{
		new item = Work_GetFuelItem(kind,i);

		if (item < 0)
		{
			continue;
		}

		Item_GetName(Item_GetDefKind(item),item,name);

		if (dest[0] != EOS)
		{
			strcat(dest,", ",size);
		}

		strcat(dest,name,size);
	}
}

static Craft_JoinRecipes(kind,dest[],size)
{
	new recipes[WORK_MENU_MAX], count = Work_GetRecipesForKind(kind,recipes), name[RECIPE_NAME_LEN];
	dest[0] = EOS;

	for (new i = 0;i < count;i++)
	{
		Recipe_GetName(recipes[i],name);

		if (dest[0] != EOS)
		{
			strcat(dest,", ",size);
		}

		strcat(dest,name,size);
	}

	if (dest[0] == EOS)
	{
		strcopy(dest,"nothing yet",size);
	}
}

static Craft_JoinChildren(node,dest[],size)
{
	new name[TALENT_NAME_LEN];
	dest[0] = EOS;

	for (new other = 0;other < Talent_GetNodeCount();other++)
	{
		if (Talent_GetNodeParent(other) != node)
		{
			continue;
		}

		Talent_GetNodeName(other,name);

		if (dest[0] != EOS)
		{
			strcat(dest,", ",size);
		}

		strcat(dest,name,size);
	}

	if (dest[0] == EOS)
	{
		strcopy(dest,"nothing further",size);
	}
}

static Craft_JoinReveals(node,dest[],size)
{
	new reveals[TALENT_REVEALS_LEN], key[WORK_KIND_KEY_LEN], name[WORK_KIND_NAME_LEN], start = 0, length;
	Talent_GetNodeReveals(node,reveals);
	length = strlen(reveals);
	dest[0] = EOS;

	for (new i = 0;i <= length;i++)
	{
		if (reveals[i] != ',' && reveals[i] != EOS)
		{
			continue;
		}

		strmid(key,reveals,start,i);
		start = i + 1;
		Work_GetKindName(Work_FindKind(key),name);

		if (name[0] == EOS)
		{
			continue;
		}

		if (dest[0] != EOS)
		{
			strcat(dest,", ",size);
		}

		strcat(dest,name,size);
	}
}

static Craft_DrawStationDetail(playerid,node,Float:x,Float:y,Float:width)
{
	new kind = Craft_KindOfNode(node), name[TALENT_NAME_LEN], trade[JOB_NAME_LEN], line[160], row = 0, bool:isKnown = Talent_Owns(playerid,node);
	Talent_GetNodeName(node,name);
	Trade_GetName(Talent_GetNodeTrade(node),trade);
	Kit_AddText(playerid,x,y,name,KIT_COLOUR_ACCENT,KIT_TEXT_BODY,TEXT_DRAW_FONT_1,false,width);
	row += 2;
	format(line,sizeof(line),"%s  -  you keep %d of %d",trade,Work_CountOwnedStations(Character_GetId(playerid)),WORK_OWNED_CAP);
	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (!isKnown)
	{
		format(line,sizeof(line),"Learn it in Talents first (%d points).",Talent_GetNextCost(playerid));
		Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_BAD,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	row++;
	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,"Needs",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
	{
		if (!Work_GetBuildMaterial(kind,i,item,amount))
		{
			continue;
		}

		new have = Inventory_Count(playerid,Item_GetDefKind(item),item), itemName[ITEM_NAME_LEN];
		Item_GetName(Item_GetDefKind(item),item,itemName);
		format(line,sizeof(line),"%d/%d  %s",min(have,amount),amount,itemName);
		Kit_AddText(playerid,x + 6.0,y + float(row++) * KIT_ROW,line,have >= amount ? KIT_COLOUR_GOOD : KIT_COLOUR_BAD,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width - 6.0);
	}

	row++;
	Craft_JoinFuels(kind,line,sizeof(line));
	format(line,sizeof(line),Work_IsFireKind(kind) ? ("Burns: %s") : ("Upkeep: %s"),line);
	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Craft_JoinRecipes(kind,line,sizeof(line));
	format(line,sizeof(line),"Makes: %s",line);
	Kit_AddText(playerid,x,y + float(row) * KIT_ROW,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (isKnown)
	{
		new reason[96], bool:canBuild = Work_CanPlaceKind(playerid,kind,reason);
		Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + float(CRAFT_DETAIL_ROWS) * KIT_ROW,90.0,"Build it",CRAFT_BUILD,canBuild ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);

		if (!canBuild)
		{
			Kit_AddText(playerid,x + width / 2.0,y + (float(CRAFT_DETAIL_ROWS) + 1.3) * KIT_ROW,reason,KIT_COLOUR_BAD,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,true,width);
		}
	}
}

static Craft_DrawTalentDetail(playerid,node,Float:x,Float:y,Float:width)
{
	new name[TALENT_NAME_LEN], trade[JOB_NAME_LEN], line[160], row = 0, status = Talent_CheckUnlock(playerid,node), tradeId = Talent_GetNodeTrade(node);
	Talent_GetNodeName(node,name);
	Trade_GetName(tradeId,trade);
	Kit_AddText(playerid,x,y,name,KIT_COLOUR_ACCENT,KIT_TEXT_BODY,TEXT_DRAW_FONT_1,false,width);
	row += 2;
	if (Talent_IsStationNode(node))
	{
		format(line,sizeof(line),"%s  -  builds the %s",trade,name);
		Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}
	else
	{
		new kinds[96];
		Craft_JoinReveals(node,kinds,sizeof(kinds));
		format(line,sizeof(line),"%s  -  sparks on %s",trade,kinds);
		Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		row++;
		Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,"Sparks show which ones still have something to gather.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	row++;

	switch (status)
	{
		case TALENT_UNLOCK_OWNED: strcopy(line,"You've learned this.");
		case TALENT_UNLOCK_OK: format(line,sizeof(line),"Costs %d of your %d points.",Talent_GetNextCost(playerid),Talent_GetPoints(playerid));
		case TALENT_UNLOCK_POINTS: format(line,sizeof(line),"Costs %d points. You have %d.",Talent_GetNextCost(playerid),Talent_GetPoints(playerid));
		default:
		{
			new parent[TALENT_NAME_LEN];
			Talent_GetNodeName(Talent_GetNodeParent(node),parent);
			format(line,sizeof(line),"Learn the %s first.",parent);
		}
	}

	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,status == TALENT_UNLOCK_OWNED ? KIT_COLOUR_GOOD : (status == TALENT_UNLOCK_OK ? KIT_COLOUR_TEXT : KIT_COLOUR_BAD),KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (status != TALENT_UNLOCK_OWNED)
	{
		format(line,sizeof(line),"%s can then reach level %d (now %d).",trade,min(TALENT_LEVEL_MAX,Talent_GetTradeLevelCap(playerid,tradeId) + TALENT_LEVEL_PER_NODE),Talent_GetTradeLevelCap(playerid,tradeId));
		Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	row++;
	Craft_JoinChildren(node,line,sizeof(line));
	format(line,sizeof(line),"Leads to: %s",line);
	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	format(line,sizeof(line),"Next point in %d min of playtime.",Talent_GetMinutesToNextPoint(playerid));
	Kit_AddText(playerid,x,y + float(row + 1) * KIT_ROW,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (status == TALENT_UNLOCK_OK)
	{
		Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + float(CRAFT_DETAIL_ROWS) * KIT_ROW,90.0,"Learn it",CRAFT_LEARN,KIT_COLOUR_ACCENT);
	}
}

static Craft_GetHandLabel(hand,dest[],size)
{
	new item, amount, name[ITEM_NAME_LEN];
	Work_GetHandOutput(hand,item,amount);
	Item_GetName(Item_GetDefKind(item),item,name);

	if (amount > 1)
	{
		format(dest,size,"%d %s",amount,name);
	}
	else
	{
		strcopy(dest,name,size);
	}
}

static Craft_DrawHandDetail(playerid,hand,Float:x,Float:y,Float:width)
{
	new label[48], line[160], row = 0, item, amount;
	Craft_GetHandLabel(hand,label,sizeof(label));
	Work_GetHandOutput(hand,item,amount);
	Kit_AddText(playerid,x,y,label,KIT_COLOUR_ACCENT,KIT_TEXT_BODY,TEXT_DRAW_FONT_1,false,width);
	row += 2;
	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,"You make this by hand, anywhere.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	row++;
	Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,"Needs",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	for (new slot = 0, input, need;slot < WORK_HAND_INPUTS;slot++)
	{
		if (!Work_GetHandInput(hand,slot,input,need))
		{
			continue;
		}

		new have = Inventory_Count(playerid,Item_GetDefKind(input),input), name[ITEM_NAME_LEN];
		Item_GetName(Item_GetDefKind(input),input,name);
		format(line,sizeof(line),"%d/%d  %s",min(have,need),need,name);
		Kit_AddText(playerid,x + 6.0,y + float(row++) * KIT_ROW,line,have >= need ? KIT_COLOUR_GOOD : KIT_COLOUR_BAD,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width - 6.0);
	}

	new tool = Work_FindToolForCrude(item);

	if (tool != -1)
	{
		new toolName[ITEM_NAME_LEN];
		Item_GetName(Item_GetDefKind(tool),tool,toolName);
		row++;
		format(line,sizeof(line),"Works as a %s. Work done with it gets at most %d stars. It can also break.",toolName,WORK_CRUDE_STAR_CAP);
		Kit_AddText(playerid,x,y + float(row++) * KIT_ROW,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + float(CRAFT_DETAIL_ROWS) * KIT_ROW,90.0,"Make it",CRAFT_MAKE,Work_CanMakeByHand(playerid,hand) ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
}

stock Craft_SetOpenGate(playerid,const handler[])
{
	if (Util_IsValidPlayer(playerid))
	{
		strcopy(s_CraftOpenGate[playerid],handler,sizeof(s_CraftOpenGate[]));
	}
}

stock Craft_Open(playerid,tab = CRAFT_TAB_BUILD,selected = 0)
{
	new epoch = Gui_BeginFlow(playerid), bool:isFirst = true;

	for (;;)
	{
		if (!Talent_IsLoaded(playerid))
		{
			Gui_Notify(playerid,"Crafting is still loading. Try again in a moment.");
			return;
		}

		new count = tab == CRAFT_TAB_HAND ? Work_GetHandCount() : (tab == CRAFT_TAB_BUILD ? Talent_GetStationNodeCount() : Talent_GetNodeCount()), rows = CRAFT_LIST_ROWS + 3, name[TALENT_NAME_LEN], detail[24], title[48], Float:x, Float:y, Float:width;

		if (selected < 0 || selected >= count)
		{
			selected = 0;
		}

		new first = (selected / CRAFT_LIST_ROWS) * CRAFT_LIST_ROWS, last = min(first + CRAFT_LIST_ROWS,count);
		format(title,sizeof(title),"Crafting - %d talent point%s",Talent_GetPoints(playerid),Talent_GetPoints(playerid) == 1 ? ("") : ("s"));
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Crafting");
		Kit_AddPanel(playerid,320.0 - CRAFT_WIDTH / 2.0,CRAFT_TOP,CRAFT_WIDTH,float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0 + KIT_PANEL_EXTRA,title,x,y,width);

		new Float:listWidth = width * CRAFT_LIST_SHARE, Float:detailX = x + listWidth + 10.0, Float:detailWidth = width - listWidth - 10.0;
		Kit_AddBox(playerid,x + listWidth + 4.0,y,1.0,float(rows) * KIT_ROW,KIT_COLOUR_MUTED);

		for (new node = first;node < last;node++)
		{
			new colour = KIT_COLOUR_MUTED, labelColour = KIT_COLOUR_TEXT;
			Talent_GetNodeName(node,name);

			if (tab == CRAFT_TAB_HAND)
			{
				Craft_GetHandLabel(node,name,sizeof(name));
				new bool:canMake = Work_CanMakeByHand(playerid,node);
				strcopy(detail,canMake ? ("ready") : ("missing"));
				colour = canMake ? KIT_COLOUR_GOOD : KIT_COLOUR_BAD;
			}
			else if (tab == CRAFT_TAB_BUILD)
			{
				new materials[160], bool:hasAll, kind = Craft_KindOfNode(node);

				if (!Talent_Owns(playerid,node))
				{
					strcopy(detail,"locked");
					labelColour = KIT_COLOUR_MUTED;
				}
				else
				{
					Work_FormatMaterials(playerid,kind,materials,sizeof(materials),hasAll);
					strcopy(detail,hasAll ? ("ready") : ("missing"));
					colour = hasAll ? KIT_COLOUR_GOOD : KIT_COLOUR_BAD;
				}
			}
			else
			{
				switch (Talent_CheckUnlock(playerid,node))
				{
					case TALENT_UNLOCK_OWNED: { strcopy(detail,"yours"); colour = KIT_COLOUR_GOOD; }
					case TALENT_UNLOCK_OK: { format(detail,sizeof(detail),"%d pts",Talent_GetNextCost(playerid)); colour = KIT_COLOUR_ACCENT; }
					case TALENT_UNLOCK_POINTS: format(detail,sizeof(detail),"%d pts",Talent_GetNextCost(playerid));
					default: { strcopy(detail,"locked"); labelColour = KIT_COLOUR_MUTED; }
				}
			}

			Kit_AddChoice(playerid,x,y + float(node - first) * KIT_ROW,listWidth,name,node,node == selected ? KIT_COLOUR_ACCENT : labelColour,detail,colour,0.62);
		}

		if (count > CRAFT_LIST_ROWS)
		{
			new Float:pageY = y + float(CRAFT_LIST_ROWS) * KIT_ROW, page[16];
			format(page,sizeof(page),"%d of %d",first / CRAFT_LIST_ROWS + 1,(count + CRAFT_LIST_ROWS - 1) / CRAFT_LIST_ROWS);
			Kit_AddText(playerid,x,pageY,page,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,listWidth * 0.4);

			if (first > 0)
			{
				Kit_AddChoice(playerid,x + listWidth * 0.4,pageY,listWidth * 0.3,"< Back",CRAFT_PAGE_PREV,KIT_COLOUR_ACCENT);
			}

			if (last < count)
			{
				Kit_AddChoice(playerid,x + listWidth * 0.7,pageY,listWidth * 0.3,"More >",CRAFT_PAGE_NEXT,KIT_COLOUR_ACCENT);
			}
		}

		if (tab == CRAFT_TAB_HAND)
		{
			Craft_DrawHandDetail(playerid,selected,detailX,y,detailWidth);
		}
		else if (tab == CRAFT_TAB_BUILD)
		{
			Craft_DrawStationDetail(playerid,selected,detailX,y,detailWidth);
			Kit_AddChoice(playerid,detailX,y + (float(CRAFT_LIST_ROWS) + 1.8) * KIT_ROW,detailWidth,"Props around stations",CRAFT_PROPS,KIT_COLOUR_TEXT,Work_IsDressShown(playerid) ? ("shown") : ("hidden"),Work_IsDressShown(playerid) ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,0.62);
		}
		else
		{
			Craft_DrawTalentDetail(playerid,selected,detailX,y,detailWidth);
		}

		new Float:footerY = y + float(rows) * KIT_ROW + 8.0, tabLabel[32];
		format(tabLabel,sizeof(tabLabel),"Talents (%d)",Talent_GetPoints(playerid));
		Kit_AddButton(playerid,x,footerY,74.0,"By hand",CRAFT_TAB_BY_HAND,tab == CRAFT_TAB_HAND ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + 80.0,footerY,74.0,"Stations",CRAFT_TAB_STATIONS,tab == CRAFT_TAB_BUILD ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + 160.0,footerY,68.0,tabLabel,CRAFT_TAB_TALENTS,tab == CRAFT_TAB_TREE ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + width - 56.0,footerY,56.0,GUI_BUTTON_CLOSE,KIT_BACK);

		new Task:shown = Kit_Present(playerid);

		if (isFirst)
		{
			isFirst = false;
			pawn_call_public("Craft_OnOpened","d",playerid);
		}

		new pick = await shown;

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case CRAFT_TAB_BY_HAND: { tab = CRAFT_TAB_HAND; selected = 0; }
			case CRAFT_TAB_STATIONS: { tab = CRAFT_TAB_BUILD; selected = 0; }
			case CRAFT_TAB_TALENTS: { tab = CRAFT_TAB_TREE; selected = 0; }
			case CRAFT_PAGE_PREV: selected = max(first - CRAFT_LIST_ROWS,0);
			case CRAFT_PAGE_NEXT: selected = min(last,count - 1);
			case CRAFT_PROPS:
			{
				new bool:show = !Work_IsDressShown(playerid);
				Work_SetDressShown(playerid,show);
				Gui_Notify(playerid,show ? ("You see the props around stations again.") : ("You no longer see the props around stations. Other players still do."));
			}
			case CRAFT_MAKE:
			{
				new label[48];
				Craft_GetHandLabel(selected,label,sizeof(label));

				if (Work_MakeByHand(playerid,selected))
				{
					Gui_Notify(playerid,sprintf("You made %s%s.",label[0] >= '0' && label[0] <= '9' ? ("") : (Util_StartsWithVowel(label) ? ("an ") : ("a ")),label));
				}
				else
				{
					Gui_Notify(playerid,"You don't have the materials for that yet.");
				}
			}
			case CRAFT_BUILD:
			{
				new kind = Craft_KindOfNode(selected), reason[96];

				if (!Work_CanPlaceKind(playerid,kind,reason))
				{
					Gui_Notify(playerid,reason);
					continue;
				}

				Kit_Close(playerid);
				Work_BuildFlow(playerid,epoch,kind);
				return;
			}
			case CRAFT_LEARN:
			{
				if (Talent_Unlock(playerid,selected))
				{
					Talent_GetNodeName(selected,name);
					new message[160];

					if (Talent_IsStationNode(selected))
					{
						format(message,sizeof(message),"You learned the %s. You can build it from the Stations tab now.",name);
						tab = CRAFT_TAB_BUILD;
					}
					else
					{
						new kinds[96];
						Craft_JoinReveals(selected,kinds,sizeof(kinds));
						format(message,sizeof(message),"You learned the %s. Sparks now show where there's something to gather (%s).",name,kinds);
					}

					Gui_Notify(playerid,message);
				}
			}
			default:
			{
				if (pick >= 0 && pick < count)
				{
					selected = pick;
				}
			}
		}
	}
}

forward Craft_OnOpened(playerid);

public Craft_OnOpened(playerid)
{
	return 1;
}

forward Craft_OpenDeferred(playerid);

public Craft_OpenDeferred(playerid)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Work_IsWorking(playerid))
	{
		if (s_CraftOpenGate[playerid][0] != EOS)
		{
			new handler[32];
			strcopy(handler,s_CraftOpenGate[playerid]);
			s_CraftOpenGate[playerid][0] = EOS;
			CallLocalFunction(handler,"d",playerid);
			return;
		}

		Craft_Open(playerid);
	}
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CraftOpenGate[playerid][0] = EOS;
}
