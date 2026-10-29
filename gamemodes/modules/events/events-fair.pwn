static s_FairMerchant = -1;
static s_FairCrowd[EVENTS_CROWD] = {-1, ...};
static s_FairSeason = -1;
static s_Bonfires[REALM_VILLAGES] = {-1, ...};

static bool:Events_IsFairVisitor(slot)
{
	new body = s_FairCrowd[slot];

	if (body == -1 || IsValidPedestrian(body) != 1 || GetPedestrianKind(body) != EVENTS_CROWD_KIND)
	{
		return false;
	}

	new actor = Actors_FindByBody(body);
	return actor != -1 && actor == Actors_FindByKey(sprintf("fair:visitor%d",slot));
}

static Events_ReleaseFairVisitor(slot)
{
	new body = s_FairCrowd[slot];

	if (body == -1)
	{
		return;
	}

	if (Events_IsFairVisitor(slot))
	{
		Walkers_StopRoute(body);
		Actors_UnregisterBody(body);
		DespawnPedestrian(body);
	}
	else
	{
		new actor = Actors_FindByKey(sprintf("fair:visitor%d",slot));

		if (actor != -1 && Actors_FindByBody(body) == actor)
		{
			Actors_UnregisterBody(body);
		}
	}

	s_FairCrowd[slot] = -1;
}

new const g_FairGoods[][2] = {
	{ITEM_SPICE, 18},
	{ITEM_DYE_PLANT, 10},
	{ITEM_CLOTH_DYED, 40},
	{ITEM_SALT, 6}
};

stock Events_FairSeasonIndex()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return year * 4 + _:Calendar_GetSeason();
}

stock Events_GetFairSeason()
{
	return s_FairSeason;
}

stock Events_SetFairSeason(index)
{
	s_FairSeason = index;
}

stock Events_GetFairMerchant()
{
	return s_FairMerchant;
}

stock Events_GetFairPos(&Float:x,&Float:y,&Float:z)
{
	x = g_RealmPointDefs[0][E_REALM_POINT_DEF_POS][0];
	y = g_RealmPointDefs[0][E_REALM_POINT_DEF_POS][1];
	z = g_RealmPointDefs[0][E_REALM_POINT_DEF_POS][2];
}

static Events_PlaceFair()
{
    if (!Market_IsOpen())
    {
        return;
    }

	new Float:x, Float:y, Float:z, skins = Skins_CountStarter(0);
	Events_GetFairPos(x,y,z);

	if (s_FairMerchant == -1)
	{
		s_FairMerchant = Actors_Register("events:merchant",ACTOR_ROLE_VILLAGER,ACTOR_KIND_STATIC,0,skins > 0 ? Skins_GetStarter(0,8 % skins) : 1,"Giacomo of Venice","A merchant from afar");
	}

	if (s_FairMerchant != -1 && !Actors_IsPlaced(s_FairMerchant))
	{
		Actors_SetPlace(s_FairMerchant,x + 3.0,y + 1.0,z + 1.0,90.0,0,0);
		Actors_Place(s_FairMerchant);
	}

	for (new i = 0;i < EVENTS_CROWD;i++)
	{
		new Float:ang = float(i * 360 / EVENTS_CROWD), Float:cx = x + floatsin(-ang,degrees) * 8.0, Float:cy = y + floatcos(-ang,degrees) * 8.0, Float:hx, Float:hy, Float:hz;

		if (s_FairCrowd[i] != -1 && !Events_IsFairVisitor(i))
		{
			Events_ReleaseFairVisitor(i);
		}

		if (s_FairCrowd[i] == -1 && CA_RayCastLine(cx,cy,z + 10.0,cx,cy,z - 10.0,hx,hy,hz) != 0)
		{
			s_FairCrowd[i] = SpawnPedestrianAt(skins > 0 ? Skins_GetStarter(0,random(skins)) : 1,cx,cy,hz + 1.0,ang,EVENTS_CROWD_KIND);
            SetPedestrianBody(s_FairCrowd[i],PED_BODY_PEOPLE);
            Actors_RegisterBody(sprintf("fair:visitor%d",i),s_FairCrowd[i],0,"Fair visitor","Visitor");
		}
	}
}

static Events_ClearFair()
{
	if (s_FairMerchant != -1)
	{
		Actors_Remove(s_FairMerchant);
	}

	for (new i = 0;i < EVENTS_CROWD;i++)
	{
		Events_ReleaseFairVisitor(i);
	}
}

stock Events_GetCrowdBody(slot)
{
	return slot >= 0 && slot < EVENTS_CROWD ? s_FairCrowd[slot] : -1;
}

stock Events_CountCrowd()
{
	new count = 0;

	for (new i = 0;i < EVENTS_CROWD;i++)
	{
		if (Events_IsFairVisitor(i))
		{
			count++;
		}
	}

	return count;
}

