#define HORSES_KEEPER_REACH (20.0)
#define HORSES_PANEL_WIDTH (300.0)
#define HORSES_LIST_MAX (8)

enum E_HORSES_STABLE
{
	E_HST_ROW,
	E_HST_ACTOR,
	bool:E_HST_TRADES,
	E_HST_CAPACITY,
}

enum E_HORSES_STOCK
{
	E_HORSES_BREED:E_HSK_BREED,
	E_HSK_SEED,
	bool:E_HSK_SOLD,
	E_HSK_DAY,
}

static s_HorseStables[HORSE_SEED_STABLES][E_HORSES_STABLE];
static s_HorseStock[HORSE_SEED_STABLES][HORSES_STOCK_PER_TRADER][E_HORSES_STOCK];

static const s_KeeperNames[][24] = {"Ota Konar", "Bara Konarova", "Jira Podkoni", "Mates Uzdar"};
static const E_HORSES_BREED:s_StockBreeds[] = {HORSES_BREED_DUTCH, HORSES_BREED_TENNESSEE, HORSES_BREED_APPALOOSA, HORSES_BREED_MUSTANG, HORSES_BREED_MUSTANG, HORSES_BREED_APPALOOSA, HORSES_BREED_DONKEY};

stock Horses_StableId(index)
{
	return index >= 0 && index < HORSE_SEED_STABLES ? s_HorseStables[index][E_HST_ROW] : 0;
}

stock Horses_StableIndex(row)
{
	for (new i = 0;i < HORSE_SEED_STABLES;i++)
	{
		if (s_HorseStables[i][E_HST_ROW] == row && row > 0)
		{
			return i;
		}
	}

	return -1;
}

stock Horses_StableName(row,dest[],size = sizeof(dest))
{
	new index = Horses_StableIndex(row);
	if (index != -1)
	{
		strcopy(dest,g_HorseStableDefs[index][E_HORSE_STABLE_DEF_NAME],size);
	}
	else
	{
		strcopy(dest,"a stable",size);
	}
}

stock Horses_StableOfActor(actor)
{
	for (new i = 0;i < HORSE_SEED_STABLES;i++)
	{
		if (s_HorseStables[i][E_HST_ACTOR] == actor && actor != -1)
		{
			return i;
		}
	}

	return -1;
}

stock Horses_PlaceKeepers()
{
	for (new i = 0;i < HORSE_SEED_STABLES;i++)
	{
		new key[24], count = Skins_CountStarter(0), skin = count > 0 ? Skins_GetStarter(0,i % count) : 1;
		format(key,sizeof(key),"stable:%d",i);
		new title[16] = "Stable keeper";

		if (g_HorseStableDefs[i][E_HORSE_STABLE_DEF_TRADES])
		{
			title = "Horse trader";
		}

		new actor = Actors_Register(key,ACTOR_ROLE_STABLEHAND,ACTOR_KIND_STATIC,0,skin,s_KeeperNames[i % sizeof(s_KeeperNames)],title);
		s_HorseStables[i][E_HST_ACTOR] = actor;
		s_HorseStables[i][E_HST_TRADES] = g_HorseStableDefs[i][E_HORSE_STABLE_DEF_TRADES];
		s_HorseStables[i][E_HST_CAPACITY] = HORSES_STABLE_CAPACITY;

		if (actor != -1)
		{
			Actors_SetPlace(actor,g_HorseStableDefs[i][E_HORSE_STABLE_DEF_KEEPER][0],g_HorseStableDefs[i][E_HORSE_STABLE_DEF_KEEPER][1],g_HorseStableDefs[i][E_HORSE_STABLE_DEF_KEEPER][2] + 1.0,g_HorseStableDefs[i][E_HORSE_STABLE_DEF_KEEPER][3],0,0);
			Actors_Place(actor);
		}
	}
}

forward Task:Horses_LoadStables();
#pragma warning push
#pragma warning disable 204
async Task:Horses_LoadStables()
{
	for (new i = 0;i < HORSE_SEED_STABLES;i++)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT id FROM horse_stables WHERE name = '%e' LIMIT 1",g_HorseStableDefs[i][E_HORSE_STABLE_DEF_NAME]));

		if (cache_num_rows() > 0)
		{
			cache_get_value_name_int(0,"id",s_HorseStables[i][E_HST_ROW]);
			continue;
		}

		await mysql_aquery_s(g_Mysql,str_format("INSERT INTO horse_stables (name, x, y, z, capacity, fee_pfennig) VALUES ('%e', %f, %f, %f, %d, %d)",g_HorseStableDefs[i][E_HORSE_STABLE_DEF_NAME],g_HorseStableDefs[i][E_HORSE_STABLE_DEF_HITCH][0],g_HorseStableDefs[i][E_HORSE_STABLE_DEF_HITCH][1],g_HorseStableDefs[i][E_HORSE_STABLE_DEF_HITCH][2],HORSES_STABLE_CAPACITY,HORSES_STABLE_FEE));
		s_HorseStables[i][E_HST_ROW] = cache_insert_id();
	}

	return async HORSE_SEED_STABLES;
}
#pragma warning pop

