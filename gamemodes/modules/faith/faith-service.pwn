#define FAITH_LINE_MS (6000)
#define FAITH_PRIEST_SKIN (20070)
#define FAITH_MASS_SKIN (20073)
#define FAITH_PRIEST_RANGE (35.0)
#define FAITH_ANSELM_KEY "faith:anselm"
#define FAITH_ACTION_RANGE (40.0)
#define FAITH_KNEEL_MS (20000)
#define FAITH_LEAD_IN_SECONDS (900)
#define FAITH_BELL_SECONDS (300)
#define FAITH_LAST_BELL_SECONDS (60)
#define FAITH_LABEL_Z (1.15)
#define FAITH_LABEL_RANGE (30.0)
#define FAITH_COLOUR_BELL (0xE8D8A8FF)
#define FAITH_COLOUR_LABEL (0xE6E6E6FF)
#define FAITH_NAME_LEN (32)
#define FAITH_ACTION_LEN (96)
#define FAITH_PART_ELEVATION "elevation"
#define FAITH_PART_LESSON "lesson"
#define FAITH_PART_HOMILY "homily"
#define FAITH_PART_BANNS "banns"
#define FAITH_LEADER_RANGE (2.5)
#define FAITH_SEASON_ANY (0)
#define FAITH_SEASON_ADVENT (1)
#define FAITH_SEASON_CHRISTMAS (2)
#define FAITH_SEASON_EPIPHANY (3)
#define FAITH_SEASON_SEPTUAGESIMA (4)
#define FAITH_SEASON_LENT (5)
#define FAITH_SEASON_PASSIONTIDE (6)
#define FAITH_SEASON_EASTER (7)
#define FAITH_SEASON_PENTECOST (8)
#define FAITH_SEASON_AFTER_PENTECOST (9)
#define FAITH_SEASON_FEAST (10)
#define FAITH_KIND_READING (1)
#define FAITH_KIND_HOMILY (2)

enum E_FAITH_CHURCH
{
	E_FAITH_CHURCH_NAME[FAITH_NAME_LEN],
	E_FAITH_CHURCH_PRIEST[FAITH_NAME_LEN],
	Float:E_FAITH_CHURCH_PULPIT[4],
	Float:E_FAITH_CHURCH_MIN[3],
	Float:E_FAITH_CHURCH_MAX[3],
    Float:E_FAITH_CHURCH_ALTAR_ANGLE,
    E_FAITH_CHURCH_WORLD,
    E_FAITH_CHURCH_INTERIOR,
}

static const s_FaithChurches[][E_FAITH_CHURCH] = {
	{"the monastery church", "Father Anselm", {716.4, -3603.8, 18.8, 90.0}, {678.5, -3610.175, 17.4}, {720.65, -3599.825, 24.0}, 270.0, 0, 0}
};

static const s_FaithServiceHours[] = {14, 19, 22};

enum E_FAITH_PART
{
	E_FAITH_PART_KEY[FAITH_TEXT_KEY_LEN],
	E_FAITH_PART_ACTION[FAITH_ACTION_LEN],
    bool:E_FAITH_PART_FACES_PEOPLE,
}

static const s_FaithParts[][E_FAITH_PART] = {
	{"asperges-me", "walks down the aisle, sprinkling the people with holy water.", false},
	{"kyrie", "turns to the altar and begins the Kyrie.", false},
	{"gloria-in-excelsis", "lifts his hands and sings the Gloria.", false},
	{FAITH_PART_LESSON, "opens the great book on the lectern and reads the lesson.", false},
	{FAITH_PART_HOMILY, "turns to the people and speaks to them in their own tongue.", true},
	{FAITH_PART_BANNS, "publishes the banns of marriage.", false},
	{"credo-nicene", "leads the Creed.", false},
	{"sanctus", "bows low before the altar.", false},
	{FAITH_PART_ELEVATION, "raises the host high above the altar. A small bell rings.", false},
	{"pater-noster", "prays the Lord's Prayer.", false},
	{"agnus-dei", "breaks the bread.", false},
	{"final-blessing", "raises his hand over the people in blessing.", false},
	{"dominus-vobiscum-ite-missa-est", "turns to the people for the dismissal.", true}
};

enum E_FAITH_SERVICE
{
	bool:E_FAITH_SERVICE_RUNNING,
	E_FAITH_SERVICE_CHURCH,
	E_FAITH_SERVICE_PART,
	E_FAITH_SERVICE_LINE,
	E_FAITH_SERVICE_TEXT,
	E_FAITH_SERVICE_LINE_MS,
	E_FAITH_SERVICE_TIMER,
	E_FAITH_SERVICE_KNEEL_STEPS,
	bool:E_FAITH_SERVICE_KNEELING,
	E_FAITH_SERVICE_READING,
	E_FAITH_SERVICE_HOMILY,
	E_FAITH_SERVICE_ACTOR,
	STREAMER_TAG_3D_TEXT_LABEL:E_FAITH_SERVICE_LABEL,
	E_FAITH_SERVICE_ANNOUNCED,
	E_FAITH_SERVICE_LEADER,
	E_FAITH_SERVICE_LEADER_TOKEN,
    E_FAITH_SERVICE_LEADER_SKIN,
    E_FAITH_SERVICE_LEADER_CHAR,
    Float:E_FAITH_SERVICE_LEADER_ANGLE,
}

