#define FAMILY_NEWCOMER_MINUTES (120)
#define FAMILY_NEWCOMER_PAY (2)
#define FAMILY_NEWCOMER_TICK_MS (15000)
#define FAMILY_NEWCOMER_KEY "newcomer_wages"

enum
{
	FAMILY_ERRAND_COLLECT,
	FAMILY_ERRAND_DELIVER,
}

enum
{
	FAMILY_ERRAND_STATE_NONE,
	FAMILY_ERRAND_STATE_TAKEN,
	FAMILY_ERRAND_STATE_DONE,
}

static s_FamilyFavour[MAX_PLAYERS][FAMILY_SEED_HOUSEHOLDS];
static s_FamilyErrandActive[MAX_PLAYERS] = {-1, ...};
static s_FamilyErrandDoneAt[MAX_PLAYERS][FAMILY_SEED_ERRANDS];
static s_FamilyGreetedAt[MAX_PLAYERS][FAMILY_SEED_MEMBERS];
static bool:s_FamilyLoaded[MAX_PLAYERS];
static bool:s_FamilyNewcomerPay[MAX_PLAYERS];
static bool:s_FamilyErrandDoable[FAMILY_SEED_ERRANDS];
static s_FamilyDoableWork = -1;
static s_FamilyDoableTraders = -1;
static s_FamilyDoableWild = -1;
static bool:s_FamilyDoableFilter = true;

forward bool:Hunting_YieldsItem(item);

static bool:Families_NodeAvailable(const node[])
{
	if (node[0] == EOS || !strcmp(node,"fishing"))
	{
		return true;
	}

	if (!strcmp(node,"cow"))
	{
		return Animals_HerdKeeps(ANIMAL_COW);
	}

	if (!strcmp(node,"sheep"))
	{
		return Animals_HerdKeeps(ANIMAL_SHEEP);
	}

	if (!strcmp(node,"herd") || !strcmp(node,"animal"))
	{
		return Animals_HerdKeeps();
	}

	if (strfind(node,"kill") == 0)
	{
		return Animals_IsWild();
	}

	new kind = Work_FindKind(node);
	return kind != -1 && Work_CountKind(kind) > 0;
}

static bool:Families_MemberObtainable(item)
{
	new E_ITEM_KIND:itemKind = Item_GetDefKind(item);

	if ((Trader_GetCount() > 0 && Trader_StocksItem(item)) || Fishing_FindBreed(item) != -1 || (Animals_IsWild() && Hunting_YieldsItem(item)))
	{
		return true;
	}

	for (new hand = 0, made, amount;hand < Work_GetHandCount();hand++)
	{
		if (Work_GetHandOutput(hand,made,amount) && made == item)
		{
			return true;
		}
	}

	for (new recipe = 0;recipe < Recipe_GetCount();recipe++)
	{
		new E_ITEM_KIND:outKind, outParam, outAmount, node[RECIPE_NODE_LEN];

		if (!Recipe_GetOutput(recipe,outKind,outParam,outAmount) || outKind != itemKind || outParam != item)
		{
			continue;
		}

		Recipe_GetNode(recipe,node);

		if (Families_NodeAvailable(node))
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_IsItemObtainable(item)
{
	for (new nth = 0, member;(member = Item_GetGroupMember(item,nth)) != -1;nth++)
	{
		if (Families_MemberObtainable(member))
		{
			return true;
		}
	}

	return false;
}

stock Families_SetDoableFilter(bool:isOn)
{
	s_FamilyDoableFilter = isOn;
}

stock bool:Families_IsErrandDoable(errand)
{
	if (errand < 0 || errand >= FAMILY_SEED_ERRANDS)
	{
		return false;
	}

	if (!s_FamilyDoableFilter)
	{
		return true;
	}

	new work = Work_GetLayoutRevision(), traders = Trader_GetRevision(), wild = _:Animals_IsWild();

	if (work != s_FamilyDoableWork || traders != s_FamilyDoableTraders || wild != s_FamilyDoableWild)
	{
		s_FamilyDoableWork = work;
		s_FamilyDoableTraders = traders;
		s_FamilyDoableWild = wild;

		for (new each = 0;each < FAMILY_SEED_ERRANDS;each++)
		{
			s_FamilyErrandDoable[each] = g_FamilyErrandDefs[each][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER || Families_IsItemObtainable(g_FamilyErrandDefs[each][E_FAMILY_ERRAND_DEF_ITEM]);
		}
	}

	return s_FamilyErrandDoable[errand];
}

stock Families_GetFavour(playerid,family)
{
	return Util_IsValidPlayer(playerid) && family >= 0 && family < FAMILY_SEED_HOUSEHOLDS ? s_FamilyFavour[playerid][family] : 0;
}

stock Families_SetFavour(playerid,family,favour)
{
	if (!Util_IsValidPlayer(playerid) || family < 0 || family >= FAMILY_SEED_HOUSEHOLDS)
	{
		return;
	}

	s_FamilyFavour[playerid][family] = clamp(favour,FAMILY_FAVOUR_MIN,FAMILY_FAVOUR_MAX);
	new characterid = Character_GetId(playerid);

	if (characterid > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO household_favour (household_id, character_id, favour, last_meal_at) VALUES (%d, %d, %d, 0) ON DUPLICATE KEY UPDATE favour = VALUES(favour)",family + 1,characterid,s_FamilyFavour[playerid][family]));
	}
}

stock Families_AddFavour(playerid,family,delta)
{
	if (delta != 0)
	{
		Families_SetFavour(playerid,family,Families_GetFavour(playerid,family) + delta);
	}
}

stock Families_GetErrand(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_FamilyErrandActive[playerid] : -1;
}

stock Families_GetErrandGiver(errand)
{
	return errand >= 0 && errand < FAMILY_SEED_ERRANDS ? Families_GetMemberActor(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER]) : -1;
}

stock Families_GetErrandCount()
{
    return FAMILY_SEED_ERRANDS;
}

stock Families_GetErrandOffer(errand,dest[],size = sizeof(dest))
{
    dest[0] = EOS;
    if (errand >= 0 && errand < FAMILY_SEED_ERRANDS)
    {
        strcopy(dest,g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TEXT],size);
    }
}

stock Families_GetErrandRequirements(errand,&item,&amount,&target)
{
    item = -1;
    amount = 0;
    target = -1;
    if (errand < 0 || errand >= FAMILY_SEED_ERRANDS)
    {
        return -1;
    }
    item = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_ITEM];
    amount = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_AMOUNT];
    target = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TARGET];
    return g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND];
}

