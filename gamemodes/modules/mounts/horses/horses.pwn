enum E_HORSES_DATA
{
	E_HD_KIND,
	E_HD_HID,
	E_HD_OWNER,
	E_HD_NAME[HORSES_NAME_LEN],
	E_HD_SEX,
	E_HORSES_BREED:E_HD_BREED,
	E_HD_SIRE,
	E_HD_DAM,
	bool:E_HD_INBRED,
	E_HD_BORN,
	E_HD_GENES[HORSES_LOCI],
	E_HD_PROVEN,
	bool:E_HD_REVEALED,
	E_HD_BOND,
	Float:E_HD_HUNGER,
	Float:E_HD_THIRST,
	Float:E_HD_CONDITION,
	E_HD_SHOES,
	E_HD_NEEDS_AT,
	E_HD_BOND_DAY,
	E_HD_GAIN_RIDE,
	E_HD_GAIN_FEED,
	bool:E_HD_GROOMED,
	bool:E_HD_CALLED,
	E_HD_FORCED,
	E_HD_TOUCHED_DAY,
	E_HD_LAME_UNTIL,
	E_HD_SICK_UNTIL,
	E_HD_IN_FOAL_BY,
	E_HD_COVERED_DAY,
	E_HD_DUE_DAY,
	E_HD_FOAL_GENES[HORSES_LOCI],
	bool:E_HD_FOAL_INBRED,
	E_HD_FOAL_SIRE_BREED,
	E_HD_COVERED_SEASON,
	E_HD_COVERS,
	E_HD_COVERS_SEASON,
	E_HD_STUD_FEE,
	E_HD_LEND_CHAR,
	E_HD_LEND_UNTIL,
	E_HD_LAST_RIDDEN,
	E_HD_RIDE_MS,
	Float:E_HD_DIST,
	Float:E_HD_LAME_DIST,
	Float:E_HD_LAST[2],
	bool:E_HD_DIRTY,
	E_HD_MEADOW,
	E_HD_SPOT,
	E_HD_LEADER,
	E_HD_SADDLEBAG,
	E_HD_LOCATION,
	E_HD_STABLE,
	E_HD_STABLED_DAY,
	bool:E_HD_FEED_INCLUDED,
	E_HD_HOLD_UNTIL,
	E_HD_THIEF,
	E_HD_HUNGER_BAND,
	E_HD_CONDITION_BAND,
	E_HD_SAVED_AT,
	bool:E_HD_BLANKET,
}

static s_HorseData[MAX_HORSES][E_HORSES_DATA];

forward Task:Horses_Foal(horseid);
forward Task:Horses_Adopt(horseid,characterid,source);

stock Horses_Now()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Calendar_DaysSinceEpoch(day,month,year) * HORSES_DAY_MINUTES + Calendar_GetMinuteOfDay();
}

stock Horses_Today()
{
	return Horses_Now() / HORSES_DAY_MINUTES;
}

stock Horses_SeasonIndex()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return year * 4 + _:Calendar_GetSeason();
}

stock bool:Horses_IsBreedingSeason()
{
	new E_SEASON:season = Calendar_GetSeason();
	return season == SEASON_SPRING || season == SEASON_SUMMER;
}

stock Horses_GetKind(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_KIND] : HORSES_KIND_NONE;
}

stock bool:Horses_IsOwned(horseid)
{
	return Horse_IsValid(horseid) && s_HorseData[horseid][E_HD_KIND] == HORSES_KIND_OWNED;
}

stock bool:Horses_IsWild(horseid)
{
	return Horse_IsValid(horseid) && s_HorseData[horseid][E_HD_KIND] == HORSES_KIND_WILD;
}

stock Horses_GetHid(horseid)
{
	return Horses_IsOwned(horseid) ? s_HorseData[horseid][E_HD_HID] : 0;
}

stock Horses_FindByHid(hid)
{
	if (hid <= 0)
	{
		return INVALID_HORSE_ID;
	}

	for (new i = 0;i < MAX_HORSES;i++)
	{
		if (Horse_IsValid(i) && s_HorseData[i][E_HD_KIND] == HORSES_KIND_OWNED && s_HorseData[i][E_HD_HID] == hid)
		{
			return i;
		}
	}

	return INVALID_HORSE_ID;
}

stock Horses_GetOwner(horseid)
{
	return Horses_IsOwned(horseid) ? s_HorseData[horseid][E_HD_OWNER] : 0;
}

stock bool:Horses_IsOwner(playerid,horseid)
{
	return Horses_IsOwned(horseid) && Character_GetId(playerid) > 0 && s_HorseData[horseid][E_HD_OWNER] == Character_GetId(playerid);
}

stock bool:Horses_MayRide(playerid,horseid)
{
	if (Horses_IsOwner(playerid,horseid))
	{
		return true;
	}

	return Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_LEND_CHAR] == Character_GetId(playerid) && Horses_Now() < s_HorseData[horseid][E_HD_LEND_UNTIL];
}

stock Horses_GetOwnerPlayer(horseid)
{
	new owner = Horses_GetOwner(horseid);

	if (owner <= 0)
	{
		return INVALID_PLAYER_ID;
	}

	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == owner)
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Horses_GetHorseName(horseid,dest[],size = sizeof(dest))
{
	if (Horse_IsValid(horseid) && s_HorseData[horseid][E_HD_NAME][0] != EOS)
	{
		strcopy(dest,s_HorseData[horseid][E_HD_NAME],size);
		return;
	}

	Horse_GetName(horseid,dest,size);
}

stock Horses_GetSex(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_SEX] : HORSES_SEX_MARE;
}

stock E_HORSES_BREED:Horses_GetBreed(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_BREED] : HORSES_BREED_WILD;
}

stock Horses_GetGenes(horseid,genes[])
{
	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		genes[locus] = Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_GENES][locus] : Gene_Pair(1,1);
	}
}

stock Horses_GetBond(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_BOND] : 0;
}

stock Horses_BondTier(bond)
{
	return Util_ClampInt(bond / 20,HORSES_TIER_STRANGER,HORSES_TIER_DEVOTED);
}

stock Horses_GetTier(horseid)
{
	return Horses_BondTier(Horses_GetBond(horseid));
}

stock Float:Horses_GetHunger(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_HUNGER] : 0.0;
}

stock Float:Horses_GetThirst(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_THIRST] : 0.0;
}

stock Float:Horses_GetCondition(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_CONDITION] : 0.0;
}

stock Horses_GetShoes(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_SHOES] : HORSES_UNSHOD;
}

stock Horses_AgeDays(bornDay,today)
{
	return max(today - bornDay,0);
}

stock Horses_GetAgeDays(horseid)
{
	return Horse_IsValid(horseid) ? Horses_AgeDays(s_HorseData[horseid][E_HD_BORN],Horses_Today()) : 0;
}

stock Horses_GetAgeYears(horseid)
{
	return Horses_GetAgeDays(horseid) / HORSES_YEAR_DAYS;
}

stock bool:Horses_IsFoal(horseid)
{
	return Horse_IsValid(horseid) && Horses_GetAgeDays(horseid) < HORSES_GROWN_DAYS;
}

stock bool:Horses_IsOld(horseid)
{
	return Horses_GetAgeYears(horseid) >= HORSES_OLD_YEARS;
}

stock bool:Horses_IsLame(horseid)
{
	return Horse_IsValid(horseid) && Horses_Now() < s_HorseData[horseid][E_HD_LAME_UNTIL];
}

stock bool:Horses_IsSick(horseid)
{
	return Horse_IsValid(horseid) && Horses_Now() < s_HorseData[horseid][E_HD_SICK_UNTIL];
}

stock bool:Horses_IsInFoal(horseid)
{
	return Horse_IsValid(horseid) && s_HorseData[horseid][E_HD_IN_FOAL_BY] > 0;
}

stock Horses_DaysToFoal(horseid)
{
	return Horses_IsInFoal(horseid) ? max(s_HorseData[horseid][E_HD_DUE_DAY] - Horses_Today(),0) : 0;
}

stock bool:Horses_IsInSeason(hid,today)
{
	return (today + hid * 5) % HORSES_SEASON_CYCLE < HORSES_SEASON_DAYS;
}

stock Horses_DaysToSeason(hid,today)
{
	for (new i = 0;i < HORSES_SEASON_CYCLE;i++)
	{
		if (Horses_IsInSeason(hid,today + i))
		{
			return i;
		}
	}

	return 0;
}

stock Horses_StatTier(horseid,locus)
{
	if (!Horse_IsValid(horseid))
	{
		return 1;
	}

	new tier = Gene_Tier(s_HorseData[horseid][E_HD_GENES],locus);

	if (locus == HORSES_LOCUS_HLT && s_HorseData[horseid][E_HD_INBRED])
	{
		tier = max(tier - 1,0);
	}

	if ((locus == HORSES_LOCUS_SPD || locus == HORSES_LOCUS_STA) && Horses_IsOld(horseid))
	{
		tier = max(tier - 1,0);
	}

	return tier;
}

stock Float:Horses_SpeedFactor(tier,bool:unshod,bool:lame,Float:condition)
{
	new Float:factor = g_HorsesSpeedTier[Util_ClampInt(tier,0,2)];

	if (unshod)
	{
		factor *= 0.92;
	}

	if (lame)
	{
		factor *= 0.6;
	}

	if (condition < 20.0)
	{
		factor *= 0.9;
	}

	return factor;
}

