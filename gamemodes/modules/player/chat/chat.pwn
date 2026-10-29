#define CHAT_RANGE_SAY (20.0)
#define CHAT_RANGE_SHOUT (40.0)
#define CHAT_RANGE_WHISPER (3.0)
#define CHAT_RANGE_ACTION (20.0)
#define CHAT_RANGE_LOW (5.0)
#define CHAT_COLOUR_SAY (0xE6E6E6FF)
#define CHAT_COLOUR_SHOUT (0xF0D9A6FF)
#define CHAT_COLOUR_WHISPER (0xB8B8C8FF)
#define CHAT_COLOUR_ACTION (0xC2A2DAFF)
#define CHAT_COLOUR_OOC (0xAAC4E5FF)
#define CHAT_COLOUR_PM_IN (0xFFCC22FF)
#define CHAT_COLOUR_PM_OUT (0xE0B84CFF)
#define CHAT_COLOUR_NOTE (0xDEDEDEFF)
#define CHAT_FADE_RATIO (1.6)
#define CHAT_LINE_MAX (144)
#define CHAT_BUBBLE_MS (8000)
#define CHAT_TARGETS_MAX (5)
#define CHAT_ROSTER_MAX (8)
#define CHAT_PM_GAP_MS (1000)
#define CHAT_NAMES_LEN (CHAT_ROSTER_MAX * (NAMETAG_LEN + 10))
#define CHAT_OUT_LEN (CHAT_LINE_MAX + CHAT_NAMES_LEN + NAMETAG_LEN + CULTURE_NAME_LEN + 48)

static const s_ChatGestures[][16] = {"prtial_gngtlkA", "prtial_gngtlkB", "prtial_gngtlkC", "prtial_gngtlkD", "prtial_gngtlkE", "prtial_gngtlkF", "prtial_gngtlkG", "prtial_gngtlkH"};

enum E_CHAT_KIND
{
	CHAT_SAY,
	CHAT_SHOUT,
	CHAT_WHISPER,
	CHAT_ME,
	CHAT_DO,
	CHAT_OOC,
	CHAT_MY,
}

static s_ChatRoster[MAX_PLAYERS][CHAT_ROSTER_MAX];
static s_ChatRosterToken[MAX_PLAYERS][CHAT_ROSTER_MAX];
static s_ChatRosterCount[MAX_PLAYERS];
static s_ChatLastPm[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};
static s_ChatLastPmToken[MAX_PLAYERS];
static s_ChatPmTick[MAX_PLAYERS];

static Chat_FadeColour(colour,Float:distance,Float:range)
{
	new Float:ratio = ((range * CHAT_FADE_RATIO) - distance) / (range * CHAT_FADE_RATIO);
	new r = floatround(ratio * float((colour >>> 24) & 0xFF));
	new g = floatround(ratio * float((colour >>> 16) & 0xFF));
	new b = floatround(ratio * float((colour >>> 8) & 0xFF));

	return (r << 24) | (g << 16) | (b << 8) | (colour & 0xFF);
}

static Chat_SendLine(playerid,colour,const line[])
{
	MessageSplit_SendClientMessage(playerid,colour,line);
}

static bool:Chat_SameSpace(playerid,otherid)
{
	return GetPlayerVirtualWorld(otherid) == GetPlayerVirtualWorld(playerid) && GetPlayerInterior(otherid) == GetPlayerInterior(playerid);
}

stock Chat_Prox(playerid,Float:range,colour,const line[],bool:bubble = true)
{
	new Float:x, Float:y, Float:z, heard = 0;
	GetPlayerPos(playerid,x,y,z);

	foreach(new i : Player)
	{
		if (i == playerid || !Session_HasCharacter(i) || !Chat_SameSpace(playerid,i))
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(i,x,y,z);
		if (distance > range)
		{
			continue;
		}

		Chat_SendLine(i,Chat_FadeColour(colour,distance,range),line);
		heard++;
	}

	Chat_SendLine(playerid,colour,line);
	if (bubble)
	{
		SetPlayerChatBubble(playerid,line,colour,range,CHAT_BUBBLE_MS);
	}

	return heard;
}