stock bool:Families_IsErrandAvailable(playerid,errand)
{
	return Util_IsValidPlayer(playerid) && errand >= 0 && errand < FAMILY_SEED_ERRANDS && s_FamilyLoaded[playerid] && Families_GetErrand(playerid) == -1 && Families_GetErrandGiver(errand) != -1 && !Families_IsErrandCooling(playerid,errand) && !Actors_IsDead(Families_GetErrandGiver(errand)) && Families_IsErrandDoable(errand);
}

stock Families_FormatLedger(playerid,errand,text[],destination[],reward[],size = 160)
{
	text[0] = EOS;
	destination[0] = EOS;
	reward[0] = EOS;

	if (errand < 0 || errand >= FAMILY_SEED_ERRANDS)
	{
		return;
	}

	new giver = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER], target = giver, name[ACTORS_NAME_LEN], goods[ITEM_NAME_LEN], money[32];
	Families_FormatName(giver,name);

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
	{
		format(text,size,"Carry a parcel for %s",name);
		target = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TARGET];
	}
	else
	{
		new item = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_ITEM];
		Item_GetName(Item_GetDefKind(item),item,goods);
		format(text,size,"%d %s for %s",g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_AMOUNT],goods,name);
	}

	Families_FormatName(target,name);
	format(destination,size,"To %s at %s",name,g_HouseDefs[Families_GetHouse(Families_GetMemberFamily(target))][E_HOUSE_DEF_NAME]);
	Economy_Format(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_COIN] * Families_ErrandPayFactor(playerid),money);
	format(reward,size,"%s + family favour | No deadline",money);
}

stock Families_ErrandFamily(errand)
{
	return g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_FAMILY];
}

stock Families_FormatErrandKey(errand,dest[],size = sizeof(dest))
{
	new family = Families_ErrandFamily(errand);
	format(dest,size,"%s:%d",g_HouseDefs[Families_GetHouse(family)][E_HOUSE_DEF_KEY],errand - g_FamilyDefs[family][E_FAMILY_DEF_FIRST_ERRAND]);
}

stock Families_FindErrandByKey(const key[])
{
	new candidate[32];

	for (new errand = 0;errand < FAMILY_SEED_ERRANDS;errand++)
	{
		Families_FormatErrandKey(errand,candidate);

		if (!strcmp(candidate,key))
		{
			return errand;
		}
	}

	return -1;
}

stock bool:Families_IsErrandCooling(playerid,errand)
{
	return s_FamilyErrandDoneAt[playerid][errand] > 0 && gettime() - s_FamilyErrandDoneAt[playerid][errand] < FAMILY_ERRAND_COOLDOWN;
}