static s_FaithService[E_FAITH_SERVICE];
static bool:s_FaithAttended[MAX_PLAYERS];
static bool:s_FaithKnelt[MAX_PLAYERS];
static s_FaithLastReading = -1;
static s_FaithLastHomily = -1;
static s_FaithIdleActor = INVALID_ACTOR_ID;
static STREAMER_TAG_3D_TEXT_LABEL:s_FaithIdleLabel = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
static s_FaithIdleActivity = -1;
static s_FaithIdleResumeAt;
static bool:s_FaithPriestAway;

#define FAITH_CONGREGATION_SEATS (56)
#define FAITH_CONGREGATION_BACK (4)

stock Faith_CountCongregationSeats()
{
	return FAITH_CONGREGATION_SEATS;
}

stock Faith_CountCongregationSpots()
{
	return FAITH_CONGREGATION_SEATS + FAITH_CONGREGATION_BACK;
}

stock bool:Faith_GetCongregationSpot(slot,&Float:x,&Float:y,&Float:z,&Float:a)
{
	if (slot < 0 || slot >= Faith_CountCongregationSpots())
	{
		return false;
	}

	a = 270.0;
	if (slot < FAITH_CONGREGATION_SEATS)
	{
		new row = slot / 8, side = slot % 8 / 4, seat = slot % 4;
		x = 712.0 - float(row) * 4.0;
		y = -3605.0 + (side == 0 ? -2.75 : 2.75) + float(seat) * 0.63 - 0.945;
		z = 18.018 + 0.40332;
	}
	else
	{
		x = 684.0;
		y = -3605.0 + float(slot - FAITH_CONGREGATION_SEATS) * 1.2 - 1.8;
		z = 17.428 + 1.0;
	}
	return true;
}

stock bool:Faith_IsServiceRunning()
{
	return s_FaithService[E_FAITH_SERVICE_RUNNING];
}

stock Faith_GetPriestSpot(church,&Float:x,&Float:y,&Float:z,&Float:a)
{
	church = clamp(church,0,sizeof(s_FaithChurches) - 1);
	x = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][0];
	y = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][1];
	z = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][2];
	a = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][3];
}

stock Faith_GetIdlePriestActor()
{
    return s_FaithIdleActor;
}

stock Faith_GetIdleActivity(localSeconds)
{
    new hour = clamp(localSeconds,0,86399) / 3600;
    if (hour >= 8 && hour < 17)
    {
        return 1;
    }
    if (hour >= 17 && hour < 23)
    {
        return 2;
    }
    return 0;
}

stock Faith_SuspendIdlePriest(seconds = 0)
{
    s_FaithIdleResumeAt = gettime() + seconds;
    if (IsValidActor(s_FaithIdleActor))
    {
        Actors_UnregisterBody(s_FaithIdleActor);
        DestroyActor(s_FaithIdleActor);
    }
    if (IsValidDynamic3DTextLabel(s_FaithIdleLabel))
    {
        DestroyDynamic3DTextLabel(s_FaithIdleLabel);
    }
    s_FaithIdleActor = INVALID_ACTOR_ID;
    s_FaithIdleLabel = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    s_FaithIdleActivity = -1;
}

stock Faith_UpdateIdlePriest(localSeconds = -1)
{
    if (Faith_IsServiceRunning() || Faith_IsRiteRunning() || s_FaithPriestAway || gettime() < s_FaithIdleResumeAt)
    {
        return;
    }

    new Float:x, Float:y, Float:z, Float:a;
    Faith_GetPriestSpot(0,x,y,z,a);
    if (!IsValidActor(s_FaithIdleActor))
    {
        s_FaithIdleActor = CreateActor(FAITH_PRIEST_SKIN,x,y,z,270.0);
        if (!IsValidActor(s_FaithIdleActor))
        {
            return;
        }
        SetActorInvulnerable(s_FaithIdleActor,true);
        SetActorVirtualWorld(s_FaithIdleActor,0);
        Actors_RegisterBody(FAITH_ANSELM_KEY,s_FaithIdleActor,0,"Father Anselm","Priest",0,0,"priest");
        s_FaithIdleActivity = -1;
    }

    new activity = Faith_GetIdleActivity(localSeconds < 0 ? Faith_LocalSeconds() : localSeconds);
    if (activity == s_FaithIdleActivity)
    {
        return;
    }
    s_FaithIdleActivity = activity;
    new label[96];
    switch (activity)
    {
        case 0:
        {
            ApplyActorAnimation(s_FaithIdleActor,"CAMERA","CAMCRCH_IDLELOOP",4.1,true,false,false,true,0);
            format(label,sizeof(label),"Father Anselm\nPraying at the altar");
        }
        case 1:
        {
            ApplyActorAnimation(s_FaithIdleActor,"COP_AMBIENT","Coplook_loop",4.1,true,false,false,true,0);
            format(label,sizeof(label),"Father Anselm\nReading the missal");
        }
        case 2:
        {
            ApplyActorAnimation(s_FaithIdleActor,"BOMBER","BOM_Plant_Loop",4.1,true,false,false,true,0);
            format(label,sizeof(label),"Father Anselm\nTending the altar candles");
        }
    }

    if (IsValidDynamic3DTextLabel(s_FaithIdleLabel))
    {
        UpdateDynamic3DTextLabelText(s_FaithIdleLabel,FAITH_COLOUR_LABEL,label);
    }
    else
    {
        s_FaithIdleLabel = CreateDynamic3DTextLabel(label,FAITH_COLOUR_LABEL,x,y,z + FAITH_LABEL_Z,FAITH_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,false,0,0);
        foreach (new playerid : Player)
        {
            if (GetPlayerVirtualWorld(playerid) == 0 && GetPlayerInterior(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,STREAMER_3D_TEXT_LABEL_SD,x,y,z))
            {
                Streamer_Update(playerid,STREAMER_TYPE_3D_TEXT_LABEL);
            }
        }
    }
}

