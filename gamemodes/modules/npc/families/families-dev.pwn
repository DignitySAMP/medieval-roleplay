static Families_DevTarget(playerid)
{
	new family = Families_FindByHouse(GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE);

	if (family != -1)
	{
		return family;
	}

	new actor = Actors_FindNear(playerid,8.0,false), member = Families_GetMemberOfActor(actor);
	return member != -1 ? Families_GetMemberFamily(member) : -1;
}

CMD<ADMIN_LEVEL_TRIAL>:family(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[32];

	if (sscanf(params,"s[12]S()[32]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/family list | info | go [house] | meal [dinner|supper|end] | favour [n] | stores [n] | errands | freeze | refresh | foul [0|1|-1]");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new placed = 0, meals = 0;

		for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
		{
			if (Actors_IsPlaced(Families_GetMemberActor(member)))
			{
				placed++;
			}
		}

		for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
		{
			if (Families_IsMealOn(family))
			{
				meals++;
			}
		}

		new hour[12];
		Routine_GetHourName(Routine_GetHour(),hour);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Households: %d, %d people, %d out where someone can see them, %d at the table. Hour: %s%s.",FAMILY_SEED_HOUSEHOLDS,FAMILY_SEED_MEMBERS,placed,meals,hour,Families_IsFeastDay() ? (", a feast day") : (Families_IsFastDay() ? (", a fast day") : (""))));
		return 1;
	}

	if (!strcmp(action,"go",true))
	{
		new house = Houses_FindByKey(rest);

		if (house == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No house with that key.");
			return 1;
		}

		SetPlayerVirtualWorld(playerid,0);
		SetPlayerInterior(playerid,0);
		SetPlayerPos(playerid,g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2] + FAMILY_PED_Z);
		return 1;
	}

	if (!strcmp(action,"freeze",true))
	{
		static bool:frozen;
		frozen = !frozen;
		Families_SetFrozen(frozen);
		SendClientMessage(playerid,0xFFFFFFFF,frozen ? ("The households stay where they are.") : ("The households follow the bells again."));
		return 1;
	}

	if (!strcmp(action,"refresh",true))
	{
		Families_Refresh();
		SendClientMessage(playerid,0xFFFFFFFF,"Everyone moved to where the hour puts them.");
		return 1;
	}

	if (!strcmp(action,"foul",true))
	{
		Families_SetFoulOverride(strval(rest));
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Foul weather override: %d (-1 follows the sky).",Families_GetFoulOverride()));
		return 1;
	}

	if (!strcmp(action,"errands",true))
	{
		Families_ResetErrands(playerid);
		SendClientMessage(playerid,0xFFFFFFFF,"Your errands and their cooldowns are cleared.");
		return 1;
	}

	new family = Families_DevTarget(playerid);

	if (family == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Stand inside a house or next to one of its people.");
		return 1;
	}

	if (!strcmp(action,"info",true))
	{
		new house = Families_GetHouse(family), dishes[3];
		Families_GetMenu(family,dishes);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("The %s household (%s): wealth %d, piety %d, stores %d, your favour %d. Meal: %s, %d at the table, %d min in.",g_FamilyDefs[family][E_FAMILY_DEF_SURNAME],g_HouseDefs[house][E_HOUSE_DEF_KEY],g_FamilyDefs[family][E_FAMILY_DEF_WEALTH],g_FamilyDefs[family][E_FAMILY_DEF_PIETY],Families_GetStores(family),Families_GetFavour(playerid,family),Families_IsMealOn(family) ? (Families_GetMealKind(family) == FAMILY_MEAL_DINNER ? ("dinner") : ("supper")) : ("none"),Families_CountEaters(family),Families_MealElapsed(family)));

		for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
		{
			new name[ACTORS_NAME_LEN];
			Families_FormatName(member,name);
			SendClientMessage(playerid,0xD8CCB2FF,sprintf("  %s: %s%s%s",name,g_FamilyPlaceNames[Families_GetPlace(member)],Actors_IsPlaced(Families_GetMemberActor(member)) ? (", seen") : (""),Actors_IsDead(Families_GetMemberActor(member)) ? (", dead") : ("")));
		}

		return 1;
	}

	if (!strcmp(action,"meal",true))
	{
		if (!strcmp(rest,"end",true))
		{
			Families_EndMeal(family);
			SendClientMessage(playerid,0xFFFFFFFF,"The table is cleared.");
			return 1;
		}

		new bool:started = Families_StartMeal(family,!strcmp(rest,"supper",true) ? FAMILY_MEAL_SUPPER : FAMILY_MEAL_DINNER);
		Families_Invite(family,Character_GetId(playerid));
		SendClientMessage(playerid,0xFFFFFFFF,started ? ("The family sits down to eat, and you're invited.") : ("Nobody in this house can sit at the table."));
		return 1;
	}

	if (!strcmp(action,"favour",true))
	{
		Families_SetFavour(playerid,family,strval(rest));
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Your favour with the %ss is %d.",g_FamilyDefs[family][E_FAMILY_DEF_SURNAME],Families_GetFavour(playerid,family)));
		return 1;
	}

	if (!strcmp(action,"stores",true))
	{
		Families_SetStores(family,strval(rest));
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("The %ss' stores: %d of %d.",g_FamilyDefs[family][E_FAMILY_DEF_SURNAME],Families_GetStores(family),FAMILY_STORES_FULL));
		return 1;
	}

	return 1;
}