stock Families_ResetErrands(playerid)
{
	s_FamilyErrandActive[playerid] = -1;

	for (new errand = 0;errand < FAMILY_SEED_ERRANDS;errand++)
	{
		s_FamilyErrandDoneAt[playerid][errand] = 0;
	}

	for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
	{
		s_FamilyGreetedAt[playerid][member] = 0;
	}

	new characterid = Character_GetId(playerid);

	if (characterid > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM errand_progress WHERE character_id = %d",characterid));
	}
}

static Families_SaveErrand(playerid,errand,progress,doneAt)
{
	new characterid = Character_GetId(playerid), key[32];

	if (characterid <= 0)
	{
		return;
	}

	Families_FormatErrandKey(errand,key);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO errand_progress (character_id, errand_key, state, taken_at, done_at) VALUES (%d, '%e', %d, %d, %d) ON DUPLICATE KEY UPDATE state = VALUES(state), taken_at = IF(VALUES(state) = 1, VALUES(taken_at), taken_at), done_at = VALUES(done_at)",characterid,key,progress,gettime(),doneAt));
}

stock Families_PickErrand(playerid,member)
{
	new family = Families_GetMemberFamily(member), first = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_ERRAND], count = g_FamilyDefs[family][E_FAMILY_DEF_ERRANDS], fallback = -1;

	for (new errand = first;errand < first + count;errand++)
	{
		if (Families_IsErrandCooling(playerid,errand) || Actors_IsDead(Families_GetMemberActor(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER])) || !Families_IsErrandDoable(errand))
		{
			continue;
		}

		if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER] == member)
		{
			return errand;
		}

		if (fallback == -1)
		{
			fallback = errand;
		}
	}

	return fallback;
}

stock bool:Families_HasUndoableErrand(playerid,member)
{
	new family = Families_GetMemberFamily(member), first = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_ERRAND], count = g_FamilyDefs[family][E_FAMILY_DEF_ERRANDS];

	for (new errand = first;errand < first + count;errand++)
	{
		if (!Families_IsErrandCooling(playerid,errand) && !Actors_IsDead(Families_GetMemberActor(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER])) && !Families_IsErrandDoable(errand))
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_TakeErrand(playerid,errand)
{
	if (!Util_IsValidPlayer(playerid) || errand < 0 || errand >= FAMILY_SEED_ERRANDS || s_FamilyErrandActive[playerid] != -1 || Families_IsErrandCooling(playerid,errand))
	{
		return false;
	}

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER && !Inventory_Give(playerid,Item_GetDefKind(ITEM_PARCEL),ITEM_PARCEL,1))
	{
		Gui_Notify(playerid,"Your bag is full. Make room for the parcel first.");
		return false;
	}

	s_FamilyErrandActive[playerid] = errand;
	Families_SaveErrand(playerid,errand,FAMILY_ERRAND_STATE_TAKEN,0);

	new text[144], name[ACTORS_NAME_LEN];

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
	{
		new target = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TARGET], house[28];
		Families_FormatName(target,name);
		strcopy(house,g_HouseDefs[Families_GetHouse(Families_GetMemberFamily(target))][E_HOUSE_DEF_NAME]);
		format(text,sizeof(text),"Errand: take the parcel to %s at %s. Anyone of that household will take it in.",name,house);
	}
	else
	{
		new item[ITEM_NAME_LEN], item_id = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_ITEM];
		Item_GetName(Item_GetDefKind(item_id),item_id,item);
		Families_FormatName(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER],name);
		format(text,sizeof(text),"Errand: bring %d %s to %s.",g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_AMOUNT],item,name);
	}

	Gui_Notify(playerid,text);
    SendClientMessage(playerid,0xD8CCB2FF,text);
	return true;
}

stock bool:Families_IsNewcomerPay(playerid)
{
	return Util_IsValidPlayer(playerid) && Talent_IsLoaded(playerid) && Talent_GetActiveMinutes(playerid) < FAMILY_NEWCOMER_MINUTES;
}

stock Families_ErrandPayFactor(playerid)
{
	return Families_IsNewcomerPay(playerid) ? FAMILY_NEWCOMER_PAY : 1;
}

