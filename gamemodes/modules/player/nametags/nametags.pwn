#define NAMETAG_LEN (44)
#define NAMETAG_STRANGER "A stranger"
#define NAMETAG_RANGE (12.0)
#define NAMETAG_INTRODUCE_RANGE (5.0)
#define NAMETAG_COLOUR (0xDEDEDEFF)
#define NAMETAG_DOING_LEN (96)
#define NAMETAG_DOING_MS (300000)
#define NAMETAG_LABEL_LEN (NAMETAG_LEN + NAMETAG_DOING_LEN + 40)
#define NAMETAG_SPAWN_STREAM_MS (1000)
#define NAMETAG_NAME_Z (0.2)
#define NAMETAG_DOING_Z (0.07)
#define NAMETAG_DOING_COLOUR (0xC2A2DAFF)
#define NAMETAG_CUE_LEN (80)
#define NAMETAG_CUE_Z (0.65)
#define NAMETAG_CUE_COLOUR (0xC9B27CFF)

enum E_NAMETAG_CUE
{
	NAMETAG_CUE_AILMENT,
	NAMETAG_CUE_WOUND,
	NAMETAG_CUE_LAW,
	NAMETAG_CUE_STINK,
	NAMETAG_CUE_LIVERY,
	NAMETAG_CUE_AWAY,
	NAMETAG_CUE_COUNT,
}

static Map:s_Known;
static bool:s_NametagArmed[MAX_PLAYERS];
static bool:s_ScoreboardCharacter[MAX_PLAYERS];
const NAMETAG_RPC_PLAYER_JOIN = 137;
const NAMETAG_RPC_PLAYER_NAME = 11;
static STREAMER_TAG_3D_TEXT_LABEL:s_Labels[MAX_PLAYERS][MAX_PLAYERS];
static STREAMER_TAG_3D_TEXT_LABEL:s_DoingLabels[MAX_PLAYERS][MAX_PLAYERS];
static s_Doing[MAX_PLAYERS][NAMETAG_DOING_LEN];
static s_DoingToken[MAX_PLAYERS];
static s_Cues[MAX_PLAYERS][E_NAMETAG_CUE][NAMETAG_CUE_LEN];
static STREAMER_TAG_3D_TEXT_LABEL:s_CueLabels[MAX_PLAYERS];

static Nametag_Key(viewerid,targetid)
{
	return viewerid * MAX_PLAYERS + targetid;
}

static bool:Nametag_Lookup(viewerid,targetid,dest[],size = sizeof(dest))
{
	if (s_Known == Map:0 || !map_has_key(s_Known,Nametag_Key(viewerid,targetid)))
	{
		dest[0] = EOS;
		return false;
	}

	map_get_str(s_Known,Nametag_Key(viewerid,targetid),dest,size);
	return true;
}

static Nametag_Store(viewerid,targetid,const name[])
{
	if (s_Known == Map:0)
	{
		s_Known = map_new();
	}

	map_set_str(s_Known,Nametag_Key(viewerid,targetid),name);
}

static Nametag_Erase(viewerid,targetid)
{
	if (s_Known != Map:0)
	{
		map_remove(s_Known,Nametag_Key(viewerid,targetid));
	}
}

stock bool:Nametag_IsScoreboardClient(playerid)
{
    if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid))
    {
        return false;
    }

    return true;
}

stock Nametag_GetScoreboardName(playerid,dest[],size = sizeof(dest))
{
    if (!Util_IsValidPlayer(playerid))
    {
        dest[0] = EOS;
        return;
    }

    if (s_ScoreboardCharacter[playerid] && Character_GetId(playerid) > 0)
    {
        Character_GetName(playerid,dest,min(size,MAX_PLAYER_NAME + 1));
        for (new i = 0; dest[i] != EOS; i++)
        {
            if (dest[i] == ' ')
            {
                dest[i] = '_';
            }
        }
        return;
    }

    GetPlayerName(playerid,dest,size);
}