stock Chat_FromPoint(Float:x,Float:y,Float:z,world,interior,Float:range,colour,const line[])
{
	new heard = 0;

	foreach(new i : Player)
	{
		if (!Session_HasCharacter(i) || GetPlayerVirtualWorld(i) != world || GetPlayerInterior(i) != interior)
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(i,x,y,z), expanded[256];

		if (distance > range)
		{
			continue;
		}

		Nametag_Expand(i,line,expanded);
		Chat_SendLine(i,Chat_FadeColour(colour,distance,range),expanded);
		heard++;
	}

	return heard;
}

static Chat_NameList(viewerid,const targets[],count,dest[],size = sizeof(dest),bool:withIds = false)
{
	new name[NAMETAG_LEN], entry[NAMETAG_LEN + 8];
	dest[0] = EOS;

	for (new i = 0;i < count;i++)
	{
		if (targets[i] == viewerid)
		{
			strcopy(entry,"you");
		}
		else
		{
			Nametag_GetKnownName(viewerid,targets[i],name);

			if (withIds)
			{
				format(entry,sizeof(entry),"%s (%d)",name,targets[i]);
			}
			else
			{
				strcopy(entry,name);
			}
		}

		if (i > 0)
		{
			strcat(dest,i == count - 1 ? (" and ") : (", "),size);
		}

		strcat(dest,entry,size);
	}
}

static Chat_LineFor(playerid,viewerid,E_CHAT_KIND:kind,const text[],dest[],size = sizeof(dest),const tongue[] = "",const to[] = "",bool:isLow = false)
{
	new name[NAMETAG_LEN], spoken[CULTURE_NAME_LEN + 4], toward[CHAT_NAMES_LEN + 8];
	spoken[0] = EOS;
	toward[0] = EOS;

	if (kind == CHAT_OOC)
	{
		Account_GetName(playerid,name);
		format(dest,size,"(( %s (%d): %s ))",name,playerid,text);
		return;
	}

	Nametag_GetKnownName(viewerid,playerid,name);

	if (tongue[0] != EOS)
	{
		format(spoken,sizeof(spoken)," in %s",tongue);
	}

	if (to[0] != EOS)
	{
		format(toward,sizeof(toward)," (to %s)",to);
	}

	switch (kind)
	{
		case CHAT_SAY: format(dest,size,"%s says%s%s%s: %s",name,isLow ? (" quietly") : (""),spoken,toward,text);
		case CHAT_SHOUT: format(dest,size,"%s shouts%s%s: %s",name,spoken,toward,text);
		case CHAT_WHISPER: format(dest,size,"%s whispers%s: %s",name,spoken,text);
		case CHAT_ME: format(dest,size,"* %s %s",name,text);
		case CHAT_MY: format(dest,size,"* %s's %s",name,text);
		case CHAT_DO: format(dest,size,"* %s (( %s ))",text,name);
		default: dest[0] = EOS;
	}
}

stock Chat_FormatSpeech(text[],size = sizeof(text),ending = '.')
{
    new first = 0, length = strlen(text);
    while (first < length && text[first] == ' ')
    {
        first++;
    }

    if (first == length || text[first] == '*' || text[first] == '>' || text[first] == '/')
    {
        return;
    }

    for (new i = first;i < length;i++)
    {
        if ((text[i] >= 'a' && text[i] <= 'z') || (text[i] >= 'A' && text[i] <= 'Z'))
        {
            text[i] = toupper(text[i]);
            break;
        }
    }

    new end = length;
    while (end > first && text[end - 1] == ' ')
    {
        end--;
    }

    new punctuation = end;
    while (punctuation > first && (text[punctuation - 1] == '"' || text[punctuation - 1] == 39 || text[punctuation - 1] == ')' || text[punctuation - 1] == ']'))
    {
        punctuation--;
    }

    if (punctuation > first && (text[punctuation - 1] == '.' || text[punctuation - 1] == '!' || text[punctuation - 1] == '?' || text[punctuation - 1] == ':' || text[punctuation - 1] == ';'))
    {
        return;
    }

    if (length + 1 < size)
    {
        for (new i = length;i >= end;i--)
        {
            text[i + 1] = text[i];
        }
        text[end] = ending;
    }
}

