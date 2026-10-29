#define INVENTORY_GUI_COLUMNS (6)
#define INVENTORY_GUI_GAP (3.0)
#define INVENTORY_GUI_WIDTH (230.0)
#define INVENTORY_GUI_ACTIONS_WIDTH (150.0)

#define INVENTORY_GUI_USE (1000)
#define INVENTORY_GUI_DROP (1001)
#define INVENTORY_GUI_PUT (1002)
#define INVENTORY_GUI_EXAMINE (1003)
#define INVENTORY_GUI_GIVE (1004)
#define INVENTORY_GUI_NEARBY_MAX (8)
#define INVENTORY_GUI_FACT_MAX (6)
#define INVENTORY_GUI_FACT_LEN (32)
#define INVENTORY_GUI_EXAMINE_WIDTH (200.0)
#define INVENTORY_GUI_BUTTON (1100)
#define INVENTORY_GUI_BUTTONS_MAX (4)
#define INVENTORY_GUI_BUTTON_LABEL_LEN (16)
#define INVENTORY_GUI_BUTTON_PUBLIC_LEN (32)

static s_InventoryButtonLabels[INVENTORY_GUI_BUTTONS_MAX][INVENTORY_GUI_BUTTON_LABEL_LEN];
static s_InventoryButtonPublics[INVENTORY_GUI_BUTTONS_MAX][INVENTORY_GUI_BUTTON_PUBLIC_LEN];
static s_InventoryButtonCount;
static bool:s_InventoryCloseAfterUse[MAX_PLAYERS];

stock bool:Inventory_AddMenuButton(const label[],const handler[])
{
	if (s_InventoryButtonCount >= INVENTORY_GUI_BUTTONS_MAX)
	{
		Log_Error("inventory","bag button table full - '%s' not registered",label);
		return false;
	}

	strcopy(s_InventoryButtonLabels[s_InventoryButtonCount],label);
	strcopy(s_InventoryButtonPublics[s_InventoryButtonCount],handler);
	s_InventoryButtonCount++;
	return true;
}

static InventoryGui_FormatItem(playerid,index,dest[],size = sizeof(dest))
{
	new E_ITEM_KIND:kind, param, amount;
	Inventory_GetSlot(playerid,index,kind,param,amount);
	Item_GetName(kind,param,dest,size);
	Item_AppendStars(dest,Inventory_GetSlotStars(playerid,index),size);
}

stock InventoryGui_AppendState(playerid,index,dest[],size = sizeof(dest))
{
	new left = Inventory_GetFreshLeft(playerid,index), wear = Inventory_GetSlotWear(playerid,index);

	if (left > 0)
	{
		format(dest,size,"%s  -  fresh for %d min",dest,(left + 59) / 60);
	}
	else if (left == 0)
	{
		format(dest,size,"%s  -  going off",dest);
	}

	if (wear > 0)
	{
		format(dest,size,"%s  -  %d%% worn",dest,wear);
	}
}

static bool:InventoryGui_IsWorn(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;
	Inventory_GetSlot(playerid,index,kind,param,amount);
	return (kind == ITEM_KIND_WEAPON && Combat_GetWeapon(playerid) == param) || (kind == ITEM_KIND_SHIELD && Combat_GetShield(playerid) == param);
}

static InventoryGui_GetAction(playerid,index,dest[],size = sizeof(dest))
{
	new E_ITEM_KIND:kind, param, amount;
	Inventory_GetSlot(playerid,index,kind,param,amount);
	dest[0] = EOS;

	switch (kind)
	{
		case ITEM_KIND_WEAPON: strcopy(dest,Combat_GetWeapon(playerid) == param ? ("Put away") : ("Carry it"),size);
		case ITEM_KIND_SHIELD: strcopy(dest,Combat_GetShield(playerid) == param ? ("Put away") : ("Strap it on"),size);
		case ITEM_KIND_FOOD: strcopy(dest,"Eat",size);
		case ITEM_KIND_DRINK: strcopy(dest,"Drink",size);
		case ITEM_KIND_CONTAINER: strcopy(dest,"Open",size);
		case ITEM_KIND_COIN: {}
		default: strcopy(dest,"Use",size);
	}
}

