#define FAITH_RITE_LINES (24)
#define FAITH_RITE_TEXT_LEN (128)
#define FAITH_RITE_PROMPT_LEN (112)
#define FAITH_RITE_LINE_MS (5000)
#define FAITH_RITE_STRAY (4.0)
#define FAITH_RITE_OFFICIANT_RANGE (4.0)
#define FAITH_RITE_OFFICIANT_STRAY (8.0)
#define FAITH_RITE_LINGER_MS (6000)
#define FAITH_RITE_NAME_LEN (CHARACTER_NAME_MAX * 2 + 2)

enum
{
	FAITH_RITE_NONE,
	FAITH_RITE_WEDDING,
	FAITH_RITE_BAPTISM,
	FAITH_RITE_LAST_RITES,
}

enum
{
	FAITH_SAY_PRIEST_ME,
	FAITH_SAY_PRIEST,
	FAITH_SAY_OTHER,
	FAITH_SAY_PLAYER,
}

enum E_FAITH_RITE_LINE
{
	E_FAITH_RITE_LINE_SPEAKER,
	E_FAITH_RITE_LINE_TEXT[FAITH_RITE_TEXT_LEN],
	E_FAITH_RITE_LINE_ENGLISH[FAITH_RITE_TEXT_LEN],
	E_FAITH_RITE_LINE_PROMPT[FAITH_RITE_PROMPT_LEN],
}

enum E_FAITH_RITE
{
	E_FAITH_RITE_KIND,
	E_FAITH_RITE_CHURCH,
	E_FAITH_RITE_PLAYER,
	E_FAITH_RITE_TOKEN,
	E_FAITH_RITE_AT,
	E_FAITH_RITE_COUNT,
	E_FAITH_RITE_TIMER,
	E_FAITH_RITE_LINE_MS,
	bool:E_FAITH_RITE_WAITING,
	E_FAITH_RITE_OFFICIANT,
	E_FAITH_RITE_OFFICIANT_TOKEN,
	E_FAITH_RITE_PRIEST_ACTOR,
	E_FAITH_RITE_OTHER_ACTOR,
	E_FAITH_RITE_INFOBOX,
	Float:E_FAITH_RITE_PRIEST_POS[4],
	E_FAITH_RITE_OTHER_NAME[FAITH_RITE_NAME_LEN],
	E_FAITH_RITE_TITLE[32],
}

static s_FaithRite[E_FAITH_RITE];
static s_FaithRiteLines[FAITH_RITE_LINES][E_FAITH_RITE_LINE];

stock Faith_GivenName(playerid,dest[],size = sizeof(dest))
{
	Character_GetName(playerid,dest,size);

	new space = strfind(dest," ");

	if (space > 0)
	{
		dest[space] = EOS;
	}
}

stock Faith_RiteKind()
{
	return s_FaithRite[E_FAITH_RITE_KIND];
}

stock Faith_RiteChurch()
{
	return s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE ? s_FaithRite[E_FAITH_RITE_CHURCH] : -1;
}

stock Faith_RitePlayer()
{
	return s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE ? s_FaithRite[E_FAITH_RITE_PLAYER] : INVALID_PLAYER_ID;
}

stock bool:Faith_IsRiteRunning()
{
	return s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE;
}

stock bool:Faith_IsRiteWaiting(playerid)
{
	return s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE && s_FaithRite[E_FAITH_RITE_PLAYER] == playerid && s_FaithRite[E_FAITH_RITE_WAITING];
}

stock Faith_RiteOfficiant()
{
	return s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE ? s_FaithRite[E_FAITH_RITE_OFFICIANT] : INVALID_PLAYER_ID;
}