stock Faith_SetPriestAway(bool:isAway)
{
    s_FaithPriestAway = isAway;
    if (isAway)
    {
        Faith_SuspendIdlePriest();
    }
    else
    {
        Faith_UpdateIdlePriest();
    }
}

stock Faith_GetPriestName(church,dest[],size = sizeof(dest))
{
	strcopy(dest,s_FaithChurches[clamp(church,0,sizeof(s_FaithChurches) - 1)][E_FAITH_CHURCH_PRIEST],size);
}

stock Faith_GetServiceChurch()
{
	return Faith_IsServiceRunning() ? s_FaithService[E_FAITH_SERVICE_CHURCH] : -1;
}

stock Faith_GetServicePart()
{
	return s_FaithService[E_FAITH_SERVICE_RUNNING] ? s_FaithService[E_FAITH_SERVICE_PART] : -1;
}

stock bool:Faith_IsKneelOpen()
{
	return s_FaithService[E_FAITH_SERVICE_RUNNING] && s_FaithService[E_FAITH_SERVICE_KNEELING];
}

stock bool:Faith_IsInChurch(playerid,church = 0)
{
	if (!Session_IsPlaying(playerid) || church < 0 || church >= sizeof(s_FaithChurches) || GetPlayerVirtualWorld(playerid) != s_FaithChurches[church][E_FAITH_CHURCH_WORLD] || GetPlayerInterior(playerid) != s_FaithChurches[church][E_FAITH_CHURCH_INTERIOR])
	{
		return false;
	}

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid,x,y,z);
    return x >= s_FaithChurches[church][E_FAITH_CHURCH_MIN][0] && x <= s_FaithChurches[church][E_FAITH_CHURCH_MAX][0] && y >= s_FaithChurches[church][E_FAITH_CHURCH_MIN][1] && y <= s_FaithChurches[church][E_FAITH_CHURCH_MAX][1] && z >= s_FaithChurches[church][E_FAITH_CHURCH_MIN][2] && z <= s_FaithChurches[church][E_FAITH_CHURCH_MAX][2];
}

stock bool:Faith_HasAttended(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FaithAttended[playerid];
}

stock bool:Faith_HasKnelt(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FaithKnelt[playerid];
}

stock Faith_GetLiturgicalSeason()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);

	if ((month == 12 && day == 25) || (month == 9 && (day == 28 || day == 29)) || (month == 11 && day <= 2))
	{
		return FAITH_SEASON_FEAST;
	}

	switch (month)
	{
		case 12: return day >= 25 ? FAITH_SEASON_CHRISTMAS : FAITH_SEASON_ADVENT;
		case 1: return day <= 5 ? FAITH_SEASON_CHRISTMAS : FAITH_SEASON_EPIPHANY;
		case 2: return FAITH_SEASON_SEPTUAGESIMA;
		case 3: return day >= 16 ? FAITH_SEASON_PASSIONTIDE : FAITH_SEASON_LENT;
		case 4, 5: return FAITH_SEASON_EASTER;
		case 6: return day <= 15 ? FAITH_SEASON_PENTECOST : FAITH_SEASON_AFTER_PENTECOST;
	}

	return FAITH_SEASON_AFTER_PENTECOST;
}

static Faith_PickText(kind,season,avoid)
{
	new picks[FAITH_TEXT_COUNT], count = 0, textKind, textSeason, lines, bool:isBilingual;

	for (new pass = 0;pass < 3 && count == 0;pass++)
	{
		for (new i = 0;i < FAITH_TEXT_COUNT;i++)
		{
			Faith_GetTextInfo(i,textKind,textSeason,lines,isBilingual);

			if (textKind != kind || (i == avoid && pass < 2))
			{
				continue;
			}

			if ((pass == 0 && textSeason == season) || (pass == 1 && (textSeason == FAITH_SEASON_ANY || textSeason == FAITH_SEASON_AFTER_PENTECOST)) || pass == 2)
			{
				picks[count++] = i;
			}
		}
	}

	return count > 0 ? picks[random(count)] : -1;
}