static InventoryGui_GetKindLabel(E_ITEM_KIND:kind,dest[],size = sizeof(dest))
{
	switch (kind)
	{
		case ITEM_KIND_WEAPON: strcopy(dest,"Weapon",size);
		case ITEM_KIND_SHIELD: strcopy(dest,"Shield",size);
		case ITEM_KIND_FOOD: strcopy(dest,"Food",size);
		case ITEM_KIND_DRINK: strcopy(dest,"Drink",size);
		case ITEM_KIND_TOOL: strcopy(dest,"Tool",size);
		case ITEM_KIND_COIN: strcopy(dest,"Coin",size);
		case ITEM_KIND_CONTAINER: strcopy(dest,"Container",size);
		case ITEM_KIND_MATERIAL: strcopy(dest,"Material",size);
		case ITEM_KIND_CLOTHING: strcopy(dest,"Clothing",size);
		default: strcopy(dest,"Curio",size);
	}
}

static InventoryGui_AddFact(labels[][INVENTORY_GUI_FACT_LEN],values[][INVENTORY_GUI_FACT_LEN],&count,const label[],const value[])
{
	if (count >= INVENTORY_GUI_FACT_MAX)
	{
		return;
	}

	strcopy(labels[count],label,INVENTORY_GUI_FACT_LEN);
	strcopy(values[count],value,INVENTORY_GUI_FACT_LEN);
	count++;
}