static Chat_Deliver(playerid,E_CHAT_KIND:kind,const text[],const targets[],targetCount,bool:isLow)
{
	if (!Session_IsPlaying(playerid) || text[0] == EOS)
	{
		return 0;
	}

	new clean[CHAT_LINE_MAX + 1];
	Util_SanitizeChatText(text,clean,CHAT_LINE_MAX);
	if (clean[0] == EOS)
	{
		return 0;
	}

    if (kind == CHAT_SAY || kind == CHAT_SHOUT || kind == CHAT_WHISPER)
    {
        Chat_FormatSpeech(clean,sizeof(clean),kind == CHAT_SHOUT ? '!' : '.');
    }

	new Float:range = CHAT_RANGE_SAY, colour = CHAT_COLOUR_SAY, bool:bubble = true;
	switch (kind)
	{
		case CHAT_SAY: { range = CHAT_RANGE_SAY; colour = CHAT_COLOUR_SAY; }
		case CHAT_SHOUT: { range = CHAT_RANGE_SHOUT; colour = CHAT_COLOUR_SHOUT; }
		case CHAT_WHISPER: { range = CHAT_RANGE_WHISPER; colour = CHAT_COLOUR_WHISPER; bubble = false; }
		case CHAT_ME, CHAT_MY, CHAT_DO: { range = CHAT_RANGE_ACTION; colour = CHAT_COLOUR_ACTION; }
		case CHAT_OOC: { range = CHAT_RANGE_SAY; colour = CHAT_COLOUR_OOC; bubble = false; }
	}

	if (isLow)
	{
		range = CHAT_RANGE_LOW;
	}

	new Float:x, Float:y, Float:z, heard = 0, line[CHAT_OUT_LEN], to[CHAT_NAMES_LEN];
	GetPlayerPos(playerid,x,y,z);

	new language = Language_GetSpoken(playerid), tongue[CULTURE_NAME_LEN], scrambled[CHAT_LINE_MAX + 1];
	new bool:isForeign = language != LANGUAGE_COMMON && (kind == CHAT_SAY || kind == CHAT_SHOUT || kind == CHAT_WHISPER);
	tongue[0] = EOS;
	to[0] = EOS;

	if (isForeign)
	{
		Language_GetName(language,tongue);
		Language_Scramble(clean,scrambled);
	}

	foreach(new i : Player)
	{
		if (i == playerid || !Session_HasCharacter(i) || !Chat_SameSpace(playerid,i))
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(i,x,y,z);
		if (distance > range)
		{
			continue;
		}

		if (targetCount > 0)
		{
			Chat_NameList(i,targets,targetCount,to);
		}

		Chat_LineFor(playerid,i,kind,(isForeign && !Language_IsKnown(i,language)) ? scrambled : clean,line,.tongue = tongue,.to = to,.isLow = isLow);
		Chat_SendLine(i,Chat_FadeColour(colour,distance,range),line);
		heard++;
	}

	if (targetCount > 0)
	{
		Chat_NameList(playerid,targets,targetCount,to);
	}

	Chat_LineFor(playerid,playerid,kind,clean,line,.tongue = tongue,.to = to,.isLow = isLow);
	Chat_SendLine(playerid,colour,line);

	if (bubble)
	{
		switch (kind)
		{
			case CHAT_SHOUT: strcopy(line,isForeign ? scrambled : clean);
			case CHAT_ME, CHAT_DO: format(line,sizeof(line),"> %s",clean);
			case CHAT_MY: format(line,sizeof(line),"> %s %s",Character_GetSex(playerid) ? ("Her") : ("His"),clean);
			default: strcopy(line,isForeign ? scrambled : clean);
		}

		SetPlayerChatBubble(playerid,line,colour,range,CHAT_BUBBLE_MS);
	}

	if ((kind == CHAT_SAY || kind == CHAT_SHOUT) && !Character_IsBusy(playerid))
	{
		ApplyAnimation(playerid,"GANGS",s_ChatGestures[random(sizeof(s_ChatGestures))],4.1,false,true,true,true,1);
	}

	pawn_call_public("Chat_OnSpoken","ddsd",playerid,_:kind,clean,heard);
	return heard;
}