stock Events_StartFair(host = 0)
{
	if (Events_FindKind(EVENT_FAIR) != -1)
	{
		return -1;
	}

	new now = gettime(), event = await Events_Declare(EVENT_FAIR,0,now,now + EVENTS_FAIR_MINUTES * 60,host,0,0);

	if (event == -1)
	{
		return -1;
	}

	s_FairSeason = Events_FairSeasonIndex();
	mysql_tquery_s(g_Mysql,str_format("UPDATE events SET place_key = 'fair-%d' WHERE kind = %d ORDER BY id DESC LIMIT 1",s_FairSeason,EVENT_FAIR));
    Market_SetFairOpen(true);
	Events_PlaceFair();
	Events_Announce(event);
	return event;
}

stock Events_FairPrice(param)
{
	for (new i = 0;i < sizeof(g_FairGoods);i++)
	{
		if (g_FairGoods[i][0] == param)
		{
			return g_FairGoods[i][1];
		}
	}

	return 0;
}

stock Events_FairBuyPrice(E_ITEM_KIND:kind,param,stars)
{
	if (kind != ITEM_KIND_FOOD && kind != ITEM_KIND_MATERIAL)
	{
		return 0;
	}

	return Item_GetPrice(kind,param,stars) * EVENTS_FAIR_BUY_PERCENT / 100;
}

stock Events_OpenFairBuy(playerid)
{
    if (!Market_IsOpen())
    {
        return;
    }
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, count = sizeof(g_FairGoods);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Goods from afar");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Goods from afar",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[ITEM_NAME_LEN], money[24], param = g_FairGoods[i][0];
		Item_GetName(g_ItemDefs[param][E_ITEM_DEF_KIND],param,name);
		Economy_Format(g_FairGoods[i][1],money);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT,money,KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || Events_FindKind(EVENT_FAIR) == -1 || !Market_IsOpen())
	{
		return;
	}

	new param = g_FairGoods[pick][0], E_ITEM_KIND:kind = g_ItemDefs[param][E_ITEM_DEF_KIND];

	if (!Inventory_CanGive(playerid,kind,param,1,3))
	{
		Gui_Notify(playerid,"You've no room for it.");
		return;
	}

	if (Economy_Pay(playerid,g_FairGoods[pick][1],INVALID_CONTAINER_ID,"fair") != PAY_OK)
	{
		Gui_Notify(playerid,"You can't pay for it.");
		return;
	}

	Inventory_Give(playerid,kind,param,1,3);
	Gui_Notify(playerid,"The merchant wraps it for you.");
}

stock Events_OpenFairSell(playerid)
{
    if (!Market_IsOpen())
    {
        return;
    }
	new slots[12], prices[12], count = 0;

	for (new index = 0, total = Inventory_GetCount(playerid);index < total && count < sizeof(slots);index++)
	{
		new E_ITEM_KIND:kind, param, amount, price;

		if (Inventory_GetSlot(playerid,index,kind,param,amount) && amount > 0 && (price = Events_FairBuyPrice(kind,param,Inventory_GetSlotStars(playerid,index))) > 0)
		{
			slots[count] = index;
			prices[count++] = price;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"The merchant buys produce and goods: you carry none.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Sell to the merchant");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Sell to the merchant",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new E_ITEM_KIND:kind, param, amount, name[ITEM_NAME_LEN], money[24];
		Inventory_GetSlot(playerid,slots[i],kind,param,amount);
		Item_GetName(kind,param,name);
		Economy_Format(prices[i],money);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT,sprintf("%s each",money),KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || Events_FindKind(EVENT_FAIR) == -1 || !Market_IsOpen())
	{
		return;
	}

	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,slots[pick],kind,param,amount) || amount <= 0 || Events_FairBuyPrice(kind,param,Inventory_GetSlotStars(playerid,slots[pick])) != prices[pick])
	{
		return;
	}

	if (Inventory_TakeSlot(playerid,slots[pick],1) && Economy_Give(playerid,prices[pick],"fair"))
	{
		Gui_Notify(playerid,"The merchant counts out the coin.");
	}
}

stock Events_LightBonfires(const title[],const text[])
{
	for (new village = 0;village < REALM_VILLAGES && village < sizeof(g_RealmPointDefs);village++)
	{
		if (s_Bonfires[village] != -1)
		{
			Light_RemoveSource(s_Bonfires[village]);
		}

		s_Bonfires[village] = Light_AddSource(0,LIGHT_SOURCE_BONFIRE,g_RealmPointDefs[village][E_REALM_POINT_DEF_POS][0] + 5.0,g_RealmPointDefs[village][E_REALM_POINT_DEF_POS][1] + 5.0,g_RealmPointDefs[village][E_REALM_POINT_DEF_POS][2],0.0,0,0,CALENDAR_NIGHT_REAL_MS / 1000);
	}

	Crier_Announce("festival",title,text);
}

stock Events_CountBonfires()
{
	new count = 0;

	for (new village = 0;village < REALM_VILLAGES;village++)
	{
		if (s_Bonfires[village] != -1)
		{
			count++;
		}
	}

	return count;
}