static Families_UpdateNewcomerPay(playerid)
{
	if (!Session_IsPlaying(playerid) || !Talent_IsLoaded(playerid) || Tutorial_IsActive(playerid) || TutorialIsland_IsOn(playerid) || Tutorial_IsWelcoming(playerid))
	{
		return;
	}

	new left = FAMILY_NEWCOMER_MINUTES - Talent_GetActiveMinutes(playerid), text[144];

	if (left > 0)
	{
		if (!s_FamilyNewcomerPay[playerid])
		{
			if (Gui_IsBusy(playerid))
			{
				return;
			}

			s_FamilyNewcomerPay[playerid] = true;
			format(text,sizeof(text),"Family errands pay you double until you've played %d hours.",FAMILY_NEWCOMER_MINUTES / 60);
			Gui_Notify(playerid,text);
		}

		format(text,sizeof(text),"Family errands pay you double coin until you've played %d hours.",FAMILY_NEWCOMER_MINUTES / 60);
		Buff_Set(playerid,FAMILY_NEWCOMER_KEY,"Newcomer's wages",text,left * 60,FAMILY_NEWCOMER_MINUTES * 60);
		return;
	}

	if (s_FamilyNewcomerPay[playerid])
	{
		s_FamilyNewcomerPay[playerid] = false;
		Buff_Clear(playerid,FAMILY_NEWCOMER_KEY);
		Gui_Notify(playerid,"Your newcomer's wages have ended. Family errands pay their usual coin from now on.");
	}
}

Timer_Declare(Families_NewcomerTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Families_UpdateNewcomerPay(playerid);
		}
	}
}

forward Families_NewcomerDeferred(playerid);

public Families_NewcomerDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Families_UpdateNewcomerPay(playerid);
	}

	return 1;
}

stock Families_ResetNewcomerPay(playerid)
{
	s_FamilyNewcomerPay[playerid] = false;
	Buff_Clear(playerid,FAMILY_NEWCOMER_KEY);
}

static Families_PayErrand(playerid,errand)
{
	new family = Families_ErrandFamily(errand), coin = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_COIN] * Families_ErrandPayFactor(playerid), text[144], money[32];

	if (coin > 0)
	{
		Economy_Give(playerid,coin,"errand");
	}

	Families_AddFavour(playerid,family,g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_FAVOUR]);
	s_FamilyErrandActive[playerid] = -1;
	s_FamilyErrandDoneAt[playerid][errand] = gettime();
	Families_SaveErrand(playerid,errand,FAMILY_ERRAND_STATE_DONE,gettime());
	Economy_Format(coin,money);

	if (Families_IsNewcomerPay(playerid))
	{
		format(text,sizeof(text),"Errand done. You get %s, double while you're new.",money);
		Gui_Notify(playerid,text);
		format(text,sizeof(text),"The %ss think better of you.",g_FamilyDefs[family][E_FAMILY_DEF_SURNAME]);
	}
	else
	{
		format(text,sizeof(text),"Errand done. You get %s, and the %ss think better of you.",money,g_FamilyDefs[family][E_FAMILY_DEF_SURNAME]);
	}

	Gui_Notify(playerid,text);
	pawn_call_public("Household_OnErrandDone","ddd",playerid,family,errand);
}

stock bool:Families_CanHandIn(playerid,member)
{
	new errand = Families_GetErrand(playerid);

	if (errand == -1)
	{
		return false;
	}

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
	{
		return Families_GetMemberFamily(member) == Families_GetMemberFamily(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TARGET]);
	}

	return Families_GetMemberFamily(member) == Families_ErrandFamily(errand);
}

stock bool:Families_HandIn(playerid,member)
{
	new errand = Families_GetErrand(playerid);

	if (!Families_CanHandIn(playerid,member))
	{
		return false;
	}

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
	{
		if (!Inventory_Take(playerid,Item_GetDefKind(ITEM_PARCEL),ITEM_PARCEL,1))
		{
			Gui_Notify(playerid,"You've lost the parcel. Go back and give up the errand.");
			return false;
		}

		new target = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TARGET];
		Families_AddFavour(playerid,Families_GetMemberFamily(member),FAMILY_FAVOUR_NEIGHBOUR);

		if (member == target)
		{
			Actors_Say(Families_GetMemberActor(member),"For me? Thank you. Tell them I said so.");
		}
		else
		{
			Actors_Say(Families_GetMemberActor(member),sprintf("For %s? I'll see %s gets it. Thank you for bringing it.",g_FamilyMemberDefs[target][E_FAMILY_MEMBER_DEF_NAME],g_FamilyMemberDefs[target][E_FAMILY_MEMBER_DEF_SEX] ? ("she") : ("he")));
		}
		Families_PayErrand(playerid,errand);
		return true;
	}

	new item = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_ITEM], amount = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_AMOUNT], E_ITEM_KIND:kind = Item_GetDefKind(item);

	if (Inventory_CountGroup(playerid,item) < amount)
	{
		new name[ITEM_NAME_LEN], text[96];
		Item_GetName(kind,item,name);
		format(text,sizeof(text),"You need %d %s. You have %d.",amount,name,Inventory_CountGroup(playerid,item));
		Gui_Notify(playerid,text);
		return false;
	}

	Inventory_TakeGroup(playerid,item,amount);
	Actors_Say(Families_GetMemberActor(member),"That's just what I needed. Bless you.");
	Families_PayErrand(playerid,errand);
	return true;
}