stock Chat_Speak(playerid,E_CHAT_KIND:kind,const text[],bool:isLow = false)
{
	new none[1];
	return Chat_Deliver(playerid,kind,text,none,0,isLow);
}

stock Chat_SpeakTo(playerid,E_CHAT_KIND:kind,const text[],const targets[],targetCount,bool:isLow = false)
{
	return Chat_Deliver(playerid,kind,text,targets,targetCount,isLow);
}

stock Chat_Annotate(playerid,const text[],bool:isPossessive = false)
{
	if (!Session_IsPlaying(playerid) || text[0] == EOS)
	{
		return 0;
	}

	new clean[CHAT_LINE_MAX];
	Util_SanitizeChatText(text,clean);
	if (clean[0] == EOS)
	{
		return 0;
	}

	new name[NAMETAG_LEN], line[CHAT_LINE_MAX + NAMETAG_LEN + 16];
	Character_GetName(playerid,name);
	format(line,sizeof(line),"> * %s%s %s",name,isPossessive ? ("'s") : (""),clean);
	Chat_SendLine(playerid,CHAT_COLOUR_ACTION,line);

	if (isPossessive)
	{
		format(line,sizeof(line),"> %s %s",Character_GetSex(playerid) ? ("Her") : ("His"),clean);
	}
	else
	{
		format(line,sizeof(line),"> %s",clean);
	}

	SetPlayerChatBubble(playerid,line,CHAT_COLOUR_ACTION,CHAT_RANGE_ACTION,3000 + strlen(clean) * 60);
	pawn_call_public("Chat_OnSpoken","ddsd",playerid,_:(isPossessive ? CHAT_MY : CHAT_ME),clean,0);
	return 1;
}

stock Chat_Whisper(playerid,const targets[],targetCount,const text[])
{
	if (!Session_IsPlaying(playerid) || text[0] == EOS || targetCount <= 0)
	{
		return 0;
	}

	new clean[CHAT_LINE_MAX + 1];
	Util_SanitizeChatText(text,clean,CHAT_LINE_MAX);
	if (clean[0] == EOS)
	{
		return 0;
	}

    Chat_FormatSpeech(clean);

	new near[CHAT_ROSTER_MAX], nearCount = 0, far[CHAT_ROSTER_MAX], farCount = 0, Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new t = 0;t < targetCount && t < CHAT_ROSTER_MAX;t++)
	{
		if (!Session_HasCharacter(targets[t]) || targets[t] == playerid)
		{
			continue;
		}

		if (Chat_SameSpace(playerid,targets[t]) && IsPlayerInRangeOfPoint(targets[t],CHAT_RANGE_WHISPER,x,y,z))
		{
			near[nearCount++] = targets[t];
		}
		else
		{
			far[farCount++] = targets[t];
		}
	}

	new names[CHAT_NAMES_LEN], line[CHAT_OUT_LEN];

	if (farCount > 0)
	{
		Chat_NameList(playerid,far,farCount,names,.withIds = true);
		format(line,sizeof(line),"%s can't hear you. A whisper only reaches %.0f metres.",names,CHAT_RANGE_WHISPER);
		Chat_SendLine(playerid,COMMAND_COLOUR_ERROR,line);
	}

	if (nearCount == 0)
	{
		return 0;
	}

	new language = Language_GetSpoken(playerid), tongue[CULTURE_NAME_LEN], spoken[CULTURE_NAME_LEN + 4], scrambled[CHAT_LINE_MAX + 1];
	new bool:isForeign = language != LANGUAGE_COMMON;
	tongue[0] = EOS;
	spoken[0] = EOS;

	if (isForeign)
	{
		Language_GetName(language,tongue);
		Language_Scramble(clean,scrambled);
		format(spoken,sizeof(spoken)," in %s",tongue);
	}

	for (new r = 0;r < nearCount;r++)
	{
		Chat_LineFor(playerid,near[r],CHAT_WHISPER,(isForeign && !Language_IsKnown(near[r],language)) ? scrambled : clean,line,.tongue = tongue);
		Chat_SendLine(near[r],CHAT_COLOUR_WHISPER,line);
	}

	Chat_NameList(playerid,near,nearCount,names);
	format(line,sizeof(line),"You whisper%s to %s: %s",spoken,names,clean);
	Chat_SendLine(playerid,CHAT_COLOUR_WHISPER,line);

	foreach(new i : Player)
	{
		if (i == playerid || !Session_HasCharacter(i) || !Chat_SameSpace(playerid,i) || !IsPlayerInRangeOfPoint(i,CHAT_RANGE_LOW,x,y,z))
		{
			continue;
		}

		new bool:isTarget = false;
		for (new r = 0;r < nearCount;r++)
		{
			if (near[r] == i)
			{
				isTarget = true;
				break;
			}
		}

		if (isTarget)
		{
			continue;
		}

		new speaker[NAMETAG_LEN];
		Nametag_GetKnownName(i,playerid,speaker);
		Chat_NameList(i,near,nearCount,names);
		format(line,sizeof(line),"* %s mutters something to %s.",speaker,names);
		Chat_SendLine(i,CHAT_COLOUR_ACTION,line);
	}

	pawn_call_public("Chat_OnSpoken","ddsd",playerid,_:CHAT_WHISPER,clean,nearCount);
	return nearCount;
}

