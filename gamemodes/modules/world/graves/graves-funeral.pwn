enum E_FUNERAL
{
	bool:E_FUNERAL_USED,
	E_FUNERAL_CHARACTER,
	E_FUNERAL_GRAVE_ROW,
	E_FUNERAL_NICHE_ROW,
	E_FUNERAL_AT,
	bool:E_FUNERAL_REMINDED,
	E_FUNERAL_NAME[GRAVES_NAME_LEN],
	E_FUNERAL_PLACE[GRAVES_KEY_LEN],
}

static s_Funerals[FUNERAL_MAX][E_FUNERAL];

enum E_FUNERAL_RITE
{
	E_FUNERAL_RITE_FUNERAL,
	E_FUNERAL_RITE_ACTOR,
	E_FUNERAL_RITE_STEP,
	E_FUNERAL_RITE_TOKEN,
	E_FUNERAL_RITE_TEXT,
	Float:E_FUNERAL_RITE_POS[3],
	E_FUNERAL_RITE_WORLD,
	E_FUNERAL_RITE_INTERIOR,
}

static s_FuneralRite[E_FUNERAL_RITE] = {-1, INVALID_ACTOR_ID, 0, 0, -1};

stock bool:Funeral_IsRiteRunning()
{
	return s_FuneralRite[E_FUNERAL_RITE_FUNERAL] != -1;
}

stock Funeral_CountPending()
{
	new count = 0;

	for (new i = 0;i < FUNERAL_MAX;i++)
	{
		if (s_Funerals[i][E_FUNERAL_USED])
		{
			count++;
		}
	}

	return count;
}

stock Funeral_FindByCharacter(characterid)
{
	for (new i = 0;i < FUNERAL_MAX;i++)
	{
		if (s_Funerals[i][E_FUNERAL_USED] && s_Funerals[i][E_FUNERAL_CHARACTER] == characterid)
		{
			return i;
		}
	}

	return -1;
}

stock Funeral_GetAt(funeral)
{
	return funeral >= 0 && funeral < FUNERAL_MAX && s_Funerals[funeral][E_FUNERAL_USED] ? s_Funerals[funeral][E_FUNERAL_AT] : 0;
}

static Funeral_Add(characterid,graveRow,nicheRow,at,const name[],const place[])
{
	for (new i = 0;i < FUNERAL_MAX;i++)
	{
		if (s_Funerals[i][E_FUNERAL_USED])
		{
			continue;
		}

		s_Funerals[i][E_FUNERAL_USED] = true;
		s_Funerals[i][E_FUNERAL_CHARACTER] = characterid;
		s_Funerals[i][E_FUNERAL_GRAVE_ROW] = graveRow;
		s_Funerals[i][E_FUNERAL_NICHE_ROW] = nicheRow;
		s_Funerals[i][E_FUNERAL_AT] = at;
		s_Funerals[i][E_FUNERAL_REMINDED] = at - gettime() <= FUNERAL_REMIND_SECONDS;
		strcopy(s_Funerals[i][E_FUNERAL_NAME],name,GRAVES_NAME_LEN);
		strcopy(s_Funerals[i][E_FUNERAL_PLACE],place,GRAVES_KEY_LEN);
		return i;
	}

	return -1;
}

static Funeral_Announce(const title[],const text[])
{
	Crier_Announce(CRIER_KIND_FAITH,title,text);

	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid))
		{
			Gui_Notify(playerid,text);
		}
	}
}

stock Funeral_GetPlaceName(const place[],bool:isCrypt,dest[],size = sizeof(dest))
{
    if (!strcmp(place,"parish"))
    {
        strcopy(dest,isCrypt ? ("the parish crypt") : ("the parish churchyard"),size);
        return;
    }
    if (!strcmp(place,"monastery"))
    {
        strcopy(dest,isCrypt ? ("the monastery crypt") : ("the monastery churchyard"),size);
        return;
    }
    strcopy(dest,place,size);
}

stock Funeral_FormatScheduled(const name[],const place[],at,dest[],size = sizeof(dest))
{
    new now = gettime(), localSeconds = (Faith_LocalSeconds() + at - now + 86400) % 86400;
    format(dest,size,"A funeral for %s will be held at %s at %02d:%02d Brussels time, in %d minutes.",name,place,localSeconds / 3600,(localSeconds % 3600) / 60,max((at - now) / 60,1));
}

