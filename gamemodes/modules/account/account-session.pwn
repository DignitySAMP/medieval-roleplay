enum E_SESSION_STATE
{
	SESSION_CONNECTING,
	SESSION_AUTH_REGISTER,
	SESSION_AUTH_LOGIN,
	SESSION_CHARACTER_SELECT,
	SESSION_CHARACTER_CREATE,
	SESSION_SPAWNING,
	SESSION_PLAYING,
	SESSION_DEAD,
	SESSION_DECEASED,
	SESSION_DISCONNECTING,
	SESSION_STATE_COUNT,
}

static const s_SessionStateNames[SESSION_STATE_COUNT][18] = {
	"connecting", "auth_register", "auth_login", "character_select", "character_create",
	"spawning", "playing", "dead", "deceased", "disconnecting"
};

static E_SESSION_STATE:s_SessionState[MAX_PLAYERS];

#define SESSION_AWAY_MS (5 * 60000)
#define SESSION_KICK_MS (15 * 60000)
#define SESSION_KICK_RESTFUL_MS (30 * 60000)
#define SESSION_WARN_MS (2 * 60000)
#define SESSION_TRAIL_EVERY (30)
#define SESSION_TRAIL (10)
#define SESSION_MOVE_MIN (10.0)

static s_SessionActiveAt[MAX_PLAYERS];
static bool:s_SessionAway[MAX_PLAYERS];
static bool:s_SessionWarned[MAX_PLAYERS];
static bool:s_SessionRestful[MAX_PLAYERS];
static bool:s_SessionIdleKick[MAX_PLAYERS] = {true, ...};
static Float:s_SessionTrail[MAX_PLAYERS][SESSION_TRAIL][3];
static s_SessionTrailCount[MAX_PLAYERS];
static s_SessionTrailNext[MAX_PLAYERS];
static s_SessionSeconds[MAX_PLAYERS];

stock E_SESSION_STATE:Session_GetState(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return SESSION_CONNECTING;
	}

	return s_SessionState[playerid];
}

stock bool:Session_IsPlaying(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SessionState[playerid] == SESSION_PLAYING;
}

stock bool:Session_IsSpawning(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SessionState[playerid] == SESSION_SPAWNING;
}

stock bool:Session_IsAuthenticated(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SessionState[playerid] >= SESSION_CHARACTER_SELECT && s_SessionState[playerid] < SESSION_DISCONNECTING;
}

stock bool:Session_HasCharacter(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SessionState[playerid] >= SESSION_SPAWNING && s_SessionState[playerid] <= SESSION_DEAD;
}

stock Session_GetStateName(E_SESSION_STATE:newState,dest[],size = sizeof(dest))
{
	if (_:newState < 0 || _:newState >= _:SESSION_STATE_COUNT)
	{
		strcopy(dest,"unknown",size);
		return;
	}

	strcopy(dest,s_SessionStateNames[newState],size);
}

stock Session_SetState(playerid,E_SESSION_STATE:newState)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	new E_SESSION_STATE:from = s_SessionState[playerid];
	if (from == newState)
	{
		return;
	}

	s_SessionState[playerid] = newState;
	Log_Debug("session","player %d %s -> %s",playerid,s_SessionStateNames[from],s_SessionStateNames[newState]);
	pawn_call_public("Session_OnStateChanged","ddd",playerid,_:from,_:newState);
}

stock Session_MarkActive(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_SessionActiveAt[playerid] = GetTickCount();
	s_SessionWarned[playerid] = false;

	if (s_SessionAway[playerid])
	{
		s_SessionAway[playerid] = false;
		pawn_call_public("Session_OnBack","d",playerid);
	}
}

stock Session_GetIdleMs(playerid)
{
	return Session_IsPlaying(playerid) ? GetTickCount() - s_SessionActiveAt[playerid] : 0;
}

stock bool:Session_IsActive(playerid)
{
	return Session_IsPlaying(playerid) && GetTickCount() - s_SessionActiveAt[playerid] < SESSION_AWAY_MS;
}

stock bool:Session_IsAway(playerid)
{
	return Session_IsPlaying(playerid) && s_SessionAway[playerid];
}

stock Session_SetRestful(playerid,bool:isRestful)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_SessionRestful[playerid] = isRestful;
	}
}

