enum E_EMOTE_PAIR
{
	E_EP_KIND,
	E_EP_PARTNER,
	E_EP_ASKED_BY,
	E_EP_ASK_KIND,
	E_EP_ASK_AT,
	bool:E_EP_ACTIVE,
	bool:E_EP_LEADER,
	E_EP_TIMER,
    E_EP_STARTED_AT,
}

static s_EmotePair[MAX_PLAYERS][E_EMOTE_PAIR];

forward bool:Emotes_Accept(playerid);

stock Emotes_GetPartner(playerid)
{
	return Util_IsValidPlayer(playerid) && s_EmotePair[playerid][E_EP_ACTIVE] ? s_EmotePair[playerid][E_EP_PARTNER] : INVALID_PLAYER_ID;
}

stock Emotes_GetPairKind(playerid)
{
	return Util_IsValidPlayer(playerid) && s_EmotePair[playerid][E_EP_ACTIVE] ? s_EmotePair[playerid][E_EP_KIND] : -1;
}

stock Emotes_GetAskedBy(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_EmotePair[playerid][E_EP_ASKED_BY] == INVALID_PLAYER_ID || gettime() - s_EmotePair[playerid][E_EP_ASK_AT] > EMOTE_REQUEST_SECONDS)
	{
		return INVALID_PLAYER_ID;
	}

	return s_EmotePair[playerid][E_EP_ASKED_BY];
}

static Emotes_NearestOther(playerid,list[],max)
{
	new count = 0, Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new other : Player)
	{
		if (other != playerid && count < max && !IsPlayerNPC(other) && Session_IsPlaying(other) && GetPlayerVirtualWorld(other) == GetPlayerVirtualWorld(playerid) && IsPlayerInRangeOfPoint(other,EMOTE_PAIR_RANGE + 1.5,x,y,z))
		{
			list[count++] = other;
		}
	}

	return count;
}

stock Emotes_GetPairCommand(kind,dest[],size = sizeof(dest))
{
    dest[0] = EOS;

    if (kind >= 0 && kind < EMOTE_PAIR_COUNT)
    {
        strcopy(dest,g_EmotePairDefs[kind][E_EP_COMMAND],size);
    }
}

stock Emotes_GetPairVariant(kind)
{
    return kind >= 0 && kind < EMOTE_PAIR_COUNT ? g_EmotePairDefs[kind][E_EP_VARIANT] : -1;
}

stock Emotes_GetPairLabel(kind,dest[],size = sizeof(dest))
{
    dest[0] = EOS;

    if (kind >= 0 && kind < EMOTE_PAIR_COUNT)
    {
        if (Emotes_GetCommandEntries(g_EmotePairDefs[kind][E_EP_COMMAND]) > 1)
        {
            format(dest,size,"%s (/%s %d)",g_EmotePairDefs[kind][E_EP_NAME],g_EmotePairDefs[kind][E_EP_COMMAND],g_EmotePairDefs[kind][E_EP_VARIANT]);
        }
        else
        {
            format(dest,size,"%s (/%s)",g_EmotePairDefs[kind][E_EP_NAME],g_EmotePairDefs[kind][E_EP_COMMAND]);
        }
    }
}

stock Emotes_FindFacingPlayer(playerid)
{
    if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid))
    {
        return INVALID_PLAYER_ID;
    }

    new targetid = INVALID_PLAYER_ID, Float:nearest = EMOTE_PAIR_RANGE, Float:x, Float:y, Float:z, Float:angle;
    GetPlayerPos(playerid,x,y,z);
    GetPlayerFacingAngle(playerid,angle);

    foreach (new other : Player)
    {
        if (other == playerid || IsPlayerNPC(other) || !Session_IsPlaying(other) || GetPlayerVirtualWorld(other) != GetPlayerVirtualWorld(playerid) || GetPlayerInterior(other) != GetPlayerInterior(playerid))
        {
            continue;
        }

        new Float:distance = GetPlayerDistanceFromPoint(other,x,y,z), Float:otherX, Float:otherY, Float:otherZ;
        GetPlayerPos(other,otherX,otherY,otherZ);
        new Float:difference = Util_NormalizeAngle(Util_GetAngleToPoint(x,y,otherX,otherY) - angle);

        if (distance <= nearest && (difference <= 45.0 || difference >= 315.0))
        {
            nearest = distance;
            targetid = other;
        }
    }

    return targetid;
}