static bool:Faith_SkipsGloria(season)
{
	return season == FAITH_SEASON_ADVENT || season == FAITH_SEASON_SEPTUAGESIMA || season == FAITH_SEASON_LENT || season == FAITH_SEASON_PASSIONTIDE;
}

stock Faith_Say(const line[])
{
    if (!Faith_IsServiceRunning())
    {
        return 0;
    }

    new church = Faith_GetServiceChurch(), leaderid = Faith_GetServiceLeader(), heard = 0;
    new name[NAMETAG_LEN], out[FAITH_LINE_LEN + NAMETAG_LEN + 32];
    foreach (new playerid : Player)
    {
        if (!Faith_IsInChurch(playerid,church))
        {
            continue;
        }

        if (leaderid != INVALID_PLAYER_ID)
        {
            Nametag_GetKnownName(playerid,leaderid,name);
        }
        else
        {
            Faith_GetPriestName(church,name);
        }

        format(out,sizeof(out),"%s calls out: %s",name,line);
        MessageSplit_SendClientMessage(playerid,CHAT_COLOUR_SAY,out);
        heard++;
    }

    if (IsValidDynamic3DTextLabel(s_FaithService[E_FAITH_SERVICE_LABEL]))
    {
        UpdateDynamic3DTextLabelText(s_FaithService[E_FAITH_SERVICE_LABEL],FAITH_COLOUR_LABEL,line);
    }
    return heard;
}

static Faith_Act(const action[])
{
	new church = s_FaithService[E_FAITH_SERVICE_CHURCH], out[FAITH_ACTION_LEN + FAITH_NAME_LEN + 8];

	if (s_FaithService[E_FAITH_SERVICE_LEADER] != INVALID_PLAYER_ID)
	{
		Chat_Speak(s_FaithService[E_FAITH_SERVICE_LEADER],CHAT_ME,action);
		return;
	}

	format(out,sizeof(out),"* %s %s",s_FaithChurches[church][E_FAITH_CHURCH_PRIEST],action);
	Chat_FromPoint(s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][0],s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][1],s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][2],0,0,FAITH_ACTION_RANGE,CHAT_COLOUR_ACTION,out);
}

static Faith_TellInside(const text[])
{
	foreach (new playerid : Player)
	{
		if (Faith_IsInChurch(playerid,s_FaithService[E_FAITH_SERVICE_CHURCH]))
		{
			Gui_Notify(playerid,text);
		}
	}
}

static Faith_Announce(const text[])
{
	foreach (new playerid : Player)
	{
		if (Session_IsPlaying(playerid))
		{
			SendClientMessage(playerid,FAITH_COLOUR_BELL,text);
		}
	}
}

static Faith_PartText(part)
{
	if (!strcmp(s_FaithParts[part][E_FAITH_PART_KEY],FAITH_PART_LESSON))
	{
		return s_FaithService[E_FAITH_SERVICE_READING];
	}

	if (!strcmp(s_FaithParts[part][E_FAITH_PART_KEY],FAITH_PART_HOMILY))
	{
		return s_FaithService[E_FAITH_SERVICE_HOMILY];
	}

	return Faith_FindText(s_FaithParts[part][E_FAITH_PART_KEY]);
}

static bool:Faith_PartIsSkipped(part)
{
	if (!strcmp(s_FaithParts[part][E_FAITH_PART_KEY],FAITH_PART_BANNS))
	{
		return Faith_CountBanns() == 0;
	}

	return !strcmp(s_FaithParts[part][E_FAITH_PART_KEY],"gloria-in-excelsis") && Faith_SkipsGloria(Faith_GetLiturgicalSeason());
}

stock Faith_GetWornSkin(playerid)
{
    new skin = GetPlayerCustomSkin(playerid);
    return skin != 0 ? skin : GetPlayerSkin(playerid);
}

static Faith_RestoreLeader()
{
    new leaderid = s_FaithService[E_FAITH_SERVICE_LEADER];
    if (leaderid != INVALID_PLAYER_ID && IsPlayerConnected(leaderid) && Account_GetToken(leaderid) == s_FaithService[E_FAITH_SERVICE_LEADER_TOKEN] && Character_GetId(leaderid) == s_FaithService[E_FAITH_SERVICE_LEADER_CHAR])
    {
        SetPlayerSkin(leaderid,s_FaithService[E_FAITH_SERVICE_LEADER_SKIN]);
        SetPlayerFacingAngle(leaderid,s_FaithService[E_FAITH_SERVICE_LEADER_ANGLE]);
    }
}

