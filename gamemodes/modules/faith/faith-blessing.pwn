#define FAITH_BLESSED_SECONDS (7200)
#define FAITH_BLESSING_DAYS (2)
#define FAITH_BLESSING_LED_DAYS (3)
#define FAITH_HOLD_CAP_MINUTES (3456)
#define FAITH_HEAL_BONUS (10)
#define FAITH_SAVE_SECONDS (60)
#define FAITH_BUFF_KEY "blessed"
#define FAITH_SHRINE_DAYS (1)

static s_FaithBlessedLeft[MAX_PLAYERS];
static bool:s_FaithBlessedLed[MAX_PLAYERS];
static bool:s_FaithBlessingBroken[MAX_PLAYERS];
static s_FaithPaidDay[MAX_PLAYERS];
static s_FaithHeldDay[MAX_PLAYERS];
static s_FaithHeldToday[MAX_PLAYERS];
static s_FaithShrineDay[MAX_PLAYERS];
static bool:s_FaithLoaded[MAX_PLAYERS];

stock Faith_RealDay()
{
	new year, month, day;
	getdate(year,month,day);
	return year * 372 + month * 31 + day;
}

stock bool:Faith_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FaithLoaded[playerid];
}

stock bool:Faith_IsBlessed(playerid)
{
	return Faith_IsLoaded(playerid) && s_FaithBlessedLeft[playerid] > 0;
}

stock bool:Faith_IsBlessingLed(playerid)
{
	return Faith_IsBlessed(playerid) && s_FaithBlessedLed[playerid];
}

stock Faith_GetBlessedSeconds(playerid)
{
	return Faith_IsLoaded(playerid) ? s_FaithBlessedLeft[playerid] : 0;
}

static Faith_Persist(playerid)
{
	if (!s_FaithLoaded[playerid] || Character_GetId(playerid) <= 0)
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO character_faith (character_id, blessed_left, blessed_led, blessing_broken, paid_day, held_day, held_today, shrine_paid_day) VALUES (%d, %d, %d, %d, %d, %d, %d, %d)",Character_GetId(playerid),s_FaithBlessedLeft[playerid],_:s_FaithBlessedLed[playerid],_:s_FaithBlessingBroken[playerid],s_FaithPaidDay[playerid],s_FaithHeldDay[playerid],s_FaithHeldToday[playerid],s_FaithShrineDay[playerid]));
}

static Faith_ShowBlessing(playerid)
{
	if (s_FaithBlessedLeft[playerid] <= 0)
	{
		Buff_Clear(playerid,FAITH_BUFF_KEY);
		Wounds_SetHealBonus(playerid,0);
		return;
	}

	Buff_Set(playerid,FAITH_BUFF_KEY,"Blessed","Wounds heal faster. Keep it to the end and your years pass more slowly.",s_FaithBlessedLeft[playerid],Faith_GetBlessingSeconds(playerid));
	Wounds_SetHealBonus(playerid,FAITH_HEAL_BONUS);
}

stock Faith_GetBlessingSeconds(playerid)
{
	return Traits_Scale(playerid,TRAIT_EFFECT_BLESSING,FAITH_BLESSED_SECONDS);
}

stock bool:Faith_Bless(playerid,bool:isLed = false)
{
	if (!Faith_IsLoaded(playerid) || !Session_IsPlaying(playerid))
	{
		return false;
	}

	new bool:wasBlessed = s_FaithBlessedLeft[playerid] > 0;
	s_FaithBlessedLeft[playerid] = Faith_GetBlessingSeconds(playerid);
	s_FaithBlessedLed[playerid] = isLed || (wasBlessed && s_FaithBlessedLed[playerid]);
	s_FaithBlessingBroken[playerid] = false;
	Faith_ShowBlessing(playerid);
	Faith_Persist(playerid);
	new text[160];
	format(text,sizeof(text),wasBlessed ? ("Your blessing is renewed for another %d hours of play.") : ("You are blessed. For %d hours of play your wounds heal faster, and if you keep the blessing to the end your years pass more slowly."),Faith_GetBlessingSeconds(playerid) / 3600);
	Gui_Notify(playerid,text);
	pawn_call_public("Faith_OnBlessed","dd",playerid,_:isLed);
	return true;
}

static Faith_HoldBack(playerid,minutes)
{
	new today = Faith_RealDay();

	if (s_FaithHeldDay[playerid] != today)
	{
		s_FaithHeldDay[playerid] = today;
		s_FaithHeldToday[playerid] = 0;
	}

	minutes = min(minutes,max(FAITH_HOLD_CAP_MINUTES - s_FaithHeldToday[playerid],0));

	if (minutes <= 0 || !Lineage_HoldBackAge(playerid,minutes))
	{
		return 0;
	}

	s_FaithHeldToday[playerid] += minutes;
	pawn_call_public("Faith_OnLifePaid","dd",playerid,minutes);
	return minutes;
}