stock Horses_RollStock(stable,day)
{
	for (new slot = 0;slot < HORSES_STOCK_PER_TRADER;slot++)
	{
		new seed = day * 7919 + stable * 104729 + slot * 1299709 + 17;
		s_HorseStock[stable][slot][E_HSK_BREED] = s_StockBreeds[Gene_Rand(seed,sizeof(s_StockBreeds))];
		s_HorseStock[stable][slot][E_HSK_SEED] = seed;
		s_HorseStock[stable][slot][E_HSK_SOLD] = false;
		s_HorseStock[stable][slot][E_HSK_DAY] = day;
	}
}

stock Horses_StockGenes(stable,slot,genes[],&sex,&ageYears)
{
	new seed = s_HorseStock[stable][slot][E_HSK_SEED];
	Gene_Roll(s_HorseStock[stable][slot][E_HSK_BREED],genes,seed);
	Gene_CapFine(genes);
	sex = Gene_Rand(seed,3) == 0 ? HORSES_SEX_STALLION : (Gene_Rand(seed,2) == 0 ? HORSES_SEX_MARE : HORSES_SEX_GELDING);
	ageYears = 3 + Gene_Rand(seed,8);
}

static Horses_DescribeGenes(const genes[],bool:inbred,dest[],size = sizeof(dest))
{
	new spd[HORSES_WORD_LEN], sta[HORSES_WORD_LEN], hlt[HORSES_WORD_LEN], tmp[HORSES_WORD_LEN];
	Gene_StatWord(genes,HORSES_LOCUS_SPD,inbred,spd);
	Gene_StatWord(genes,HORSES_LOCUS_STA,inbred,sta);
	Gene_StatWord(genes,HORSES_LOCUS_HLT,inbred,hlt);
	Gene_StatWord(genes,HORSES_LOCUS_TMP,inbred,tmp);
	format(dest,size,"%s, %s, %s, %s",spd,sta,hlt,tmp);
}

stock Horses_OwnedNear(playerid,stable,list[HORSES_LIST_MAX])
{
	new count = 0, Float:kx = g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_KEEPER][0], Float:ky = g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_KEEPER][1], Float:kz = g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_KEEPER][2];

	for (new horseid = 0;horseid < MAX_HORSES && count < HORSES_LIST_MAX;horseid++)
	{
		if (!Horses_IsOwner(playerid,horseid))
		{
			continue;
		}

		new rider = Horse_GetRider(horseid), Float:x, Float:y, Float:z, Float:a;

		if (rider != INVALID_PLAYER_ID && rider != playerid)
		{
			continue;
		}

		if (rider == playerid)
		{
			GetPlayerPos(playerid,x,y,z);
		}
		else
		{
			Horse_GetPos(horseid,x,y,z,a);
		}

		if (VectorSize(x - kx,y - ky,z - kz) <= HORSES_KEEPER_REACH)
		{
			list[count++] = horseid;
		}
	}

	return count;
}

static Horses_PickHorse(playerid,const title[],const list[HORSES_LIST_MAX],count)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[HORSES_NAME_LEN], detail[48];
		Horses_GetHorseName(list[i],name);
		format(detail,sizeof(detail),"%s, %s",g_HorsesSexNames[Horses_GetSex(list[i])],g_HorsesTierNames[Horses_GetTier(list[i])]);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT,detail,KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return INVALID_HORSE_ID;
	}

	return list[pick];
}

static Horses_Confirm(playerid,const title[],const line[],const yes[])
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH,KIT_ROW * 3.0 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width,yes,1,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 3.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return Gui_IsFlowCurrent(playerid,epoch) && pick == 1;
}