stock Funeral_Schedule(characterid,graveRow,nicheRow,const name[],const place[],delay = FUNERAL_DELAY_SECONDS)
{
	new at = gettime() + delay;

	if (Funeral_Add(characterid,graveRow,nicheRow,at,name,place) == -1)
	{
		return -1;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO funerals (character_id, grave_id, niche_id, scheduled_at, held) VALUES (%d, %s, %s, %d, 0)",characterid,graveRow > 0 ? sprintf("%d",graveRow) : ("NULL"),nicheRow > 0 ? sprintf("%d",nicheRow) : ("NULL"),at));

    new text[256], location[64];
    Funeral_GetPlaceName(place,nicheRow > 0,location);
    Funeral_FormatScheduled(name,location,at,text);
    Funeral_Announce("A funeral",text);
	return at;
}

static bool:Funeral_GetSpot(funeral,&Float:x,&Float:y,&Float:z,&Float:a,&world,&interior)
{
	if (s_Funerals[funeral][E_FUNERAL_GRAVE_ROW] > 0)
	{
		new grave = Grave_FindByRow(s_Funerals[funeral][E_FUNERAL_GRAVE_ROW]), Float:moundA;

		if (!Grave_GetPos(grave,x,y,z,moundA,world,interior))
		{
			return false;
		}

		x -= 1.4 * floatsin(moundA,degrees);
		y += 1.4 * floatcos(moundA,degrees);
		z += 1.0;
		a = moundA + 180.0;
		return true;
	}

	new entry = Crypt_FindNicheByRow(s_Funerals[funeral][E_FUNERAL_NICHE_ROW]), Float:rz;

	if (entry == -1)
	{
		return false;
	}

	Crypt_GetNicheWorldPos(entry,x,y,z,rz,world);
	x += 1.4 * floatsin(rz,degrees);
	y -= 1.4 * floatcos(rz,degrees);
	z = CRYPT_SKY_Z + 1.0;
	a = rz;
	interior = CRYPT_INTERIOR;
	return true;
}

static Funeral_Say(const line[],colour)
{
	Chat_FromPoint(s_FuneralRite[E_FUNERAL_RITE_POS][0],s_FuneralRite[E_FUNERAL_RITE_POS][1],s_FuneralRite[E_FUNERAL_RITE_POS][2],s_FuneralRite[E_FUNERAL_RITE_WORLD],s_FuneralRite[E_FUNERAL_RITE_INTERIOR],FUNERAL_RANGE,colour,line);
}

static Funeral_Finish(funeral)
{
	new characterid = s_Funerals[funeral][E_FUNERAL_CHARACTER], attendees = 0, text[128];
	format(text,sizeof(text),"You stood at %s's graveside.",s_Funerals[funeral][E_FUNERAL_NAME]);

	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == s_FuneralRite[E_FUNERAL_RITE_WORLD] && IsPlayerInRangeOfPoint(playerid,FUNERAL_RANGE,s_FuneralRite[E_FUNERAL_RITE_POS][0],s_FuneralRite[E_FUNERAL_RITE_POS][1],s_FuneralRite[E_FUNERAL_RITE_POS][2]))
		{
			attendees++;
			Gui_Notify(playerid,text);
		}
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE funerals SET held = 1, attendees = %d WHERE character_id = %d AND held = 0",attendees,characterid));
    new announcement[256], location[64];
    Funeral_GetPlaceName(s_Funerals[funeral][E_FUNERAL_PLACE],s_Funerals[funeral][E_FUNERAL_NICHE_ROW] > 0,location);
    format(announcement,sizeof(announcement),"The funeral for %s has been held at %s.",s_Funerals[funeral][E_FUNERAL_NAME],location);
    Funeral_Announce("A funeral held",announcement);
	s_Funerals[funeral][E_FUNERAL_USED] = false;
	pawn_call_public("Graves_OnFuneral","dd",characterid,attendees);
	Log_Info("graves","funeral for character %d held, %d mourner(s)",characterid,attendees);
}