stock Horses_StaminaMax(tier,Float:hunger)
{
	new stamina = g_HorsesStaminaTier[Util_ClampInt(tier,0,2)];
	return hunger < HORSES_HUNGRY_BAND ? stamina * 7 / 10 : stamina;
}

stock bool:Horses_CannotGallop(horseid)
{
	if (!Horse_IsValid(horseid))
	{
		return true;
	}

	if (s_HorseData[horseid][E_HD_HUNGER] <= 0.0 || s_HorseData[horseid][E_HD_CONDITION] < 10.0 || Horses_IsLame(horseid) || Horses_IsSick(horseid) || Horses_IsFoal(horseid))
	{
		return true;
	}

	return Horses_IsInFoal(horseid) && Horses_Today() - s_HorseData[horseid][E_HD_COVERED_DAY] >= HORSES_GESTATION_NO_GALLOP;
}

stock Horses_TypeOf(E_HORSES_BREED:breed,const genes[])
{
	return breed == HORSES_BREED_DONKEY ? MOUNT_DONKEY_TYPE : Gene_Coat(genes);
}

stock Horses_Refresh(horseid)
{
	if (!Horse_IsValid(horseid) || s_HorseData[horseid][E_HD_KIND] == HORSES_KIND_NONE)
	{
		return;
	}

	Horse_SetLabelHint(horseid,Horses_IsWild(horseid) ? ("Approach slowly with a halter and rope. Press Y to tame.") : ("Press F to ride"));
	new Float:speed = Horses_SpeedFactor(Horses_StatTier(horseid,HORSES_LOCUS_SPD),s_HorseData[horseid][E_HD_SHOES] == HORSES_UNSHOD,Horses_IsLame(horseid),s_HorseData[horseid][E_HD_CONDITION]);
	Horse_SetTack(horseid,0,s_HorseData[horseid][E_HD_SADDLEBAG] != INVALID_CONTAINER_ID ? MODEL_CARRY_SADDLEBAGS : 0);
	Horse_SetTack(horseid,1,s_HorseData[horseid][E_HD_BLANKET] ? MODEL_CARRY_HORSE_BLANKET : 0);
	Horse_SetTack(horseid,2,s_HorseData[horseid][E_HD_LEADER] != INVALID_PLAYER_ID ? MODEL_CARRY_HALTER_WORN : 0);
	Horse_SetRideStats(horseid,speed,Horses_StaminaMax(Horses_StatTier(horseid,HORSES_LOCUS_STA),s_HorseData[horseid][E_HD_HUNGER]),Horses_CannotGallop(horseid));
}

stock Horses_NeedsStep(&Float:hunger,&Float:thirst,&Float:condition,minutes,place,bool:fedIncluded,bool:winter,bool:sick,bool:canDie,bool:blanket = false)
{
	if (minutes <= 0)
	{
		return;
	}

	new Float:days = float(minutes) / float(HORSES_DAY_MINUTES), Float:factor = place == HORSES_PLACE_PASTURE ? HORSES_PASTURE_FACTOR : 1.0, bool:stabled = place == HORSES_PLACE_STABLED;

	if (!stabled || !fedIncluded)
	{
		hunger -= 100.0 / HORSES_HUNGER_DAYS * days * factor;
	}

	if (!stabled)
	{
		thirst -= 100.0 / HORSES_THIRST_DAYS * days * factor;
	}

	hunger = Util_Clamp(hunger,0.0,100.0);
	thirst = Util_Clamp(thirst,0.0,100.0);

	new Float:delta = 0.0;

	if (hunger <= 0.0)
	{
		delta -= HORSES_STARVE_CONDITION * days * factor;
	}

	if (thirst <= 0.0)
	{
		delta -= HORSES_STARVE_CONDITION * days * factor;
	}

	if (winter && !stabled)
	{
		delta -= HORSES_WINTER_CONDITION * days * factor * (blanket ? 0.5 : 1.0);
	}

	if (sick)
	{
		delta -= HORSES_SICK_CONDITION * days;
	}

	if (hunger > 70.0 && thirst > 70.0)
	{
		delta += HORSES_FED_CONDITION * days;
	}

	if (stabled)
	{
		delta += HORSES_STABLE_CONDITION * days;
	}

	condition = Util_Clamp(condition + delta,canDie ? 0.0 : 1.0,100.0);
}

static Horses_Band(Float:value,Float:low)
{
	if (value <= 0.0)
	{
		return 0;
	}

	return value < low ? 1 : 2;
}

stock Horses_UpdateNeeds(horseid)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	new now = Horses_Now(), minutes = now - s_HorseData[horseid][E_HD_NEEDS_AT];

	if (minutes <= 0)
	{
		s_HorseData[horseid][E_HD_NEEDS_AT] = now;
		return;
	}

	new Float:hunger = s_HorseData[horseid][E_HD_HUNGER], Float:thirst = s_HorseData[horseid][E_HD_THIRST], Float:condition = s_HorseData[horseid][E_HD_CONDITION];
	Horses_NeedsStep(hunger,thirst,condition,minutes,s_HorseData[horseid][E_HD_LOCATION],s_HorseData[horseid][E_HD_FEED_INCLUDED],Calendar_GetSeason() == SEASON_WINTER,Horses_IsSick(horseid),s_HorseData[horseid][E_HD_LOCATION] == HORSES_PLACE_WORLD && Horses_GetOwnerPlayer(horseid) != INVALID_PLAYER_ID,s_HorseData[horseid][E_HD_BLANKET]);
	s_HorseData[horseid][E_HD_HUNGER] = hunger;
	s_HorseData[horseid][E_HD_THIRST] = thirst;
	s_HorseData[horseid][E_HD_CONDITION] = condition;
	s_HorseData[horseid][E_HD_NEEDS_AT] = now;
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_CheckBands(horseid);

	if (condition <= 0.0)
	{
		Horses_Die(horseid,HORSES_DEATH_NEGLECT);
		return;
	}

	Horses_Refresh(horseid);
}

stock Horses_CheckBands(horseid)
{
	new hungerBand = Horses_Band(s_HorseData[horseid][E_HD_HUNGER],HORSES_HUNGRY_BAND), conditionBand = Horses_Band(s_HorseData[horseid][E_HD_CONDITION],30.0);

	new playerid = Horses_GetOwnerPlayer(horseid), name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);

	if (hungerBand != s_HorseData[horseid][E_HD_HUNGER_BAND])
	{
		new old = s_HorseData[horseid][E_HD_HUNGER_BAND];
		s_HorseData[horseid][E_HD_HUNGER_BAND] = hungerBand;
		pawn_call_public("Horse_OnNeedState","dddd",horseid,0,old,hungerBand);

		if (playerid != INVALID_PLAYER_ID && hungerBand < old)
		{
			if (hungerBand == 0)
			{
				Gui_Notify(playerid,sprintf("%s is starving. It won't gallop, and it wastes away until it's fed.",name));
			}
			else
			{
				Gui_Notify(playerid,sprintf("%s is getting hungry. Oats or hay soon.",name));
			}
		}
	}

	if (conditionBand != s_HorseData[horseid][E_HD_CONDITION_BAND])
	{
		new old = s_HorseData[horseid][E_HD_CONDITION_BAND];
		s_HorseData[horseid][E_HD_CONDITION_BAND] = conditionBand;
		pawn_call_public("Horse_OnNeedState","dddd",horseid,1,old,conditionBand);

		if (playerid != INVALID_PLAYER_ID && conditionBand < old)
		{
			Gui_Notify(playerid,sprintf("%s is growing thin. Feed it, water it and groom it, or stable it.",name));
		}
	}

	Horses_SyncBuffs(horseid);
}

stock Horses_SyncBuffs(horseid)
{
	new playerid = Horses_GetOwnerPlayer(horseid);

	if (playerid == INVALID_PLAYER_ID)
	{
		return;
	}

	new name[HORSES_NAME_LEN], label[64];
	Horses_GetHorseName(horseid,name);

	if (s_HorseData[horseid][E_HD_HUNGER] < HORSES_HUNGRY_BAND)
	{
		format(label,sizeof(label),"%s is hungry",name);
		Buff_Set(playerid,"horse_hungry",label,s_HorseData[horseid][E_HD_HUNGER] <= 0.0 ? ("It won't gallop at all. Feed it oats or hay.") : ("It won't gallop for long. Feed it oats, hay."));
	}
	else
	{
		Buff_Clear(playerid,"horse_hungry");
	}

	if (s_HorseData[horseid][E_HD_THIRST] < HORSES_THIRSTY_BAND)
	{
		format(label,sizeof(label),"%s is thirsty",name);
		Buff_Set(playerid,"horse_thirsty",label,"Water it at a trough, a stream or from a bucket.");
	}
	else
	{
		Buff_Clear(playerid,"horse_thirsty");
	}

	if (Horses_IsLame(horseid))
	{
		format(label,sizeof(label),"%s is lame",name);
		Buff_Set(playerid,"horse_lame",label,"It walks slowly and won't gallop. Rest it and have it shod.");
	}
	else
	{
		Buff_Clear(playerid,"horse_lame");
	}

	if (Horses_IsSick(horseid))
	{
		format(label,sizeof(label),"%s is sick",name);
		Buff_Set(playerid,"horse_sick",label,"It won't gallop and grows thin. A stable keeper can treat it.");
	}
	else
	{
		Buff_Clear(playerid,"horse_sick");
	}
}