stock Faith_FindOfficiant(Float:x,Float:y,Float:z,excludeid,bool:mustLead)
{
	foreach (new i : Player)
	{
		if (i == excludeid || !Session_IsPlaying(i) || !IsPlayerInRangeOfPoint(i,FAITH_RITE_OFFICIANT_RANGE,x,y,z))
		{
			continue;
		}

		if (mustLead ? Clergy_CanLead(i) : Clergy_CanBaptise(i))
		{
			return i;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Faith_RitePriestName(dest[],size = sizeof(dest))
{
	if (s_FaithRite[E_FAITH_RITE_OFFICIANT] != INVALID_PLAYER_ID)
	{
		Clergy_Address(s_FaithRite[E_FAITH_RITE_OFFICIANT],dest,size);
		return;
	}

	Faith_GetPriestName(s_FaithRite[E_FAITH_RITE_CHURCH],dest,size);
}

stock bool:Faith_RiteBegin(kind,playerid,church,Float:x,Float:y,Float:z,Float:a,const title[],bool:mustLead,lineMs = FAITH_RITE_LINE_MS)
{
	if (s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE || Faith_IsServiceRunning() || !Session_IsPlaying(playerid))
	{
		return false;
	}

    Faith_SuspendIdlePriest();
	s_FaithRite[E_FAITH_RITE_KIND] = kind;
	s_FaithRite[E_FAITH_RITE_CHURCH] = church;
	s_FaithRite[E_FAITH_RITE_PLAYER] = playerid;
	s_FaithRite[E_FAITH_RITE_TOKEN] = Account_GetToken(playerid);
	s_FaithRite[E_FAITH_RITE_AT] = 0;
	s_FaithRite[E_FAITH_RITE_COUNT] = 0;
	s_FaithRite[E_FAITH_RITE_TIMER] = 0;
	s_FaithRite[E_FAITH_RITE_LINE_MS] = max(lineMs,10);
	s_FaithRite[E_FAITH_RITE_WAITING] = false;
	s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR] = INVALID_ACTOR_ID;
	s_FaithRite[E_FAITH_RITE_OTHER_ACTOR] = INVALID_ACTOR_ID;
	s_FaithRite[E_FAITH_RITE_INFOBOX] = 0;
	s_FaithRite[E_FAITH_RITE_PRIEST_POS][0] = x;
	s_FaithRite[E_FAITH_RITE_PRIEST_POS][1] = y;
	s_FaithRite[E_FAITH_RITE_PRIEST_POS][2] = z;
	s_FaithRite[E_FAITH_RITE_PRIEST_POS][3] = a;
	s_FaithRite[E_FAITH_RITE_OTHER_NAME][0] = EOS;
	strcopy(s_FaithRite[E_FAITH_RITE_TITLE],title,32);
	s_FaithRite[E_FAITH_RITE_OFFICIANT] = Faith_FindOfficiant(x,y,z,playerid,mustLead);
	s_FaithRite[E_FAITH_RITE_OFFICIANT_TOKEN] = s_FaithRite[E_FAITH_RITE_OFFICIANT] != INVALID_PLAYER_ID ? Account_GetToken(s_FaithRite[E_FAITH_RITE_OFFICIANT]) : 0;
	return true;
}

stock Faith_RiteAdd(speaker,const text[],const english[] = "",const prompt[] = "")
{
	new at = s_FaithRite[E_FAITH_RITE_COUNT];

	if (at >= FAITH_RITE_LINES)
	{
		return;
	}

	s_FaithRiteLines[at][E_FAITH_RITE_LINE_SPEAKER] = speaker;
	strcopy(s_FaithRiteLines[at][E_FAITH_RITE_LINE_TEXT],text,FAITH_RITE_TEXT_LEN);
	strcopy(s_FaithRiteLines[at][E_FAITH_RITE_LINE_ENGLISH],english,FAITH_RITE_TEXT_LEN);
	strcopy(s_FaithRiteLines[at][E_FAITH_RITE_LINE_PROMPT],prompt,FAITH_RITE_PROMPT_LEN);
	s_FaithRite[E_FAITH_RITE_COUNT]++;
}

stock Faith_RiteOther(skin,Float:x,Float:y,Float:z,Float:a,const name[])
{
	strcopy(s_FaithRite[E_FAITH_RITE_OTHER_NAME],name,FAITH_RITE_NAME_LEN);
	s_FaithRite[E_FAITH_RITE_OTHER_ACTOR] = CreateActor(skin,x,y,z,a);

	if (IsValidActor(s_FaithRite[E_FAITH_RITE_OTHER_ACTOR]))
	{
        if (s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_BAPTISM)
        {
            Actors_RegisterBody("faith:participant",s_FaithRite[E_FAITH_RITE_OTHER_ACTOR],0,name,"Wedding guest");
        }

		SetActorInvulnerable(s_FaithRite[E_FAITH_RITE_OTHER_ACTOR],true);
	}
}

static Faith_RiteSpawnPriest()
{
	if (IsValidActor(s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR]))
	{
		return;
	}

	s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR] = CreateActor(FAITH_PRIEST_SKIN,s_FaithRite[E_FAITH_RITE_PRIEST_POS][0],s_FaithRite[E_FAITH_RITE_PRIEST_POS][1],s_FaithRite[E_FAITH_RITE_PRIEST_POS][2],s_FaithRite[E_FAITH_RITE_PRIEST_POS][3]);

	if (IsValidActor(s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR]))
	{
        Actors_RegisterBody("faith:rite",s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR],0,"Father Anselm","Priest",-1,0,"priest");
		SetActorInvulnerable(s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR],true);
		ApplyActorAnimation(s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR],"PED","IDLE_CHAT",4.1,true,false,false,false,0);
	}
}