stock Families_GiveUpErrand(playerid)
{
	new errand = Families_GetErrand(playerid);

	if (errand == -1)
	{
		return;
	}

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
	{
		Inventory_Take(playerid,Item_GetDefKind(ITEM_PARCEL),ITEM_PARCEL,1);
	}

	s_FamilyErrandActive[playerid] = -1;
	Families_SaveErrand(playerid,errand,FAMILY_ERRAND_STATE_NONE,0);
	Gui_Notify(playerid,"You give up the errand.");
}

stock E_FAMILY_MEAL:Families_NextMeal(&bool:soon)
{
	new E_HOUR_NAME:name = Routine_GetHour();
	soon = true;

    if (Calendar_GetMinuteOfDay() % 60 < FAMILY_MEAL_WINDOW && Routine_HourAt(Calendar_GetHour()) == name)
    {
        if (name == HOUR_SEXT)
        {
            return FAMILY_MEAL_DINNER;
        }
        if (name == HOUR_VESPERS)
        {
            return FAMILY_MEAL_SUPPER;
        }
    }

	switch (name)
	{
		case HOUR_LAUDS, HOUR_PRIME, HOUR_TERCE: return FAMILY_MEAL_DINNER;
		case HOUR_SEXT, HOUR_NONES: return FAMILY_MEAL_SUPPER;
	}

	soon = false;
	return FAMILY_MEAL_DINNER;
}

stock Families_AskForMeal(playerid,member)
{
	new family = Families_GetMemberFamily(member), actor = Families_GetMemberActor(member), characterid = Character_GetId(playerid), bool:soon;
	new E_FAMILY_MEAL:meal = Families_NextMeal(soon), bool:laid = Families_IsTableOpen(family);

	if (laid)
	{
		meal = Families_GetMealKind(family);
		soon = true;
	}

	if (Hygiene_IsReeking(playerid))
	{
		Actors_Say(actor,"Not at our table like that. Wash first, then ask.");
		return 0;
	}

	if (!Families_HasGuestSeat(family))
	{
		Actors_Say(actor,"We've only the stools for our own, and no room for a guest at the board. The inn will feed you, or try a bigger house.");
		return 0;
	}

	if (Families_FindFreeSeat(INVALID_PLAYER_ID,family) == -1)
	{
		Actors_Say(actor,"Our table's full, I'm afraid. Try another house, there may be room.");
		return 0;
	}

	if (Families_IsMealOn(family) && !Families_IsGraceSaid(family))
	{
		Families_Invite(family,characterid);
		Actors_Say(actor,"We're just sitting down. Find a seat, quick.");
		return 1;
	}

	if (Families_IsMealOn(family) || !soon)
	{
		Actors_Say(actor,"You've missed it. Come back before the next bell.");
		return 0;
	}

	if (Families_IsInvited(family,characterid))
	{
		Actors_Say(actor,laid ? ("You're expected. Sit down.") : (meal == FAMILY_MEAL_DINNER ? ("Yes, yes. Come at Sext.") : ("Yes, yes. Come at Vespers.")));
		return 1;
	}

	if (Houses_HoldsRoomIn(playerid,Families_GetHouse(family)))
	{
		Families_Invite(family,characterid);
		Actors_Say(actor,"You live under our roof. Of course you eat with us.");
		return 1;
	}

	new favour = Families_GetFavour(playerid,family);

	if (favour < 0)
	{
		Actors_Say(actor,"Not today. We don't know you well enough.");
		return 0;
	}

	if (favour < FAMILY_FAVOUR_FREE_MEAL && g_FamilyDefs[family][E_FAMILY_DEF_WEALTH] <= 1)
	{
		Actors_Say(actor,"We've little enough. A coin for the pot and you're welcome.");
		return 2;
	}

	Families_Invite(family,characterid);
	new text[CHAT_LINE_MAX];

	if (laid)
	{
		strcopy(text,"Sit down, then. There's always room for one more.");
	}
	else if (Families_FormatVoice(member,_:FAMILY_VOICE_MEAL,text,sizeof(text)))
	{
		new at = strfind(text,"{meal}");

		if (at != -1)
		{
			strdel(text,at,at + 6);
			strins(text,meal == FAMILY_MEAL_DINNER ? ("Sext") : ("Vespers"),at,sizeof(text));
		}
	}
	else
	{
		format(text,sizeof(text),"Come and eat with us at %s. There's always room for one more.",meal == FAMILY_MEAL_DINNER ? ("Sext") : ("Vespers"));
	}

	Actors_Say(actor,text);
	return 1;
}