static InventoryGui_ExamineOpen(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount, stars = Inventory_GetSlotStars(playerid,index), title[ITEM_NAME_LEN], labels[INVENTORY_GUI_FACT_MAX][INVENTORY_GUI_FACT_LEN], values[INVENTORY_GUI_FACT_MAX][INVENTORY_GUI_FACT_LEN], count = 0, text[INVENTORY_GUI_FACT_LEN];
	Inventory_GetSlot(playerid,index,kind,param,amount);
	Item_GetName(kind,param,title);

	InventoryGui_GetKindLabel(kind,text);
	InventoryGui_AddFact(labels,values,count,"Kind",text);

	if (kind != ITEM_KIND_COIN && kind != ITEM_KIND_CONTAINER && Item_IsValidStars(stars))
	{
		format(text,sizeof(text),"%d of %d stars",stars,ITEM_STARS_MAX);
		InventoryGui_AddFact(labels,values,count,"Quality",text);
	}

	if (amount > 1)
	{
		format(text,sizeof(text),"%d",amount);
		InventoryGui_AddFact(labels,values,count,"Carrying",text);
	}

	new price = Item_GetPrice(kind,param,stars);

	if (price > 0)
	{
		Economy_Format(price,text);
		InventoryGui_AddFact(labels,values,count,"Worth",text);
	}

	new left = Inventory_GetFreshLeft(playerid,index), wear = Inventory_GetSlotWear(playerid,index);

	if (left > 0)
	{
		format(text,sizeof(text),"%d min left",(left + 59) / 60);
		InventoryGui_AddFact(labels,values,count,"Fresh",text);
	}
	else if (left == 0)
	{
		InventoryGui_AddFact(labels,values,count,"Fresh","going off");
	}

	if (wear > 0)
	{
		format(text,sizeof(text),"%d%%",wear);
		InventoryGui_AddFact(labels,values,count,"Worn",text);
	}

	new Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,INVENTORY_GUI_EXAMINE_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new row = 0;row < count;row++)
	{
		Kit_AddText(playerid,x,y + float(row) * KIT_ROW,labels[row],KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		Kit_AddText(playerid,x + width * 0.42,y + float(row) * KIT_ROW,values[row],KIT_COLOUR_TEXT,KIT_TEXT_ROW);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
}

static InventoryGui_GiveOpen(playerid,const ids[],count)
{
	new name[MAX_PLAYER_NAME * 2], Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Give to");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW * 1.35 + 6.0 + KIT_ROW + 12.0,"Give to",x,y,width);

	for (new i = 0;i < count;i++)
	{
		Nametag_GetKnownName(playerid,ids[i],name);
		Kit_AddButton(playerid,x,y + float(i) * KIT_ROW * 1.35,width,name,i,KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW * 1.35 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
}

static Float:InventoryGui_TileSize(Float:width)
{
	return (width - INVENTORY_GUI_GAP * float(INVENTORY_GUI_COLUMNS - 1)) / float(INVENTORY_GUI_COLUMNS);
}

static Float:InventoryGui_GridHeight(Float:width,slots)
{
	new rows = (slots + INVENTORY_GUI_COLUMNS - 1) / INVENTORY_GUI_COLUMNS;
	return float(rows) * (KIT_UNITS_Y(KIT_PIXELS_X(InventoryGui_TileSize(width))) + INVENTORY_GUI_GAP);
}

static InventoryGui_AddBagTiles(playerid,Float:x,Float:y,Float:width,selected,bool:isPutMode)
{
	new Float:tile = InventoryGui_TileSize(width), Float:tileHeight = KIT_UNITS_Y(KIT_PIXELS_X(tile)), count = Inventory_GetCount(playerid), E_ITEM_KIND:kind, param, amount;

	for (new slot = 0;slot < INVENTORY_SLOTS;slot++)
	{
		new Float:tileX = x + float(slot % INVENTORY_GUI_COLUMNS) * (tile + INVENTORY_GUI_GAP), Float:tileY = y + float(slot / INVENTORY_GUI_COLUMNS) * (tileHeight + INVENTORY_GUI_GAP);

		if (slot >= count)
		{
			Kit_AddSprite(playerid,tileX,tileY,tile,tileHeight,KIT_SPRITE_PLATE,KIT_COLOUR_PLATE_EMPTY);
			continue;
		}

		Inventory_GetSlot(playerid,slot,kind,param,amount);

		new bool:isClickable = !isPutMode || kind != ITEM_KIND_CONTAINER, icon[ITEM_ICON_LEN], stars = Inventory_GetSlotStars(playerid,slot);
		Item_GetIcon(kind,param,icon);
		Kit_AddTile(playerid,tileX,tileY,tile,Item_GetModel(kind,param),amount,slot == selected,isClickable ? slot : KIT_NONE,InventoryGui_IsWorn(playerid,slot),icon,stars > ITEM_STARS_MIN ? stars : 0);
	}
}

static InventoryGui_Close(playerid)
{
	Kit_Close(playerid);
}

stock Inventory_GetMenuButtonValue(const label[])
{
	for (new i = 0;i < s_InventoryButtonCount;i++)
	{
		if (!strcmp(s_InventoryButtonLabels[i],label))
		{
			return INVENTORY_GUI_BUTTON + i;
		}
	}

	return KIT_NONE;
}

stock Inventory_CloseBagAfterUse(playerid)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_InventoryCloseAfterUse[playerid] = true;
	}
}

InventoryGui_ShowBag(playerid)
{
	yield 1;

	if (!Session_IsPlaying(playerid) || !Inventory_IsLoaded(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), selected = -1, name[ITEM_NAME_LEN], action[16], purse[48], footer[80], bool:isFirst = true, Float:x, Float:y, Float:width, nearby[INVENTORY_GUI_NEARBY_MAX], nearbyCount = 0;

	for (;;)
	{
		new count = Inventory_GetCount(playerid);

		if (selected >= count)
		{
			selected = -1;
		}

		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your bag");
		Kit_CoverHud(playerid);
		Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM_RIGHT,INVENTORY_GUI_WIDTH,KIT_ROW + 2.0 + InventoryGui_GridHeight(INVENTORY_GUI_WIDTH * 0.72,INVENTORY_SLOTS) + KIT_ROW + 4.0 + KIT_ROW + 2.0 + (s_InventoryButtonCount > 0 ? (KIT_ROW + 4.0) : 0.0),"Your bag",x,y,width);

		Economy_Format(Economy_Worth(playerid),purse);
		Kit_AddText(playerid,x,y,"Purse",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		Kit_AddText(playerid,x + width * 0.25,y,purse,KIT_COLOUR_ACCENT,KIT_TEXT_ROW);

		new Float:gridY = y + KIT_ROW + 2.0, Float:footerY = gridY + InventoryGui_GridHeight(width,INVENTORY_SLOTS);
		InventoryGui_AddBagTiles(playerid,x,gridY,width,selected,false);

		if (selected != -1)
		{
			InventoryGui_FormatItem(playerid,selected,footer);
			InventoryGui_AppendState(playerid,selected,footer);
		}
		else
		{
			format(footer,sizeof(footer),"%d of %d slots",count,INVENTORY_SLOTS);

			for (new slot = 0;slot < count;slot++)
			{
				if (InventoryGui_IsWorn(playerid,slot))
				{
					InventoryGui_FormatItem(playerid,slot,name);
					format(footer,sizeof(footer),"In hand: %s",name);
					break;
				}
			}
		}

		Kit_AddText(playerid,x,footerY,footer,selected != -1 ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		new Float:closeY = footerY + KIT_ROW + 2.0;

		if (s_InventoryButtonCount > 0)
		{
			new Float:buttonWidth = (width + 3.0) / float(s_InventoryButtonCount);

			for (new i = 0;i < s_InventoryButtonCount;i++)
			{
				Kit_AddButton(playerid,x + float(i) * buttonWidth,closeY,buttonWidth - 3.0,s_InventoryButtonLabels[i],INVENTORY_GUI_BUTTON + i,KIT_COLOUR_ACCENT);
			}

			closeY += KIT_ROW + 4.0;
		}

		Kit_AddButton(playerid,x + width - 70.0,closeY,70.0,GUI_BUTTON_CLOSE,KIT_BACK);

		if (selected != -1)
		{
			new E_ITEM_KIND:selectedKind, selectedParam, selectedAmount;
			Inventory_GetSlot(playerid,selected,selectedKind,selectedParam,selectedAmount);
			nearbyCount = selectedKind == ITEM_KIND_COIN ? 0 : Trade_GetNearby(playerid,nearby);
			InventoryGui_GetAction(playerid,selected,action);

			new Float:actionsX, Float:actionsY, Float:actionsWidth, Float:actionsHeight = KIT_ROW * float(2 + (action[0] != EOS ? 1 : 0) + (nearbyCount > 0 ? 1 : 0)) + KIT_PANEL_EXTRA, Float:rowY;
			InventoryGui_FormatItem(playerid,selected,name);
			Kit_AddPanel(playerid,640.0 - 6.0 - INVENTORY_GUI_WIDTH - 4.0 - INVENTORY_GUI_ACTIONS_WIDTH,448.0 - 6.0 - actionsHeight,INVENTORY_GUI_ACTIONS_WIDTH,actionsHeight,name,actionsX,actionsY,actionsWidth);
			rowY = actionsY;

			if (action[0] != EOS)
			{
				Kit_AddChoice(playerid,actionsX,rowY,actionsWidth,action,INVENTORY_GUI_USE);
				rowY += KIT_ROW;
			}

			Kit_AddChoice(playerid,actionsX,rowY,actionsWidth,"Examine",INVENTORY_GUI_EXAMINE);
			rowY += KIT_ROW;

			if (nearbyCount > 0)
			{
				Kit_AddChoice(playerid,actionsX,rowY,actionsWidth,"Give",INVENTORY_GUI_GIVE);
				rowY += KIT_ROW;
			}

			Kit_AddChoice(playerid,actionsX,rowY,actionsWidth,"Drop",INVENTORY_GUI_DROP);
		}

		new Task:shown = Kit_Present(playerid);

		if (isFirst)
		{
			isFirst = false;
			pawn_call_public("Inventory_OnMenuOpened","d",playerid);
		}

		new pick = await shown;

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (!Session_IsPlaying(playerid))
		{
			InventoryGui_Close(playerid);
			return;
		}

		if (pick == KIT_BACK)
		{
			if (selected != -1)
			{
				selected = -1;
				continue;
			}

			InventoryGui_Close(playerid);
			return;
		}

		if (pick >= 0 && pick < count)
		{
			selected = pick == selected ? -1 : pick;
			continue;
		}

		if (pick >= INVENTORY_GUI_BUTTON && pick < INVENTORY_GUI_BUTTON + s_InventoryButtonCount)
		{
			InventoryGui_Close(playerid);
			SetTimerEx(s_InventoryButtonPublics[pick - INVENTORY_GUI_BUTTON],0,false,"d",playerid);
			return;
		}

		if (selected == -1 || (pick != INVENTORY_GUI_USE && pick != INVENTORY_GUI_DROP && pick != INVENTORY_GUI_EXAMINE && pick != INVENTORY_GUI_GIVE))
		{
			continue;
		}

		if (pick == INVENTORY_GUI_EXAMINE)
		{
			InventoryGui_ExamineOpen(playerid,selected);
			await Kit_Present(playerid);

			if (!Gui_IsFlowCurrent(playerid,epoch))
			{
				return;
			}

			continue;
		}

		if (pick == INVENTORY_GUI_GIVE)
		{
			nearbyCount = Trade_GetNearby(playerid,nearby);

			if (nearbyCount == 0)
			{
				Gui_Notify(playerid,"Nobody is close enough to hand it to.");
				continue;
			}

			InventoryGui_GiveOpen(playerid,nearby,nearbyCount);
			new whom = await Kit_Present(playerid);

			if (!Gui_IsFlowCurrent(playerid,epoch))
			{
				return;
			}

			if (whom >= 0 && whom < nearbyCount)
			{
				new given = selected;
				selected = -1;
				Inventory_HandOver(playerid,given,nearby[whom]);
			}

			continue;
		}

		new index = selected;
		selected = -1;

		if (pick == INVENTORY_GUI_DROP)
		{
			if (Inventory_Drop(playerid,index))
			{
				InventoryGui_Close(playerid);
				return;
			}
			continue;
		}

		new E_ITEM_KIND:kind, param, amount;
		Inventory_GetSlot(playerid,index,kind,param,amount);

		if (kind == ITEM_KIND_CONTAINER)
		{
			Inventory_Use(playerid,index);
			return;
		}

		s_InventoryCloseAfterUse[playerid] = false;

		if (!Inventory_Use(playerid,index))
		{
			Gui_Notify(playerid,"You can't use that right now.");
		}

		if (s_InventoryCloseAfterUse[playerid])
		{
			s_InventoryCloseAfterUse[playerid] = false;
			InventoryGui_Close(playerid);
			return;
		}
	}
}

stock ContainerGui_PutRefusal(containerid,E_ITEM_KIND:kind,param,dest[],size = sizeof(dest))
{
	if (kind == ITEM_KIND_CONTAINER)
	{
		strcopy(dest,"A purse or a coin bag can't go inside another container. Keep it in your bag.",size);
		return;
	}

	new item[ITEM_NAME_LEN], label[CONTAINER_LABEL_LEN];
	Item_GetName(kind,param,item);
	Container_GetLabel(containerid,label);
	item[0] = tolower(item[0]);

	if (Container_GetOwnerType(containerid) != CONTAINER_OWNER_CARRIED)
	{
		strcopy(dest,"That container is full. Take something out first.",size);
		return;
	}

	label[0] = tolower(label[0]);

	if (Container_Accepts(containerid,kind,param))
	{
		format(dest,size,"The %s is full. Take something out first.",label);
		return;
	}

	if (Item_IsBulky(kind,param))
	{
		format(dest,size,"The %s is far too big for the %s. Carry it in your arms instead.",item,label);
		return;
	}

	switch (Container_GetOwnerId(containerid))
	{
		case ITEM_BELT_POUCH: format(dest,size,"The %s won't fit in the %s. It only holds coin, herbs, bait, seed and small things like dice, keys and letters.",item,label);
		case ITEM_BASKET, ITEM_WOVEN_BASKET: format(dest,size,"The %s doesn't go in the %s. It's for produce: vegetables, fruit, eggs, nuts, mushrooms, herbs, bread and cheese.",item,label);
		case ITEM_CREEL: format(dest,size,"The %s doesn't go in the %s. A creel is for fish and bait.",item,label);
		default: format(dest,size,"The %s doesn't go in the %s.",item,label);
	}
}

stock ContainerGui_ShowDeferred(playerid,containerid)
{
	SetTimerEx("ContainerGui_ShowTimer",0,false,"dd",playerid,containerid);
}

forward ContainerGui_ShowTimer(playerid,containerid);

public ContainerGui_ShowTimer(playerid,containerid)
{
	ContainerGui_Show(playerid,containerid);
	return 1;
}

stock ContainerGui_PutCaption(const label[],dest[],size = sizeof(dest))
{
	format(dest,size,"Into %s",label);

	if (size > 5 && (!strcmp(label,"The ",false,4) || !strcmp(label,"Your ",false,5)))
	{
		dest[5] += 'a' - 'A';
	}
}

ContainerGui_Show(playerid,containerid)
{
	yield 1;

	if (!Session_IsPlaying(playerid) || !Inventory_IsLoaded(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid);

	if (!Container_IsLoaded(containerid))
	{
		new isLoaded = await Container_Load(containerid);

		if (!isLoaded || !Gui_IsFlowCurrent(playerid,epoch))
		{
			InventoryGui_Close(playerid);
			return;
		}
	}

	new label[CONTAINER_LABEL_LEN], footer[CONTAINER_LABEL_LEN + 6], bool:isPutMode = false, Float:x, Float:y, Float:width;

	for (;;)
	{
		if (!Container_IsLoaded(containerid) || !Session_IsPlaying(playerid))
		{
			InventoryGui_Close(playerid);
			return;
		}

		new count = Container_GetCount(containerid), slots = Container_GetSlots(containerid);
		Container_GetLabel(containerid,label);

		if (isPutMode)
		{
			Kit_Begin(playerid,KIT_LAYER_SCREEN,"Put in");
			Kit_CoverHud(playerid);
			Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM_RIGHT,INVENTORY_GUI_WIDTH,InventoryGui_GridHeight(INVENTORY_GUI_WIDTH * 0.72,INVENTORY_SLOTS) + KIT_ROW + 4.0 + KIT_ROW + 2.0,"Put in",x,y,width);
			InventoryGui_AddBagTiles(playerid,x,y,width,-1,true);
			new Float:footerY = y + InventoryGui_GridHeight(width,INVENTORY_SLOTS);
			ContainerGui_PutCaption(label,footer);
			Kit_AddText(playerid,x,footerY,footer,KIT_COLOUR_MUTED,KIT_TEXT_ROW);
			Kit_AddButton(playerid,x + width - 70.0,footerY + KIT_ROW + 2.0,70.0,GUI_BUTTON_BACK,KIT_BACK);
		}
		else
		{
			new Float:tile, Float:tileHeight, E_ITEM_KIND:kind, param, amount, stars;
			Kit_Begin(playerid,KIT_LAYER_SCREEN,label);
			Kit_CoverHud(playerid);
			Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM_RIGHT,INVENTORY_GUI_WIDTH,InventoryGui_GridHeight(INVENTORY_GUI_WIDTH * 0.72,slots) + KIT_ROW + 4.0 + KIT_ROW + 2.0,label,x,y,width);
			tile = InventoryGui_TileSize(width);
			tileHeight = KIT_UNITS_Y(KIT_PIXELS_X(tile));

			for (new slot = 0;slot < slots;slot++)
			{
				new Float:tileX = x + float(slot % INVENTORY_GUI_COLUMNS) * (tile + INVENTORY_GUI_GAP), Float:tileY = y + float(slot / INVENTORY_GUI_COLUMNS) * (tileHeight + INVENTORY_GUI_GAP);

				if (slot >= count)
				{
					Kit_AddSprite(playerid,tileX,tileY,tile,tileHeight,KIT_SPRITE_PLATE,KIT_COLOUR_PLATE_EMPTY);
					continue;
				}

				new icon[ITEM_ICON_LEN];
				Container_GetSlot(containerid,slot,kind,param,amount,stars);
				Item_GetIcon(kind,param,icon);
				Kit_AddTile(playerid,tileX,tileY,tile,Item_GetModel(kind,param),amount,false,slot,false,icon,stars > ITEM_STARS_MIN ? stars : 0);
			}

			new Float:footerY = y + InventoryGui_GridHeight(width,slots);
			format(footer,sizeof(footer),"%d of %d slots, click to take",count,slots);
			Kit_AddText(playerid,x,footerY,footer,KIT_COLOUR_MUTED,KIT_TEXT_ROW);
			Kit_AddButton(playerid,x,footerY + KIT_ROW + 2.0,width * 0.6,"Put something in",INVENTORY_GUI_PUT,KIT_COLOUR_ACCENT);
			Kit_AddButton(playerid,x + width - 70.0,footerY + KIT_ROW + 2.0,70.0,GUI_BUTTON_CLOSE,KIT_BACK);
		}

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (pick == KIT_BACK)
		{
			if (isPutMode)
			{
				isPutMode = false;
				continue;
			}

			InventoryGui_Close(playerid);
			return;
		}

		if (!Container_IsLoaded(containerid))
		{
			continue;
		}

		if (isPutMode)
		{
			if (pick >= 0 && pick < Inventory_GetCount(playerid))
			{
				new E_ITEM_KIND:kind, param, amount, bool:wasStarted, refusal[160];
				wasStarted = Inventory_GetSlot(playerid,pick,kind,param,amount) && Inventory_GetSlotUsed(playerid,pick) > 0 && amount <= 1;

				if (!Container_PutFromBag(playerid,containerid,pick) && !wasStarted)
				{
					ContainerGui_PutRefusal(containerid,kind,param,refusal);
					Gui_Notify(playerid,refusal);
				}
			}

			continue;
		}

		if (pick == INVENTORY_GUI_PUT)
		{
			isPutMode = true;
			continue;
		}

		if (pick >= 0 && pick < Container_GetCount(containerid) && !Container_TakeToBag(playerid,containerid,pick))
		{
			Gui_Notify(playerid,"Your bag is full. Make some room first.");
		}
	}
}

forward Inventory_OnMenuOpened(playerid);

public Inventory_OnMenuOpened(playerid)
{
	return 1;
}

forward bool:Inventory_KeyContext(playerid);

public bool:Inventory_KeyContext(playerid)
{
	return Session_IsPlaying(playerid);
}

forward InventoryGui_BagDeferred(playerid);

public InventoryGui_BagDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid))
	{
		InventoryGui_ShowBag(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_NO) && !(oldkeys & KEY_NO) && !(newkeys & KEY_WALK) && !Keys_IsBusy(playerid,KEY_NO,KEYS_PRIO_MENU) && !Gui_IsBusy(playerid) && Session_IsPlaying(playerid) && !Combat_IsInMode(playerid) && !Mount_IsRiding(playerid))
	{
		SetTimerEx("InventoryGui_BagDeferred",0,false,"d",playerid);
	}
}