stock bool:Funeral_StartRite(funeral)
{
	if (funeral < 0 || funeral >= FUNERAL_MAX || !s_Funerals[funeral][E_FUNERAL_USED] || Funeral_IsRiteRunning())
	{
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a, world, interior;

	if (!Funeral_GetSpot(funeral,x,y,z,a,world,interior))
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE funerals SET held = 1 WHERE character_id = %d AND held = 0",s_Funerals[funeral][E_FUNERAL_CHARACTER]));
		s_Funerals[funeral][E_FUNERAL_USED] = false;
		return false;
	}

	new actor = CreateActor(FUNERAL_PRIEST_SKIN,x,y,z,a);
    if (!IsValidActor(actor))
    {
        return false;
    }
    Faith_SetPriestAway(true);
	SetActorVirtualWorld(actor,world);
    Actors_RegisterBody("faith:funeral",actor,0,FUNERAL_PRIEST_NAME,"Priest",world,interior,"priest");
	s_FuneralRite[E_FUNERAL_RITE_FUNERAL] = funeral;
	s_FuneralRite[E_FUNERAL_RITE_ACTOR] = actor;
	s_FuneralRite[E_FUNERAL_RITE_STEP] = 0;
	s_FuneralRite[E_FUNERAL_RITE_TOKEN]++;
	s_FuneralRite[E_FUNERAL_RITE_TEXT] = Faith_FindText("requiem-aeternam");
	s_FuneralRite[E_FUNERAL_RITE_POS][0] = x;
	s_FuneralRite[E_FUNERAL_RITE_POS][1] = y;
	s_FuneralRite[E_FUNERAL_RITE_POS][2] = z;
	s_FuneralRite[E_FUNERAL_RITE_WORLD] = world;
	s_FuneralRite[E_FUNERAL_RITE_INTERIOR] = interior;

    new announcement[256], location[64];
    Funeral_GetPlaceName(s_Funerals[funeral][E_FUNERAL_PLACE],s_Funerals[funeral][E_FUNERAL_NICHE_ROW] > 0,location);
    format(announcement,sizeof(announcement),"The funeral for %s is beginning at %s now. All are welcome.",s_Funerals[funeral][E_FUNERAL_NAME],location);
    Funeral_Announce("A funeral begins",announcement);

	new text[160];
	format(text,sizeof(text),"* %s makes the sign of the cross over %s.",FUNERAL_PRIEST_NAME,s_Funerals[funeral][E_FUNERAL_NAME]);
	Funeral_Say(text,CHAT_COLOUR_ACTION);
	SetTimerEx("Funeral_RiteStep",FUNERAL_LINE_MS,false,"d",s_FuneralRite[E_FUNERAL_RITE_TOKEN]);
	return true;
}

stock Funeral_EndRite()
{
	if (s_FuneralRite[E_FUNERAL_RITE_ACTOR] != INVALID_ACTOR_ID)
	{
        Actors_UnregisterBody(s_FuneralRite[E_FUNERAL_RITE_ACTOR]);
		DestroyActor(s_FuneralRite[E_FUNERAL_RITE_ACTOR]);
	}

	s_FuneralRite[E_FUNERAL_RITE_ACTOR] = INVALID_ACTOR_ID;
	s_FuneralRite[E_FUNERAL_RITE_FUNERAL] = -1;
	s_FuneralRite[E_FUNERAL_RITE_TOKEN]++;
    Faith_SetPriestAway(false);
}

stock Funeral_Tick()
{
	new now = gettime();

	for (new i = 0;i < FUNERAL_MAX;i++)
	{
		if (!s_Funerals[i][E_FUNERAL_USED])
		{
			continue;
		}

		if (!s_Funerals[i][E_FUNERAL_REMINDED] && s_Funerals[i][E_FUNERAL_AT] - now <= FUNERAL_REMIND_SECONDS)
		{
            new text[256], location[64];
			s_Funerals[i][E_FUNERAL_REMINDED] = true;
            Funeral_GetPlaceName(s_Funerals[i][E_FUNERAL_PLACE],s_Funerals[i][E_FUNERAL_NICHE_ROW] > 0,location);
            Funeral_FormatScheduled(s_Funerals[i][E_FUNERAL_NAME],location,s_Funerals[i][E_FUNERAL_AT],text);
			Funeral_Announce("A funeral soon",text);
		}

		if (now >= s_Funerals[i][E_FUNERAL_AT] && !Funeral_IsRiteRunning())
		{
			Funeral_StartRite(i);
		}
	}
}