stock bool:Emotes_CanPrivate(playerid,targetid)
{
    if (!Util_IsValidPlayer(playerid) || !Util_IsValidPlayer(targetid) || playerid == targetid || !Session_IsPlaying(playerid) || !Session_IsPlaying(targetid))
    {
        return false;
    }

    new sex = Character_GetSex(playerid), targetSex = Character_GetSex(targetid);
    return (sex == 0 && targetSex == 1) || (sex == 1 && targetSex == 0);
}

stock bool:Emotes_Ask(playerid,targetid,kind)
{
	if (kind < 0 || kind >= EMOTE_PAIR_COUNT || !Util_IsValidPlayer(playerid) || !Util_IsValidPlayer(targetid) || targetid == playerid || s_EmotePair[playerid][E_EP_ACTIVE] || s_EmotePair[targetid][E_EP_ACTIVE])
	{
		return false;
	}

    if (kind == EMOTE_PAIR_PRIVATE && !Emotes_CanPrivate(playerid,targetid))
    {
        Gui_Notify(playerid,"A private moment is only available between a man and a woman.");
        return false;
    }

	if (kind == EMOTE_PAIR_CARRY && !Combat_IsStruckDown(targetid) && !Law_IsBound(targetid))
	{
		Gui_Notify(playerid,"You can only carry someone who's down or bound.");
		return false;
	}

	s_EmotePair[targetid][E_EP_ASKED_BY] = playerid;
	s_EmotePair[targetid][E_EP_ASK_KIND] = kind;
	s_EmotePair[targetid][E_EP_ASK_AT] = gettime();
	new name[NAMETAG_LEN];
	Nametag_GetKnownName(targetid,playerid,name);

	if (kind == EMOTE_PAIR_CARRY && (Combat_IsStruckDown(targetid) || Law_IsBound(targetid)))
	{
		return Emotes_Accept(targetid);
	}

	Gui_Notify(targetid,sprintf("%s %s. Press ~y~Walk + N~w~ to answer.",name,g_EmotePairDefs[kind][E_EP_ASK]));
	Gui_Notify(playerid,"You wait for their answer.");
	return true;
}

static Emotes_Face(playerid,targetid,Float:gap)
{
	new Float:x, Float:y, Float:z, Float:tx, Float:ty, Float:tz, Float:a;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerPos(targetid,tx,ty,tz);

	if (floatabs(tx - x) + floatabs(ty - y) > 0.05)
	{
		a = atan2(ty - y,tx - x) - 90.0;
	}
	else
	{
		GetPlayerFacingAngle(playerid,a);
	}

	a = Util_NormalizeAngle(a);
	SetPlayerFacingAngle(playerid,a);
	SetPlayerPos(targetid,x + floatsin(-a,degrees) * gap,y + floatcos(-a,degrees) * gap,z + EMOTE_PAIR_DROP);
	SetPlayerFacingAngle(targetid,Util_NormalizeAngle(a + 180.0));
}