static Faith_FaceServicePart()
{
    new part = Faith_GetServicePart();
    if (part < 0 || part >= sizeof(s_FaithParts))
    {
        return;
    }

    new church = Faith_GetServiceChurch(), leaderid = Faith_GetServiceLeader();
    new Float:angle = s_FaithParts[part][E_FAITH_PART_FACES_PEOPLE] ? s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][3] : s_FaithChurches[church][E_FAITH_CHURCH_ALTAR_ANGLE];
    if (leaderid != INVALID_PLAYER_ID)
    {
        SetPlayerFacingAngle(leaderid,angle);
    }
    else if (IsValidActor(s_FaithService[E_FAITH_SERVICE_ACTOR]))
    {
        SetActorFacingAngle(s_FaithService[E_FAITH_SERVICE_ACTOR],angle);
    }
}

static Faith_EndService()
{
    Faith_RestoreLeader();
	if (s_FaithService[E_FAITH_SERVICE_TIMER] != 0)
	{
		KillTimer(s_FaithService[E_FAITH_SERVICE_TIMER]);
	}

	if (IsValidActor(s_FaithService[E_FAITH_SERVICE_ACTOR]))
	{
		DestroyActor(s_FaithService[E_FAITH_SERVICE_ACTOR]);
	}

	if (IsValidDynamic3DTextLabel(s_FaithService[E_FAITH_SERVICE_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_FaithService[E_FAITH_SERVICE_LABEL]);
	}

	s_FaithService[E_FAITH_SERVICE_RUNNING] = false;
	s_FaithService[E_FAITH_SERVICE_TIMER] = 0;
	s_FaithService[E_FAITH_SERVICE_KNEELING] = false;
	s_FaithService[E_FAITH_SERVICE_ACTOR] = INVALID_ACTOR_ID;
	s_FaithService[E_FAITH_SERVICE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    Faith_UpdateIdlePriest();
    pawn_call_public("Faith_OnServiceEnded","d",s_FaithService[E_FAITH_SERVICE_CHURCH]);
}

static Faith_Dismiss()
{
	new church = s_FaithService[E_FAITH_SERVICE_CHURCH];

	foreach (new playerid : Player)
	{
		if (!Faith_IsInChurch(playerid,church))
		{
			continue;
		}

		if ((s_FaithAttended[playerid] && s_FaithKnelt[playerid]) || playerid == s_FaithService[E_FAITH_SERVICE_LEADER])
		{
			Faith_Bless(playerid,s_FaithService[E_FAITH_SERVICE_LEADER] != INVALID_PLAYER_ID);
		}
		else
		{
			Gui_Notify(playerid,"You stayed to the end, but you missed part of the mass, so there's no blessing this time. Be inside by the end of the Kyrie and kneel at the elevation.");
		}
	}

	foreach (new playerid : Player)
	{
		s_FaithAttended[playerid] = false;
		s_FaithKnelt[playerid] = false;
	}

	Log_Info("faith","mass ended at %s",s_FaithChurches[church][E_FAITH_CHURCH_NAME]);
	Faith_EndService();
}

static Faith_NextPart()
{
	new church = s_FaithService[E_FAITH_SERVICE_CHURCH], part = s_FaithService[E_FAITH_SERVICE_PART];

	if (part >= 0 && !strcmp(s_FaithParts[part][E_FAITH_PART_KEY],"kyrie"))
	{
		foreach (new playerid : Player)
		{
			s_FaithAttended[playerid] = Faith_IsInChurch(playerid,church);
		}
	}

	do
	{
		part++;
	}
	while (part < sizeof(s_FaithParts) && Faith_PartIsSkipped(part));

	if (part >= sizeof(s_FaithParts))
	{
		Faith_Dismiss();
		return;
	}

	s_FaithService[E_FAITH_SERVICE_PART] = part;
	s_FaithService[E_FAITH_SERVICE_LINE] = 0;
	s_FaithService[E_FAITH_SERVICE_TEXT] = Faith_PartText(part);
    Faith_FaceServicePart();
	Faith_Act(s_FaithParts[part][E_FAITH_PART_ACTION]);

	if (!strcmp(s_FaithParts[part][E_FAITH_PART_KEY],FAITH_PART_ELEVATION))
	{
		s_FaithService[E_FAITH_SERVICE_KNEELING] = true;
		s_FaithService[E_FAITH_SERVICE_KNEEL_STEPS] = max(FAITH_KNEEL_MS / s_FaithService[E_FAITH_SERVICE_LINE_MS],1);
		if (s_FaithService[E_FAITH_SERVICE_LEADER] != INVALID_PLAYER_ID)
		{
			ApplyAnimation(s_FaithService[E_FAITH_SERVICE_LEADER],"PED","HANDSUP",4.1,false,false,false,true,0,SYNC_ALL);
		}
		else
		{
			ApplyActorAnimation(s_FaithService[E_FAITH_SERVICE_ACTOR],"PED","HANDSUP",4.1,false,false,false,true,0);
		}
		Faith_TellInside("The host is raised. Kneel now: press ~k~~CONVERSATION_YES~.");
	}
}

static Faith_SpeakLine()
{
	if (s_FaithService[E_FAITH_SERVICE_PART] >= 0 && !strcmp(s_FaithParts[s_FaithService[E_FAITH_SERVICE_PART]][E_FAITH_PART_KEY],FAITH_PART_BANNS))
	{
		new banns[FAITH_LINE_LEN + FAITH_NAME_LEN * 2];

		if (!Faith_GetBannsLine(s_FaithService[E_FAITH_SERVICE_LINE]++,banns))
		{
			Faith_NextPart();
			return;
		}

		Faith_Say(banns);
		return;
	}

	new text = s_FaithService[E_FAITH_SERVICE_TEXT], kind, season, count, bool:isBilingual, line[FAITH_LINE_LEN], english[FAITH_LINE_LEN];

	if (!Faith_GetTextInfo(text,kind,season,count,isBilingual))
	{
		Faith_NextPart();
		return;
	}

	new at = s_FaithService[E_FAITH_SERVICE_LINE];

	if (at >= count)
	{
		Faith_NextPart();
		return;
	}

	Faith_GetTextLine(text,at,line);

	if (isBilingual)
	{
		Faith_GetTextLine(text,at + 1,english);

		if (line[0] != EOS)
		{
			Faith_Say(line);
		}

		Faith_TellInside(english);
		s_FaithService[E_FAITH_SERVICE_LINE] = at + 2;
	}
	else
	{
		Faith_Say(line);
		s_FaithService[E_FAITH_SERVICE_LINE] = at + 1;
	}
}

static Faith_FindLeader(church)
{
	foreach (new playerid : Player)
	{
		if (Session_IsPlaying(playerid) && Clergy_CanLead(playerid) && IsPlayerInRangeOfPoint(playerid,FAITH_LEADER_RANGE,s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][0],s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][1],s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][2]))
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

static Faith_SpawnPriest(church)
{
	new Float:x = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][0], Float:y = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][1], Float:z = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][2];
	s_FaithService[E_FAITH_SERVICE_ACTOR] = CreateActor(FAITH_MASS_SKIN,x,y,z,s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][3]);

	if (IsValidActor(s_FaithService[E_FAITH_SERVICE_ACTOR]))
	{
		SetActorInvulnerable(s_FaithService[E_FAITH_SERVICE_ACTOR],true);
		ApplyActorAnimation(s_FaithService[E_FAITH_SERVICE_ACTOR],"PED","IDLE_CHAT",4.1,true,false,false,false,0);
	}
}