stock Horses_MenuStableFor(playerid,stable)
{
	new list[HORSES_LIST_MAX], count = Horses_OwnedNear(playerid,stable,list);

	if (count == 0)
	{
		Gui_Notify(playerid,"Bring your horse here to stable it.");
		return;
	}

	new horseid = Horses_PickHorse(playerid,"Stable which horse?",list,count);

	if (horseid == INVALID_HORSE_ID)
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, fed[24], plain[24], line[64];
	Economy_Format(HORSES_STABLE_FEE_FED,fed);
	Economy_Format(HORSES_STABLE_FEE,plain);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Stabling");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,"Stabling",x,y,width);
	Kit_AddText(playerid,x,y,"Pay when you fetch it. Unpaid ten days, it's sold on.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	format(line,sizeof(line),"With feed and water (%s a day)",fed);
	Kit_AddChoice(playerid,x,y + KIT_ROW * 1.5,width,line,1,KIT_COLOUR_GOOD);
	format(line,sizeof(line),"Water only (%s a day)",plain);
	Kit_AddChoice(playerid,x,y + KIT_ROW * 2.5,width,line,2,KIT_COLOUR_TEXT);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 4.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || (pick != 1 && pick != 2) || !Horses_IsOwner(playerid,horseid))
	{
		return;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM horses WHERE status = %d AND location_kind = %d AND stable_id = %d",HORSES_STATUS_ALIVE,HORSES_PLACE_STABLED,Horses_StableId(stable)));
	new used = 0;
	cache_get_value_name_int(0,"n",used);

	if (used >= s_HorseStables[stable][E_HST_CAPACITY])
	{
		Gui_Notify(playerid,"Every stall here is taken. Try another stable.");
		return;
	}

	if (Horse_GetRider(horseid) == playerid)
	{
		Mount_Dismount(playerid);
	}

	new name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);
	Horses_SetStableState(horseid,HORSES_PLACE_STABLED,Horses_StableId(stable),Horses_Today(),pick == 1);
	Horses_Event(Horses_GetHid(horseid),HORSES_EVENT_STABLED,Character_GetId(playerid),"");
	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET hold_until = 0 WHERE id = %d",Horses_GetHid(horseid)));
	Horses_Park(horseid,HORSES_PLACE_STABLED);
	Gui_Notify(playerid,sprintf("The keeper leads %s into a stall. Fetch it here when you want it.",name));
}

stock Horses_MenuFetchFor(playerid,stable)
{
	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT * FROM horses WHERE owner_character_id = %d AND status = %d AND location_kind = %d AND stable_id = %d ORDER BY id LIMIT %d",characterid,HORSES_STATUS_ALIVE,HORSES_PLACE_STABLED,Horses_StableId(stable),HORSES_LIST_MAX));
	new rows = cache_num_rows();

	if (rows == 0)
	{
		Gui_Notify(playerid,"You have no horse stabled here.");
		return;
	}

	new names[HORSES_LIST_MAX][HORSES_NAME_LEN], owed[HORSES_LIST_MAX], ids[HORSES_LIST_MAX], today = Horses_Today();

	for (new r = 0;r < rows;r++)
	{
		new stabledDay, fed, hold;
		cache_get_value_name_int(r,"id",ids[r]);
		cache_get_value_name(r,"name",names[r]);
		cache_get_value_name_int(r,"stabled_day",stabledDay);
		cache_get_value_name_int(r,"feed_included",fed);
		cache_get_value_name_int(r,"hold_until",hold);
		owed[r] = hold > 0 ? 0 : Horses_StableOwed(stabledDay,today,fed != 0);

		if (names[r][0] == EOS)
		{
			strcopy(names[r],"A foal");
		}
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your stabled horses");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH,float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Your stabled horses",x,y,width);

	for (new r = 0;r < rows;r++)
	{
		new money[24], detail[48];
		Economy_Format(owed[r],money);
		if (owed[r] > 0)
		{
			format(detail,sizeof(detail),"owes %s",money);
		}
		else
		{
			strcopy(detail,"paid up");
		}
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(r),width,names[r],r,KIT_COLOUR_TEXT,detail,owed[r] >= HORSES_STABLE_FEE * (HORSES_STABLE_UNPAID_DAYS - 2) ? KIT_COLOUR_BAD : KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= rows)
	{
		return;
	}

	if (owed[pick] > 0 && Economy_Pay(playerid,owed[pick],INVALID_CONTAINER_ID,"stable") != PAY_OK)
	{
		Gui_Notify(playerid,"You can't pay the stable bill.");
		return;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT * FROM horses WHERE id = %d AND owner_character_id = %d AND location_kind = %d",ids[pick],characterid,HORSES_PLACE_STABLED));

	if (cache_num_rows() == 0 || !IsPlayerConnected(playerid))
	{
		return;
	}

	new horseid = Horses_SpawnRow(0,g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][0],g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][1],g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][2],g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][3]);

	if (horseid == INVALID_HORSE_ID)
	{
		Gui_Notify(playerid,"The yard is too full to bring it out. Try again shortly.");
		return;
	}

	Horses_SetStableState(horseid,HORSES_PLACE_WORLD,-1,0,false);
	Horses_Event(ids[pick],HORSES_EVENT_RETRIEVED,characterid,"");
	Horses_CheckFoaling(horseid);
	Horses_Save(horseid);
	Gui_Notify(playerid,sprintf("The keeper brings out %s.",names[pick]));
}