stock Horses_ClearBuffs(playerid)
{
	Buff_Clear(playerid,"horse_hungry");
	Buff_Clear(playerid,"horse_thirsty");
	Buff_Clear(playerid,"horse_lame");
	Buff_Clear(playerid,"horse_sick");
}

static Horses_DayRoll(horseid)
{
	new today = Horses_Today(), last = s_HorseData[horseid][E_HD_BOND_DAY];

	if (last == today)
	{
		return;
	}

	if (last > 0)
	{
		new touched = s_HorseData[horseid][E_HD_TOUCHED_DAY];
		new lost = max(today - touched - HORSES_UNTOUCHED_DAYS,0) - max(last - touched - HORSES_UNTOUCHED_DAYS,0);

		if (lost > 0)
		{
			Horses_AddBond(horseid,-lost);
		}
	}

	s_HorseData[horseid][E_HD_BOND_DAY] = today;
	s_HorseData[horseid][E_HD_GAIN_RIDE] = 0;
	s_HorseData[horseid][E_HD_GAIN_FEED] = 0;
	s_HorseData[horseid][E_HD_GROOMED] = false;
	s_HorseData[horseid][E_HD_CALLED] = false;
	s_HorseData[horseid][E_HD_FORCED] = 0;
	s_HorseData[horseid][E_HD_DIRTY] = true;
}

stock Horses_AddBond(horseid,amount)
{
	if (!Horses_IsOwned(horseid) || amount == 0)
	{
		return 0;
	}

	new oldTier = Horses_GetTier(horseid), before = s_HorseData[horseid][E_HD_BOND];
	s_HorseData[horseid][E_HD_BOND] = Util_ClampInt(before + amount,0,100);
	s_HorseData[horseid][E_HD_DIRTY] = true;
	new newTier = Horses_GetTier(horseid);

	if (newTier != oldTier)
	{
		pawn_call_public("Horse_OnBondChanged","dddd",horseid,s_HorseData[horseid][E_HD_OWNER],oldTier,newTier);
		new playerid = Horses_GetOwnerPlayer(horseid), name[HORSES_NAME_LEN];

		if (playerid != INVALID_PLAYER_ID)
		{
			Horses_GetHorseName(horseid,name);

			if (newTier > oldTier)
			{
				Gui_Notify(playerid,sprintf("%s trusts you more now: %s.",name,g_HorsesTierNames[newTier]));
			}
			else
			{
				Gui_Notify(playerid,sprintf("%s trusts you less now: %s.",name,g_HorsesTierNames[newTier]));
			}
		}
	}

	return s_HorseData[horseid][E_HD_BOND] - before;
}

stock Horses_Gain(horseid,kind)
{
	if (!Horses_IsOwned(horseid))
	{
		return 0;
	}

	Horses_DayRoll(horseid);
	s_HorseData[horseid][E_HD_TOUCHED_DAY] = Horses_Today();

	switch (kind)
	{
		case 0:
		{
			if (s_HorseData[horseid][E_HD_GAIN_RIDE] >= HORSES_BOND_RIDE_CAP)
			{
				return 0;
			}

			s_HorseData[horseid][E_HD_GAIN_RIDE]++;
			return Horses_AddBond(horseid,1);
		}
		case 1:
		{
			if (s_HorseData[horseid][E_HD_GAIN_FEED] >= HORSES_BOND_FEED_CAP)
			{
				return 0;
			}

			s_HorseData[horseid][E_HD_GAIN_FEED] += HORSES_BOND_FEED;
			return Horses_AddBond(horseid,HORSES_BOND_FEED);
		}
		case 2:
		{
			if (s_HorseData[horseid][E_HD_GROOMED])
			{
				return 0;
			}

			s_HorseData[horseid][E_HD_GROOMED] = true;
			return Horses_AddBond(horseid,HORSES_BOND_GROOM);
		}
		case 3:
		{
			if (s_HorseData[horseid][E_HD_CALLED])
			{
				return 0;
			}

			s_HorseData[horseid][E_HD_CALLED] = true;
			return Horses_AddBond(horseid,1);
		}
		case 4:
		{
			if (s_HorseData[horseid][E_HD_FORCED] >= HORSES_BOND_FORCED_CAP)
			{
				return 0;
			}

			s_HorseData[horseid][E_HD_FORCED]++;
			return Horses_AddBond(horseid,-1);
		}
	}

	return 0;
}

stock bool:Horses_Feed(horseid,Float:amount)
{
	if (!Horses_IsOwned(horseid))
	{
		return false;
	}

	Horses_UpdateNeeds(horseid);
	s_HorseData[horseid][E_HD_HUNGER] = Util_Clamp(s_HorseData[horseid][E_HD_HUNGER] + amount,0.0,100.0);
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_Gain(horseid,1);
	Horses_CheckBands(horseid);
	Horses_Refresh(horseid);
	return true;
}

stock bool:Horses_Water(horseid,Float:amount = HORSES_WATER)
{
	if (!Horses_IsOwned(horseid))
	{
		return false;
	}

	Horses_UpdateNeeds(horseid);
	s_HorseData[horseid][E_HD_THIRST] = Util_Clamp(s_HorseData[horseid][E_HD_THIRST] + amount,0.0,100.0);
	s_HorseData[horseid][E_HD_DIRTY] = true;
	s_HorseData[horseid][E_HD_TOUCHED_DAY] = Horses_Today();
	Horses_CheckBands(horseid);
	Horses_Refresh(horseid);
	return true;
}

stock bool:Horses_Groom(horseid)
{
	if (!Horses_IsOwned(horseid))
	{
		return false;
	}

	Horses_UpdateNeeds(horseid);
	Horses_DayRoll(horseid);

	if (!s_HorseData[horseid][E_HD_GROOMED])
	{
		s_HorseData[horseid][E_HD_CONDITION] = Util_Clamp(s_HorseData[horseid][E_HD_CONDITION] + HORSES_GROOM_CONDITION,0.0,100.0);
	}

	Horses_Gain(horseid,2);
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_CheckBands(horseid);
	Horses_Refresh(horseid);
	return true;
}

stock bool:Horses_Shoe(horseid)
{
	if (!Horses_IsOwned(horseid))
	{
		return false;
	}

	s_HorseData[horseid][E_HD_SHOES] = 0;
	s_HorseData[horseid][E_HD_LAME_DIST] = 0.0;
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_Event(s_HorseData[horseid][E_HD_HID],HORSES_EVENT_SHOD,0,"");
	Horses_Refresh(horseid);
	return true;
}

stock Horses_SetNeeds(horseid,Float:hunger,Float:thirst,Float:condition)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	s_HorseData[horseid][E_HD_HUNGER] = Util_Clamp(hunger,0.0,100.0);
	s_HorseData[horseid][E_HD_THIRST] = Util_Clamp(thirst,0.0,100.0);
	s_HorseData[horseid][E_HD_CONDITION] = Util_Clamp(condition,0.0,100.0);
	s_HorseData[horseid][E_HD_NEEDS_AT] = Horses_Now();
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_CheckBands(horseid);
	Horses_Refresh(horseid);
}

stock Horses_SetBond(horseid,bond)
{
	if (Horses_IsOwned(horseid))
	{
		Horses_AddBond(horseid,bond - s_HorseData[horseid][E_HD_BOND]);
	}
}

stock Horses_SetBorn(horseid,bornDay)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_BORN] = bornDay;
		s_HorseData[horseid][E_HD_DIRTY] = true;
		Horses_Refresh(horseid);
	}
}

stock Horses_SetLame(horseid,days)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_LAME_UNTIL] = days > 0 ? Horses_Now() + days * HORSES_DAY_MINUTES : 0;
		s_HorseData[horseid][E_HD_DIRTY] = true;
		Horses_SyncBuffs(horseid);
		Horses_Refresh(horseid);
	}
}

stock Horses_SetSick(horseid,days)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_SICK_UNTIL] = days > 0 ? Horses_Now() + days * HORSES_DAY_MINUTES : 0;
		s_HorseData[horseid][E_HD_DIRTY] = true;
		Horses_SyncBuffs(horseid);
		Horses_Refresh(horseid);
	}
}

stock bool:Horses_HasBlanket(horseid)
{
	return Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_BLANKET];
}

stock Horses_SetBlanket(horseid,bool:on)
{
	if (Horses_IsOwned(horseid))
	{
		s_HorseData[horseid][E_HD_BLANKET] = on;
		s_HorseData[horseid][E_HD_DIRTY] = true;
		Horses_Refresh(horseid);
	}
}

stock Horses_GetLocation(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_LOCATION] : HORSES_PLACE_WORLD;
}

stock Horses_GetLeader(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_LEADER] : INVALID_PLAYER_ID;
}

stock Horses_SetLeader(horseid,playerid)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_LEADER] = playerid;
		Horses_Refresh(horseid);
	}
}

stock Horses_GetSaddlebag(horseid)
{
	return Horses_IsOwned(horseid) ? s_HorseData[horseid][E_HD_SADDLEBAG] : INVALID_CONTAINER_ID;
}

stock Horses_SetSaddlebag(horseid,containerid)
{
	if (Horses_IsOwned(horseid))
	{
		s_HorseData[horseid][E_HD_SADDLEBAG] = containerid;
		s_HorseData[horseid][E_HD_DIRTY] = true;
		Horses_Refresh(horseid);
	}
}