stock Nametag_WriteNameRPC(playerid,BitStream:stream)
{
    new name[MAX_PLAYER_NAME + 1];
    Nametag_GetScoreboardName(playerid,name);
    BS_Reset(stream);
    BS_WriteValue(stream,PR_UINT16,playerid,PR_UINT8,strlen(name),PR_STRING,name,PR_UINT8,1);
}

stock bool:Nametag_RewriteJoinRPC(viewerid,BitStream:stream)
{
    if (!Nametag_IsScoreboardClient(viewerid))
    {
        return true;
    }

    new playerid, colour, isNpc;
    BS_ResetReadPointer(stream);
    BS_ReadValue(stream,PR_UINT16,playerid,PR_UINT32,colour,PR_UINT8,isNpc);
    if (!Nametag_IsScoreboardClient(playerid) || isNpc || !s_ScoreboardCharacter[playerid])
    {
        BS_ResetReadPointer(stream);
        return true;
    }

    new name[MAX_PLAYER_NAME + 1];
    Nametag_GetScoreboardName(playerid,name);
    BS_Reset(stream);
    BS_WriteValue(stream,PR_UINT16,playerid,PR_UINT32,colour,PR_UINT8,isNpc,PR_UINT8,strlen(name),PR_STRING,name);
    return true;
}

static Nametag_RefreshScoreboard(playerid)
{
    if (!Nametag_IsScoreboardClient(playerid))
    {
        return;
    }

    new BitStream:stream = BS_New();
    Nametag_WriteNameRPC(playerid,stream);
    foreach (new viewerid : Player)
    {
        if (Nametag_IsScoreboardClient(viewerid))
        {
            PR_SendRPC(stream,viewerid,NAMETAG_RPC_PLAYER_NAME);
        }
    }
    BS_Delete(stream);
}

stock Nametag_GetKnownName(viewerid,targetid,dest[],size = sizeof(dest))
{
	if (!Util_IsValidPlayer(viewerid) || !Util_IsValidPlayer(targetid))
	{
		dest[0] = EOS;
		return;
	}

	if (viewerid == targetid)
	{
		Character_GetName(targetid,dest,size);
		return;
	}

	if (!Nametag_Lookup(viewerid,targetid,dest,size))
	{
		strcopy(dest,NAMETAG_STRANGER,size);
	}
}

stock Nametag_Token(targetid,dest[],size = sizeof(dest))
{
	format(dest,size,"{p:%d}",targetid);
}

stock Nametag_Expand(viewerid,const text[],dest[],size = sizeof(dest))
{
	new out[256], part[256], name[NAMETAG_LEN], from = 0, at, close;
	out[0] = EOS;

	while ((at = strfind(text,"{p:",false,from)) != -1 && (close = strfind(text,"}",false,at)) != -1)
	{
		strmid(part,text,from,at);
		strcat(out,part);
		strmid(part,text,at + 3,close);
		Nametag_GetKnownName(viewerid,strval(part),name);

		if (name[0] == EOS)
		{
			strcopy(name,NAMETAG_STRANGER);
		}

		strcat(out,name);
		from = close + 1;
	}

	strmid(part,text,from,strlen(text));
	strcat(out,part);
	strcopy(dest,out,size);
}

stock bool:Nametag_Knows(viewerid,targetid)
{
	new name[NAMETAG_LEN];
	return Util_IsValidPlayer(viewerid) && Util_IsValidPlayer(targetid) && Nametag_Lookup(viewerid,targetid,name);
}