stock Horses_MenuBuyFor(playerid,stable)
{
	if (!s_HorseStables[stable][E_HST_TRADES])
	{
		return;
	}

	if (s_HorseStock[stable][0][E_HSK_DAY] != Horses_Today())
	{
		Horses_RollStock(stable,Horses_Today());
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, slots[HORSES_STOCK_PER_TRADER], count = 0;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Horses for sale");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH + 60.0,float(HORSES_STOCK_PER_TRADER) * KIT_ROW * 2.0 + 6.0 + KIT_ROW + 12.0,"Horses for sale",x,y,width);

	for (new slot = 0;slot < HORSES_STOCK_PER_TRADER;slot++)
	{
		if (s_HorseStock[stable][slot][E_HSK_SOLD])
		{
			continue;
		}

		new genes[HORSES_LOCI], sex, age, coat[MOUNT_NAME_LEN], label[64], words[96], money[24];
		Horses_StockGenes(stable,slot,genes,sex,age);
		Gene_CoatName(Horses_TypeOf(s_HorseStock[stable][slot][E_HSK_BREED],genes),coat);
		Economy_Format(Horses_Price(s_HorseStock[stable][slot][E_HSK_BREED],genes,age,false),money);
		format(label,sizeof(label),"%s %s, %d years",g_HorsesBreedNames[s_HorseStock[stable][slot][E_HSK_BREED]],g_HorsesSexNames[sex],age);
		Horses_DescribeGenes(genes,false,words);
		format(words,sizeof(words),"%s, %s",coat,words);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0 * float(count),width,label,slot,KIT_COLOUR_TEXT,money,KIT_COLOUR_ACCENT);
		Kit_AddText(playerid,x + 8.0,y + KIT_ROW * (2.0 * float(count) + 0.9),words,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width - 8.0);
		slots[count++] = slot;
	}

	if (count == 0)
	{
		Kit_AddText(playerid,x,y,"Sold out today. More come tomorrow.",KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(HORSES_STOCK_PER_TRADER) * KIT_ROW * 2.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= HORSES_STOCK_PER_TRADER || s_HorseStock[stable][pick][E_HSK_SOLD])
	{
		return;
	}

	Horses_BuyStock(playerid,stable,pick);
}

stock bool:Horses_PayStock(playerid,price)
{
    new E_PAY_RESULT:result = Economy_Pay(playerid,price,INVALID_CONTAINER_ID,"horse trader");

    if (result == PAY_OK)
    {
        return true;
    }

    new cost[ECONOMY_FORMAT_LEN], shortfall[ECONOMY_FORMAT_LEN], text[144];
    Economy_Format(price,cost);

    if (result == PAY_SHORT)
    {
        Economy_Format(max(0,price - Economy_Worth(playerid)),shortfall);
        format(text,sizeof(text),"That horse costs %s. You're short %s.",cost,shortfall);
    }
    else
    {
        format(text,sizeof(text),"That horse costs %s. Make room in your bag for the change first.",cost);
    }

    Gui_Notify(playerid,text);
    return false;
}

forward Task:Horses_BuyStock(playerid,stable,slot);
#pragma warning push
#pragma warning disable 204
async Task:Horses_BuyStock(playerid,stable,slot)
{
	new characterid = Character_GetId(playerid), owned = await Horses_CountOwned(characterid);

	if (!IsPlayerConnected(playerid) || s_HorseStock[stable][slot][E_HSK_SOLD])
	{
		return async 0;
	}

	if (owned >= HORSES_PER_CHARACTER)
	{
		Gui_Notify(playerid,"You keep two horses already. Sell one first.");
		return async 0;
	}

	new genes[HORSES_LOCI], sex, age, E_HORSES_BREED:breed = s_HorseStock[stable][slot][E_HSK_BREED];
	Horses_StockGenes(stable,slot,genes,sex,age);
	new price = Horses_Price(breed,genes,age,false);

	if (!Horses_PayStock(playerid,price))
	{
		return async 0;
	}

	new seed = s_HorseStock[stable][slot][E_HSK_SEED];
	new horseid = Horses_Spawn(breed,g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][0],g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][1],g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][2],g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_HITCH][3],0,HORSES_KIND_NONE,seed,true);

	if (horseid == INVALID_HORSE_ID)
	{
		Economy_Give(playerid,price,"horse trader refund");
		Gui_Notify(playerid,"The yard is too full to bring it out. Your coin is back.");
		return async 0;
	}

	s_HorseStock[stable][slot][E_HSK_SOLD] = true;
	Horses_SetupStock(horseid,sex,age);
	new hid = await Horses_Adopt(horseid,characterid,HORSES_EVENT_BOUGHT);

	if (hid <= 0)
	{
		return async 0;
	}

	Horses_SetBond(horseid,HORSES_BOND_NEW_OWNER);
	Horses_Shoe(horseid);
	Gui_Notify(playerid,"The trader leads the horse out to you. Give it a name.");
	Horses_AskName(playerid,horseid);
	return async hid;
}
#pragma warning pop