stock Horses_Lend(horseid,characterid,days)
{
	if (Horses_IsOwned(horseid))
	{
		s_HorseData[horseid][E_HD_LEND_CHAR] = characterid;
		s_HorseData[horseid][E_HD_LEND_UNTIL] = characterid > 0 ? Horses_Now() + days * HORSES_DAY_MINUTES : 0;
		s_HorseData[horseid][E_HD_DIRTY] = true;
	}
}

stock Horses_GetLendChar(horseid)
{
	return Horses_IsOwned(horseid) && Horses_Now() < s_HorseData[horseid][E_HD_LEND_UNTIL] ? s_HorseData[horseid][E_HD_LEND_CHAR] : 0;
}

stock bool:Horses_IsRevealed(horseid)
{
	return Horse_IsValid(horseid) && s_HorseData[horseid][E_HD_REVEALED];
}

stock bool:Horses_IsProven(horseid,locus)
{
	return Horse_IsValid(horseid) && (s_HorseData[horseid][E_HD_PROVEN] & (1 << locus)) != 0;
}

stock bool:Horses_IsInbred(horseid)
{
	return Horse_IsValid(horseid) && s_HorseData[horseid][E_HD_INBRED];
}

stock Horses_GetParents(horseid,&sire,&dam)
{
	sire = Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_SIRE] : 0;
	dam = Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_DAM] : 0;
}

stock Horses_GetStudFee(horseid)
{
	return Horses_IsOwned(horseid) ? s_HorseData[horseid][E_HD_STUD_FEE] : -1;
}

stock Horses_GetCovers(horseid)
{
	if (!Horses_IsOwned(horseid))
	{
		return 0;
	}

	return s_HorseData[horseid][E_HD_COVERS_SEASON] == Horses_SeasonIndex() ? s_HorseData[horseid][E_HD_COVERS] : 0;
}

stock bool:Horses_CoveredThisSeason(horseid)
{
	return Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_COVERED_SEASON] == Horses_SeasonIndex();
}

stock Horses_Price(E_HORSES_BREED:breed,const genes[],ageYears,bool:inbred)
{
	new price = g_HorsesBreedPrice[breed];

	for (new locus = 0;locus < 4;locus++)
	{
		switch (Gene_Tier(genes,locus))
		{
			case 2: price += HORSES_GULDEN * 2;
			case 0: price -= HORSES_GULDEN;
		}
	}

	if (inbred)
	{
		price -= HORSES_GULDEN;
	}

	if (ageYears >= HORSES_OLD_YEARS)
	{
		price /= 2;
	}

	return max(price,HORSES_GULDEN);
}

stock Horses_PriceOf(horseid)
{
	if (!Horse_IsValid(horseid))
	{
		return 0;
	}

	return Horses_Price(s_HorseData[horseid][E_HD_BREED],s_HorseData[horseid][E_HD_GENES],Horses_GetAgeYears(horseid),s_HorseData[horseid][E_HD_INBRED]);
}

stock Horses_StableOwed(stabledDay,today,bool:fed)
{
	return max(today - stabledDay,0) * (fed ? HORSES_STABLE_FEE_FED : HORSES_STABLE_FEE);
}

stock Horses_Kinship(sire,dam,sireSire,sireDam,damSire,damDam,const sireGrand[4],const damGrand[4])
{
	if (sire == damSire || sire == damDam || dam == sireSire || dam == sireDam)
	{
		return 2;
	}

	if (sireSire > 0 && sireSire == damSire && sireDam > 0 && sireDam == damDam)
	{
		return 2;
	}

	if ((sireSire > 0 && (sireSire == damSire || sireSire == damDam)) || (sireDam > 0 && (sireDam == damSire || sireDam == damDam)))
	{
		return 1;
	}

	for (new i = 0;i < 4;i++)
	{
		if (sireGrand[i] <= 0)
		{
			continue;
		}

		for (new j = 0;j < 4;j++)
		{
			if (sireGrand[i] == damGrand[j])
			{
				return 1;
			}
		}
	}

	return 0;
}

stock Horses_Event(hid,kind,actor,const note[])
{
	if (hid <= 0)
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO horse_events (horse_id, at, kind, actor_character_id, note) VALUES (%d, %d, %d, NULLIF(%d, 0), '%e')",hid,gettime(),kind,actor,note));
}

static Horses_ResetData(horseid)
{
	s_HorseData[horseid][E_HD_KIND] = HORSES_KIND_NONE;
	s_HorseData[horseid][E_HD_HID] = 0;
	s_HorseData[horseid][E_HD_OWNER] = 0;
	s_HorseData[horseid][E_HD_NAME][0] = EOS;
	s_HorseData[horseid][E_HD_SEX] = HORSES_SEX_MARE;
	s_HorseData[horseid][E_HD_BREED] = HORSES_BREED_WILD;
	s_HorseData[horseid][E_HD_SIRE] = 0;
	s_HorseData[horseid][E_HD_DAM] = 0;
	s_HorseData[horseid][E_HD_INBRED] = false;
	s_HorseData[horseid][E_HD_BORN] = 0;
	s_HorseData[horseid][E_HD_PROVEN] = 0;
	s_HorseData[horseid][E_HD_REVEALED] = false;
	s_HorseData[horseid][E_HD_BOND] = 0;
	s_HorseData[horseid][E_HD_HUNGER] = 100.0;
	s_HorseData[horseid][E_HD_THIRST] = 100.0;
	s_HorseData[horseid][E_HD_CONDITION] = 80.0;
	s_HorseData[horseid][E_HD_SHOES] = HORSES_UNSHOD;
	s_HorseData[horseid][E_HD_NEEDS_AT] = 0;
	s_HorseData[horseid][E_HD_BOND_DAY] = 0;
	s_HorseData[horseid][E_HD_GAIN_RIDE] = 0;
	s_HorseData[horseid][E_HD_GAIN_FEED] = 0;
	s_HorseData[horseid][E_HD_GROOMED] = false;
	s_HorseData[horseid][E_HD_CALLED] = false;
	s_HorseData[horseid][E_HD_FORCED] = 0;
	s_HorseData[horseid][E_HD_TOUCHED_DAY] = 0;
	s_HorseData[horseid][E_HD_LAME_UNTIL] = 0;
	s_HorseData[horseid][E_HD_SICK_UNTIL] = 0;
	s_HorseData[horseid][E_HD_IN_FOAL_BY] = 0;
	s_HorseData[horseid][E_HD_COVERED_DAY] = 0;
	s_HorseData[horseid][E_HD_DUE_DAY] = 0;
	s_HorseData[horseid][E_HD_FOAL_INBRED] = false;
	s_HorseData[horseid][E_HD_FOAL_SIRE_BREED] = 0;
	s_HorseData[horseid][E_HD_COVERED_SEASON] = 0;
	s_HorseData[horseid][E_HD_COVERS] = 0;
	s_HorseData[horseid][E_HD_COVERS_SEASON] = 0;
	s_HorseData[horseid][E_HD_STUD_FEE] = -1;
	s_HorseData[horseid][E_HD_LEND_CHAR] = 0;
	s_HorseData[horseid][E_HD_LEND_UNTIL] = 0;
	s_HorseData[horseid][E_HD_LAST_RIDDEN] = 0;
	s_HorseData[horseid][E_HD_RIDE_MS] = 0;
	s_HorseData[horseid][E_HD_DIST] = 0.0;
	s_HorseData[horseid][E_HD_LAME_DIST] = 0.0;
	s_HorseData[horseid][E_HD_DIRTY] = false;
	s_HorseData[horseid][E_HD_MEADOW] = -1;
	s_HorseData[horseid][E_HD_SPOT] = -1;
	s_HorseData[horseid][E_HD_LEADER] = INVALID_PLAYER_ID;
	s_HorseData[horseid][E_HD_SADDLEBAG] = INVALID_CONTAINER_ID;
	s_HorseData[horseid][E_HD_LOCATION] = HORSES_PLACE_WORLD;
	s_HorseData[horseid][E_HD_STABLE] = -1;
	s_HorseData[horseid][E_HD_STABLED_DAY] = 0;
	s_HorseData[horseid][E_HD_FEED_INCLUDED] = false;
	s_HorseData[horseid][E_HD_HOLD_UNTIL] = 0;
	s_HorseData[horseid][E_HD_THIEF] = INVALID_PLAYER_ID;
	s_HorseData[horseid][E_HD_HUNGER_BAND] = 2;
	s_HorseData[horseid][E_HD_CONDITION_BAND] = 2;
	s_HorseData[horseid][E_HD_SAVED_AT] = 0;
	s_HorseData[horseid][E_HD_BLANKET] = false;

	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		s_HorseData[horseid][E_HD_GENES][locus] = Gene_Pair(1,1);
		s_HorseData[horseid][E_HD_FOAL_GENES][locus] = 0;
	}
}