stock bool:Emotes_Accept(playerid)
{
	new asker = Emotes_GetAskedBy(playerid), kind = s_EmotePair[playerid][E_EP_ASK_KIND];
	s_EmotePair[playerid][E_EP_ASKED_BY] = INVALID_PLAYER_ID;

	if (asker == INVALID_PLAYER_ID || !IsPlayerConnected(asker) || s_EmotePair[asker][E_EP_ACTIVE] || s_EmotePair[playerid][E_EP_ACTIVE])
	{
		return false;
	}

    if (kind == EMOTE_PAIR_PRIVATE && !Emotes_CanPrivate(asker,playerid))
    {
        Gui_Notify(playerid,"A private moment is only available between a man and a woman.");
        return false;
    }

	new Float:x, Float:y, Float:z;
	GetPlayerPos(asker,x,y,z);

	if (!IsPlayerInRangeOfPoint(playerid,EMOTE_PAIR_RANGE + 2.0,x,y,z) || (kind == EMOTE_PAIR_PRIVATE && (GetPlayerVirtualWorld(asker) != GetPlayerVirtualWorld(playerid) || GetPlayerInterior(asker) != GetPlayerInterior(playerid))))
	{
		Gui_Notify(playerid,"They've moved away.");
		return false;
	}

	Emotes_Stop(asker);
	Emotes_Stop(playerid);
	s_EmotePair[asker][E_EP_ACTIVE] = true;
	s_EmotePair[asker][E_EP_PARTNER] = playerid;
	s_EmotePair[asker][E_EP_KIND] = kind;
	s_EmotePair[asker][E_EP_LEADER] = true;
	s_EmotePair[playerid][E_EP_ACTIVE] = true;
	s_EmotePair[playerid][E_EP_PARTNER] = asker;
	s_EmotePair[playerid][E_EP_KIND] = kind;
	s_EmotePair[playerid][E_EP_LEADER] = false;
    s_EmotePair[asker][E_EP_STARTED_AT] = GetTickCount();
    s_EmotePair[playerid][E_EP_STARTED_AT] = s_EmotePair[asker][E_EP_STARTED_AT];

	switch (kind)
	{
		case EMOTE_PAIR_PRIVATE:
		{
			ScreenFade_Set(asker,0x000000FF);
			ScreenFade_Set(playerid,0x000000FF);
			Chat_Speak(asker,CHAT_ME,"steps away with them for a private moment.");
		}
		case EMOTE_PAIR_SUPPORT, EMOTE_PAIR_CARRY:
		{
			Emotes_Face(asker,playerid,0.8);
			ApplyAnimation(playerid,g_EmotePairDefs[kind][E_EP_LIB_B],g_EmotePairDefs[kind][E_EP_ANIM_B],4.1,true,false,false,false,0,SYNC_ALL);

			if (kind == EMOTE_PAIR_CARRY)
			{
				TogglePlayerControllable(playerid,false);
				ApplyAnimation(asker,"CARRY","crry_prtial",4.1,false,true,true,true,1,SYNC_ALL);
			}
		}
		default:
		{
			Emotes_Face(asker,playerid,0.9);
			SetTimerEx("Emotes_PairStart",EMOTE_PAIR_FACE_MS,false,"ddd",asker,playerid,kind);
		}
	}

	if (g_EmotePairDefs[kind][E_EP_MS] > 0)
	{
		s_EmotePair[asker][E_EP_TIMER] = SetTimerEx("Emotes_PairDone",g_EmotePairDefs[kind][E_EP_MS] + (kind == EMOTE_PAIR_PRIVATE ? 0 : EMOTE_PAIR_FACE_MS),false,"dd",asker,playerid);
	}

	pawn_call_public("Emotes_OnPair","ddd",asker,playerid,kind);
	return true;
}

stock Emotes_Decline(playerid)
{
	new asker = Emotes_GetAskedBy(playerid);
	s_EmotePair[playerid][E_EP_ASKED_BY] = INVALID_PLAYER_ID;

	if (asker != INVALID_PLAYER_ID && IsPlayerConnected(asker))
	{
		Gui_Notify(asker,"They decline.");
	}
}

stock Emotes_EndPair(playerid)
{
	if (playerid < 0 || playerid >= MAX_PLAYERS)
	{
		return;
	}

    if (!s_EmotePair[playerid][E_EP_ACTIVE])
    {
        return;
    }

	new partner = s_EmotePair[playerid][E_EP_PARTNER], kind = s_EmotePair[playerid][E_EP_KIND];

	if (s_EmotePair[playerid][E_EP_TIMER] != 0)
	{
		KillTimer(s_EmotePair[playerid][E_EP_TIMER]);
	}

	s_EmotePair[playerid][E_EP_ACTIVE] = false;
	s_EmotePair[playerid][E_EP_TIMER] = 0;
    s_EmotePair[playerid][E_EP_PARTNER] = INVALID_PLAYER_ID;
    if (IsPlayerConnected(playerid))
    {
        ClearAnimations(playerid,SYNC_ALL);
    }

	if (kind == EMOTE_PAIR_PRIVATE)
	{
		ScreenFade_Set(playerid,SCREENFADE_CLEAR);
	}

	if (kind == EMOTE_PAIR_CARRY && IsPlayerConnected(playerid))
	{
		TogglePlayerControllable(playerid,true);
	}

	if (partner >= 0 && partner < MAX_PLAYERS && s_EmotePair[partner][E_EP_ACTIVE] && s_EmotePair[partner][E_EP_PARTNER] == playerid)
	{
		Emotes_EndPair(partner);
	}
}