stock Horses_MenuSellFor(playerid,stable)
{
	new list[HORSES_LIST_MAX], count = Horses_OwnedNear(playerid,stable,list);

	if (count == 0)
	{
		Gui_Notify(playerid,"Bring the horse here to sell it.");
		return;
	}

	new horseid = Horses_PickHorse(playerid,"Sell which horse?",list,count);

	if (horseid == INVALID_HORSE_ID)
	{
		return;
	}

	if (Horses_GetAgeDays(horseid) < HORSES_YEARLING_DAYS)
	{
		Gui_Notify(playerid,"The trader won't buy a foal that young.");
		return;
	}

	new price = Horses_PriceOf(horseid) / 2, money[24], name[HORSES_NAME_LEN], line[96];
	Economy_Format(price,money);
	Horses_GetHorseName(horseid,name);
	format(line,sizeof(line),"The trader offers %s for %s. It won't be yours again.",money,name);

	if (!Horses_Confirm(playerid,"Sell a horse",line,"Sell it") || !Horses_IsOwner(playerid,horseid))
	{
		return;
	}

	if (Horse_GetRider(horseid) == playerid)
	{
		Mount_Dismount(playerid);
	}

	new hid = Horses_GetHid(horseid);
	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET status = %d, owner_character_id = NULL WHERE id = %d",HORSES_STATUS_SOLD,hid));
	Horses_Event(hid,HORSES_EVENT_SOLD,Character_GetId(playerid),"trader");
	Economy_Give(playerid,price,"horse sold");
	Horses_ForgetOwned(horseid);
	Horse_Destroy(horseid);
	Horses_ClearBuffs(playerid);
	Gui_Notify(playerid,sprintf("You sell %s for %s.",name,money));
}

stock Horses_MenuServicesFor(playerid,stable)
{
	new list[HORSES_LIST_MAX], count = Horses_OwnedNear(playerid,stable,list);

	if (count == 0)
	{
		Gui_Notify(playerid,"Bring your horse here first.");
		return;
	}

	new horseid = Horses_PickHorse(playerid,"Which horse?",list,count);

	if (horseid == INVALID_HORSE_ID)
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, rows = 0, labels[6][64], picks[6], money[24], name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);
	Economy_Format(HORSES_READING_FEE,money);
	format(labels[rows],64,"Read its blood (%s)",money);
	picks[rows++] = 1;

	if (Horses_GetSex(horseid) == HORSES_SEX_STALLION)
	{
		Economy_Format(HORSES_GELDING_FEE,money);
		format(labels[rows],64,"Geld him (%s)",money);
		picks[rows++] = 2;
		if (Horses_GetStudFee(horseid) >= 0)
		{
			strcopy(labels[rows],"Change his stud fee or withdraw him",64);
		}
		else
		{
			strcopy(labels[rows],"Offer him at stud",64);
		}

		picks[rows++] = 4;
	}

	if (Horses_IsSick(horseid))
	{
		Economy_Format(HORSES_TREAT_FEE,money);
		format(labels[rows],64,"Treat the sickness (%s)",money);
		picks[rows++] = 3;
	}

	if (Horses_GetSex(horseid) == HORSES_SEX_MARE)
	{
		strcopy(labels[rows],"Book a covering",64);
		picks[rows++] = 5;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH,float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);

	for (new i = 0;i < rows;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i],picks[i] == 2 ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick <= 0 || !Horses_IsOwner(playerid,horseid))
	{
		return;
	}

	switch (pick)
	{
		case 1:
		{
			if (Economy_Pay(playerid,HORSES_READING_FEE,INVALID_CONTAINER_ID,"blood reading") != PAY_OK)
			{
				Gui_Notify(playerid,"You can't pay for the reading.");
				return;
			}

			Horses_SetRevealed(horseid);
			Horses_Event(Horses_GetHid(horseid),HORSES_EVENT_READ,Character_GetId(playerid),"");
			Gui_Notify(playerid,sprintf("The keeper reads %s's line. Its hidden blood shows on its Traits now.",name));
			Horses_OpenPanel(playerid,horseid,2);
		}
		case 2:
		{
			if (!Horses_Confirm(playerid,"Geld him",sprintf("%s will be calmer but can never sire a foal.",name),"Geld him"))
			{
				return;
			}

			if (Economy_Pay(playerid,HORSES_GELDING_FEE,INVALID_CONTAINER_ID,"gelding") != PAY_OK)
			{
				Gui_Notify(playerid,"You can't pay the keeper.");
				return;
			}

			Horses_SetGelded(horseid);
			Horses_Event(Horses_GetHid(horseid),HORSES_EVENT_GELDED,Character_GetId(playerid),"");
			Horses_Save(horseid);
			Gui_Notify(playerid,sprintf("%s is a gelding now.",name));
		}
		case 3:
		{
			if (Economy_Pay(playerid,HORSES_TREAT_FEE,INVALID_CONTAINER_ID,"horse doctor") != PAY_OK)
			{
				Gui_Notify(playerid,"You can't pay the keeper.");
				return;
			}

			Horses_SetSick(horseid,0);
			Horses_Save(horseid);
			Gui_Notify(playerid,sprintf("The keeper doses %s with a warm mash. It's over the worst.",name));
		}
		case 4:
		{
			new text[8];

			if (!Horses_AskText(playerid,"Stud fee",sprintf("What do you ask for %s to cover a mare, in pfennig? Leave it empty to withdraw him.",name),text,sizeof(text)))
			{
				return;
			}

			new fee = text[0] == EOS ? -1 : Util_ClampInt(strval(text),0,HORSES_GULDEN * 20);
			Horses_SetStudFee(horseid,fee);
			Horses_Save(horseid);

			if (fee < 0)
			{
				Gui_Notify(playerid,sprintf("%s is no longer offered at stud.",name));
			}
			else
			{
				Economy_Format(fee,money);
				Gui_Notify(playerid,sprintf("%s stands at stud here for %s. Mare owners book him with any stable keeper while he's here.",name,money));
			}
		}
		case 5: Horses_BookCovering(playerid,stable,horseid);
	}
}