stock Horses_Spawn(E_HORSES_BREED:breed,Float:x,Float:y,Float:z,Float:a,world,kind,seed,bool:capFine = false)
{
	new genes[HORSES_LOCI];
	Gene_Roll(breed,genes,seed);

	if (capFine)
	{
		Gene_CapFine(genes);
	}

	new horseid = Horse_Create(Horses_TypeOf(breed,genes),x,y,z,a,world);

	if (horseid == INVALID_HORSE_ID)
	{
		return INVALID_HORSE_ID;
	}

	s_HorseData[horseid][E_HD_KIND] = kind;
	s_HorseData[horseid][E_HD_BREED] = breed;
	s_HorseData[horseid][E_HD_SEX] = Gene_Rand(seed,2) == 0 ? HORSES_SEX_MARE : HORSES_SEX_STALLION;
	s_HorseData[horseid][E_HD_BORN] = Horses_Today() - HORSES_YEAR_DAYS * (3 + Gene_Rand(seed,7)) - Gene_Rand(seed,HORSES_YEAR_DAYS);
	s_HorseData[horseid][E_HD_NEEDS_AT] = Horses_Now();
	s_HorseData[horseid][E_HD_CONDITION] = 70.0 + float(Gene_Rand(seed,25));

	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		s_HorseData[horseid][E_HD_GENES][locus] = genes[locus];
	}

	Horses_Refresh(horseid);
	return horseid;
}

stock Horses_SetWildSpot(horseid,meadow,spot)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_MEADOW] = meadow;
		s_HorseData[horseid][E_HD_SPOT] = spot;
	}
}

stock Horses_GetWildSpot(horseid,&meadow,&spot)
{
	meadow = Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_MEADOW] : -1;
	spot = Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_SPOT] : -1;
}

stock Horses_SetName(horseid,const name[])
{
	if (!Horse_IsValid(horseid))
	{
		return;
	}

	strcopy(s_HorseData[horseid][E_HD_NAME],name,HORSES_NAME_LEN);
	Horse_SetName(horseid,name);
	s_HorseData[horseid][E_HD_DIRTY] = true;
}

static Horses_CurrentPos(horseid,&Float:x,&Float:y,&Float:z,&Float:a,&world)
{
	new rider = Horse_GetRider(horseid);

	if (rider != INVALID_PLAYER_ID && IsPlayerConnected(rider))
	{
		GetPlayerPos(rider,x,y,z);
		GetPlayerFacingAngle(rider,a);
		z -= 0.5;
		world = GetPlayerVirtualWorld(rider);
		return;
	}

	Horse_GetPos(horseid,x,y,z,a);
	world = 0;
}

stock Horses_Save(horseid)
{
	if (!Horses_IsOwned(horseid) || s_HorseData[horseid][E_HD_HID] <= 0)
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a, world, genes[HORSES_GENES_HEX], foal[HORSES_GENES_HEX];
	Horses_CurrentPos(horseid,x,y,z,a,world);
	Gene_Encode(s_HorseData[horseid][E_HD_GENES],genes);
	Gene_Encode(s_HorseData[horseid][E_HD_FOAL_GENES],foal);
	s_HorseData[horseid][E_HD_DIRTY] = false;
	s_HorseData[horseid][E_HD_SAVED_AT] = GetTickCount();

	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET name = '%e', owner_character_id = %d, type = %d, sex = %d, genes = '%e', proven = %d, revealed = %d, bond = %d, hunger = %f, thirst = %f, condition_pct = %f, shoes_wear = %d, needs_at = %d, bond_day = %d, gain_ride = %d, gain_feed = %d, groomed = %d, called = %d, forced = %d, touched_day = %d, location_kind = %d, x = %f, y = %f, z = %f, a = %f, lame_until = %d, sick_until = %d, last_ridden = %d, lend_character_id = %d, lend_until = %d, saddlebag_container_id = NULLIF(%d, %d), stud_fee = %d, blanket = %d WHERE id = %d",
		s_HorseData[horseid][E_HD_NAME],s_HorseData[horseid][E_HD_OWNER],Horse_GetType(horseid),s_HorseData[horseid][E_HD_SEX],genes,s_HorseData[horseid][E_HD_PROVEN],s_HorseData[horseid][E_HD_REVEALED] ? 1 : 0,s_HorseData[horseid][E_HD_BOND],
		s_HorseData[horseid][E_HD_HUNGER],s_HorseData[horseid][E_HD_THIRST],s_HorseData[horseid][E_HD_CONDITION],s_HorseData[horseid][E_HD_SHOES],s_HorseData[horseid][E_HD_NEEDS_AT],s_HorseData[horseid][E_HD_BOND_DAY],s_HorseData[horseid][E_HD_GAIN_RIDE],
		s_HorseData[horseid][E_HD_GAIN_FEED],s_HorseData[horseid][E_HD_GROOMED] ? 1 : 0,s_HorseData[horseid][E_HD_CALLED] ? 1 : 0,s_HorseData[horseid][E_HD_FORCED],s_HorseData[horseid][E_HD_TOUCHED_DAY],s_HorseData[horseid][E_HD_LOCATION],x,y,z,a,
		s_HorseData[horseid][E_HD_LAME_UNTIL],s_HorseData[horseid][E_HD_SICK_UNTIL],s_HorseData[horseid][E_HD_LAST_RIDDEN],s_HorseData[horseid][E_HD_LEND_CHAR],s_HorseData[horseid][E_HD_LEND_UNTIL],s_HorseData[horseid][E_HD_SADDLEBAG],INVALID_CONTAINER_ID,s_HorseData[horseid][E_HD_STUD_FEE],s_HorseData[horseid][E_HD_BLANKET] ? 1 : 0,s_HorseData[horseid][E_HD_HID]));
	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET in_foal_by = NULLIF(%d, 0), covered_day = %d, due_day = %d, foal_genes = '%e', foal_inbred = %d, foal_sire_breed = %d, covered_season = %d, covers = %d, covers_season = %d, born_day = %d, sire_id = NULLIF(%d, 0), dam_id = NULLIF(%d, 0), inbred = %d, breed = %d, stable_id = NULLIF(%d, -1), stabled_day = %d, feed_included = %d WHERE id = %d",
		s_HorseData[horseid][E_HD_IN_FOAL_BY],s_HorseData[horseid][E_HD_COVERED_DAY],s_HorseData[horseid][E_HD_DUE_DAY],foal,s_HorseData[horseid][E_HD_FOAL_INBRED] ? 1 : 0,s_HorseData[horseid][E_HD_FOAL_SIRE_BREED],s_HorseData[horseid][E_HD_COVERED_SEASON],s_HorseData[horseid][E_HD_COVERS],
		s_HorseData[horseid][E_HD_COVERS_SEASON],s_HorseData[horseid][E_HD_BORN],s_HorseData[horseid][E_HD_SIRE],s_HorseData[horseid][E_HD_DAM],s_HorseData[horseid][E_HD_INBRED] ? 1 : 0,_:s_HorseData[horseid][E_HD_BREED],s_HorseData[horseid][E_HD_STABLE],s_HorseData[horseid][E_HD_STABLED_DAY],s_HorseData[horseid][E_HD_FEED_INCLUDED] ? 1 : 0,s_HorseData[horseid][E_HD_HID]));
}

#pragma warning push
#pragma warning disable 204
async Task:Horses_Adopt(horseid,characterid,source)
{
	if (!Horse_IsValid(horseid) || characterid <= 0)
	{
		wait_ticks(1);
		return async 0;
	}

	new genes[HORSES_GENES_HEX], Float:x, Float:y, Float:z, Float:a;
	Gene_Encode(s_HorseData[horseid][E_HD_GENES],genes);
	Horse_GetPos(horseid,x,y,z,a);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO horses (name, owner_character_id, type, sex, breed, sire_id, dam_id, inbred, born_day, genes, bond, hunger, thirst, condition_pct, shoes_wear, needs_at, bond_day, touched_day, location_kind, x, y, z, a) VALUES ('%e', %d, %d, %d, %d, NULLIF(%d, 0), NULLIF(%d, 0), %d, %d, '%e', %d, %f, %f, %f, %d, %d, %d, %d, %d, %f, %f, %f, %f)",
		s_HorseData[horseid][E_HD_NAME],characterid,Horse_GetType(horseid),s_HorseData[horseid][E_HD_SEX],_:s_HorseData[horseid][E_HD_BREED],s_HorseData[horseid][E_HD_SIRE],s_HorseData[horseid][E_HD_DAM],s_HorseData[horseid][E_HD_INBRED] ? 1 : 0,s_HorseData[horseid][E_HD_BORN],genes,
		s_HorseData[horseid][E_HD_BOND],s_HorseData[horseid][E_HD_HUNGER],s_HorseData[horseid][E_HD_THIRST],s_HorseData[horseid][E_HD_CONDITION],s_HorseData[horseid][E_HD_SHOES],Horses_Now(),Horses_Today(),Horses_Today(),HORSES_PLACE_WORLD,x,y,z,a));
	new hid = cache_insert_id();

	if (!Horse_IsValid(horseid) || hid <= 0)
	{
		return async 0;
	}

	s_HorseData[horseid][E_HD_KIND] = HORSES_KIND_OWNED;
	s_HorseData[horseid][E_HD_HID] = hid;
	s_HorseData[horseid][E_HD_OWNER] = characterid;
	s_HorseData[horseid][E_HD_NEEDS_AT] = Horses_Now();
	s_HorseData[horseid][E_HD_BOND_DAY] = Horses_Today();
	s_HorseData[horseid][E_HD_TOUCHED_DAY] = Horses_Today();
	s_HorseData[horseid][E_HD_LOCATION] = HORSES_PLACE_WORLD;
	s_HorseData[horseid][E_HD_MEADOW] = -1;
	s_HorseData[horseid][E_HD_SPOT] = -1;
	Horses_Event(hid,source,characterid,"");
	pawn_call_public("Horse_OnOwned","ddd",horseid,characterid,source);
	Horses_Refresh(horseid);
	return async hid;
}
#pragma warning pop