static Nametag_DropLabel(&STREAMER_TAG_3D_TEXT_LABEL:label)
{
	if (IsValidDynamic3DTextLabel(label))
	{
		DestroyDynamic3DTextLabel(label);
	}

	label = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

static bool:Nametag_PutLabel(&STREAMER_TAG_3D_TEXT_LABEL:label,const text[],colour,Float:z,viewerid,targetid)
{
	if (IsValidDynamic3DTextLabel(label))
	{
		UpdateDynamic3DTextLabelText(label,colour,text);
		return false;
	}

	label = CreateDynamic3DTextLabel(text,colour,0.0,0.0,z,NAMETAG_RANGE,targetid,INVALID_VEHICLE_ID,1,-1,-1,viewerid);
	return true;
}

static Nametag_Refresh(viewerid,targetid)
{
	if (!Session_HasCharacter(viewerid) || !Session_HasCharacter(targetid) || viewerid == targetid)
	{
		Nametag_DropLabel(s_Labels[targetid][viewerid]);
		Nametag_DropLabel(s_DoingLabels[targetid][viewerid]);
		return;
	}

	new name[NAMETAG_LEN], label[NAMETAG_LABEL_LEN];
	Nametag_GetKnownName(viewerid,targetid,name);
	format(label,sizeof(label),"%s (%d)",name,targetid);
	new bool:isNew = Nametag_PutLabel(s_Labels[targetid][viewerid],label,NAMETAG_COLOUR,NAMETAG_NAME_Z,viewerid,targetid);

	if (s_Doing[targetid][0] == EOS)
	{
		Nametag_DropLabel(s_DoingLabels[targetid][viewerid]);
	}
	else
	{
		format(label,sizeof(label),"> * %s %s",name,s_Doing[targetid]);
		isNew = Nametag_PutLabel(s_DoingLabels[targetid][viewerid],label,NAMETAG_DOING_COLOUR,NAMETAG_DOING_Z,viewerid,targetid) || isNew;
	}

	if (isNew)
	{
		Streamer_Update(viewerid,STREAMER_TYPE_3D_TEXT_LABEL);
	}
}

stock STREAMER_TAG_3D_TEXT_LABEL:Nametag_GetLabel(viewerid,targetid)
{
	return Util_IsValidPlayer(viewerid) && Util_IsValidPlayer(targetid) ? s_Labels[targetid][viewerid] : STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock STREAMER_TAG_3D_TEXT_LABEL:Nametag_GetDoingLabel(viewerid,targetid)
{
	return Util_IsValidPlayer(viewerid) && Util_IsValidPlayer(targetid) ? s_DoingLabels[targetid][viewerid] : STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

static Nametag_RefreshTarget(targetid)
{
	foreach(new i : Player)
	{
		if (i != targetid)
		{
			Nametag_Refresh(i,targetid);
		}
	}
}

stock bool:Nametag_SetDoing(playerid,const text[])
{
	if (!Session_HasCharacter(playerid) || text[0] == EOS)
	{
		return false;
	}

	strcopy(s_Doing[playerid],text,NAMETAG_DOING_LEN);
	SetTimerEx("Nametag_DoingExpire",NAMETAG_DOING_MS,false,"dd",playerid,++s_DoingToken[playerid]);
	Nametag_RefreshTarget(playerid);
	return true;
}

stock bool:Nametag_ClearDoing(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_Doing[playerid][0] == EOS)
	{
		return false;
	}

	s_Doing[playerid][0] = EOS;
	s_DoingToken[playerid]++;
	Nametag_RefreshTarget(playerid);
	return true;
}

stock Nametag_GetDoing(playerid,dest[],size = sizeof(dest))
{
	if (!Util_IsValidPlayer(playerid))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Doing[playerid],size);
}

stock Nametag_GetCue(playerid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	for (new E_NAMETAG_CUE:i = E_NAMETAG_CUE:0;Util_IsValidPlayer(playerid) && i < NAMETAG_CUE_COUNT;i++)
	{
		if (s_Cues[playerid][i][0] != EOS)
		{
			if (dest[0] != EOS)
			{
				strcat(dest,", ",size);
			}

			strcat(dest,s_Cues[playerid][i],size);
		}
	}
}

stock STREAMER_TAG_3D_TEXT_LABEL:Nametag_GetCueLabel(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CueLabels[playerid] : STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

static Nametag_RefreshCue(playerid)
{
	new cue[NAMETAG_CUE_LEN * 2];
	Nametag_GetCue(playerid,cue);

	if (cue[0] == EOS || !Session_IsPlaying(playerid))
	{
		Nametag_DropLabel(s_CueLabels[playerid]);
		return;
	}

	if (IsValidDynamic3DTextLabel(s_CueLabels[playerid]))
	{
		UpdateDynamic3DTextLabelText(s_CueLabels[playerid],NAMETAG_CUE_COLOUR,cue);
		return;
	}

	s_CueLabels[playerid] = CreateDynamic3DTextLabel(cue,NAMETAG_CUE_COLOUR,0.0,0.0,NAMETAG_CUE_Z,NAMETAG_RANGE,playerid,INVALID_VEHICLE_ID,1);
	Nametag_StreamAround(playerid,Account_GetToken(playerid));
}

stock Nametag_SetCue(playerid,E_NAMETAG_CUE:source,const text[])
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	if (text[0] == EOS ? s_Cues[playerid][source][0] == EOS : (s_Cues[playerid][source][0] != EOS && !strcmp(s_Cues[playerid][source],text)))
	{
		return;
	}

	strcopy(s_Cues[playerid][source],text,NAMETAG_CUE_LEN);
	Nametag_RefreshCue(playerid);
}

static Nametag_Persist(viewerid,targetid)
{
	new name[NAMETAG_LEN];
	Nametag_Lookup(viewerid,targetid,name);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO character_aliases (viewer_id, target_id, alias) VALUES (%d, %d, '%e') ON DUPLICATE KEY UPDATE alias = '%e'",Character_GetId(viewerid),Character_GetId(targetid),name,name));
}

stock bool:Nametag_Know(viewerid,targetid,const name[])
{
	if (!Session_HasCharacter(viewerid) || !Session_HasCharacter(targetid) || viewerid == targetid || name[0] == EOS)
	{
		return false;
	}

	Nametag_Store(viewerid,targetid,name);
	Nametag_Refresh(viewerid,targetid);
	Nametag_Persist(viewerid,targetid);
	return true;
}

stock Nametag_Introduce(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		return 0;
	}

	new Float:x, Float:y, Float:z, name[NAMETAG_LEN], told = 0;
	GetPlayerPos(playerid,x,y,z);
	Character_GetName(playerid,name);

	foreach(new i : Player)
	{
		if (i == playerid || !Session_HasCharacter(i) || GetPlayerVirtualWorld(i) != GetPlayerVirtualWorld(playerid) || GetPlayerInterior(i) != GetPlayerInterior(playerid))
		{
			continue;
		}

		if (!IsPlayerInRangeOfPoint(i,NAMETAG_INTRODUCE_RANGE,x,y,z) || Nametag_Knows(i,playerid))
		{
			continue;
		}

		Nametag_Know(i,playerid,name);
		told++;
	}

	pawn_call_public("Nametag_OnIntroduced","dd",playerid,told);
	return told;
}