stock Faith_RiteStart()
{
	if (s_FaithRite[E_FAITH_RITE_OFFICIANT] == INVALID_PLAYER_ID)
	{
		Faith_RiteSpawnPriest();
	}

	s_FaithRite[E_FAITH_RITE_TIMER] = SetTimer("Faith_RiteStep",s_FaithRite[E_FAITH_RITE_LINE_MS],true);
	Faith_RiteAdvance();
}

static Faith_RiteSay(speaker,const text[],const english[])
{
	new out[FAITH_RITE_TEXT_LEN + FAITH_RITE_NAME_LEN + 16], priest[FAITH_RITE_NAME_LEN], officiant = s_FaithRite[E_FAITH_RITE_OFFICIANT], Float:x = s_FaithRite[E_FAITH_RITE_PRIEST_POS][0], Float:y = s_FaithRite[E_FAITH_RITE_PRIEST_POS][1], Float:z = s_FaithRite[E_FAITH_RITE_PRIEST_POS][2];

	switch (speaker)
	{
		case FAITH_SAY_PRIEST_ME:
		{
			if (officiant != INVALID_PLAYER_ID)
			{
				Chat_Speak(officiant,CHAT_ME,text);
			}
			else
			{
				Faith_RitePriestName(priest);
				format(out,sizeof(out),"* %s %s",priest,text);
				Chat_FromPoint(x,y,z,0,0,FAITH_ACTION_RANGE,CHAT_COLOUR_ACTION,out);
			}
		}
		case FAITH_SAY_PRIEST:
		{
			if (officiant != INVALID_PLAYER_ID)
			{
				Chat_Speak(officiant,CHAT_SAY,text);
			}
			else
			{
				Faith_RitePriestName(priest);
				format(out,sizeof(out),"%s says: %s",priest,text);
				Chat_FromPoint(x,y,z,0,0,FAITH_PRIEST_RANGE,CHAT_COLOUR_SAY,out);
			}
		}
		case FAITH_SAY_OTHER:
		{
			new Float:ox = x, Float:oy = y, Float:oz = z;

			if (IsValidActor(s_FaithRite[E_FAITH_RITE_OTHER_ACTOR]))
			{
				GetActorPos(s_FaithRite[E_FAITH_RITE_OTHER_ACTOR],ox,oy,oz);
			}

			format(out,sizeof(out),"%s says: %s",s_FaithRite[E_FAITH_RITE_OTHER_NAME],text);
			Chat_FromPoint(ox,oy,oz,0,0,CHAT_RANGE_SAY,CHAT_COLOUR_SAY,out);
		}
		default:
		{
			Chat_Speak(s_FaithRite[E_FAITH_RITE_PLAYER],CHAT_SAY,text);
		}
	}

	if (english[0] != EOS)
	{
		foreach (new i : Player)
		{
			if (Faith_IsInChurch(i,s_FaithRite[E_FAITH_RITE_CHURCH]) || (i == s_FaithRite[E_FAITH_RITE_PLAYER] || (Session_IsPlaying(i) && GetPlayerVirtualWorld(i) == 0 && IsPlayerInRangeOfPoint(i,CHAT_RANGE_SAY,x,y,z))))
			{
				Gui_Notify(i,english);
			}
		}
	}
}