stock bool:Chat_SendPm(playerid,targetid,const text[])
{
	if (Account_GetId(playerid) <= 0 || text[0] == EOS)
	{
		return false;
	}

	if (targetid == INVALID_PLAYER_ID || !IsPlayerConnected(targetid) || Account_GetId(targetid) <= 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,COMMAND_REPLY_NOT_ONLINE);
		return false;
	}

	if (targetid == playerid)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't send a message to yourself.");
		return false;
	}

	if (GetTickCount() - s_ChatPmTick[playerid] < CHAT_PM_GAP_MS)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Wait a second before you send another message.");
		return false;
	}

	new clean[CHAT_LINE_MAX];
	Util_SanitizeChatText(text,clean);
	if (clean[0] == EOS)
	{
		return false;
	}

	new from[NAMETAG_LEN], to[NAMETAG_LEN], line[CHAT_LINE_MAX + NAMETAG_LEN + 24];
	Account_GetName(playerid,from);
	Account_GetName(targetid,to);
	s_ChatPmTick[playerid] = GetTickCount();

	format(line,sizeof(line),"(( PM from %s (%d): %s ))",from,playerid,clean);
	Chat_SendLine(targetid,CHAT_COLOUR_PM_IN,line);
	PlayerPlaySound(targetid,1085,0.0,0.0,0.0);

	format(line,sizeof(line),"(( PM to %s (%d): %s ))",to,targetid,clean);
	Chat_SendLine(playerid,CHAT_COLOUR_PM_OUT,line);

	s_ChatLastPm[targetid] = playerid;
	s_ChatLastPmToken[targetid] = Account_GetToken(playerid);
	return true;
}

stock bool:Chat_SendDod(playerid,targetid,const text[])
{
	if (!Session_IsPlaying(playerid) || text[0] == EOS)
	{
		return false;
	}

	if (targetid == INVALID_PLAYER_ID || !Session_HasCharacter(targetid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,COMMAND_REPLY_NOT_ONLINE);
		return false;
	}

	if (targetid == playerid)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't send a /dod to yourself.");
		return false;
	}

	new clean[CHAT_LINE_MAX];
	Util_SanitizeChatText(text,clean);
	if (clean[0] == EOS)
	{
		return false;
	}

	new name[NAMETAG_LEN], line[CHAT_LINE_MAX + NAMETAG_LEN + 24];
	Nametag_GetKnownName(targetid,playerid,name);
	format(line,sizeof(line),"(DOD from %s (%d)): %s",name,playerid,clean);
	Chat_SendLine(targetid,CHAT_COLOUR_ACTION,line);

	Nametag_GetKnownName(playerid,targetid,name);
	format(line,sizeof(line),"(DOD to %s (%d)): %s",name,targetid,clean);
	Chat_SendLine(playerid,CHAT_COLOUR_ACTION,line);
	return true;
}