stock Emotes_OpenPairs(playerid)
{
	new list[8], count = Emotes_NearestOther(playerid,list,sizeof(list));

	if (count == 0)
	{
		Gui_Notify(playerid,"Stand close to the person first.");
		return;
	}

    new bool:privateAvailable = false;
    for (new i = 0;i < count;i++)
    {
        if (Emotes_CanPrivate(playerid,list[i]))
        {
            privateAvailable = true;
            break;
        }
    }

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
    new rows = EMOTE_PAIR_COUNT - (privateAvailable ? 0 : 1), row = 0;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"With someone else");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,280.0,float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"With someone else",x,y,width);

	for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
	{
        if (kind == EMOTE_PAIR_PRIVATE && !privateAvailable)
        {
            continue;
        }

        new label[EMOTE_LABEL_LEN];
        Emotes_GetPairLabel(kind,label);
        Kit_AddChoice(playerid,x,y + KIT_ROW * float(row++),width,label,kind,kind == EMOTE_PAIR_PRIVATE ? KIT_COLOUR_MUTED : KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new kind = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || kind < 0 || kind >= EMOTE_PAIR_COUNT)
	{
		return;
	}

    if (kind == EMOTE_PAIR_PRIVATE)
    {
        new eligible = 0;
        for (new i = 0;i < count;i++)
        {
            if (Emotes_CanPrivate(playerid,list[i]))
            {
                list[eligible++] = list[i];
            }
        }

        count = eligible;
        if (count == 0)
        {
            Gui_Notify(playerid,"No one nearby is available for a private moment.");
            return;
        }
    }

	new target = list[0];

	if (count > 1)
	{
		epoch = Gui_BeginFlow(playerid);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"With whom?");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"With whom?",x,y,width);

		for (new i = 0;i < count;i++)
		{
			new known[NAMETAG_LEN], name[NAMETAG_LEN + 8];
			Nametag_GetKnownName(playerid,list[i],known);
			format(name,sizeof(name),"%s (%d)",known,list[i]);
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
		{
			return;
		}

		target = list[pick];
	}

	Emotes_Ask(playerid,target,kind);
}

stock Emotes_OpenAnswer(playerid)
{
	new asker = Emotes_GetAskedBy(playerid);

	if (asker == INVALID_PLAYER_ID)
	{
		return;
	}

	new name[NAMETAG_LEN], line[96], epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Nametag_GetKnownName(playerid,asker,name);
	format(line,sizeof(line),"%s %s.",name,g_EmotePairDefs[s_EmotePair[playerid][E_EP_ASK_KIND]][E_EP_ASK]);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"An offer");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,280.0,KIT_ROW * 3.0 + 6.0 + KIT_ROW + 12.0,"An offer",x,y,width);
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddChoice(playerid,x,y + KIT_ROW * 1.5,width,"Accept",1,KIT_COLOUR_GOOD);
	Kit_AddChoice(playerid,x,y + KIT_ROW * 2.5,width,"Decline",2,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 3.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	if (pick == 1)
	{
		Emotes_Accept(playerid);
	}
	else
	{
		Emotes_Decline(playerid);
	}
}

Timer_Declare(Emotes_PairTick)
{
	foreach (new playerid : Player)
	{
		if (!s_EmotePair[playerid][E_EP_ACTIVE] || !s_EmotePair[playerid][E_EP_LEADER])
		{
			continue;
		}

		new partner = s_EmotePair[playerid][E_EP_PARTNER], kind = s_EmotePair[playerid][E_EP_KIND];

		if (!IsPlayerConnected(partner))
		{
			Emotes_EndPair(playerid);
			continue;
		}

        if (kind == EMOTE_PAIR_PRIVATE)
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid,x,y,z);
            if (GetTickCount() - s_EmotePair[playerid][E_EP_STARTED_AT] >= g_EmotePairDefs[kind][E_EP_MS] || !Session_IsPlaying(playerid) || !Session_IsPlaying(partner) || GetPlayerState(playerid) == PLAYER_STATE_WASTED || GetPlayerState(partner) == PLAYER_STATE_WASTED || Gui_IsBusy(playerid) || Gui_IsBusy(partner) || GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(partner) || GetPlayerInterior(playerid) != GetPlayerInterior(partner) || !IsPlayerInRangeOfPoint(partner,EMOTE_PAIR_RANGE + 2.0,x,y,z))
            {
                Emotes_EndPair(playerid);
                continue;
            }
        }

		if (kind == EMOTE_PAIR_CARRY || kind == EMOTE_PAIR_SUPPORT)
		{
			new Float:x, Float:y, Float:z, Float:a;
			GetPlayerPos(playerid,x,y,z);
			GetPlayerFacingAngle(playerid,a);
			new Float:side = kind == EMOTE_PAIR_CARRY ? 0.0 : 0.7, Float:ahead = kind == EMOTE_PAIR_CARRY ? 0.6 : 0.1;
			SetPlayerPos(partner,x + floatsin(-a,degrees) * ahead + floatcos(a,degrees) * side,y + floatcos(-a,degrees) * ahead + floatsin(a,degrees) * side,z + (kind == EMOTE_PAIR_CARRY ? 0.3 : 0.0));
			SetPlayerFacingAngle(partner,a);
		}
	}

	return 1;
}