static Nametag_Forget(playerid)
{
	s_Doing[playerid][0] = EOS;
	s_DoingToken[playerid]++;
	Nametag_DropLabel(s_CueLabels[playerid]);

	for (new E_NAMETAG_CUE:i = E_NAMETAG_CUE:0;i < NAMETAG_CUE_COUNT;i++)
	{
		s_Cues[playerid][i][0] = EOS;
	}

	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		Nametag_Erase(playerid,i);
		Nametag_Erase(i,playerid);
		Nametag_DropLabel(s_Labels[playerid][i]);
		Nametag_DropLabel(s_Labels[i][playerid]);
		Nametag_DropLabel(s_DoingLabels[playerid][i]);
		Nametag_DropLabel(s_DoingLabels[i][playerid]);
	}
}

static Nametag_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT viewer_id, target_id, alias FROM character_aliases WHERE viewer_id = %d OR target_id = %d",characterid,characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new rows = cache_num_rows();
	for (new r = 0; r < rows; r++)
	{
		new viewerCharacter, targetCharacter, alias[NAMETAG_LEN];
		cache_get_value_name_int(r,"viewer_id",viewerCharacter);
		cache_get_value_name_int(r,"target_id",targetCharacter);
		cache_get_value_name(r,"alias",alias);
		new bool:isOwn = viewerCharacter == characterid, other = isOwn ? targetCharacter : viewerCharacter;
		foreach(new i : Player)
		{
			if (i == playerid || !Session_HasCharacter(i) || Character_GetId(i) != other)
			{
				continue;
			}

			if (isOwn)
			{
				Nametag_Store(playerid,i,alias);
			}
			else
			{
				Nametag_Store(i,playerid,alias);
			}
		}
	}

	foreach(new i : Player)
	{
		if (i == playerid || !Session_HasCharacter(i))
		{
			continue;
		}

		Nametag_Refresh(playerid,i);
		Nametag_Refresh(i,playerid);
	}
}