stock Faith_GetServiceActor()
{
    return Faith_IsServiceRunning() ? s_FaithService[E_FAITH_SERVICE_ACTOR] : INVALID_ACTOR_ID;
}

stock Faith_GetServiceLeader()
{
	return s_FaithService[E_FAITH_SERVICE_RUNNING] ? s_FaithService[E_FAITH_SERVICE_LEADER] : INVALID_PLAYER_ID;
}

stock bool:Faith_StartService(church = 0,lineMs = FAITH_LINE_MS,leaderid = INVALID_PLAYER_ID)
{
	if (s_FaithService[E_FAITH_SERVICE_RUNNING] || church < 0 || church >= sizeof(s_FaithChurches) || Faith_RiteChurch() == church)
	{
		return false;
	}

	if (leaderid == INVALID_PLAYER_ID || !Clergy_CanLead(leaderid))
	{
		leaderid = Faith_FindLeader(church);
	}

	s_FaithService[E_FAITH_SERVICE_LEADER] = leaderid;
	s_FaithService[E_FAITH_SERVICE_LEADER_TOKEN] = leaderid != INVALID_PLAYER_ID ? Account_GetToken(leaderid) : 0;
    if (leaderid != INVALID_PLAYER_ID)
    {
        s_FaithService[E_FAITH_SERVICE_LEADER_SKIN] = Faith_GetWornSkin(leaderid);
        s_FaithService[E_FAITH_SERVICE_LEADER_CHAR] = Character_GetId(leaderid);
        GetPlayerFacingAngle(leaderid,s_FaithService[E_FAITH_SERVICE_LEADER_ANGLE]);
        SetPlayerSkin(leaderid,FAITH_MASS_SKIN);
    }
    Faith_SuspendIdlePriest();
	Faith_LoadBanns(church);

	new season = Faith_GetLiturgicalSeason();
	s_FaithService[E_FAITH_SERVICE_RUNNING] = true;
	s_FaithService[E_FAITH_SERVICE_CHURCH] = church;
	s_FaithService[E_FAITH_SERVICE_PART] = -1;
	s_FaithService[E_FAITH_SERVICE_LINE] = 0;
	s_FaithService[E_FAITH_SERVICE_TEXT] = -1;
	s_FaithService[E_FAITH_SERVICE_LINE_MS] = max(lineMs,10);
	s_FaithService[E_FAITH_SERVICE_KNEELING] = false;
	s_FaithService[E_FAITH_SERVICE_READING] = Faith_PickText(FAITH_KIND_READING,season,s_FaithLastReading);
	s_FaithService[E_FAITH_SERVICE_HOMILY] = Faith_PickText(FAITH_KIND_HOMILY,season,s_FaithLastHomily);
	s_FaithLastReading = s_FaithService[E_FAITH_SERVICE_READING];
	s_FaithLastHomily = s_FaithService[E_FAITH_SERVICE_HOMILY];

	foreach (new playerid : Player)
	{
		s_FaithAttended[playerid] = false;
		s_FaithKnelt[playerid] = false;
	}

	new Float:x = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][0], Float:y = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][1], Float:z = s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][2];
	s_FaithService[E_FAITH_SERVICE_ACTOR] = INVALID_ACTOR_ID;

	if (leaderid == INVALID_PLAYER_ID)
	{
		Faith_SpawnPriest(church);
		s_FaithService[E_FAITH_SERVICE_LABEL] = CreateDynamic3DTextLabel(" ",FAITH_COLOUR_LABEL,x,y,z + FAITH_LABEL_Z,FAITH_LABEL_RANGE);
	}
	else
	{
		new leader[FAITH_NAME_LEN];
		Clergy_Address(leaderid,leader);
		s_FaithService[E_FAITH_SERVICE_LABEL] = CreateDynamic3DTextLabel(" ",FAITH_COLOUR_LABEL,0.0,0.0,FAITH_LABEL_Z - 0.6,FAITH_LABEL_RANGE,leaderid);
		Crier_Announce(CRIER_KIND_FAITH,"Mass at the monastery church",sprintf("%s is saying mass at %s now, and all are welcome.",leader,s_FaithChurches[church][E_FAITH_CHURCH_NAME]));
	}

	foreach (new playerid : Player)
	{
		if (IsPlayerInRangeOfPoint(playerid,STREAMER_3D_TEXT_LABEL_SD,x,y,z))
		{
			Streamer_Update(playerid,STREAMER_TYPE_3D_TEXT_LABEL);
		}
	}

	s_FaithService[E_FAITH_SERVICE_TIMER] = SetTimer("Faith_ServiceStep",s_FaithService[E_FAITH_SERVICE_LINE_MS],true);
	Log_Info("faith","mass begins at %s",s_FaithChurches[church][E_FAITH_CHURCH_NAME]);
    pawn_call_public("Faith_OnServiceStarted","d",church);
	Faith_NextPart();
	return true;
}