stock Families_RememberPaid(playerid,family)
{
	new characterid = Character_GetId(playerid), meal = Families_CurrentMealId(family);

	if (characterid > 0 && meal > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO household_favour (household_id, character_id, favour, last_meal_at) VALUES (%d, %d, %d, %d) ON DUPLICATE KEY UPDATE last_meal_at = VALUES(last_meal_at)",family + 1,characterid,s_FamilyFavour[playerid][family],meal));
	}
}

stock bool:Families_PayForMeal(playerid,member)
{
	new family = Families_GetMemberFamily(member), characterid = Character_GetId(playerid), actor = Families_GetMemberActor(member);

	if (!Families_IsInvited(family,characterid))
	{
		if (!Families_HasGuestSeat(family))
		{
			Actors_Say(actor,"We've no room for a guest at the board. Keep your coin and try the inn.");
			return false;
		}

		if (Families_FindFreeSeat(INVALID_PLAYER_ID,family) == -1)
		{
			Actors_Say(actor,"Our table's full, I'm afraid. Keep your coin and try another house.");
			return false;
		}

		if (!Families_CanInvite(family,characterid))
		{
			Actors_Say(actor,"We've no more room at the table for this meal. Come another day.");
			return false;
		}

		if (Economy_Pay(playerid,FAMILY_MEAL_COIN,INVALID_CONTAINER_ID,"meal") != PAY_OK)
		{
			Gui_Notify(playerid,"You don't have a coin to spare.");
			return false;
		}

		Families_Invite(family,characterid);
		Families_RememberPaid(playerid,family);
	}
	else
	{
		Actors_Say(actor,Families_IsTableOpen(family) ? ("You've paid already. Sit down.") : ("You've paid already. Come back at the bell."));
		Families_SeatInvited(playerid,family);
		return true;
	}

	if (Families_IsTableOpen(family))
	{
		Actors_Say(actor,"Thank you. The table is laid, sit down.");
		Families_SeatInvited(playerid,family);
		return true;
	}

	Actors_Say(actor,"Thank you. Come back at the bell.");
	return true;
}

stock bool:Families_WillGreet(playerid,member)
{
	return !Families_IsGuest(playerid) && gettime() >= s_FamilyGreetedAt[playerid][member];
}

stock Families_Greet(playerid,member)
{
	if (!Families_WillGreet(playerid,member))
	{
		return;
	}

	s_FamilyGreetedAt[playerid][member] = gettime() + FAMILY_GREET_COOLDOWN;
	new actor = Families_GetMemberActor(member), family = Families_GetMemberFamily(member), favour = Families_GetFavour(playerid,family), text[96];

	if (Hygiene_IsStinking(playerid))
	{
		strcopy(text,Hygiene_IsReeking(playerid) ? ("Mother of God, the smell. Say what you want and go wash.") : ("You've a smell about you, friend. What is it?"));
	}
	else if (favour >= FAMILY_FAVOUR_NAME)
	{
		new name[MAX_PLAYER_NAME];
		Character_GetName(playerid,name);
		new space = strfind(name," ");

		if (space != -1)
		{
			name[space] = EOS;
		}

		format(text,sizeof(text),"Good to see you, %s.",name);
	}
	else if (favour < 0)
	{
		strcopy(text,"What is it?");
	}
	else
	{
		switch (Routine_GetHour())
		{
			case HOUR_LAUDS, HOUR_PRIME, HOUR_TERCE: strcopy(text,"God give you a good morning.");
			case HOUR_SEXT, HOUR_NONES: strcopy(text,"Good day to you.");
			default: strcopy(text,"Good evening.");
		}
	}

	Actors_Say(actor,text);
}