stock Events_StartHarvest()
{
	if (Events_FindKind(EVENT_FESTIVAL) != -1)
	{
		return -1;
	}

	new now = gettime(), purse = Events_TakeFromCounty(120) ? 120 : 0, event = await Events_Declare(EVENT_FESTIVAL,1 << CONTEST_PRODUCE,now + 7200,now + 4 * 3600,0,purse,0);

	if (event != -1)
	{
		Events_Announce(event);
	}

	return event;
}

Timer_Declare(Events_MinuteTick)
{
	new now = gettime();

	for (new event = 0;event < EVENTS_MAX;event++)
	{
		if (!Events_IsValid(event))
		{
			continue;
		}

		Events_Reminders(event);

		if (Events_GetKind(event) == EVENT_FAIR && now >= Events_GetEnds(event))
		{
			Events_End(event);
		}
	}

	if (Events_FindKind(EVENT_FAIR) != -1)
	{
		Events_PlaceFair();
	}

	for (new i = 0;i < EVENTS_CROWD;i++)
	{
		if (!Events_IsFairVisitor(i) || Walkers_IsPaused(s_FairCrowd[i]))
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:ang = float(random(360)), Float:dist = float(3 + random(10)), Float:hx, Float:hy, Float:hz;
		Events_GetFairPos(x,y,z);
		x += floatsin(-ang,degrees) * dist;
		y += floatcos(-ang,degrees) * dist;

		if (CA_RayCastLine(x,y,z + 10.0,x,y,z - 10.0,hx,hy,hz) != 0)
		{
			Walkers_RouteTo(s_FairCrowd[i],x,y,hz + 1.0,1.1,true);
		}
	}

	return 1;
}

forward Events_StartFairDeferred();

public Events_StartFairDeferred()
{
	Events_StartFair(0);
	return 1;
}

forward Events_StartHarvestDeferred();

public Events_StartHarvestDeferred()
{
	Events_StartHarvest();
	return 1;
}

forward Events_MenuFairBuy(playerid,index,data);

public Events_MenuFairBuy(playerid,index,data)
{
	Events_OpenFairBuy(playerid);
	return 1;
}

forward Events_MenuFairSell(playerid,index,data);

public Events_MenuFairSell(playerid,index,data)
{
	Events_OpenFairSell(playerid);
	return 1;
}

#include <pp-hooks>

hook Events_OnEnded(event,kind)
{
	#pragma unused event

	if (kind == EVENT_FAIR)
	{
        Market_SetFairOpen(false);
		Events_ClearFair();
		Crier_Announce("event","The fair","The merchants pack their carts. The fair is over until next season.");
	}
}

hook Calendar_OnDawn()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);

	if (Events_FairSeasonIndex() != s_FairSeason)
	{
		SetTimer("Events_StartFairDeferred",0,false);
	}

	if (month == 10 && day == 1)
	{
		SetTimer("Events_StartHarvestDeferred",0,false);
	}

	if (Realm_IsDecreeActive(REALM_DECREE_FEAST))
	{
		Crier_Announce("festival","A feast day","By the duke's decree today is a feast day. Hear mass, rest from your labours and feast together.");
	}
}

hook Calendar_OnHour(hour)
{
	if (hour != CALENDAR_DUSK_HOUR)
	{
		return;
	}

	new day, month, year;
	Calendar_GetDate(day,month,year);

	if (month == 6 && day == 24)
	{
		Events_LightBonfires("Midsummer","It's midsummer's night: the fires are lit on the village squares. Leap them for luck!");
	}
	else if (month == 12 && day == 21)
	{
		Events_LightBonfires("Midwinter","The longest night: the fires burn on the squares to call the sun back. Bring a log for the fire.");
	}
}

hook Actors_OnMenuBuild(playerid,index)
{
	if (index == -1 || index != s_FairMerchant || Events_FindKind(EVENT_FAIR) == -1 || !Market_IsOpen())
	{
		return;
	}

	Actors_MenuAdd(playerid,"Buy goods from afar","Events_MenuFairBuy");
	Actors_MenuAdd(playerid,"Sell him your surplus","Events_MenuFairSell");
}

hook Market_OnChanged(open)
{
    if (Events_FindKind(EVENT_FAIR) == -1)
    {
        return;
    }
    if (open)
    {
        Events_PlaceFair();
    }
    else
    {
        Events_ClearFair();
    }
}

stock Events_RefreshFair()
{
    new event = Events_FindKind(EVENT_FAIR);
    if (event != -1 && gettime() < Events_GetEnds(event))
    {
        Market_SetFairOpen(true);
        Events_PlaceFair();
    }
    else
    {
        Market_SetFairOpen(false);
        Events_ClearFair();
    }
}

stock Events_CountMarketActors()
{
    return MarketVisitors_Count() + Trader_CountMarketPresent() + Events_CountCrowd() + (Actors_IsPlaced(s_FairMerchant) ? 1 : 0);
}