stock bool:Faith_StopService()
{
	if (!s_FaithService[E_FAITH_SERVICE_RUNNING])
	{
		return false;
	}

	foreach (new playerid : Player)
	{
		s_FaithAttended[playerid] = false;
		s_FaithKnelt[playerid] = false;
	}

	Faith_EndService();
	return true;
}

stock bool:Faith_Kneel(playerid)
{
	if (!Faith_IsKneelOpen() || s_FaithKnelt[playerid] || !Faith_IsInChurch(playerid,s_FaithService[E_FAITH_SERVICE_CHURCH]))
	{
		return false;
	}

	s_FaithKnelt[playerid] = true;
	ApplyAnimation(playerid,"CAMERA","CAMCRCH_IDLELOOP",4.1,true,false,false,true,0,SYNC_ALL);
	Gui_Notify(playerid,"You kneel as the host is raised.");
	return true;
}

stock Faith_LocalSeconds()
{
	new hour, minute, second;
	gettime(hour,minute,second);
	return hour * 3600 + minute * 60 + second;
}

stock Faith_SecondsToNextService()
{
	new now = Faith_LocalSeconds(), best = cellmax;

	for (new i = 0;i < sizeof(s_FaithServiceHours);i++)
	{
		new wait = (s_FaithServiceHours[i] * 3600 - now + 86400) % 86400;
		best = min(best,wait);
	}

	return best;
}

static Faith_CheckSchedule()
{
	if (s_FaithService[E_FAITH_SERVICE_RUNNING])
	{
		return;
	}

	new wait = Faith_SecondsToNextService(), church = 0;

	if (wait == 0)
	{
		Faith_StartService(church);
		return;
	}

	if (wait == FAITH_LEAD_IN_SECONDS)
	{
		new at = (Faith_LocalSeconds() + wait) % 86400;
		Crier_Announce(CRIER_KIND_FAITH,"Mass at the monastery church",sprintf("The bells ring for mass at %02d:%02d, Brussels time, at %s. All are welcome, and those who kneel at the elevation leave blessed.",at / 3600,(at % 3600) / 60,s_FaithChurches[church][E_FAITH_CHURCH_NAME]));
	}

	if (wait == FAITH_LEAD_IN_SECONDS || wait == FAITH_BELL_SECONDS || wait == FAITH_LAST_BELL_SECONDS)
	{
		Faith_Announce(sprintf("The bell of %s rings: mass begins in %d %s.",s_FaithChurches[church][E_FAITH_CHURCH_NAME],wait / 60,wait == 60 ? ("minute") : ("minutes")));
	}
}

forward Faith_OnServiceStarted(church);

public Faith_OnServiceStarted(church)
{
    #pragma unused church
    return 1;
}

forward Faith_OnServiceEnded(church);

public Faith_OnServiceEnded(church)
{
    #pragma unused church
    return 1;
}

forward Faith_ServiceStep();