static Faith_RiteClean()
{
	if (s_FaithRite[E_FAITH_RITE_TIMER] != 0)
	{
		KillTimer(s_FaithRite[E_FAITH_RITE_TIMER]);
	}

	new playerid = s_FaithRite[E_FAITH_RITE_PLAYER];

	if (IsPlayerConnected(playerid) && s_FaithRite[E_FAITH_RITE_INFOBOX] != 0)
	{
		Infobox_Hide(playerid,s_FaithRite[E_FAITH_RITE_INFOBOX]);
	}

    Faith_SuspendIdlePriest((FAITH_RITE_LINGER_MS + 999) / 1000);
	SetTimerEx("Faith_RiteActorsLeave",FAITH_RITE_LINGER_MS,false,"dd",s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR],s_FaithRite[E_FAITH_RITE_OTHER_ACTOR]);
	s_FaithRite[E_FAITH_RITE_KIND] = FAITH_RITE_NONE;
	s_FaithRite[E_FAITH_RITE_TIMER] = 0;
	s_FaithRite[E_FAITH_RITE_WAITING] = false;
	s_FaithRite[E_FAITH_RITE_PLAYER] = INVALID_PLAYER_ID;
	s_FaithRite[E_FAITH_RITE_OFFICIANT] = INVALID_PLAYER_ID;
	s_FaithRite[E_FAITH_RITE_PRIEST_ACTOR] = INVALID_ACTOR_ID;
	s_FaithRite[E_FAITH_RITE_OTHER_ACTOR] = INVALID_ACTOR_ID;
	s_FaithRite[E_FAITH_RITE_INFOBOX] = 0;
}

stock bool:Faith_CancelRite(const reason[] = "")
{
	if (s_FaithRite[E_FAITH_RITE_KIND] == FAITH_RITE_NONE)
	{
		return false;
	}

	new playerid = s_FaithRite[E_FAITH_RITE_PLAYER];
	Faith_RiteClean();

	if (IsPlayerConnected(playerid) && reason[0] != EOS)
	{
		Gui_Notify(playerid,reason);
	}

	return true;
}

static Faith_RiteFinish()
{
	new kind = s_FaithRite[E_FAITH_RITE_KIND], playerid = s_FaithRite[E_FAITH_RITE_PLAYER], church = s_FaithRite[E_FAITH_RITE_CHURCH], priest[FAITH_RITE_NAME_LEN];
	Faith_RitePriestName(priest);
	Faith_RiteClean();

	switch (kind)
	{
		case FAITH_RITE_WEDDING: Faith_OnWeddingDone(playerid,church,priest);
		case FAITH_RITE_BAPTISM: Faith_OnBaptismDone(playerid,church,priest);
		case FAITH_RITE_LAST_RITES: Infirmary_OnLastRitesDone(playerid,priest);
	}
}

static Faith_RiteAdvance()
{
	new at = s_FaithRite[E_FAITH_RITE_AT];

	if (at >= s_FaithRite[E_FAITH_RITE_COUNT])
	{
		Faith_RiteFinish();
		return;
	}

	if (s_FaithRiteLines[at][E_FAITH_RITE_LINE_PROMPT][0] != EOS && !s_FaithRite[E_FAITH_RITE_WAITING])
	{
		s_FaithRite[E_FAITH_RITE_WAITING] = true;
		s_FaithRite[E_FAITH_RITE_INFOBOX] = Infobox_Show(s_FaithRite[E_FAITH_RITE_PLAYER],s_FaithRite[E_FAITH_RITE_TITLE],s_FaithRiteLines[at][E_FAITH_RITE_LINE_PROMPT],2);
		return;
	}

	Faith_RiteSay(s_FaithRiteLines[at][E_FAITH_RITE_LINE_SPEAKER],s_FaithRiteLines[at][E_FAITH_RITE_LINE_TEXT],s_FaithRiteLines[at][E_FAITH_RITE_LINE_ENGLISH]);
	s_FaithRite[E_FAITH_RITE_AT]++;
}