forward Task:Horses_CountOwned(characterid);
#pragma warning push
#pragma warning disable 204
async Task:Horses_CountOwned(characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM horses WHERE owner_character_id = %d AND status = %d AND born_day <= %d",characterid,HORSES_STATUS_ALIVE,Horses_Today() - HORSES_GROWN_DAYS));
	new count = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"n",count);
	}

	return async count;
}
#pragma warning pop

static Horses_ReadRow(row,horseid)
{
	new value, Float:f, text[HORSES_GENES_HEX];
	cache_get_value_name_int(row,"id",value);
	s_HorseData[horseid][E_HD_HID] = value;
	cache_get_value_name_int(row,"owner_character_id",value);
	s_HorseData[horseid][E_HD_OWNER] = value;
	cache_get_value_name(row,"name",s_HorseData[horseid][E_HD_NAME],HORSES_NAME_LEN);
	cache_get_value_name_int(row,"sex",value);
	s_HorseData[horseid][E_HD_SEX] = value;
	cache_get_value_name_int(row,"breed",value);
	s_HorseData[horseid][E_HD_BREED] = E_HORSES_BREED:Util_ClampInt(value,0,_:HORSES_BREED_COUNT - 1);
	cache_get_value_name_int(row,"sire_id",value);
	s_HorseData[horseid][E_HD_SIRE] = value;
	cache_get_value_name_int(row,"dam_id",value);
	s_HorseData[horseid][E_HD_DAM] = value;
	cache_get_value_name_int(row,"inbred",value);
	s_HorseData[horseid][E_HD_INBRED] = value != 0;
	cache_get_value_name_int(row,"born_day",value);
	s_HorseData[horseid][E_HD_BORN] = value;
	cache_get_value_name(row,"genes",text);
	new genes[HORSES_LOCI];
	Gene_Decode(text,genes);
	cache_get_value_name(row,"foal_genes",text);
	new foal[HORSES_LOCI];
	Gene_Decode(text,foal);

	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		s_HorseData[horseid][E_HD_GENES][locus] = genes[locus];
		s_HorseData[horseid][E_HD_FOAL_GENES][locus] = foal[locus];
	}

	cache_get_value_name_int(row,"proven",value);
	s_HorseData[horseid][E_HD_PROVEN] = value;
	cache_get_value_name_int(row,"revealed",value);
	s_HorseData[horseid][E_HD_REVEALED] = value != 0;
	cache_get_value_name_int(row,"bond",value);
	s_HorseData[horseid][E_HD_BOND] = value;
	cache_get_value_name_float(row,"hunger",f);
	s_HorseData[horseid][E_HD_HUNGER] = f;
	cache_get_value_name_float(row,"thirst",f);
	s_HorseData[horseid][E_HD_THIRST] = f;
	cache_get_value_name_float(row,"condition_pct",f);
	s_HorseData[horseid][E_HD_CONDITION] = f;
	cache_get_value_name_int(row,"shoes_wear",value);
	s_HorseData[horseid][E_HD_SHOES] = value;
	cache_get_value_name_int(row,"needs_at",value);
	s_HorseData[horseid][E_HD_NEEDS_AT] = value;
	cache_get_value_name_int(row,"bond_day",value);
	s_HorseData[horseid][E_HD_BOND_DAY] = value;
	cache_get_value_name_int(row,"gain_ride",value);
	s_HorseData[horseid][E_HD_GAIN_RIDE] = value;
	cache_get_value_name_int(row,"gain_feed",value);
	s_HorseData[horseid][E_HD_GAIN_FEED] = value;
	cache_get_value_name_int(row,"groomed",value);
	s_HorseData[horseid][E_HD_GROOMED] = value != 0;
	cache_get_value_name_int(row,"called",value);
	s_HorseData[horseid][E_HD_CALLED] = value != 0;
	cache_get_value_name_int(row,"forced",value);
	s_HorseData[horseid][E_HD_FORCED] = value;
	cache_get_value_name_int(row,"touched_day",value);
	s_HorseData[horseid][E_HD_TOUCHED_DAY] = value;
	cache_get_value_name_int(row,"lame_until",value);
	s_HorseData[horseid][E_HD_LAME_UNTIL] = value;
	cache_get_value_name_int(row,"sick_until",value);
	s_HorseData[horseid][E_HD_SICK_UNTIL] = value;
	cache_get_value_name_int(row,"in_foal_by",value);
	s_HorseData[horseid][E_HD_IN_FOAL_BY] = value;
	cache_get_value_name_int(row,"covered_day",value);
	s_HorseData[horseid][E_HD_COVERED_DAY] = value;
	cache_get_value_name_int(row,"due_day",value);
	s_HorseData[horseid][E_HD_DUE_DAY] = value;
	cache_get_value_name_int(row,"foal_inbred",value);
	s_HorseData[horseid][E_HD_FOAL_INBRED] = value != 0;
	cache_get_value_name_int(row,"foal_sire_breed",value);
	s_HorseData[horseid][E_HD_FOAL_SIRE_BREED] = value;
	cache_get_value_name_int(row,"covered_season",value);
	s_HorseData[horseid][E_HD_COVERED_SEASON] = value;
	cache_get_value_name_int(row,"covers",value);
	s_HorseData[horseid][E_HD_COVERS] = value;
	cache_get_value_name_int(row,"covers_season",value);
	s_HorseData[horseid][E_HD_COVERS_SEASON] = value;
	cache_get_value_name_int(row,"stud_fee",value);
	s_HorseData[horseid][E_HD_STUD_FEE] = value;
	cache_get_value_name_int(row,"lend_character_id",value);
	s_HorseData[horseid][E_HD_LEND_CHAR] = value;
	cache_get_value_name_int(row,"lend_until",value);
	s_HorseData[horseid][E_HD_LEND_UNTIL] = value;
	cache_get_value_name_int(row,"last_ridden",value);
	s_HorseData[horseid][E_HD_LAST_RIDDEN] = value;
	cache_get_value_name_int(row,"location_kind",value);
	s_HorseData[horseid][E_HD_LOCATION] = value;
	cache_get_value_name_int(row,"blanket",value);
	s_HorseData[horseid][E_HD_BLANKET] = value != 0;
	cache_get_value_name_int(row,"saddlebag_container_id",value);
	s_HorseData[horseid][E_HD_SADDLEBAG] = value > 0 ? value : INVALID_CONTAINER_ID;
	s_HorseData[horseid][E_HD_KIND] = HORSES_KIND_OWNED;
}

static bool:Horses_ClearSpot(Float:x,Float:y,Float:z)
{
	new Float:hx, Float:hy, Float:hz;

	for (new i = 0;i < 4;i++)
	{
		new Float:ang = float(i) * 90.0;

		if (CA_RayCastLine(x,y,z + 1.0,x + floatsin(ang,degrees) * 1.4,y + floatcos(ang,degrees) * 1.4,z + 1.0,hx,hy,hz) != 0)
		{
			return false;
		}
	}

	return CA_RayCastLine(x,y,z + 0.3,x,y,z + 3.0,hx,hy,hz) == 0;
}

stock bool:Horses_FindStandSpot(Float:cx,Float:cy,Float:cz,Float:radius,&Float:x,&Float:y,&Float:z,Float:startAngle = 0.0)
{
	for (new ring = 0;ring < 4;ring++)
	{
		new Float:r = radius + float(ring) * 1.5;

		for (new k = 0;k < 12;k++)
		{
			new Float:ang = startAngle + float(k) * 30.0, Float:px = cx + floatsin(-ang,degrees) * r, Float:py = cy + floatcos(-ang,degrees) * r, Float:hx, Float:hy, Float:hz;

			if (CA_RayCastLine(px,py,cz + 3.0,px,py,cz - 6.0,hx,hy,hz) == 0)
			{
				continue;
			}

			if (!Horses_ClearSpot(px,py,hz))
			{
				continue;
			}

			x = px;
			y = py;
			z = hz;
			return true;
		}
	}

	return false;
}

stock Horses_SpawnRow(row,Float:x,Float:y,Float:z,Float:a)
{
	new hid, type;
	cache_get_value_name_int(row,"id",hid);

	if (Horses_FindByHid(hid) != INVALID_HORSE_ID)
	{
		return Horses_FindByHid(hid);
	}

	cache_get_value_name_int(row,"type",type);
	new horseid = Horse_Create(Mount_IsValidType(type) ? type : 0,x,y,z,a,0);

	if (horseid == INVALID_HORSE_ID)
	{
		return INVALID_HORSE_ID;
	}

	Horses_ReadRow(row,horseid);
	new stable, stabledDay, fed;
	cache_get_value_name_int(row,"stable_id",stable);
	cache_get_value_name_int(row,"stabled_day",stabledDay);
	cache_get_value_name_int(row,"feed_included",fed);
	s_HorseData[horseid][E_HD_STABLE] = stable;
	s_HorseData[horseid][E_HD_STABLED_DAY] = stabledDay;
	s_HorseData[horseid][E_HD_FEED_INCLUDED] = fed != 0;
	Horse_SetName(horseid,s_HorseData[horseid][E_HD_NAME]);
	Horses_DayRoll(horseid);
	Horses_UpdateNeeds(horseid);
	return horseid;
}