static Chat_PruneRoster(playerid)
{
	new kept = 0;

	for (new i = 0;i < s_ChatRosterCount[playerid];i++)
	{
		new memberid = s_ChatRoster[playerid][i];

		if (IsPlayerConnected(memberid) && Account_GetToken(memberid) == s_ChatRosterToken[playerid][i] && Session_HasCharacter(memberid))
		{
			s_ChatRoster[playerid][kept] = memberid;
			s_ChatRosterToken[playerid][kept] = s_ChatRosterToken[playerid][i];
			kept++;
		}
	}

	s_ChatRosterCount[playerid] = kept;
}

stock Chat_GetRosterCount(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	Chat_PruneRoster(playerid);
	return s_ChatRosterCount[playerid];
}

stock Chat_ToggleRoster(playerid,memberid)
{
	Chat_PruneRoster(playerid);

	for (new i = 0;i < s_ChatRosterCount[playerid];i++)
	{
		if (s_ChatRoster[playerid][i] == memberid)
		{
			s_ChatRosterCount[playerid]--;
			s_ChatRoster[playerid][i] = s_ChatRoster[playerid][s_ChatRosterCount[playerid]];
			s_ChatRosterToken[playerid][i] = s_ChatRosterToken[playerid][s_ChatRosterCount[playerid]];
			return 0;
		}
	}

	if (s_ChatRosterCount[playerid] >= CHAT_ROSTER_MAX)
	{
		return -1;
	}

	s_ChatRoster[playerid][s_ChatRosterCount[playerid]] = memberid;
	s_ChatRosterToken[playerid][s_ChatRosterCount[playerid]] = Account_GetToken(memberid);
	s_ChatRosterCount[playerid]++;
	return 1;
}

static Chat_ParseTargets(playerid,const params[],targets[],text[],textSize = sizeof(text))
{
	new split = strfind(params," ");
	if (split <= 0)
	{
		return -1;
	}

	new pos = split;
	while (params[pos] == ' ')
	{
		pos++;
	}

	if (params[pos] == EOS)
	{
		return -1;
	}

	strmid(text,params,pos,strlen(params),textSize);

	new list[64], part[24], start = 0, count = 0, message[96];
	strmid(list,params,0,split);

	for (new i = 0, length = strlen(list);i <= length;i++)
	{
		if (list[i] != ',' && list[i] != EOS)
		{
			continue;
		}

		strmid(part,list,start,i);
		start = i + 1;

		if (part[0] == EOS)
		{
			continue;
		}

		new targetid = INVALID_PLAYER_ID;
		if (sscanf(part,"u",targetid) || targetid == INVALID_PLAYER_ID || !Session_HasCharacter(targetid))
		{
			format(message,sizeof(message),"Nobody with the number or name %s is online.",part);
			SendClientMessage(playerid,COMMAND_COLOUR_ERROR,message);
			return 0;
		}

		if (targetid == playerid)
		{
			SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't pick yourself.");
			return 0;
		}

		new bool:isListed = false;
		for (new t = 0;t < count;t++)
		{
			if (targets[t] == targetid)
			{
				isListed = true;
				break;
			}
		}

		if (isListed)
		{
			continue;
		}

		if (count >= CHAT_TARGETS_MAX)
		{
			format(message,sizeof(message),"You can talk to %d people at once.",CHAT_TARGETS_MAX);
			SendClientMessage(playerid,COMMAND_COLOUR_ERROR,message);
			return 0;
		}

		targets[count++] = targetid;
	}

	return count;
}

static bool:Chat_TargetsCanHear(playerid,const targets[],count,Float:range)
{
	new Float:x, Float:y, Float:z, name[NAMETAG_LEN], message[128];
	GetPlayerPos(playerid,x,y,z);

	for (new t = 0;t < count;t++)
	{
		if (Chat_SameSpace(playerid,targets[t]) && IsPlayerInRangeOfPoint(targets[t],range,x,y,z))
		{
			continue;
		}

		Nametag_GetKnownName(playerid,targets[t],name);
		format(message,sizeof(message),"%s (%d) is too far away to hear you. This reaches %.0f metres.",name,targets[t],range);
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,message);
		return false;
	}

	return true;
}