stock bool:Session_IsRestful(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SessionRestful[playerid];
}

stock Session_GetIdleLimitMs(playerid)
{
	return Session_IsRestful(playerid) ? SESSION_KICK_RESTFUL_MS : SESSION_KICK_MS;
}

stock Session_SetIdleKick(playerid,bool:isOn)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_SessionIdleKick[playerid] = isOn;
	}
}

stock Session_SetIdleMs(playerid,ms)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_SessionActiveAt[playerid] = GetTickCount() - max(0,ms);
	Session_CheckIdle(playerid);
}

static Session_ResetActivity(playerid)
{
	s_SessionActiveAt[playerid] = GetTickCount();
	s_SessionAway[playerid] = false;
	s_SessionWarned[playerid] = false;
	s_SessionRestful[playerid] = false;
	s_SessionIdleKick[playerid] = true;
	s_SessionTrailCount[playerid] = 0;
	s_SessionTrailNext[playerid] = 0;
	s_SessionSeconds[playerid] = 0;
}

static Session_SampleTrail(playerid)
{
	new Float:x, Float:y, Float:z, slot = s_SessionTrailNext[playerid], oldest = s_SessionTrailCount[playerid] < SESSION_TRAIL ? 0 : slot;
	GetPlayerPos(playerid,x,y,z);

	if (s_SessionTrailCount[playerid] > 0 && Util_GetDistance3D(x,y,z,s_SessionTrail[playerid][oldest][0],s_SessionTrail[playerid][oldest][1],s_SessionTrail[playerid][oldest][2]) >= SESSION_MOVE_MIN)
	{
		Session_MarkActive(playerid);
	}

	s_SessionTrail[playerid][slot][0] = x;
	s_SessionTrail[playerid][slot][1] = y;
	s_SessionTrail[playerid][slot][2] = z;
	s_SessionTrailNext[playerid] = (slot + 1) % SESSION_TRAIL;
	s_SessionTrailCount[playerid] = min(s_SessionTrailCount[playerid] + 1,SESSION_TRAIL);
}

static Session_CheckIdle(playerid)
{
	new idle = GetTickCount() - s_SessionActiveAt[playerid], limit = Session_GetIdleLimitMs(playerid);

	if (!s_SessionAway[playerid] && idle >= SESSION_AWAY_MS)
	{
		s_SessionAway[playerid] = true;
		pawn_call_public("Session_OnAway","d",playerid);
	}

	if (!s_SessionIdleKick[playerid] || IsPlayerNPC(playerid))
	{
		return;
	}

	if (!s_SessionWarned[playerid] && idle >= limit - SESSION_WARN_MS)
	{
		s_SessionWarned[playerid] = true;
		Subtitle_Show(playerid,"~w~You've been idle a while. Do something in the next ~y~two minutes~w~ or you'll be logged out.");
	}

	if (idle >= limit)
	{
		s_SessionIdleKick[playerid] = false;
		pawn_call_public("Session_OnIdleKick","d",playerid);
		Gui_Notify(playerid,"You were logged out for being idle. Your character is saved.");
		SetTimerEx("Account_KickPlayer",500,false,"d",playerid);
	}
}

forward Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to);

public Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	return 1;
}

forward Session_OnAway(playerid);

public Session_OnAway(playerid)
{
	return 1;
}

forward Session_OnBack(playerid);

public Session_OnBack(playerid)
{
	return 1;
}

forward Session_OnIdleKick(playerid);

public Session_OnIdleKick(playerid)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_SessionState[playerid] = SESSION_CONNECTING;
	Session_ResetActivity(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	if (to == SESSION_PLAYING && from != SESSION_DEAD)
	{
		new bool:isKick = s_SessionIdleKick[playerid];
		Session_ResetActivity(playerid);
		s_SessionIdleKick[playerid] = isKick;
	}
}

hook Tick_OnPlayerSecond(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	if (++s_SessionSeconds[playerid] % SESSION_TRAIL_EVERY == 1)
	{
		Session_SampleTrail(playerid);
	}

	Session_CheckIdle(playerid);
}

hook OnPlayerDisconnect(playerid,reason)
{
	Session_SetState(playerid,SESSION_DISCONNECTING);
}