stock bool:Faith_RiteAnswer(playerid)
{
	if (!Faith_IsRiteWaiting(playerid))
	{
		return false;
	}

	if (s_FaithRite[E_FAITH_RITE_INFOBOX] != 0)
	{
		Infobox_Hide(playerid,s_FaithRite[E_FAITH_RITE_INFOBOX]);
		s_FaithRite[E_FAITH_RITE_INFOBOX] = 0;
	}

	s_FaithRite[E_FAITH_RITE_WAITING] = false;
	new at = s_FaithRite[E_FAITH_RITE_AT];
	s_FaithRiteLines[at][E_FAITH_RITE_LINE_PROMPT][0] = EOS;
	Faith_RiteSay(s_FaithRiteLines[at][E_FAITH_RITE_LINE_SPEAKER],s_FaithRiteLines[at][E_FAITH_RITE_LINE_TEXT],s_FaithRiteLines[at][E_FAITH_RITE_LINE_ENGLISH]);
	s_FaithRite[E_FAITH_RITE_AT]++;

	while (s_FaithRite[E_FAITH_RITE_AT] < s_FaithRite[E_FAITH_RITE_COUNT] && s_FaithRiteLines[s_FaithRite[E_FAITH_RITE_AT]][E_FAITH_RITE_LINE_SPEAKER] == FAITH_SAY_PLAYER && s_FaithRiteLines[s_FaithRite[E_FAITH_RITE_AT]][E_FAITH_RITE_LINE_PROMPT][0] == EOS)
	{
		new next = s_FaithRite[E_FAITH_RITE_AT];
		Faith_RiteSay(FAITH_SAY_PLAYER,s_FaithRiteLines[next][E_FAITH_RITE_LINE_TEXT],s_FaithRiteLines[next][E_FAITH_RITE_LINE_ENGLISH]);
		s_FaithRite[E_FAITH_RITE_AT]++;
	}

	return true;
}

forward Faith_RiteStep();

public Faith_RiteStep()
{
	if (s_FaithRite[E_FAITH_RITE_KIND] == FAITH_RITE_NONE)
	{
		return 1;
	}

	new playerid = s_FaithRite[E_FAITH_RITE_PLAYER], officiant = s_FaithRite[E_FAITH_RITE_OFFICIANT], Float:x = s_FaithRite[E_FAITH_RITE_PRIEST_POS][0], Float:y = s_FaithRite[E_FAITH_RITE_PRIEST_POS][1], Float:z = s_FaithRite[E_FAITH_RITE_PRIEST_POS][2];

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != s_FaithRite[E_FAITH_RITE_TOKEN] || !Session_IsPlaying(playerid))
	{
		Faith_CancelRite();
		return 1;
	}

	if (!IsPlayerInRangeOfPoint(playerid,FAITH_RITE_STRAY,x,y,z))
	{
		Faith_CancelRite("You walked away, so the rite stops. Come back when you're ready.");
		return 1;
	}

	if (officiant != INVALID_PLAYER_ID && (!IsPlayerConnected(officiant) || Account_GetToken(officiant) != s_FaithRite[E_FAITH_RITE_OFFICIANT_TOKEN] || !IsPlayerInRangeOfPoint(officiant,FAITH_RITE_OFFICIANT_STRAY,x,y,z)))
	{
		s_FaithRite[E_FAITH_RITE_OFFICIANT] = INVALID_PLAYER_ID;
		Faith_RiteSpawnPriest();
	}

	if (!s_FaithRite[E_FAITH_RITE_WAITING])
	{
		Faith_RiteAdvance();
	}

	return 1;
}

forward Faith_RiteActorsLeave(priest,other);

public Faith_RiteActorsLeave(priest,other)
{
	if (IsValidActor(priest))
	{
        Actors_UnregisterBody(priest);
		DestroyActor(priest);
	}

	if (IsValidActor(other))
	{
        Actors_UnregisterBody(other);
		DestroyActor(other);
	}

	return 1;
}

forward bool:Faith_RiteContext(playerid);

public bool:Faith_RiteContext(playerid)
{
	return Faith_IsRiteWaiting(playerid);
}

#include <pp-hooks>

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE && s_FaithRite[E_FAITH_RITE_PLAYER] == playerid)
	{
		Faith_CancelRite();
	}
}

hook Character_OnUnloaded(playerid)
{
	if (s_FaithRite[E_FAITH_RITE_KIND] != FAITH_RITE_NONE && s_FaithRite[E_FAITH_RITE_PLAYER] == playerid)
	{
		Faith_CancelRite();
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && Faith_IsRiteWaiting(playerid))
	{
		Faith_RiteAnswer(playerid);
	}
}
