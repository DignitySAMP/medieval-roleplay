CMD<ADMIN_LEVEL_TRIAL>:horses(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[32];

	if (sscanf(params,"s[12]S()[32]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/horses give [breed 0-5] | wild | info | bond <n> | needs <hunger> <thirst> <condition> | age <days> | foal | season | lame | sick | kill | stock | stats");
		return 1;
	}

	new horseid = Mount_GetHorse(playerid);

	if (horseid == INVALID_HORSE_ID)
	{
		horseid = Horse_Nearest(playerid,4.0);
	}

	if (!strcmp(action,"give",true))
	{
		new breed = rest[0] != EOS ? Util_ClampInt(strval(rest),0,(_:HORSES_BREED_DONKEY)) : (_:HORSES_BREED_APPALOOSA), Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		new spawned = Horses_Spawn(E_HORSES_BREED:breed,x + floatsin(-a,degrees) * 2.5,y + floatcos(-a,degrees) * 2.5,z - 1.0,a,GetPlayerVirtualWorld(playerid),HORSES_KIND_NONE,random(1000000) + 1);

		if (spawned == INVALID_HORSE_ID)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No horse slot left.");
			return 1;
		}

		Horses_SetupStock(spawned,random(2),5);
		Horses_SetName(spawned,"Staff horse");
		Horses_Adopt(spawned,Character_GetId(playerid),HORSES_EVENT_BOUGHT);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("A %s is yours (no cap check).",g_HorsesBreedNames[E_HORSES_BREED:breed]));
		return 1;
	}

	if (!strcmp(action,"wild",true))
	{
		new Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		new wild = Horses_Spawn(HORSES_BREED_WILD,x + floatsin(-a,degrees) * 3.0,y + floatcos(-a,degrees) * 3.0,z - 1.0,a,GetPlayerVirtualWorld(playerid),HORSES_KIND_WILD,random(1000000) + 1);
		Horses_SetName(wild,"Wild horse");
		SendClientMessage(playerid,0xFFFFFFFF,"A wild horse stands in front of you. A rope and Y to halter it.");
		return 1;
	}

	if (!strcmp(action,"stats",true))
	{
		new owned = 0, wild = 0, total = 0;

		for (new i = 0;i < MAX_HORSES;i++)
		{
			if (Horse_IsValid(i))
			{
				total++;
			}

			if (Horses_IsOwned(i))
			{
				owned++;
			}

			if (Horses_IsWild(i))
			{
				wild++;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Horses: %d slots used of %d, %d owned, %d wild. Day %d, season %d, breeding %s.",total,MAX_HORSES,owned,wild,Horses_Today(),Horses_SeasonIndex(),Horses_IsBreedingSeason() ? ("on") : ("off")));
		return 1;
	}

	if (!strcmp(action,"stock",true))
	{
		Horses_DailySweep();
		SendClientMessage(playerid,0xFFFFFFFF,"Trader stock rerolled and the stable sweep ran.");
		return 1;
	}

	if (!Horse_IsValid(horseid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Ride or stand by a horse.");
		return 1;
	}

	if (!strcmp(action,"info",true))
	{
		new genes[HORSES_LOCI], hex[HORSES_GENES_HEX], name[HORSES_NAME_LEN];
		Horses_GetGenes(horseid,genes);
		Gene_Encode(genes,hex);
		Horses_GetHorseName(horseid,name);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: slot %d hid %d kind %d owner %d breed %d sex %d age %dd genes %s",name,horseid,Horses_GetHid(horseid),Horses_GetKind(horseid),Horses_GetOwner(horseid),_:Horses_GetBreed(horseid),Horses_GetSex(horseid),Horses_GetAgeDays(horseid),hex));
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("bond %d tier %d hunger %.1f thirst %.1f condition %.1f shoes %d lame %d sick %d foal-in %d speed %.2f stamina %d nogallop %d",Horses_GetBond(horseid),Horses_GetTier(horseid),Horses_GetHunger(horseid),Horses_GetThirst(horseid),Horses_GetCondition(horseid),Horses_GetShoes(horseid),Horses_IsLame(horseid),Horses_IsSick(horseid),Horses_DaysToFoal(horseid),Horse_GetSpeed(horseid),Horse_GetStaminaMax(horseid),Horse_IsNoGallop(horseid)));
		return 1;
	}

	if (!Horses_IsOwned(horseid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"That horse has no owner.");
		return 1;
	}

	if (!strcmp(action,"bond",true))
	{
		Horses_SetBond(horseid,Util_ClampInt(strval(rest),0,100));
	}
	else if (!strcmp(action,"needs",true))
	{
		new Float:hunger, Float:thirst, Float:condition;

		if (sscanf(rest,"fff",hunger,thirst,condition))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"/horses needs <hunger> <thirst> <condition>");
			return 1;
		}

		Horses_SetNeeds(horseid,hunger,thirst,condition);
	}
	else if (!strcmp(action,"age",true))
	{
		Horses_SetBorn(horseid,Horses_Today() - strval(rest));
	}
	else if (!strcmp(action,"foal",true))
	{
		if (!Horses_IsInFoal(horseid))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"She isn't in foal.");
			return 1;
		}

		Horses_Foal(horseid);
	}
	else if (!strcmp(action,"season",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("In season %d, next in %d days, breeding season %d.",Horses_IsInSeason(Horses_GetHid(horseid),Horses_Today()),Horses_DaysToSeason(Horses_GetHid(horseid),Horses_Today()),Horses_IsBreedingSeason()));
		return 1;
	}
	else if (!strcmp(action,"lame",true))
	{
		Horses_SetLame(horseid,Horses_IsLame(horseid) ? 0 : HORSES_LAME_DAYS);
	}
	else if (!strcmp(action,"sick",true))
	{
		Horses_SetSick(horseid,Horses_IsSick(horseid) ? 0 : HORSES_SICK_DAYS);
	}
	else if (!strcmp(action,"kill",true))
	{
		Horses_Die(horseid,HORSES_DEATH_STAFF);
		SendClientMessage(playerid,0xFFFFFFFF,"The horse is dead.");
		return 1;
	}
	else
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Unknown action.");
		return 1;
	}

	Horses_Save(horseid);
	SendClientMessage(playerid,0xFFFFFFFF,"Done.");
	return 1;
}