forward Task:Families_LoadPlayer(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Families_LoadPlayer(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT household_id, favour, last_meal_at FROM household_favour WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new household, favour, paidMeal;
		cache_get_value_name_int(row,"household_id",household);
		cache_get_value_name_int(row,"favour",favour);
		cache_get_value_name_int(row,"last_meal_at",paidMeal);

		if (household >= 1 && household <= FAMILY_SEED_HOUSEHOLDS)
		{
			s_FamilyFavour[playerid][household - 1] = favour;

			if (paidMeal > 0 && paidMeal == Families_CurrentMealId(household - 1))
			{
				Families_Invite(household - 1,characterid);
			}
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT errand_key, state, done_at FROM errand_progress WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new key[32], progress, doneAt;
		cache_get_value_name(row,"errand_key",key);
		cache_get_value_name_int(row,"state",progress);
		cache_get_value_name_int(row,"done_at",doneAt);
		new errand = Families_FindErrandByKey(key);

		if (errand == -1)
		{
			continue;
		}

		s_FamilyErrandDoneAt[playerid][errand] = doneAt;

		if (progress == FAMILY_ERRAND_STATE_TAKEN)
		{
			s_FamilyErrandActive[playerid] = errand;
		}
	}

	s_FamilyLoaded[playerid] = true;
	return async 1;
}
#pragma warning pop

static Families_ClearPlayer(playerid)
{
	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		s_FamilyFavour[playerid][family] = 0;
	}

	for (new errand = 0;errand < FAMILY_SEED_ERRANDS;errand++)
	{
		s_FamilyErrandDoneAt[playerid][errand] = 0;
	}

	s_FamilyErrandActive[playerid] = -1;
	s_FamilyLoaded[playerid] = false;
}

stock bool:Families_IsPlayerLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FamilyLoaded[playerid];
}

stock Families_OpenWork(playerid,member)
{
    if (Families_GetErrand(playerid) != -1)
    {
        Actors_Say(Families_GetMemberActor(member),"You've already taken an errand. Finish that one first.");
        return;
    }

	new actor = Families_GetMemberActor(member), errand = Families_PickErrand(playerid,member);

	if (errand == -1)
	{
		new line[CHAT_LINE_MAX];

		if (Families_HasUndoableErrand(playerid,member))
		{
			Actors_Say(actor,"I've jobs waiting, but nothing you could fetch for me right now. Ask me again another day.");
			return;
		}

		if (!Families_FormatVoice(member,_:FAMILY_VOICE_WORK,line,sizeof(line)))
		{
			strcopy(line,"Nothing today. Come back another time.");
		}

		Actors_Say(actor,line);
		return;
	}

	Families_OfferErrand(playerid,errand);
}

stock Families_WrapLines(const text[],Float:width)
{
	new perLine = max(1,floatround(width / FAMILY_TEXT_CHAR_WIDTH,floatround_floor)), lines = 1, column = 0, length = strlen(text);

	for (new i = 0;i < length;)
	{
		new word = i;

		while (word < length && text[word] != ' ')
		{
			word++;
		}

		new size = word - i;

		if (column > 0 && column + 1 + size > perLine)
		{
			lines++;
			column = 0;
		}

		column += (column > 0 ? 1 : 0) + size;
		i = word + 1;
	}

	return lines;
}