forward Task:Horses_LoadFor(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Horses_LoadFor(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT * FROM horses WHERE owner_character_id = %d AND status = %d AND location_kind <> %d ORDER BY last_ridden DESC LIMIT %d",characterid,HORSES_STATUS_ALIVE,HORSES_PLACE_STABLED,HORSES_PER_CHARACTER + 2));
	new rows = cache_num_rows(), loaded = 0;

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	new Float:px, Float:py, Float:pz, Float:pa, bool:outdoors = GetPlayerVirtualWorld(playerid) == 0 && GetPlayerInterior(playerid) == 0;
	GetPlayerPos(playerid,px,py,pz);
	GetPlayerFacingAngle(playerid,pa);

	for (new row = 0;row < rows;row++)
	{
		new hid;
		cache_get_value_name_int(row,"id",hid);

		if (Horses_FindByHid(hid) != INVALID_HORSE_ID)
		{
			Log_Warn("horses","horse %d already has a slot; not loaded twice",hid);
			continue;
		}

		new type, Float:x, Float:y, Float:z, Float:a;
		cache_get_value_name_int(row,"type",type);
		cache_get_value_name_float(row,"x",x);
		cache_get_value_name_float(row,"y",y);
		cache_get_value_name_float(row,"z",z);
		cache_get_value_name_float(row,"a",a);

		if (outdoors)
		{
			new Float:sx, Float:sy, Float:sz;

			if (Horses_FindStandSpot(px,py,pz - 1.0,3.0 + float(loaded) * 2.0,sx,sy,sz,pa + 120.0))
			{
				x = sx;
				y = sy;
				z = sz;
				a = pa;
			}
		}

		new horseid = Horse_Create(Mount_IsValidType(type) ? type : 0,x,y,z,a,0);

		if (horseid == INVALID_HORSE_ID)
		{
			break;
		}

		Horses_ReadRow(row,horseid);
		Horse_SetName(horseid,s_HorseData[horseid][E_HD_NAME]);
		s_HorseData[horseid][E_HD_LOCATION] = HORSES_PLACE_PASTURE;
		loaded++;
	}

	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_OWNER] == characterid && s_HorseData[horseid][E_HD_LOCATION] != HORSES_PLACE_WORLD)
		{
			Horses_DayRoll(horseid);
			Horses_UpdateNeeds(horseid);

			if (!Horses_IsOwned(horseid))
			{
				continue;
			}

			s_HorseData[horseid][E_HD_LOCATION] = HORSES_PLACE_WORLD;
			s_HorseData[horseid][E_HD_DIRTY] = true;
			Horses_CheckFoaling(horseid);
		}
	}

	return async loaded;
}
#pragma warning pop

stock Horses_Park(horseid,place = HORSES_PLACE_PASTURE)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	Horses_UpdateNeeds(horseid);

	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	s_HorseData[horseid][E_HD_LOCATION] = place;
	Horses_Save(horseid);
	Horse_Destroy(horseid);
}

stock Horses_Die(horseid,cause)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	new hid = s_HorseData[horseid][E_HD_HID], owner = s_HorseData[horseid][E_HD_OWNER], playerid = Horses_GetOwnerPlayer(horseid), name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);
	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET status = %d, condition_pct = 0 WHERE id = %d",HORSES_STATUS_DEAD,hid));
	new note[12];

	switch (cause)
	{
		case HORSES_DEATH_NEGLECT: note = "neglect";
		case HORSES_DEATH_AGE: note = "old age";
		default: note = "staff";
	}

	Horses_Event(hid,HORSES_EVENT_DIED,owner,note);
	pawn_call_public("Horse_OnDied","dd",horseid,cause);

	if (playerid != INVALID_PLAYER_ID)
	{
		Horses_ClearBuffs(playerid);

		if (cause == HORSES_DEATH_NEGLECT)
		{
			Gui_Notify(playerid,sprintf("%s has died of neglect. It went hungry and thirsty too long.",name));
		}
		else
		{
			Gui_Notify(playerid,sprintf("%s has died. It was old.",name));
		}
	}

	s_HorseData[horseid][E_HD_KIND] = HORSES_KIND_NONE;
	Horse_Destroy(horseid);
}

stock Horses_CheckFoaling(horseid)
{
	if (!Horses_IsOwned(horseid) || s_HorseData[horseid][E_HD_IN_FOAL_BY] <= 0 || Horses_Today() < s_HorseData[horseid][E_HD_DUE_DAY])
	{
		return;
	}

	Horses_Foal(horseid);
}

#pragma warning push
#pragma warning disable 204
async Task:Horses_Foal(horseid)
{
	new sire = s_HorseData[horseid][E_HD_IN_FOAL_BY], dam = s_HorseData[horseid][E_HD_HID], owner = s_HorseData[horseid][E_HD_OWNER], genes[HORSES_LOCI];

	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		genes[locus] = s_HorseData[horseid][E_HD_FOAL_GENES][locus];
	}

	new E_HORSES_BREED:breed = s_HorseData[horseid][E_HD_FOAL_SIRE_BREED] == _:s_HorseData[horseid][E_HD_BREED] ? s_HorseData[horseid][E_HD_BREED] : HORSES_BREED_MIXED, bool:inbred = s_HorseData[horseid][E_HD_FOAL_INBRED];
	new Float:foalCondition = s_HorseData[horseid][E_HD_HUNGER] < HORSES_HUNGRY_BAND ? 40.0 : 80.0;
	s_HorseData[horseid][E_HD_IN_FOAL_BY] = 0;
	s_HorseData[horseid][E_HD_DUE_DAY] = 0;
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_Save(horseid);

	new Float:x, Float:y, Float:z, Float:a, Float:sx, Float:sy, Float:sz;
	Horse_GetPos(horseid,x,y,z,a);

	if (Horses_FindStandSpot(x,y,z,2.5,sx,sy,sz,a + 90.0))
	{
		x = sx;
		y = sy;
		z = sz;
	}

	new foalid = s_HorseData[horseid][E_HD_LOCATION] == HORSES_PLACE_WORLD ? Horse_Create(Horses_TypeOf(breed,genes),x,y,z,a,0) : INVALID_HORSE_ID;
	new genesHex[HORSES_GENES_HEX];
	Gene_Encode(genes,genesHex);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO horses (name, owner_character_id, type, sex, breed, sire_id, dam_id, inbred, born_day, genes, bond, hunger, thirst, condition_pct, shoes_wear, needs_at, bond_day, touched_day, location_kind, stable_id, stabled_day, x, y, z, a) SELECT '', %d, %d, %d, %d, %d, %d, %d, %d, '%e', %d, 90, 90, %f, %d, %d, %d, %d, location_kind, stable_id, stabled_day, %f, %f, %f, %f FROM horses WHERE id = %d",
		owner,Horses_TypeOf(breed,genes),random(2) == 0 ? HORSES_SEX_MARE : HORSES_SEX_STALLION,_:breed,sire,dam,inbred ? 1 : 0,Horses_Today(),genesHex,HORSES_BOND_TAMED * 3,foalCondition,HORSES_UNSHOD,Horses_Now(),Horses_Today(),Horses_Today(),x,y,z,a,dam));
	new hid = cache_insert_id();

	new proven = 0;

	for (new locus = 0;locus < 4;locus++)
	{
		if (Gene_Tier(genes,locus) == 0)
		{
			proven |= 1 << locus;
		}
	}

	if (proven != 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET proven = proven | %d WHERE id IN (%d, %d)",proven,sire,dam));

		for (new i = 0;i < MAX_HORSES;i++)
		{
			if (Horses_IsOwned(i) && (s_HorseData[i][E_HD_HID] == sire || s_HorseData[i][E_HD_HID] == dam))
			{
				s_HorseData[i][E_HD_PROVEN] |= proven;
			}
		}
	}

	Horses_Event(dam,HORSES_EVENT_FOALED,owner,"");
	Horses_Event(hid,HORSES_EVENT_BORN,owner,"");

	if (foalid != INVALID_HORSE_ID)
	{
		s_HorseData[foalid][E_HD_KIND] = HORSES_KIND_OWNED;
		s_HorseData[foalid][E_HD_HID] = hid;
		s_HorseData[foalid][E_HD_OWNER] = owner;
		s_HorseData[foalid][E_HD_BREED] = breed;
		s_HorseData[foalid][E_HD_SIRE] = sire;
		s_HorseData[foalid][E_HD_DAM] = dam;
		s_HorseData[foalid][E_HD_INBRED] = inbred;
		s_HorseData[foalid][E_HD_BORN] = Horses_Today();
		s_HorseData[foalid][E_HD_BOND] = HORSES_BOND_TAMED * 3;
		s_HorseData[foalid][E_HD_HUNGER] = 90.0;
		s_HorseData[foalid][E_HD_THIRST] = 90.0;
		s_HorseData[foalid][E_HD_CONDITION] = foalCondition;
		s_HorseData[foalid][E_HD_NEEDS_AT] = Horses_Now();
		s_HorseData[foalid][E_HD_BOND_DAY] = Horses_Today();
		s_HorseData[foalid][E_HD_TOUCHED_DAY] = Horses_Today();
		s_HorseData[foalid][E_HD_LEADER] = INVALID_PLAYER_ID;

		for (new locus = 0;locus < HORSES_LOCI;locus++)
		{
			s_HorseData[foalid][E_HD_GENES][locus] = genes[locus];
		}

		s_HorseData[foalid][E_HD_DIRTY] = true;
		Horses_Refresh(foalid);
	}

	pawn_call_public("Horse_OnFoaled","ddd",foalid,sire,dam);
	new playerid = INVALID_PLAYER_ID;

	foreach (new p : Player)
	{
		if (Character_GetId(p) == owner)
		{
			playerid = p;
		}
	}

	if (playerid != INVALID_PLAYER_ID)
	{
		new name[HORSES_NAME_LEN];
		Horses_GetHorseName(horseid,name);
		Gui_Notify(playerid,sprintf("%s has foaled. Open your horse's panel to name the foal.",name));
	}

	return async hid;
}
#pragma warning pop