forward Nametag_DoingExpire(playerid,token);

public Nametag_DoingExpire(playerid,token)
{
	if (IsPlayerConnected(playerid) && s_DoingToken[playerid] == token)
	{
		new notice[96];
		Nametag_ClearDoing(playerid);
		format(notice,sizeof(notice),"Your /doing line is gone after %d minutes. Use /doing to set a new one.",NAMETAG_DOING_MS / 60000);
		Gui_Notify(playerid,notice);
	}

	return 1;
}

forward Nametag_LoadDeferred(playerid,token);

public Nametag_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Nametag_Load(playerid,token);
	}

	return 1;
}

forward Nametag_StreamAround(playerid,token);

public Nametag_StreamAround(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach(new i : Player)
	{
		if (i != playerid && IsPlayerInRangeOfPoint(i,STREAMER_3D_TEXT_LABEL_SD,x,y,z))
		{
			Streamer_Update(i,STREAMER_TYPE_3D_TEXT_LABEL);
		}
	}

	Streamer_Update(playerid,STREAMER_TYPE_3D_TEXT_LABEL);
	return 1;
}

forward Nametag_OnIntroduced(playerid,told);

public Nametag_OnIntroduced(playerid,told)
{
	return 1;
}

forward bool:Nametag_KeyContext(playerid);

public bool:Nametag_KeyContext(playerid)
{
	return Session_IsPlaying(playerid) && !s_NametagArmed[playerid];
}

ORPC:NAMETAG_RPC_PLAYER_JOIN(playerid,BitStream:bs)
{
    return Nametag_RewriteJoinRPC(playerid,bs);
}

#include <pp-hooks>

hook OnGameModeInit()
{
	ShowNameTags(false);
	for (new a = 0; a < MAX_PLAYERS; a++)
	{
		s_CueLabels[a] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

		for (new b = 0; b < MAX_PLAYERS; b++)
		{
			s_Labels[a][b] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
			s_DoingLabels[a][b] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
		}
	}
}

hook OnPlayerConnect(playerid)
{
	Nametag_Forget(playerid);
	s_NametagArmed[playerid] = false;
    s_ScoreboardCharacter[playerid] = false;
}

hook Combat_OnModeChanged(playerid,enabled)
{
	s_NametagArmed[playerid] = bool:enabled;
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	SetTimerEx("Nametag_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Nametag_Forget(playerid);
    s_ScoreboardCharacter[playerid] = false;
    Nametag_RefreshScoreboard(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
    if (to == SESSION_PLAYING && Character_GetId(playerid) > 0)
    {
        s_ScoreboardCharacter[playerid] = true;
        Nametag_RefreshScoreboard(playerid);
    }
    else if (to < SESSION_SPAWNING && s_ScoreboardCharacter[playerid])
    {
        s_ScoreboardCharacter[playerid] = false;
        Nametag_RefreshScoreboard(playerid);
    }

	if (from == SESSION_PLAYING || to == SESSION_PLAYING)
	{
		Nametag_RefreshCue(playerid);
	}
}

hook OnPlayerSpawn(playerid)
{
	SetTimerEx("Nametag_StreamAround",NAMETAG_SPAWN_STREAM_MS,false,"dd",playerid,Account_GetToken(playerid));
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_CTRL_BACK) && !(oldkeys & KEY_CTRL_BACK) && !Keys_IsBusy(playerid,KEY_CTRL_BACK,KEYS_PRIO_MENU) && Session_IsPlaying(playerid) && !s_NametagArmed[playerid] && !Gui_IsBusy(playerid))
	{
		new told = Nametag_Introduce(playerid);
		Gui_Notify(playerid,told > 0 ? ("You introduce yourself to those around you.") : ("Nobody new is close enough to hear your name."));
	}
}
