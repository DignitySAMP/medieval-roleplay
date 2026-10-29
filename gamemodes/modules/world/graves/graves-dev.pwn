static Graves_DevPlot(playerid,const yard[])
{
	yield 1;

	new Float:x, Float:y, Float:z, Float:a, Float:groundZ, yardCopy[GRAVES_KEY_LEN];
	strcopy(yardCopy,yard);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x += 1.5 * floatsin(-a,degrees);
	y += 1.5 * floatcos(-a,degrees);

	if (!Placement_FindSurface(x,y,z + 0.5,3.0,groundZ))
	{
		groundZ = z - 1.0;
	}

	new grave = await Grave_CreatePlot(yardCopy,x,y,groundZ,Util_NormalizeAngle(a + 90.0),GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (IsPlayerConnected(playerid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,grave == -1 ? ("The plot couldn't be saved. The list may be full.") : sprintf("Plot %d of '%s' marked 1.5 m ahead, the head away from you. %d free plot(s) in all.",Grave_CountYard(yardCopy),yardCopy,Grave_CountPlots(true)));
	}
}

static Graves_DevBury(playerid,characterid)
{
	yield 1;

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	new grave = await Graves_Bury(characterid,x,y,z);

	if (IsPlayerConnected(playerid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,grave != -1 ? ("Buried in the nearest free plot. The funeral is set.") : ("Not buried in a plot: already buried, no such character, or no plot free (then the crypt took them, if there is one)."));
	}
}

static Graves_DevCrypt(playerid,const key[])
{
	yield 1;

	new Float:x, Float:y, Float:z, Float:a, keyCopy[GRAVES_KEY_LEN];
	strcopy(keyCopy,key);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	new crypt = await Crypt_Create(keyCopy,x,y,z,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (IsPlayerConnected(playerid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,crypt == -1 ? ("The crypt couldn't be saved. The list may be full.") : sprintf("The crypt '%s' opens here (facing the way you face). /crypt enter to look inside.",keyCopy));
	}
}

static Graves_DevFill(playerid,crypt,count)
{
	yield 1;

	new placed = 0;

	for (new i = 0;i < count;i++)
	{
		new niche = Crypt_FindFreeNiche(crypt);

		if (niche == -1 && Crypt_Grow(crypt))
		{
			niche = Crypt_FindFreeNiche(crypt);
		}

		if (niche == -1)
		{
			break;
		}

		await mysql_aquery_s(g_Mysql,str_format("INSERT INTO crypt_niches (crypt_id, niche, character_id) VALUES (%d, %d, 0)",Crypt_GetRow(crypt),niche));

		new row = cache_insert_id();

		if (row > 0 && Crypt_AddNiche(row,crypt,niche,0,sprintf("Test Soul %d",niche + 1),0,30,40,"the test") != -1)
		{
			placed++;
		}
	}

	if (IsPlayerConnected(playerid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d test niche(s) sealed; the crypt has %d chamber(s).",placed,Crypt_GetChambers(crypt)));
	}
}

CMD<ADMIN_LEVEL_TRIAL>:grave(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], arg[GRAVES_KEY_LEN];

	if (sscanf(params,"s[12]S()[24]",action,arg))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /grave plot <yard>, remove, list, bury <character id>, settle, marker <wood|headstone|cross>, funeral, exhume");
		return 1;
	}

	if (!strcmp(action,"plot",true))
	{
		if (arg[0] == EOS)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /grave plot <yard>, e.g. /grave plot monastery. Stand at the foot, facing the head.");
			return 1;
		}

		Graves_DevPlot(playerid,arg);
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d plot(s), %d free; %d funeral(s) waiting%s.",Grave_CountPlots(),Grave_CountPlots(true),Funeral_CountPending(),Funeral_IsRiteRunning() ? (", one under way") : ("")));
		return 1;
	}

	if (!strcmp(action,"bury",true))
	{
		new characterid = strval(arg);

		if (characterid <= 0)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /grave bury <character id>. The character must be dead for good.");
			return 1;
		}

		Graves_DevBury(playerid,characterid);
		return 1;
	}

	new grave = Grave_FindForPlayer(playerid,3.0);

	if (grave == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"There's no plot within 3 m of you.");
		return 1;
	}

	if (!strcmp(action,"remove",true))
	{
		if (Grave_IsTaken(grave))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Someone lies there. /grave exhume first.");
			return 1;
		}

		Grave_RemovePlot(grave);
		SendClientMessage(playerid,0xFFFFFFFF,"The plot is gone.");
		return 1;
	}

	if (!strcmp(action,"exhume",true))
	{
		Grave_Exhume(grave);
		SendClientMessage(playerid,0xFFFFFFFF,"The plot is empty again.");
		return 1;
	}

	if (!strcmp(action,"settle",true))
	{
		Grave_Settle(grave);
		SendClientMessage(playerid,0xFFFFFFFF,"The mound has settled and grassed over.");
		return 1;
	}

	if (!strcmp(action,"marker",true))
	{
		for (new i = 0;i < GRAVE_MARKER_COUNT;i++)
		{
			if (!strcmp(arg,g_GraveMarkerNames[i],true))
			{
				Grave_SetMarker(grave,i);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("The grave now has a %s marker.",g_GraveMarkerNames[i]));
				return 1;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,"Use: /grave marker <wood|headstone|cross>");
		return 1;
	}

	if (!strcmp(action,"funeral",true))
	{
		new funeral = Funeral_FindByCharacter(Grave_GetCharacter(grave));

		if (funeral == -1 || !Funeral_StartRite(funeral))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No funeral is waiting for this grave, or one is already under way.");
			return 1;
		}

		SendClientMessage(playerid,0xFFFFFFFF,"The priest comes to the grave.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /grave plot <yard>, remove, list, bury <character id>, settle, marker <wood|headstone|cross>, funeral, exhume");
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:crypt(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], arg[GRAVES_KEY_LEN];

	if (sscanf(params,"s[12]S()[24]",action,arg))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /crypt place <key>, enter, grow, fill <count>, list, remove");
		return 1;
	}

	if (!strcmp(action,"place",true))
	{
		if (arg[0] == EOS)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /crypt place <key>. Stand at the door, facing out.");
			return 1;
		}

		Graves_DevCrypt(playerid,arg);
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		for (new i = 0;i < CRYPT_MAX;i++)
		{
			if (Crypt_IsValid(i))
			{
				new key[GRAVES_KEY_LEN];
				Crypt_GetKey(i,key);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: %d chamber(s), %d of %d niches sealed, world %d.",key,Crypt_GetChambers(i),Crypt_CountNiches(i),Crypt_GetChambers(i) * CRYPT_NICHES_PER_CHAMBER,Crypt_GetWorld(i)));
			}
		}

		return 1;
	}

	new crypt = Crypt_FindByWorld(GetPlayerVirtualWorld(playerid));

	if (crypt == -1)
	{
		crypt = Crypt_FindDoorNear(playerid,6.0);
	}

	if (crypt == -1)
	{
		for (new i = 0;i < CRYPT_MAX && crypt == -1;i++)
		{
			if (Crypt_IsValid(i))
			{
				crypt = i;
			}
		}
	}

	if (crypt == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"There's no crypt yet. /crypt place <key> at a church door.");
		return 1;
	}

	if (!strcmp(action,"enter",true))
	{
		Crypt_Enter(playerid,crypt);
		return 1;
	}

	if (!strcmp(action,"grow",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Crypt_Grow(crypt) ? ("A new chamber is dug.") : ("The crypt is as big as it gets."));
		return 1;
	}

	if (!strcmp(action,"fill",true))
	{
		Graves_DevFill(playerid,crypt,Util_ClampInt(strval(arg),1,CRYPT_NICHES_PER_CHAMBER * 2));
		return 1;
	}

	if (!strcmp(action,"remove",true))
	{
		Crypt_Remove(crypt);
		SendClientMessage(playerid,0xFFFFFFFF,"The crypt and its niches are gone.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /crypt place <key>, enter, grow, fill <count>, list, remove");
	return 1;
}