static Chat_Directed(playerid,cmdid,const params[],E_CHAT_KIND:kind,bool:isLow)
{
	new targets[CHAT_TARGETS_MAX], text[CHAT_LINE_MAX];
	new count = Chat_ParseTargets(playerid,params,targets,text);

	if (count < 0)
	{
		Command_Usage(playerid,cmdid,"<id>[,<id>...] <text>");
		return;
	}

	if (count == 0)
	{
		return;
	}

	new Float:range = kind == CHAT_SHOUT ? CHAT_RANGE_SHOUT : CHAT_RANGE_SAY;

	if (isLow)
	{
		range = CHAT_RANGE_LOW;
	}

	if (Chat_TargetsCanHear(playerid,targets,count,range))
	{
		Chat_SpeakTo(playerid,kind,text,targets,count,isLow);
	}
}

forward Chat_OnSpoken(playerid,kind,const text[],heard);

public Chat_OnSpoken(playerid,kind,const text[],heard)
{
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:me(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<action>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_ME,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:melow(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<action>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_ME,params,true);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:ame(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<action>");
		return 1;
	}

	Chat_Annotate(playerid,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:my(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_MY,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:amy(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Annotate(playerid,params,true);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:do(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<description>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_DO,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:doing(cmdid, playerid, params[])
{
	if (!Session_IsPlaying(playerid))
	{
		return 1;
	}

	if (isnull(params))
	{
		if (Nametag_ClearDoing(playerid))
		{
			SendClientMessage(playerid,CHAT_COLOUR_ACTION,"Your /doing line is gone.");
		}
		else
		{
			Command_Usage(playerid,cmdid,"<what you're doing>");
		}

		return 1;
	}

	new clean[NAMETAG_DOING_LEN], name[NAMETAG_LEN], line[NAMETAG_DOING_LEN + NAMETAG_LEN + 96];
	Util_SanitizeChatText(params,clean);

	if (clean[0] == EOS || !Nametag_SetDoing(playerid,clean))
	{
		return 1;
	}

	Character_GetName(playerid,name);
	format(line,sizeof(line),"Over your head for %d minutes: > * %s %s. Use /doing on its own to clear it.",NAMETAG_DOING_MS / 60000,name,clean);
	SendClientMessage(playerid,CHAT_COLOUR_ACTION,line);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:to(cmdid, playerid, params[])
{
	Chat_Directed(playerid,cmdid,params,CHAT_SAY,false);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:lowto(cmdid, playerid, params[])
{
	Chat_Directed(playerid,cmdid,params,CHAT_SAY,true);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:lowerto(cmdid, playerid, params[])
{
	Chat_Directed(playerid,cmdid,params,CHAT_SAY,true);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:s(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_SHOUT,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:shout(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_SHOUT,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:shoutto(cmdid, playerid, params[])
{
	Chat_Directed(playerid,cmdid,params,CHAT_SHOUT,false);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:w(cmdid, playerid, params[])
{
	new targets[1], text[CHAT_LINE_MAX];

	if (sscanf(params,"us[144]",targets[0],text))
	{
		Command_Usage(playerid,cmdid,"<id or name> <text>");
		return 1;
	}

	if (targets[0] == INVALID_PLAYER_ID || !Session_HasCharacter(targets[0]))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,COMMAND_REPLY_NOT_ONLINE);
		return 1;
	}

	if (targets[0] == playerid)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't whisper to yourself.");
		return 1;
	}

	Chat_Whisper(playerid,targets,1,text);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:whisper(cmdid, playerid, params[])
{
	new targets[1], text[CHAT_LINE_MAX];

	if (sscanf(params,"us[144]",targets[0],text))
	{
		Command_Usage(playerid,cmdid,"<id or name> <text>");
		return 1;
	}

	if (targets[0] == INVALID_PLAYER_ID || !Session_HasCharacter(targets[0]))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,COMMAND_REPLY_NOT_ONLINE);
		return 1;
	}

	if (targets[0] == playerid)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't whisper to yourself.");
		return 1;
	}

	Chat_Whisper(playerid,targets,1,text);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:addwhisper(cmdid, playerid, params[])
{
	#pragma unused cmdid

	if (!Session_IsPlaying(playerid))
	{
		return 1;
	}

	new line[CHAT_NAMES_LEN + 64];

	if (isnull(params))
	{
		if (Chat_GetRosterCount(playerid) == 0)
		{
			SendClientMessage(playerid,CHAT_COLOUR_NOTE,"Your whisper group is empty. Add someone with /addwhisper <id>, then whisper to everyone in it with /gw.");
			return 1;
		}

		new names[CHAT_NAMES_LEN];
		Chat_NameList(playerid,s_ChatRoster[playerid],s_ChatRosterCount[playerid],names,.withIds = true);
		format(line,sizeof(line),"Your whisper group: %s. /addwhisper <id> again takes someone out.",names);
		Chat_SendLine(playerid,CHAT_COLOUR_NOTE,line);
		return 1;
	}

	new memberid = INVALID_PLAYER_ID;

	if (sscanf(params,"u",memberid) || memberid == INVALID_PLAYER_ID || !Session_HasCharacter(memberid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,COMMAND_REPLY_NOT_ONLINE);
		return 1;
	}

	if (memberid == playerid)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"You can't add yourself to your whisper group.");
		return 1;
	}

	new name[NAMETAG_LEN];
	Nametag_GetKnownName(playerid,memberid,name);

	switch (Chat_ToggleRoster(playerid,memberid))
	{
		case 1: format(line,sizeof(line),"%s (%d) is in your whisper group now. Use /gw <text> to whisper to the whole group.",name,memberid);
		case 0: format(line,sizeof(line),"%s (%d) is out of your whisper group.",name,memberid);
		default: format(line,sizeof(line),"Your whisper group is full at %d people. Take someone out with /addwhisper <id> first.",CHAT_ROSTER_MAX);
	}

	SendClientMessage(playerid,CHAT_COLOUR_NOTE,line);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:gw(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	if (Chat_GetRosterCount(playerid) == 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Your whisper group is empty. Add someone with /addwhisper <id> first.");
		return 1;
	}

	Chat_Whisper(playerid,s_ChatRoster[playerid],s_ChatRosterCount[playerid],params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:groupwhisper(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	if (Chat_GetRosterCount(playerid) == 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Your whisper group is empty. Add someone with /addwhisper <id> first.");
		return 1;
	}

	Chat_Whisper(playerid,s_ChatRoster[playerid],s_ChatRosterCount[playerid],params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:b(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_OOC,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:blow(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_OOC,params,true);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:blower(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<text>");
		return 1;
	}

	Chat_Speak(playerid,CHAT_OOC,params,true);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:pm(cmdid, playerid, params[])
{
	new targetid = INVALID_PLAYER_ID, text[CHAT_LINE_MAX];

	if (sscanf(params,"us[144]",targetid,text))
	{
		Command_Usage(playerid,cmdid,"<id or name> <message>");
		return 1;
	}

	Chat_SendPm(playerid,targetid,text);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:re(cmdid, playerid, params[])
{
	if (isnull(params))
	{
		Command_Usage(playerid,cmdid,"<message>");
		return 1;
	}

	new senderid = s_ChatLastPm[playerid];

	if (senderid == INVALID_PLAYER_ID)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Nobody has sent you a PM yet.");
		return 1;
	}

	if (!IsPlayerConnected(senderid) || Account_GetToken(senderid) != s_ChatLastPmToken[playerid])
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"The last person who sent you a PM has left the server.");
		return 1;
	}

	Chat_SendPm(playerid,senderid,params);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:dod(cmdid, playerid, params[])
{
	new targetid = INVALID_PLAYER_ID, text[CHAT_LINE_MAX];

	if (sscanf(params,"us[144]",targetid,text))
	{
		Command_Usage(playerid,cmdid,"<id or name> <description>");
		return 1;
	}

	Chat_SendDod(playerid,targetid,text);
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_ChatRosterCount[playerid] = 0;
	s_ChatLastPm[playerid] = INVALID_PLAYER_ID;
	s_ChatLastPmToken[playerid] = 0;
	s_ChatPmTick[playerid] = 0;
}

hook OnPlayerText(playerid,text[])
{
	if (IsPlayerNPC(playerid))
	{
		return;
	}

	if (!Session_IsPlaying(playerid))
	{
		Gui_Notify(playerid,"You can't talk until you've spawned.");
		return;
	}

	Chat_Speak(playerid,CHAT_SAY,text);
}