stock Families_OfferErrand(playerid,errand)
{
	new giver = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_GIVER], name[ACTORS_NAME_LEN], Float:x, Float:y, Float:width;
	Actors_Say(Families_GetMemberActor(giver),g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TEXT]);
	Actors_GetName(Families_GetMemberActor(giver),name);

	new epoch = Gui_BeginFlow(playerid), Float:panelWidth = FAMILY_PANEL_WIDTH + 60.0, recipient[64];
	new Float:textHeight = float(max(2,Families_WrapLines(g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TEXT],panelWidth * (1.0 - KIT_BOX_INSET_X * 2.0)))) * FAMILY_TEXT_LINE, Float:forHeight = 0.0;

	if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
	{
		new target = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TARGET], person[ACTORS_NAME_LEN];
		Families_FormatName(target,person);
		format(recipient,sizeof(recipient),"For %s, at %s.",person,g_HouseDefs[Families_GetHouse(Families_GetMemberFamily(target))][E_HOUSE_DEF_NAME]);
		forHeight = FAMILY_TEXT_LINE + 2.0;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,panelWidth,textHeight + forHeight + KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
	Kit_AddText(playerid,x,y,g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_TEXT],KIT_COLOUR_TEXT,KIT_TEXT_BODY,TEXT_DRAW_FONT_1,false,width);

	if (forHeight > 0.0)
	{
		Kit_AddText(playerid,x,y + textHeight + 2.0,recipient,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddChoice(playerid,x,y + textHeight + forHeight,width,"I'll do it",1,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + textHeight + forHeight + KIT_ROW + 8.0,80.0,"Not now",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick == 1 && Families_TakeErrand(playerid,errand))
	{
		Actors_Say(Families_GetMemberActor(giver),"Good. Don't be long.");
	}
}

stock Families_OpenMealOffer(playerid,member)
{
	new result = Families_AskForMeal(playerid,member);

	if (result == 1)
	{
		Families_SeatInvited(playerid,Families_GetMemberFamily(member));
		return;
	}

	if (result != 2)
	{
		return;
	}

	new name[ACTORS_NAME_LEN], money[24], label[48], Float:x, Float:y, Float:width;
	Actors_GetName(Families_GetMemberActor(member),name);
	Economy_Format(FAMILY_MEAL_COIN,money);
	format(label,sizeof(label),"Give %s for the pot",money);

	new epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,FAMILY_PANEL_WIDTH,KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
	Kit_AddChoice(playerid,x,y,width,label,1,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW + 8.0,80.0,"Not now",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick == 1)
	{
		Families_PayForMeal(playerid,member);
	}
}

forward Families_MenuMeal(playerid,index,data);

public Families_MenuMeal(playerid,index,data)
{
	#pragma unused index

	if (IsPlayerConnected(playerid))
	{
		Families_OpenMealOffer(playerid,data);
	}

	return 1;
}

forward Families_MenuWork(playerid,index,data);

public Families_MenuWork(playerid,index,data)
{
	#pragma unused index

	if (IsPlayerConnected(playerid))
	{
		Families_OpenWork(playerid,data);
	}

	return 1;
}

forward Families_MenuHandIn(playerid,index,data);

public Families_MenuHandIn(playerid,index,data)
{
	#pragma unused index

	if (IsPlayerConnected(playerid))
	{
		Families_HandIn(playerid,data);
	}

	return 1;
}

forward Families_MenuGiveUp(playerid,index,data);

public Families_MenuGiveUp(playerid,index,data)
{
	#pragma unused index, data

	if (IsPlayerConnected(playerid))
	{
		Families_GiveUpErrand(playerid);
	}

	return 1;
}

forward Household_OnErrandDone(playerid,family,errand);

public Household_OnErrandDone(playerid,family,errand)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Families_ClearPlayer(playerid);
	s_FamilyNewcomerPay[playerid] = false;
}

hook Character_OnLoaded(playerid,characterid)
{
	Families_ClearPlayer(playerid);
	Families_LoadPlayer(playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Families_ClearPlayer(playerid);
	Families_ResetNewcomerPay(playerid);
}

hook Talent_OnLoaded(playerid)
{
	Families_UpdateNewcomerPay(playerid);
}

hook Tutorial_OnWelcomed(playerid)
{
	SetTimerEx("Families_NewcomerDeferred",0,false,"d",playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		Families_ResetNewcomerPay(playerid);
	}
}

hook Actors_OnMenuOpen(playerid,index)
{
	new member = Families_GetMemberOfActor(index);

	if (member != -1)
	{
		Families_Greet(playerid,member);
	}
}

hook Actors_OnMenuBuild(playerid,index)
{
	new member = Families_GetMemberOfActor(index);

	if (member == -1)
	{
		return;
	}

	new family = Families_GetMemberFamily(member), errand = Families_GetErrand(playerid), bool:soon;

	if (errand != -1 && Families_CanHandIn(playerid,member))
	{
		if (g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_KIND] == FAMILY_ERRAND_DELIVER)
		{
			Actors_MenuAdd(playerid,"Hand over the parcel","Families_MenuHandIn",member,KIT_COLOUR_GOOD);
		}
		else
		{
			new label[ACTORS_MENU_LABEL], item[ITEM_NAME_LEN], item_id = g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_ITEM];
			Item_GetName(Item_GetDefKind(item_id),item_id,item);
			format(label,sizeof(label),"Give %d %s",g_FamilyErrandDefs[errand][E_FAMILY_ERRAND_DEF_AMOUNT],item);
			Actors_MenuAdd(playerid,label,"Families_MenuHandIn",member,KIT_COLOUR_GOOD);
		}
	}

	Families_NextMeal(soon);

	if ((soon || (Families_IsMealOn(family) && !Families_IsGraceSaid(family))) && !Families_IsInvited(family,Character_GetId(playerid)))
	{
		Actors_MenuAdd(playerid,"Ask to eat with the family","Families_MenuMeal",member);
	}

	if (errand == -1)
	{
		Actors_MenuAdd(playerid,"Ask if there's work","Families_MenuWork",member);
	}
	else if (Families_ErrandFamily(errand) == family)
	{
		Actors_MenuAdd(playerid,"Give up the errand","Families_MenuGiveUp",member,KIT_COLOUR_BAD);
	}
}