forward Funeral_RiteStep(token);

public Funeral_RiteStep(token)
{
	if (token != s_FuneralRite[E_FUNERAL_RITE_TOKEN] || !Funeral_IsRiteRunning())
	{
		return 1;
	}

	new funeral = s_FuneralRite[E_FUNERAL_RITE_FUNERAL], text = s_FuneralRite[E_FUNERAL_RITE_TEXT], kind, season, count, bool:isBilingual, line[FAITH_LINE_LEN], out[FAITH_LINE_LEN + 32];

	if (text != -1 && Faith_GetTextInfo(text,kind,season,count,isBilingual) && s_FuneralRite[E_FUNERAL_RITE_STEP] < count)
	{
		#pragma unused kind, season
		new at = s_FuneralRite[E_FUNERAL_RITE_STEP];
		Faith_GetTextLine(text,at,line);
		format(out,sizeof(out),"%s says: %s",FUNERAL_PRIEST_NAME,line);
		Funeral_Say(out,CHAT_COLOUR_SAY);

		if (isBilingual && at + 1 < count)
		{
			Faith_GetTextLine(text,at + 1,line);
			format(out,sizeof(out),"(( %s ))",line);
			Funeral_Say(out,CHAT_COLOUR_NOTE);
		}

		s_FuneralRite[E_FUNERAL_RITE_STEP] = at + (isBilingual ? 2 : 1);
		SetTimerEx("Funeral_RiteStep",FUNERAL_LINE_MS,false,"d",token);
		return 1;
	}

	format(out,sizeof(out),"* %s sprinkles the grave with holy water and steps back.",FUNERAL_PRIEST_NAME);
	Funeral_Say(out,CHAT_COLOUR_ACTION);
	Funeral_Finish(funeral);
	SetTimerEx("Funeral_RiteEnd",8000,false,"d",token);
	return 1;
}

forward Funeral_RiteEnd(token);

public Funeral_RiteEnd(token)
{
	if (token == s_FuneralRite[E_FUNERAL_RITE_TOKEN])
	{
		Funeral_EndRite();
	}

	return 1;
}

forward Graves_OnFuneral(characterid,attendees);

public Graves_OnFuneral(characterid,attendees)
{
	return 1;
}

forward Funeral_LoadOnBoot();

public Funeral_LoadOnBoot()
{
	yield 1;

	new now = gettime();
	await mysql_aquery_s(g_Mysql,str_format("UPDATE funerals SET held = 1 WHERE held = 0 AND scheduled_at < %d",now - FUNERAL_STALE_SECONDS));
	await mysql_aquery_s(g_Mysql,str_new("SELECT f.character_id, IFNULL(f.grave_id, 0) AS grave_id, IFNULL(f.niche_id, 0) AS niche_id, f.scheduled_at, IFNULL(c.name, '') AS name, IFNULL(c.surname, '') AS surname, IFNULL(g.yard_key, IFNULL(k.crypt_key, '')) AS place FROM funerals f LEFT JOIN characters c ON c.id = f.character_id LEFT JOIN graves g ON g.id = f.grave_id LEFT JOIN crypt_niches n ON n.id = f.niche_id LEFT JOIN crypts k ON k.id = n.crypt_id WHERE f.held = 0 ORDER BY f.scheduled_at"));

	new pending = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new characterid, graveRow, nicheRow, at, first[24], surname[24], name[GRAVES_NAME_LEN], place[GRAVES_KEY_LEN];
		cache_get_value_name_int(r,"character_id",characterid);
		cache_get_value_name_int(r,"grave_id",graveRow);
		cache_get_value_name_int(r,"niche_id",nicheRow);
		cache_get_value_name_int(r,"scheduled_at",at);
		cache_get_value_name(r,"name",first);
		cache_get_value_name(r,"surname",surname);
		cache_get_value_name(r,"place",place);
		format(name,sizeof(name),"%s %s",first,surname);

		if (Funeral_Add(characterid,graveRow,nicheRow,at,name,place) != -1)
		{
			pending++;
		}
	}

	Log_Info("graves","%d funeral(s) to hold",pending);
	Boot_LoaderDone();
}
