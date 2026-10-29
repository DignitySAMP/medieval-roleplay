enum E_HORSES_RIDER
{
	E_HR_HORSE,
	Float:E_HR_LAST[3],
	E_HR_LAST_TICK,
	E_HR_LAST_HORSE,
	E_HR_LEADING,
	E_HR_CALL_TICK,
	E_HR_HOLD_TICK,
	E_HR_HOLD_TOKEN,
}

static s_HorseRider[MAX_PLAYERS][E_HORSES_RIDER];

stock Horses_GetLastHorse(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return INVALID_HORSE_ID;
	}

	new horseid = s_HorseRider[playerid][E_HR_LAST_HORSE];

	if (Horses_IsOwner(playerid,horseid))
	{
		return horseid;
	}

	for (new i = 0;i < MAX_HORSES;i++)
	{
		if (Horses_IsOwner(playerid,i) && !Horses_IsFoal(i))
		{
			return i;
		}
	}

	return INVALID_HORSE_ID;
}

stock Horses_GetLeading(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_HorseRider[playerid][E_HR_LEADING] : INVALID_HORSE_ID;
}

stock bool:Horses_CanLead(playerid,horseid)
{
	if (!Horses_IsOwner(playerid,horseid))
	{
		return false;
	}

	return Horses_GetTier(horseid) >= HORSES_TIER_DEVOTED || Inventory_Count(playerid,Item_GetDefKind(ITEM_HALTER),ITEM_HALTER) > 0;
}

stock bool:Horses_StartLead(playerid,horseid)
{
	if (!Horses_CanLead(playerid,horseid) || Horse_GetRider(horseid) != INVALID_PLAYER_ID)
	{
		return false;
	}

	Horses_StopLead(playerid);
	s_HorseRider[playerid][E_HR_LEADING] = horseid;
	Horses_SetLeader(horseid,playerid);
	return true;
}

stock Horses_StopLead(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	new horseid = s_HorseRider[playerid][E_HR_LEADING];
	s_HorseRider[playerid][E_HR_LEADING] = INVALID_HORSE_ID;

	if (Horse_IsValid(horseid) && Horses_GetLeader(horseid) == playerid)
	{
		Horses_SetLeader(horseid,INVALID_PLAYER_ID);

		if (Horse_IsWalking(horseid))
		{
			Horse_StopWalk(horseid);
		}
	}
}

stock bool:Horses_Call(playerid)
{
	new tick = GetTickCount();

	if (tick - s_HorseRider[playerid][E_HR_CALL_TICK] < HORSES_CALL_COOLDOWN_MS)
	{
		return false;
	}

	s_HorseRider[playerid][E_HR_CALL_TICK] = tick;

	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		Gui_Notify(playerid,"Your horse can't hear you in here.");
		return false;
	}

	new horseid = Horses_GetLastHorse(playerid);

	if (horseid == INVALID_HORSE_ID)
	{
		Horses_TellWhereHorsesAre(playerid);
		return false;
	}

	new name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);

	if (Horse_GetRider(horseid) != INVALID_PLAYER_ID)
	{
		Gui_Notify(playerid,sprintf("Someone is riding %s.",name));
		return false;
	}

	new Float:px, Float:py, Float:pz, Float:pa, Float:hx, Float:hy, Float:hz, Float:ha;
	GetPlayerPos(playerid,px,py,pz);
	GetPlayerFacingAngle(playerid,pa);
	Horse_GetPos(horseid,hx,hy,hz,ha);
	new Float:distance = VectorSize(px - hx,py - hy,pz - hz), Float:range = g_HorsesTierCall[Horses_GetTier(horseid)];

	if (distance > range)
	{
		Gui_Notify(playerid,sprintf("%s is too far away to hear you. It comes from %.0f m once it trusts you more.",name,range));
		return false;
	}

	if (distance > 35.0)
	{
		new Float:sx, Float:sy, Float:sz;

		if (Horses_FindStandSpot(px,py,pz - 1.0,28.0,sx,sy,sz,pa + 150.0) || Horses_FindStandSpot(px,py,pz - 1.0,18.0,sx,sy,sz,pa + 150.0))
		{
			Horse_MoveTo(horseid,sx,sy,sz,pa,0);
		}
	}

	new Float:tx = px + floatsin(-(pa + 120.0),degrees) * 2.0, Float:ty = py + floatcos(-(pa + 120.0),degrees) * 2.0;
	Horse_WalkTo(horseid,tx,ty,pz - 1.0,HORSES_CALL_SPEED);
	Horses_SetLeader(horseid,INVALID_PLAYER_ID);
	SetPVarInt(playerid,"horse_called",horseid + 1);
	ApplyAnimation(playerid,"ON_LOOKERS","shout_01",4.1,false,false,false,false,0,SYNC_ALL);
	Gui_Notify(playerid,sprintf("You whistle for %s.",name));
	return true;
}