public Faith_ServiceStep()
{
	if (!s_FaithService[E_FAITH_SERVICE_RUNNING])
	{
		return 1;
	}

	new leaderid = s_FaithService[E_FAITH_SERVICE_LEADER], church = s_FaithService[E_FAITH_SERVICE_CHURCH];

	if (leaderid != INVALID_PLAYER_ID && (!IsPlayerConnected(leaderid) || Account_GetToken(leaderid) != s_FaithService[E_FAITH_SERVICE_LEADER_TOKEN] || !Faith_IsInChurch(leaderid,church)))
	{
        Faith_RestoreLeader();
		s_FaithService[E_FAITH_SERVICE_LEADER] = INVALID_PLAYER_ID;

		if (IsValidDynamic3DTextLabel(s_FaithService[E_FAITH_SERVICE_LABEL]))
		{
			DestroyDynamic3DTextLabel(s_FaithService[E_FAITH_SERVICE_LABEL]);
		}

		Faith_SpawnPriest(church);
        Faith_FaceServicePart();
		s_FaithService[E_FAITH_SERVICE_LABEL] = CreateDynamic3DTextLabel(" ",FAITH_COLOUR_LABEL,s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][0],s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][1],s_FaithChurches[church][E_FAITH_CHURCH_PULPIT][2] + FAITH_LABEL_Z,FAITH_LABEL_RANGE);
		Faith_TellInside(sprintf("%s steps up to the altar and carries on the mass.",s_FaithChurches[church][E_FAITH_CHURCH_PRIEST]));
	}

	if (s_FaithService[E_FAITH_SERVICE_KNEELING])
	{
		if (--s_FaithService[E_FAITH_SERVICE_KNEEL_STEPS] > 0)
		{
			return 1;
		}

		s_FaithService[E_FAITH_SERVICE_KNEELING] = false;

		if (s_FaithService[E_FAITH_SERVICE_LEADER] != INVALID_PLAYER_ID)
		{
			ClearAnimations(s_FaithService[E_FAITH_SERVICE_LEADER],SYNC_ALL);
		}
		else
		{
			ApplyActorAnimation(s_FaithService[E_FAITH_SERVICE_ACTOR],"PED","IDLE_CHAT",4.1,true,false,false,false,0);
		}

		foreach (new playerid : Player)
		{
			if (s_FaithKnelt[playerid])
			{
				ClearAnimations(playerid,SYNC_ALL);
			}
		}

		Faith_NextPart();
		return 1;
	}

	Faith_SpeakLine();
	return 1;
}

forward Faith_ScheduleTick();

public Faith_ScheduleTick()
{
	Faith_CheckSchedule();
    Faith_UpdateIdlePriest();
	return 1;
}

forward bool:Faith_KneelContext(playerid);

public bool:Faith_KneelContext(playerid)
{
	return Faith_IsKneelOpen() && !s_FaithKnelt[playerid] && Faith_IsInChurch(playerid,s_FaithService[E_FAITH_SERVICE_CHURCH]);
}

CMD<ADMIN_LEVEL_TRIAL>:service(cmdid, playerid, params[])
{
	if (!strcmp(params,"start",true))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,Faith_StartService() ? ("Mass begins.") : ("A mass is already under way."));
		return 1;
	}

	if (!strcmp(params,"stop",true))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,Faith_StopService() ? ("Mass stopped.") : ("No mass is under way."));
		return 1;
	}

	if (!isnull(params))
	{
		Command_Usage(playerid,cmdid,"[start|stop]");
		return 1;
	}

	if (Faith_IsServiceRunning())
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("Mass is under way (part %d of %d).",Faith_GetServicePart() + 1,sizeof(s_FaithParts)));
	}
	else
	{
		new wait = Faith_SecondsToNextService();
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("The next mass begins in %dh %02dm (%02d:%02d Brussels time).",wait / 3600,(wait % 3600) / 60,((Faith_LocalSeconds() + wait) % 86400) / 3600,((Faith_LocalSeconds() + wait) % 3600) / 60));
	}

	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
    AnimPreload_Register("CAMERA");
    AnimPreload_Register("COP_AMBIENT");
    AnimPreload_Register("BOMBER");
    Faith_UpdateIdlePriest();

	for (new church = 0;church < sizeof(s_FaithChurches);church++)
	{
		Weather_AddShelter(s_FaithChurches[church][E_FAITH_CHURCH_MIN][0],s_FaithChurches[church][E_FAITH_CHURCH_MIN][1],s_FaithChurches[church][E_FAITH_CHURCH_MIN][2],s_FaithChurches[church][E_FAITH_CHURCH_MAX][0],s_FaithChurches[church][E_FAITH_CHURCH_MAX][1],s_FaithChurches[church][E_FAITH_CHURCH_MAX][2]);
	}

	s_FaithService[E_FAITH_SERVICE_ACTOR] = INVALID_ACTOR_ID;
	s_FaithService[E_FAITH_SERVICE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_FaithAttended[playerid] = false;
	s_FaithKnelt[playerid] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_SCENE))
	{
		Faith_Kneel(playerid);
	}
}