forward Emotes_OnPair(playerid,partnerid,kind);

public Emotes_OnPair(playerid,partnerid,kind)
{
	return 1;
}

forward Emotes_PairStart(playerid,partnerid,kind);

public Emotes_PairStart(playerid,partnerid,kind)
{
	if (!IsPlayerConnected(playerid) || !IsPlayerConnected(partnerid) || !s_EmotePair[playerid][E_EP_ACTIVE] || s_EmotePair[playerid][E_EP_PARTNER] != partnerid || s_EmotePair[playerid][E_EP_KIND] != kind)
	{
		return 1;
	}

	new bool:hold = g_EmotePairDefs[kind][E_EP_MS] == 0;
	ApplyAnimation(playerid,g_EmotePairDefs[kind][E_EP_LIB_A],g_EmotePairDefs[kind][E_EP_ANIM_A],4.1,hold,false,false,hold,0,SYNC_ALL);
	ApplyAnimation(partnerid,g_EmotePairDefs[kind][E_EP_LIB_B],g_EmotePairDefs[kind][E_EP_ANIM_B],4.1,hold,false,false,hold,0,SYNC_ALL);
	return 1;
}

forward Emotes_PairDone(playerid,partnerid);

public Emotes_PairDone(playerid,partnerid)
{
	if (playerid >= 0 && playerid < MAX_PLAYERS && s_EmotePair[playerid][E_EP_ACTIVE] && s_EmotePair[playerid][E_EP_PARTNER] == partnerid)
	{
		Emotes_EndPair(playerid);
	}

    if (partnerid >= 0 && partnerid < MAX_PLAYERS && s_EmotePair[partnerid][E_EP_ACTIVE] && s_EmotePair[partnerid][E_EP_PARTNER] == playerid)
    {
        Emotes_EndPair(partnerid);
    }

	return 1;
}

forward Emotes_AnswerDeferred(playerid);

public Emotes_AnswerDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Emotes_OpenAnswer(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_EmotePair[playerid][E_EP_ACTIVE] = false;
	s_EmotePair[playerid][E_EP_PARTNER] = INVALID_PLAYER_ID;
	s_EmotePair[playerid][E_EP_ASKED_BY] = INVALID_PLAYER_ID;
	s_EmotePair[playerid][E_EP_TIMER] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason
	Emotes_EndPair(playerid);
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
    #pragma unused killerid, reason
    Emotes_EndPair(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
    #pragma unused from
    if (to != SESSION_PLAYING)
    {
        Emotes_EndPair(playerid);
    }
}

hook Kit_OnVisibilityChanged(playerid,bool:isVisible)
{
    if (isVisible)
    {
        Emotes_EndPair(playerid);
    }
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!((newkeys & KEY_NO) && (newkeys & KEY_WALK)) || ((oldkeys & KEY_NO) && (oldkeys & KEY_WALK)))
	{
		return;
	}

	if (s_EmotePair[playerid][E_EP_ACTIVE])
	{
		Emotes_EndPair(playerid);
		return;
	}

	if (Emotes_GetAskedBy(playerid) != INVALID_PLAYER_ID)
	{
		SetTimerEx("Emotes_AnswerDeferred",0,false,"d",playerid);
	}
}