stock Horses_TellWhereHorsesAre(playerid)
{
	Horses_TellWhere(playerid,Character_GetId(playerid));
}

forward Task:Horses_TellWhere(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Horses_TellWhere(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT name, location_kind, stable_id FROM horses WHERE owner_character_id = %d AND status = %d LIMIT 1",characterid,HORSES_STATUS_ALIVE));

	if (!IsPlayerConnected(playerid))
	{
		return async 0;
	}

	if (cache_num_rows() == 0)
	{
		Gui_Notify(playerid,"You have no horse to call. Buy one from a horse trader at a stable, or tame a wild one with a rope.");
		return async 0;
	}

	new name[HORSES_NAME_LEN], place, stable;
	cache_get_value_name(0,"name",name);
	cache_get_value_name_int(0,"location_kind",place);
	cache_get_value_name_int(0,"stable_id",stable);

	if (place == HORSES_PLACE_STABLED)
	{
		new where[28];
		Horses_StableName(stable,where);

		if (name[0] == EOS)
		{
			strcopy(name,"Your horse");
		}

		Gui_Notify(playerid,sprintf("%s is stabled at %s. Fetch it from the keeper there.",name,where));
	}
	else
	{
		Gui_Notify(playerid,"Your horse doesn't answer.");
	}

	return async 1;
}
#pragma warning pop

static Horses_FollowTarget(playerid,&Float:x,&Float:y,&Float:z)
{
	new Float:a;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x += floatsin(-(a + 180.0),degrees) * 2.2;
	y += floatcos(-(a + 180.0),degrees) * 2.2;
	z -= 1.0;
}

Timer_Declare(Horses_RideTick)
{
	new now = GetTickCount();

	foreach (new playerid : Player)
	{
		if (Mount_IsRiding(playerid))
		{
			new horseid = Mount_GetHorse(playerid), Float:x, Float:y, Float:z;
			GetPlayerPos(playerid,x,y,z);

			if (s_HorseRider[playerid][E_HR_HORSE] == horseid && Horses_IsOwned(horseid))
			{
				new Float:moved = VectorSize(x - s_HorseRider[playerid][E_HR_LAST][0],y - s_HorseRider[playerid][E_HR_LAST][1],0.0), ms = now - s_HorseRider[playerid][E_HR_LAST_TICK];

				if (moved > 40.0)
				{
					moved = 0.0;
				}

				Horses_MarkRidden(horseid,moved > 0.5 ? ms : 0,moved);
			}

			s_HorseRider[playerid][E_HR_HORSE] = horseid;
			s_HorseRider[playerid][E_HR_LAST][0] = x;
			s_HorseRider[playerid][E_HR_LAST][1] = y;
			s_HorseRider[playerid][E_HR_LAST][2] = z;
			s_HorseRider[playerid][E_HR_LAST_TICK] = now;
		}
		else
		{
			s_HorseRider[playerid][E_HR_HORSE] = INVALID_HORSE_ID;
		}

		new led = s_HorseRider[playerid][E_HR_LEADING];

		if (led != INVALID_HORSE_ID)
		{
			if (!Horse_IsValid(led) || Mount_IsRiding(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
			{
				Horses_StopLead(playerid);
				continue;
			}

			new Float:hx, Float:hy, Float:hz, Float:ha, Float:tx, Float:ty, Float:tz;
			Horse_GetPos(led,hx,hy,hz,ha);
			Horses_FollowTarget(playerid,tx,ty,tz);
			new Float:gap = VectorSize(tx - hx,ty - hy,0.0);

			if (gap > HORSES_LEAD_LOSE)
			{
				Horses_StopLead(playerid);
				Gui_Notify(playerid,"You've lost the lead rope. Your horse stopped.");
			}
			else if (gap > HORSES_LEAD_GAP)
			{
				Horse_WalkTo(led,tx,ty,tz,gap > 8.0 ? 3.0 : 1.6);
			}
		}
	}

	for (new foalid = 0;foalid < MAX_HORSES;foalid++)
	{
		new mother = Horses_FoalOf(foalid);

		if (mother == INVALID_HORSE_ID)
		{
			continue;
		}

		new Float:mx, Float:my, Float:mz, Float:ma, rider = Horse_GetRider(mother);

		if (rider != INVALID_PLAYER_ID)
		{
			GetPlayerPos(rider,mx,my,mz);
			GetPlayerFacingAngle(rider,ma);
			mz -= 1.0;
		}
		else
		{
			Horse_GetPos(mother,mx,my,mz,ma);
		}

		new Float:fx, Float:fy, Float:fz, Float:fa;
		Horse_GetPos(foalid,fx,fy,fz,fa);
		new Float:gap = VectorSize(mx - fx,my - fy,0.0);

		if (gap > 60.0)
		{
			Horse_MoveTo(foalid,mx + 2.0,my,mz,ma,0);
		}
		else if (gap > 3.5)
		{
			Horse_WalkTo(foalid,mx + floatsin(-(ma + 140.0),degrees) * 2.5,my + floatcos(-(ma + 140.0),degrees) * 2.5,mz,gap > 10.0 ? 4.0 : 1.8);
		}
	}

	return 1;
}

Timer_Declare(Horses_SaveTick)
{
	Horses_FlushDirty();
	return 1;
}

forward Horse_OnOwned(horseid,characterid,source);

public Horse_OnOwned(horseid,characterid,source)
{
	return 1;
}

forward Horse_OnBondChanged(horseid,characterid,oldTier,newTier);

public Horse_OnBondChanged(horseid,characterid,oldTier,newTier)
{
	return 1;
}

forward Horse_OnNeedState(horseid,need,oldBand,newBand);

public Horse_OnNeedState(horseid,need,oldBand,newBand)
{
	return 1;
}

forward Horse_OnTamed(playerid,horseid);

public Horse_OnTamed(playerid,horseid)
{
	return 1;
}

forward Horse_OnFoaled(foalid,sireid,damid);

public Horse_OnFoaled(foalid,sireid,damid)
{
	return 1;
}

forward Horse_OnGrown(horseid);

public Horse_OnGrown(horseid)
{
	return 1;
}

forward Horse_OnDied(horseid,cause);

public Horse_OnDied(horseid,cause)
{
	return 1;
}

forward Horse_OnStolen(horseid,thiefid);

public Horse_OnStolen(horseid,thiefid)
{
	return 1;
}

forward Horses_OnLeadLost(playerid,horseid);

public Horses_OnLeadLost(playerid,horseid)
{
	if (IsPlayerConnected(playerid) && s_HorseRider[playerid][E_HR_LEADING] == horseid)
	{
		s_HorseRider[playerid][E_HR_LEADING] = INVALID_HORSE_ID;
	}

	return 1;
}

forward Horses_CallHold(playerid,token);

public Horses_CallHold(playerid,token)
{
	if (!IsPlayerConnected(playerid) || s_HorseRider[playerid][E_HR_HOLD_TOKEN] != token || Mount_IsRiding(playerid) || Gui_IsBusy(playerid))
	{
		return 1;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);

	if (keys & KEY_SECONDARY_ATTACK)
	{
		Horses_Call(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HorseRider[playerid][E_HR_HORSE] = INVALID_HORSE_ID;
	s_HorseRider[playerid][E_HR_LAST_HORSE] = INVALID_HORSE_ID;
	s_HorseRider[playerid][E_HR_LEADING] = INVALID_HORSE_ID;
	s_HorseRider[playerid][E_HR_CALL_TICK] = 0;
	s_HorseRider[playerid][E_HR_HOLD_TOKEN]++;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_SECONDARY_ATTACK) || (oldkeys & KEY_SECONDARY_ATTACK) || Mount_IsRiding(playerid) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
	{
		return;
	}

	if (Horse_Nearest(playerid) != INVALID_HORSE_ID)
	{
		return;
	}

	s_HorseRider[playerid][E_HR_HOLD_TOKEN]++;
	SetTimerEx("Horses_CallHold",HORSES_CALL_HOLD_MS,false,"dd",playerid,s_HorseRider[playerid][E_HR_HOLD_TOKEN]);
}

hook Mount_OnTryMount(playerid,horseid)
{
	new name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);

	switch (Horses_GetKind(horseid))
	{
		case HORSES_KIND_WILD:
		{
			Mount_Veto(playerid,"It's wild. Halter it first: stand by it with a halter and rope and press Y.");
			return;
		}
		case HORSES_KIND_OWNED:
		{
			if (Horses_IsFoal(horseid))
			{
				Mount_Veto(playerid,sprintf("%s is a foal, too young to ride.",name));
				return;
			}

			if (Horses_MayRide(playerid,horseid))
			{
				return;
			}

			if (random(100) < Horses_GetBond(horseid))
			{
				Mount_Veto(playerid,sprintf("%s shies away and won't let a stranger on its back.",name));
				return;
			}

			Horses_SetThief(horseid,playerid);
			Law_Commit(playerid,LAW_CRIME_THEFT);
			Horses_Event(Horses_GetHid(horseid),HORSES_EVENT_STOLEN,Character_GetId(playerid),"");
			pawn_call_public("Horse_OnStolen","dd",horseid,playerid);
			new owner = Horses_GetOwnerPlayer(horseid);

			if (owner != INVALID_PLAYER_ID)
			{
				Gui_Notify(owner,sprintf("Someone has taken %s. Hold the mount key with no horse near to whistle it back.",name));
			}
		}
	}
}

hook Mount_OnMounted(playerid,horseid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	s_HorseRider[playerid][E_HR_HORSE] = horseid;
	s_HorseRider[playerid][E_HR_LAST][0] = x;
	s_HorseRider[playerid][E_HR_LAST][1] = y;
	s_HorseRider[playerid][E_HR_LAST][2] = z;
	s_HorseRider[playerid][E_HR_LAST_TICK] = GetTickCount();

	if (Horses_IsOwner(playerid,horseid))
	{
		s_HorseRider[playerid][E_HR_LAST_HORSE] = horseid;
	}

	if (s_HorseRider[playerid][E_HR_LEADING] != INVALID_HORSE_ID)
	{
		Horses_StopLead(playerid);
	}

	if (Horses_IsOwned(horseid))
	{
		Horses_UpdateNeeds(horseid);
		Horses_Refresh(horseid);
	}
}

hook Mount_OnDismounted(playerid,horseid)
{
	s_HorseRider[playerid][E_HR_HORSE] = INVALID_HORSE_ID;

	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	if (Horses_GetThief(horseid) == playerid)
	{
		Horses_SetThief(horseid,INVALID_PLAYER_ID);
	}

	if (GetTickCount() - Horses_GetSavedAt(horseid) > 30000)
	{
		Horses_Save(horseid);
	}
}

hook Mount_OnGallopStart(playerid,horseid)
{
	if (!Horses_IsOwned(horseid) && !Horses_IsWild(horseid))
	{
		return;
	}

	new tier = Horses_GetTier(horseid);

	if (tier >= HORSES_TIER_FAMILIAR)
	{
		return;
	}

	new chance = g_HorsesThrowPercent[Horses_StatTier(horseid,HORSES_LOCUS_TMP)];

	if (tier == HORSES_TIER_WARY)
	{
		chance /= 2;
	}

	if (random(100) < chance)
	{
		new name[HORSES_NAME_LEN];
		Horses_GetHorseName(horseid,name);
		Mount_Throw(playerid,sprintf("%s rears at the gallop and throws you. It doesn't trust you yet.",name),5.0);
	}
}

hook Mount_OnGallopRefused(playerid,horseid)
{
	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	new name[HORSES_NAME_LEN];
	Horses_GetHorseName(horseid,name);

	if (Horses_IsFoal(horseid))
	{
		return;
	}

	if (Horses_CannotGallop(horseid))
	{
		if (Horses_GetHunger(horseid) <= 0.0)
		{
			Gui_Notify(playerid,sprintf("%s is too hungry to gallop.",name));
		}
		else if (Horses_IsLame(horseid))
		{
			Gui_Notify(playerid,sprintf("%s is lame and won't gallop.",name));
		}
		else if (Horses_IsSick(horseid))
		{
			Gui_Notify(playerid,sprintf("%s is sick and won't gallop.",name));
		}
		else if (Horses_IsInFoal(horseid))
		{
			Gui_Notify(playerid,sprintf("%s is heavy in foal and won't gallop.",name));
		}
		else
		{
			Gui_Notify(playerid,sprintf("%s is too weak to gallop.",name));
		}

		return;
	}

	if (Horses_MayRide(playerid,horseid) && Horses_Gain(horseid,4) < 0)
	{
		Gui_Notify(playerid,sprintf("%s is spent. Driving it on hurts its trust in you.",name));
	}
}

hook Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[])
{
	if (after >= before || !Mount_IsRiding(playerid) || !strcmp(source,"thrown from a horse"))
	{
		return;
	}

	new horseid = Mount_GetHorse(playerid);

	if (!Horses_IsOwned(horseid))
	{
		return;
	}

	new tier = Horses_GetTier(horseid), temper = Horses_StatTier(horseid,HORSES_LOCUS_TMP);
	new bool:bolts = tier < HORSES_TIER_FAMILIAR || (temper == 0 && tier < HORSES_TIER_TRUSTING);

	if (!bolts)
	{
		return;
	}

	new name[HORSES_NAME_LEN], Float:x, Float:y, Float:z, Float:a;
	Horses_GetHorseName(horseid,name);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	Mount_Throw(playerid,sprintf("%s panics at the blow, throws you and bolts.",name),3.0);

	if (Horses_MayRide(playerid,horseid))
	{
		Horses_AddBond(horseid,-HORSES_BOND_BOLT);
	}

	Horse_WalkTo(horseid,x + floatsin(-a,degrees) * 30.0,y + floatcos(-a,degrees) * 30.0,z - 1.0,HORSES_BOLT_SPEED);
}

hook Vitals_OnDepleted(playerid,const source[])
{
	#pragma unused source

	if (!Mount_IsRiding(playerid))
	{
		return;
	}

	new horseid = Mount_GetHorse(playerid), name[HORSES_NAME_LEN], Float:x, Float:y, Float:z, Float:a;

	if (!Horses_IsOwned(horseid) || !Horses_MayRide(playerid,horseid))
	{
		return;
	}

	Horses_GetHorseName(horseid,name);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	Mount_Dismount(playerid);

	if (Horses_GetTier(horseid) >= HORSES_TIER_DEVOTED)
	{
		Gui_Notify(playerid,sprintf("%s stands over you as you fall.",name));
		return;
	}

	Horse_WalkTo(horseid,x + floatsin(-a,degrees) * 30.0,y + floatcos(-a,degrees) * 30.0,z - 1.0,HORSES_BOLT_SPEED);
}

hook Horse_OnArrived(horseid)
{
	foreach (new playerid : Player)
	{
		if (GetPVarInt(playerid,"horse_called") == horseid + 1)
		{
			DeletePVar(playerid,"horse_called");

			if (Horses_IsOwner(playerid,horseid))
			{
				Horses_Gain(horseid,3);
			}
		}
	}
}

hook Character_OnLoaded(playerid,characterid)
{
	Horses_LoadFor(playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Horses_StopLead(playerid);
	new characterid = Character_GetId(playerid);

	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (Horses_IsOwned(horseid) && Horses_GetOwner(horseid) == characterid)
		{
			Horses_Park(horseid);
		}
	}

	Horses_ClearBuffs(playerid);
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour

	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (Horses_IsOwned(horseid))
		{
			Horses_UpdateNeeds(horseid);
		}
	}
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year

	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (!Horses_IsOwned(horseid))
		{
			continue;
		}

		Horses_UpdateNeeds(horseid);

		if (!Horses_IsOwned(horseid))
		{
			continue;
		}

		if (Horses_GetHunger(horseid) < HORSES_HUNGRY_BAND / 2.0)
		{
			Horses_AddBond(horseid,-HORSES_BOND_STARVING);
		}

		if (Horses_GetAgeDays(horseid) == HORSES_GROWN_DAYS)
		{
			pawn_call_public("Horse_OnGrown","d",horseid);
			new playerid = Horses_GetOwnerPlayer(horseid), name[HORSES_NAME_LEN];
			Horses_GetHorseName(horseid,name);

			if (playerid != INVALID_PLAYER_ID)
			{
				Gui_Notify(playerid,sprintf("%s is grown and can be ridden now.",name));
			}
		}

		if (Calendar_GetSeason() == SEASON_WINTER && Horses_GetCondition(horseid) < 25.0 && !Horses_IsSick(horseid) && random(100) < g_HorsesSickPercent[Horses_StatTier(horseid,HORSES_LOCUS_HLT)])
		{
			Horses_SetSick(horseid,HORSES_SICK_DAYS);
		}

		new years = Horses_GetAgeYears(horseid), life = HORSES_LIFE_YEARS + (Horses_StatTier(horseid,HORSES_LOCUS_HLT) - 1) * 3;

		if (years >= life && random(100) < HORSES_OLD_DEATH_PERCENT)
		{
			Horses_Die(horseid,HORSES_DEATH_AGE);
			continue;
		}

		Horses_CheckFoaling(horseid);
		Horses_Refresh(horseid);
	}

	Horses_DailySweep();
}