stock bool:Horses_MareReady(mareid,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	if (!Horses_IsOwned(mareid) || Horses_GetSex(mareid) != HORSES_SEX_MARE)
	{
		strcopy(reason,"Only a mare can be covered.",size);
	}
	else if (Horses_IsFoal(mareid) || Horses_GetAgeDays(mareid) < HORSES_GROWN_DAYS * 2)
	{
		strcopy(reason,"She's too young.",size);
	}
	else if (Horses_IsInFoal(mareid))
	{
		strcopy(reason,"She's already in foal.",size);
	}
	else if (Horses_CoveredThisSeason(mareid))
	{
		strcopy(reason,"She's been covered this season already. Once a season.",size);
	}
	else if (!Horses_IsBreedingSeason())
	{
		strcopy(reason,"Mares come in season in spring and summer only.",size);
	}
	else if (!Horses_IsInSeason(Horses_GetHid(mareid),Horses_Today()))
	{
		format(reason,size,"Not in season, try in %d days.",Horses_DaysToSeason(Horses_GetHid(mareid),Horses_Today()));
	}
	else if (Horses_GetHunger(mareid) < 30.0)
	{
		strcopy(reason,"She's too hungry to carry a foal. Feed her first.",size);
	}

	return reason[0] == EOS;
}