stock bool:Faith_HasPrayedToday(playerid)
{
	return Faith_IsLoaded(playerid) && s_FaithShrineDay[playerid] == Faith_RealDay();
}

stock Faith_PayShrine(playerid)
{
	if (!Faith_IsLoaded(playerid) || Faith_HasPrayedToday(playerid))
	{
		return 0;
	}

	new minutes = Faith_HoldBack(playerid,FAITH_SHRINE_DAYS * LINEAGE_DAY_MINUTES);

	if (minutes > 0)
	{
		s_FaithShrineDay[playerid] = Faith_RealDay();
		Faith_Persist(playerid);
	}

	return minutes;
}

static Faith_EndBlessing(playerid)
{
	new today = Faith_RealDay(), bool:canPay = !s_FaithBlessingBroken[playerid] && s_FaithPaidDay[playerid] != today, days = s_FaithBlessedLed[playerid] ? FAITH_BLESSING_LED_DAYS : FAITH_BLESSING_DAYS;

	s_FaithBlessedLeft[playerid] = 0;
	s_FaithBlessedLed[playerid] = false;
	Faith_ShowBlessing(playerid);

	if (canPay && Faith_HoldBack(playerid,days * LINEAGE_DAY_MINUTES) > 0)
	{
		s_FaithPaidDay[playerid] = today;
		Gui_Notify(playerid,"Your blessing has run its course. Your years pass a little more slowly for it.");
	}
	else
	{
		Gui_Notify(playerid,"Your blessing has run its course.");
	}

	s_FaithBlessingBroken[playerid] = false;
	Faith_Persist(playerid);
}

stock Faith_BlessingStep(playerid,seconds = 1)
{
	if (!Faith_IsLoaded(playerid) || !Session_IsPlaying(playerid) || s_FaithBlessedLeft[playerid] <= 0)
	{
		return;
	}

	s_FaithBlessedLeft[playerid] = max(s_FaithBlessedLeft[playerid] - seconds,0);

	if (s_FaithBlessedLeft[playerid] == 0)
	{
		Faith_EndBlessing(playerid);
		return;
	}

	if (s_FaithBlessedLeft[playerid] % FAITH_SAVE_SECONDS == 0 || seconds > 1)
	{
		Faith_ShowBlessing(playerid);
		Faith_Persist(playerid);
	}
}

static Faith_ResetBlessing(playerid)
{
	s_FaithLoaded[playerid] = false;
	s_FaithBlessedLeft[playerid] = 0;
	s_FaithBlessedLed[playerid] = false;
	s_FaithBlessingBroken[playerid] = false;
	s_FaithPaidDay[playerid] = 0;
	s_FaithHeldDay[playerid] = 0;
	s_FaithHeldToday[playerid] = 0;
	s_FaithShrineDay[playerid] = 0;
}

static Faith_LoadBlessing(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT blessed_left, blessed_led, blessing_broken, paid_day, held_day, held_today, shrine_paid_day FROM character_faith WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	if (cache_num_rows() > 0)
	{
		new led, broken;
		cache_get_value_name_int(0,"blessed_left",s_FaithBlessedLeft[playerid]);
		cache_get_value_name_int(0,"blessed_led",led);
		cache_get_value_name_int(0,"blessing_broken",broken);
		cache_get_value_name_int(0,"paid_day",s_FaithPaidDay[playerid]);
		cache_get_value_name_int(0,"held_day",s_FaithHeldDay[playerid]);
		cache_get_value_name_int(0,"held_today",s_FaithHeldToday[playerid]);
		cache_get_value_name_int(0,"shrine_paid_day",s_FaithShrineDay[playerid]);
		s_FaithBlessedLed[playerid] = led != 0;
		s_FaithBlessingBroken[playerid] = broken != 0;
	}

	s_FaithLoaded[playerid] = true;
	Faith_ShowBlessing(playerid);
}

forward Faith_OnBlessed(playerid,isLed);

public Faith_OnBlessed(playerid,isLed)
{
	return 1;
}

forward Faith_OnLifePaid(playerid,minutes);

public Faith_OnLifePaid(playerid,minutes)
{
	return 1;
}

forward Faith_LoadDeferred(playerid,token);

public Faith_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Faith_LoadBlessing(playerid,token);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Faith_ResetBlessing(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Faith_ResetBlessing(playerid);
	SetTimerEx("Faith_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Faith_Persist(playerid);
	Buff_Clear(playerid,FAITH_BUFF_KEY);
	Faith_ResetBlessing(playerid);
}

hook Tick_OnPlayerSecond(playerid)
{
	Faith_BlessingStep(playerid,1);
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid, reason

	if (Faith_IsBlessed(playerid))
	{
		s_FaithBlessingBroken[playerid] = true;
		Faith_Persist(playerid);
	}
}