stock Horses_FoalOf(foalid)
{
	if (!Horses_IsOwned(foalid) || !Horses_IsFoal(foalid))
	{
		return INVALID_HORSE_ID;
	}

	return Horses_FindByHid(s_HorseData[foalid][E_HD_DAM]);
}

stock Horses_MarkCovered(mareid,sireHid,E_HORSES_BREED:sireBreed,const foalGenes[],bool:inbred)
{
	s_HorseData[mareid][E_HD_IN_FOAL_BY] = sireHid;
	s_HorseData[mareid][E_HD_COVERED_DAY] = Horses_Today();
	s_HorseData[mareid][E_HD_DUE_DAY] = Horses_Today() + HORSES_GESTATION_DAYS;
	s_HorseData[mareid][E_HD_FOAL_INBRED] = inbred;
	s_HorseData[mareid][E_HD_FOAL_SIRE_BREED] = _:sireBreed;
	s_HorseData[mareid][E_HD_COVERED_SEASON] = Horses_SeasonIndex();
	s_HorseData[mareid][E_HD_DIRTY] = true;

	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		s_HorseData[mareid][E_HD_FOAL_GENES][locus] = foalGenes[locus];
	}

	Horses_Refresh(mareid);
	Horses_Save(mareid);
}

stock Horses_SetStableState(horseid,place,stable,stabledDay,bool:fed)
{
	if (!Horse_IsValid(horseid))
	{
		return;
	}

	s_HorseData[horseid][E_HD_LOCATION] = place;
	s_HorseData[horseid][E_HD_STABLE] = stable;
	s_HorseData[horseid][E_HD_STABLED_DAY] = stabledDay;
	s_HorseData[horseid][E_HD_FEED_INCLUDED] = fed;
	s_HorseData[horseid][E_HD_DIRTY] = true;
}

stock Horses_SetGelded(horseid)
{
	if (Horses_IsOwned(horseid))
	{
		s_HorseData[horseid][E_HD_SEX] = HORSES_SEX_GELDING;
		s_HorseData[horseid][E_HD_STUD_FEE] = -1;
		s_HorseData[horseid][E_HD_DIRTY] = true;
	}
}

stock Horses_SetRevealed(horseid)
{
	if (Horses_IsOwned(horseid))
	{
		s_HorseData[horseid][E_HD_REVEALED] = true;
		s_HorseData[horseid][E_HD_DIRTY] = true;
	}
}

stock Horses_SetStudFee(horseid,fee)
{
	if (Horses_IsOwned(horseid))
	{
		s_HorseData[horseid][E_HD_STUD_FEE] = fee;
		s_HorseData[horseid][E_HD_DIRTY] = true;
	}
}

stock Horses_AddCover(horseid)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	if (s_HorseData[horseid][E_HD_COVERS_SEASON] != Horses_SeasonIndex())
	{
		s_HorseData[horseid][E_HD_COVERS_SEASON] = Horses_SeasonIndex();
		s_HorseData[horseid][E_HD_COVERS] = 0;
	}

	s_HorseData[horseid][E_HD_COVERS]++;
	s_HorseData[horseid][E_HD_DIRTY] = true;
}

stock Horses_TransferOwner(horseid,characterid)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	s_HorseData[horseid][E_HD_OWNER] = characterid;
	s_HorseData[horseid][E_HD_BOND] = min(s_HorseData[horseid][E_HD_BOND],HORSES_BOND_NEW_OWNER);
	s_HorseData[horseid][E_HD_LEND_CHAR] = 0;
	s_HorseData[horseid][E_HD_LEND_UNTIL] = 0;
	s_HorseData[horseid][E_HD_STUD_FEE] = -1;
	s_HorseData[horseid][E_HD_DIRTY] = true;
	Horses_Save(horseid);
}

stock Horses_SetThief(horseid,playerid)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_THIEF] = playerid;
	}
}

stock Horses_GetThief(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_THIEF] : INVALID_PLAYER_ID;
}

stock Horses_MarkRidden(horseid,ms,Float:metres)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	s_HorseData[horseid][E_HD_LAST_RIDDEN] = Horses_Now();
	s_HorseData[horseid][E_HD_DIRTY] = true;

	if (s_HorseData[horseid][E_HD_SHOES] != HORSES_UNSHOD && metres > 0.0)
	{
		s_HorseData[horseid][E_HD_SHOES] += floatround(metres);

		if (s_HorseData[horseid][E_HD_SHOES] >= HORSES_SHOES_LIFE)
		{
			s_HorseData[horseid][E_HD_SHOES] = HORSES_UNSHOD;
			new playerid = Horse_GetRider(horseid), name[HORSES_NAME_LEN];
			Horses_GetHorseName(horseid,name);

			if (playerid != INVALID_PLAYER_ID)
			{
				Gui_Notify(playerid,sprintf("%s has thrown its last shoe. Unshod it is slower and can go lame; a smith's horseshoes fix it.",name));
			}

			Horses_Refresh(horseid);
		}
	}
	else if (metres > 0.0)
	{
		s_HorseData[horseid][E_HD_LAME_DIST] += metres;

		while (s_HorseData[horseid][E_HD_LAME_DIST] >= 1000.0)
		{
			s_HorseData[horseid][E_HD_LAME_DIST] -= 1000.0;

			if (!Horses_IsLame(horseid) && random(100) < HORSES_LAME_PER_KM)
			{
				Horses_SetLame(horseid,HORSES_LAME_DAYS);
				new playerid = Horse_GetRider(horseid), name[HORSES_NAME_LEN];
				Horses_GetHorseName(horseid,name);

				if (playerid != INVALID_PLAYER_ID)
				{
					Gui_Notify(playerid,sprintf("%s goes lame on the hard ground. Walk it, rest it two days and have it shod.",name));
				}
			}
		}
	}

	new rideMs = s_HorseData[horseid][E_HD_RIDE_MS] + ms, msPerMinute = max(Calendar_MsPerMinute(),1);
	new minutes = rideMs / msPerMinute;
	s_HorseData[horseid][E_HD_RIDE_MS] = rideMs % msPerMinute;

	if (minutes > 0)
	{
		s_HorseData[horseid][E_HD_HUNGER] = Util_Clamp(s_HorseData[horseid][E_HD_HUNGER] - 100.0 / HORSES_HUNGER_DAYS * float(minutes) / float(HORSES_DAY_MINUTES),0.0,100.0);
		s_HorseData[horseid][E_HD_DIST] += float(minutes);

		while (s_HorseData[horseid][E_HD_DIST] >= 60.0)
		{
			s_HorseData[horseid][E_HD_DIST] -= 60.0;
			Horses_Gain(horseid,0);
		}

		Horses_CheckBands(horseid);
	}
}

stock Horses_GetSavedAt(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_SAVED_AT] : 0;
}

stock Horses_GetStable(horseid)
{
	return Horse_IsValid(horseid) ? s_HorseData[horseid][E_HD_STABLE] : -1;
}

stock Horses_SetupStock(horseid,sex,ageYears)
{
	if (!Horse_IsValid(horseid))
	{
		return;
	}

	s_HorseData[horseid][E_HD_SEX] = sex;
	s_HorseData[horseid][E_HD_BORN] = Horses_Today() - ageYears * HORSES_YEAR_DAYS - random(HORSES_YEAR_DAYS);
	s_HorseData[horseid][E_HD_HUNGER] = 90.0;
	s_HorseData[horseid][E_HD_THIRST] = 90.0;
	s_HorseData[horseid][E_HD_CONDITION] = 85.0;
}

stock Horses_ForgetOwned(horseid)
{
	if (Horse_IsValid(horseid))
	{
		s_HorseData[horseid][E_HD_KIND] = HORSES_KIND_NONE;
		s_HorseData[horseid][E_HD_OWNER] = 0;
	}
}

stock bool:Horses_FedToday(horseid)
{
	return Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_BOND_DAY] == Horses_Today() && s_HorseData[horseid][E_HD_GAIN_FEED] > 0;
}

stock bool:Horses_RiddenToday(horseid)
{
	return Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_LAST_RIDDEN] / HORSES_DAY_MINUTES == Horses_Today();
}

stock bool:Horses_GroomedToday(horseid)
{
	return Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_BOND_DAY] == Horses_Today() && s_HorseData[horseid][E_HD_GROOMED];
}

stock Horses_FlushDirty()
{
	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (Horses_IsOwned(horseid) && s_HorseData[horseid][E_HD_DIRTY])
		{
			Horses_Save(horseid);
		}
	}
}

#include <pp-hooks>

hook Horse_OnCreated(horseid)
{
	Horses_ResetData(horseid);
}

hook Horse_OnDestroyed(horseid)
{
	new leader = s_HorseData[horseid][E_HD_LEADER];
	Horses_ResetData(horseid);

	if (leader != INVALID_PLAYER_ID)
	{
		pawn_call_public("Horses_OnLeadLost","dd",leader,horseid);
	}
}