stock Horses_BookCovering(playerid,stable,mareid)
{
	new reason[64];

	if (!Horses_MareReady(mareid,reason))
	{
		Gui_Notify(playerid,reason);
		return;
	}

	new characterid = Character_GetId(playerid), mareHid = Horses_GetHid(mareid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT h.id, h.name, h.owner_character_id, h.stud_fee, h.genes, h.breed, h.sire_id, h.dam_id, h.covers, h.covers_season, h.born_day FROM horses h WHERE h.status = %d AND h.sex = %d AND h.id <> %d AND h.born_day <= %d AND ((h.location_kind = %d AND h.stable_id = %d) OR h.location_kind = %d) AND (h.stud_fee >= 0 OR h.owner_character_id = %d) ORDER BY h.stud_fee LIMIT %d",
		HORSES_STATUS_ALIVE,HORSES_SEX_STALLION,mareHid,Horses_Today() - HORSES_GROWN_DAYS * 2,HORSES_PLACE_STABLED,Horses_StableId(stable),HORSES_PLACE_WORLD,characterid,HORSES_LIST_MAX));
	new rows = cache_num_rows(), ids[HORSES_LIST_MAX], owners[HORSES_LIST_MAX], fees[HORSES_LIST_MAX], breeds[HORSES_LIST_MAX], sires[HORSES_LIST_MAX], dams[HORSES_LIST_MAX], names[HORSES_LIST_MAX][HORSES_NAME_LEN], genesHex[HORSES_LIST_MAX][HORSES_GENES_HEX], count = 0, season = Horses_SeasonIndex();

	for (new r = 0;r < rows;r++)
	{
		new covers, coversSeason, id;
		cache_get_value_name_int(r,"id",id);
		cache_get_value_name_int(r,"covers",covers);
		cache_get_value_name_int(r,"covers_season",coversSeason);

		if (coversSeason == season && covers >= HORSES_STALLION_COVERS)
		{
			continue;
		}

		new runtime = Horses_FindByHid(id);

		if (runtime != INVALID_HORSE_ID)
		{
			new Float:hx, Float:hy, Float:hz, Float:ha;
			Horse_GetPos(runtime,hx,hy,hz,ha);

			if (Horse_GetRider(runtime) != INVALID_PLAYER_ID || VectorSize(hx - g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_KEEPER][0],hy - g_HorseStableDefs[stable][E_HORSE_STABLE_DEF_KEEPER][1],0.0) > HORSES_KEEPER_REACH)
			{
				continue;
			}
		}

		ids[count] = id;
		cache_get_value_name_int(r,"owner_character_id",owners[count]);
		cache_get_value_name_int(r,"stud_fee",fees[count]);
		cache_get_value_name_int(r,"breed",breeds[count]);
		cache_get_value_name_int(r,"sire_id",sires[count]);
		cache_get_value_name_int(r,"dam_id",dams[count]);
		cache_get_value_name(r,"name",names[count]);
		cache_get_value_name(r,"genes",genesHex[count]);

		if (owners[count] == characterid)
		{
			fees[count] = 0;
		}

		count++;
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"No stallion stands at stud here now. Bring your own, or ask a breeder.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Pick a stallion");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HORSES_PANEL_WIDTH + 60.0,float(count) * KIT_ROW * 2.0 + 6.0 + KIT_ROW + 12.0,"Pick a stallion",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new genes[HORSES_LOCI], words[96], money[24], label[48];
		Gene_Decode(genesHex[i],genes);
		Horses_DescribeGenes(genes,false,words);
		Economy_Format(fees[i],money);
		if (names[i][0] == EOS)
		{
			strcopy(names[i],"Unnamed");
		}

		if (fees[i] <= 0)
		{
			strcopy(money,"yours");
		}

		format(label,sizeof(label),"%s (%s)",names[i],g_HorsesBreedNames[E_HORSES_BREED:Util_ClampInt(breeds[i],0,_:HORSES_BREED_COUNT - 1)]);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0 * float(i),width,label,i,KIT_COLOUR_TEXT,money,KIT_COLOUR_ACCENT);
		Kit_AddText(playerid,x + 8.0,y + KIT_ROW * (2.0 * float(i) + 0.9),words,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width - 8.0);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW * 2.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || !Horses_IsOwner(playerid,mareid) || !Horses_MareReady(mareid,reason))
	{
		if (reason[0] != EOS)
		{
			Gui_Notify(playerid,reason);
		}

		return;
	}

	new mareSire, mareDam, sireGrand[4], damGrand[4];
	Horses_GetParents(mareid,mareSire,mareDam);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, COALESCE(sire_id, 0) AS s, COALESCE(dam_id, 0) AS d FROM horses WHERE id IN (%d, %d, %d, %d)",sires[pick] > 0 ? sires[pick] : -1,dams[pick] > 0 ? dams[pick] : -1,mareSire > 0 ? mareSire : -1,mareDam > 0 ? mareDam : -1));

	for (new r = 0;r < cache_num_rows();r++)
	{
		new id, s, d;
		cache_get_value_name_int(r,"id",id);
		cache_get_value_name_int(r,"s",s);
		cache_get_value_name_int(r,"d",d);

		if (id == sires[pick])
		{
			sireGrand[0] = s;
			sireGrand[1] = d;
		}

		if (id == dams[pick])
		{
			sireGrand[2] = s;
			sireGrand[3] = d;
		}

		if (id == mareSire)
		{
			damGrand[0] = s;
			damGrand[1] = d;
		}

		if (id == mareDam)
		{
			damGrand[2] = s;
			damGrand[3] = d;
		}
	}

	new kin = Horses_Kinship(ids[pick],mareHid,sires[pick],dams[pick],mareSire,mareDam,sireGrand,damGrand);

	if (kin == 2)
	{
		Gui_Notify(playerid,"Too closely related. The keeper won't put them together.");
		return;
	}

	if (kin == 1 && !Horses_Confirm(playerid,"Close kin","They share a parent or grandparent. The foal will be inbred: weaker, frailer.","Cover her anyway"))
	{
		return;
	}

	if (fees[pick] > 0)
	{
		if (Economy_Pay(playerid,fees[pick],INVALID_CONTAINER_ID,"stud fee") != PAY_OK)
		{
			Gui_Notify(playerid,"You can't pay the stud fee.");
			return;
		}

		new ownerPlayer = INVALID_PLAYER_ID;

		foreach (new p : Player)
		{
			if (Character_GetId(p) == owners[pick])
			{
				ownerPlayer = p;
			}
		}

		Economy_GiveOrClaim(ownerPlayer,owners[pick],fees[pick],"stud fee");
	}

	new sireGenes[HORSES_LOCI], mareGenes[HORSES_LOCI], foal[HORSES_LOCI], seed = random(2000000000) + 1;
	Gene_Decode(genesHex[pick],sireGenes);
	Horses_GetGenes(mareid,mareGenes);
	Gene_Cross(sireGenes,mareGenes,foal,seed);
	Horses_MarkCovered(mareid,ids[pick],E_HORSES_BREED:breeds[pick],foal,kin == 1);
	new stallion = Horses_FindByHid(ids[pick]);

	if (stallion != INVALID_HORSE_ID)
	{
		Horses_AddCover(stallion);
		Horses_Save(stallion);
	}
	else
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET covers = IF(covers_season = %d, covers + 1, 1), covers_season = %d WHERE id = %d",season,season,ids[pick]));
	}

	Horses_Event(mareHid,HORSES_EVENT_COVERED,characterid,names[pick]);
	new name[HORSES_NAME_LEN];
	Horses_GetHorseName(mareid,name);
	Gui_Notify(playerid,sprintf("%s is covered. If she takes, she foals in %d days. Feed her well and don't gallop her late on.",name,HORSES_GESTATION_DAYS));
}