hook Family_OnHeir(deceasedid,childid,heirid)
{
	#pragma unused childid

	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET owner_character_id = %d, bond = LEAST(bond, %d), hold_until = 0, lend_character_id = 0, stud_fee = -1 WHERE owner_character_id = %d AND status = %d",heirid,HORSES_BOND_NEW_OWNER,deceasedid,HORSES_STATUS_ALIVE));
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO horse_events (horse_id, at, kind, actor_character_id, note) SELECT id, %d, %d, %d, 'estate' FROM horses WHERE owner_character_id = %d AND status = %d",gettime(),HORSES_EVENT_INHERITED,heirid,heirid,HORSES_STATUS_ALIVE));
}

hook Lineage_OnDeceased(characterid)
{
	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (Horses_IsOwned(horseid) && Horses_GetOwner(horseid) == characterid)
		{
			Horses_Park(horseid);
		}
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE horses SET location_kind = %d, stable_id = COALESCE(stable_id, %d), stabled_day = %d, hold_until = %d WHERE owner_character_id = %d AND status = %d AND location_kind <> %d",HORSES_PLACE_STABLED,Horses_StableId(0),Horses_Today(),Horses_Today() + HORSES_STABLE_HOLD_DAYS,characterid,HORSES_STATUS_ALIVE,HORSES_PLACE_STABLED));
}