stock Horses_DailySweep()
{
	new today = Horses_Today();
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO horse_events (horse_id, at, kind, actor_character_id, note) SELECT id, %d, %d, owner_character_id, 'unpaid stable' FROM horses WHERE status = %d AND location_kind = %d AND ((hold_until = 0 AND stabled_day + %d < %d) OR (hold_until > 0 AND hold_until < %d))",gettime(),HORSES_EVENT_SOLD_ON,HORSES_STATUS_ALIVE,HORSES_PLACE_STABLED,HORSES_STABLE_UNPAID_DAYS,today,today));
	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET status = %d, owner_character_id = NULL WHERE status = %d AND location_kind = %d AND ((hold_until = 0 AND stabled_day + %d < %d) OR (hold_until > 0 AND hold_until < %d))",HORSES_STATUS_SOLD,HORSES_STATUS_ALIVE,HORSES_PLACE_STABLED,HORSES_STABLE_UNPAID_DAYS,today,today));

	for (new stable = 0;stable < HORSE_SEED_STABLES;stable++)
	{
		if (s_HorseStables[stable][E_HST_TRADES])
		{
			Horses_RollStock(stable,today);
		}
	}
}

forward Horses_KeeperStable(playerid,index,data);

public Horses_KeeperStable(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && Horses_StableOfActor(index) != -1)
	{
		Horses_MenuStableFor(playerid,Horses_StableOfActor(index));
	}

	return 1;
}

forward Horses_KeeperFetch(playerid,index,data);

public Horses_KeeperFetch(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && Horses_StableOfActor(index) != -1)
	{
		Horses_MenuFetchFor(playerid,Horses_StableOfActor(index));
	}

	return 1;
}

forward Horses_KeeperBuy(playerid,index,data);

public Horses_KeeperBuy(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && Horses_StableOfActor(index) != -1)
	{
		Horses_MenuBuyFor(playerid,Horses_StableOfActor(index));
	}

	return 1;
}

forward Horses_KeeperSell(playerid,index,data);

public Horses_KeeperSell(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && Horses_StableOfActor(index) != -1)
	{
		Horses_MenuSellFor(playerid,Horses_StableOfActor(index));
	}

	return 1;
}

forward Horses_KeeperServices(playerid,index,data);

public Horses_KeeperServices(playerid,index,data)
{
	if (IsPlayerConnected(playerid) && Horses_StableOfActor(index) != -1)
	{
		Horses_MenuServicesFor(playerid,Horses_StableOfActor(index));
	}

	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0;i < HORSE_SEED_STABLES;i++)
	{
		s_HorseStables[i][E_HST_ACTOR] = -1;
		s_HorseStables[i][E_HST_ROW] = 0;
	}
}

hook Actors_OnMenuBuild(playerid,index)
{
	new stable = Horses_StableOfActor(index);

	if (stable == -1)
	{
		return;
	}

	Actors_MenuAdd(playerid,"Stable a horse","Horses_KeeperStable",0,KIT_COLOUR_GOOD);
	Actors_MenuAdd(playerid,"Fetch a stabled horse","Horses_KeeperFetch");

	if (s_HorseStables[stable][E_HST_TRADES])
	{
		Actors_MenuAdd(playerid,"Buy a horse","Horses_KeeperBuy",0,KIT_COLOUR_ACCENT);
		Actors_MenuAdd(playerid,"Sell a horse","Horses_KeeperSell");
	}

	Actors_MenuAdd(playerid,"Doctoring and breeding","Horses_KeeperServices");
}
