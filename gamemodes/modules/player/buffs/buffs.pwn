#define BUFF_MAX (12)
#define BUFF_KEY_LEN (24)
#define BUFF_NAME_LEN (32)
#define BUFF_TEXT_LEN (160)
#define BUFF_HUD_TICK_MS (15000)

enum E_BUFF
{
	bool:E_BUFF_USED,
	E_BUFF_KEY[BUFF_KEY_LEN],
	E_BUFF_NAME[BUFF_NAME_LEN],
	E_BUFF_TEXT[BUFF_TEXT_LEN],
	E_BUFF_ENDS_AT,
	E_BUFF_TOTAL,
}

static s_Buffs[MAX_PLAYERS][BUFF_MAX][E_BUFF];

static Buff_Find(playerid,const key[])
{
	for (new i = 0;i < BUFF_MAX;i++)
	{
		if (s_Buffs[playerid][i][E_BUFF_USED] && !strcmp(s_Buffs[playerid][i][E_BUFF_KEY],key))
		{
			return i;
		}
	}

	return -1;
}

stock Buff_RefreshHud(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	new order[BUFF_MAX], count = 0, now = gettime();

	for (new i = 0;i < BUFF_MAX;i++)
	{
		if (s_Buffs[playerid][i][E_BUFF_USED] && s_Buffs[playerid][i][E_BUFF_ENDS_AT] > now)
		{
			new at = count++;

			while (at > 0 && s_Buffs[playerid][order[at - 1]][E_BUFF_ENDS_AT] > s_Buffs[playerid][i][E_BUFF_ENDS_AT])
			{
				order[at] = order[at - 1];
				at--;
			}

			order[at] = i;
		}
	}

	for (new slot = 0;slot < HUD_BUFF_SLOTS;slot++)
	{
		if (slot >= count)
		{
			Hud_SetBuffSlot(playerid,slot,"",0.0);
			continue;
		}

		new i = order[slot], left = s_Buffs[playerid][i][E_BUFF_ENDS_AT] - now, label[HUD_BUFF_LABEL_LEN];

		if (left >= 3600)
		{
			format(label,sizeof(label),"%s  %dh %02dm",s_Buffs[playerid][i][E_BUFF_NAME],left / 3600,(left % 3600) / 60);
		}
		else
		{
			format(label,sizeof(label),"%s  %d min",s_Buffs[playerid][i][E_BUFF_NAME],max(left / 60,1));
		}

		Hud_SetBuffSlot(playerid,slot,label,float(left) * 100.0 / float(max(s_Buffs[playerid][i][E_BUFF_TOTAL],left)));
	}
}

stock bool:Buff_Set(playerid,const key[],const name[],const text[],secondsLeft = 0,totalSeconds = 0)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return false;
	}

	new slot = Buff_Find(playerid,key);

	for (new i = 0;slot == -1 && i < BUFF_MAX;i++)
	{
		if (!s_Buffs[playerid][i][E_BUFF_USED])
		{
			slot = i;
		}
	}

	if (slot == -1)
	{
		return false;
	}

	if (totalSeconds <= 0)
	{
		totalSeconds = s_Buffs[playerid][slot][E_BUFF_USED] && !strcmp(s_Buffs[playerid][slot][E_BUFF_KEY],key) && s_Buffs[playerid][slot][E_BUFF_TOTAL] >= secondsLeft ? s_Buffs[playerid][slot][E_BUFF_TOTAL] : secondsLeft;
	}

	s_Buffs[playerid][slot][E_BUFF_USED] = true;
	strcopy(s_Buffs[playerid][slot][E_BUFF_KEY],key,BUFF_KEY_LEN);
	strcopy(s_Buffs[playerid][slot][E_BUFF_NAME],name,BUFF_NAME_LEN);
	strcopy(s_Buffs[playerid][slot][E_BUFF_TEXT],text,BUFF_TEXT_LEN);
	s_Buffs[playerid][slot][E_BUFF_ENDS_AT] = secondsLeft > 0 ? gettime() + secondsLeft : 0;
	s_Buffs[playerid][slot][E_BUFF_TOTAL] = secondsLeft > 0 ? totalSeconds : 0;
	Buff_RefreshHud(playerid);
	return true;
}

stock Buff_Clear(playerid,const key[])
{
	new slot = Util_IsValidPlayer(playerid) ? Buff_Find(playerid,key) : -1;

	if (slot != -1)
	{
		s_Buffs[playerid][slot][E_BUFF_USED] = false;
		Buff_RefreshHud(playerid);
	}
}

stock bool:Buff_Has(playerid,const key[])
{
	return Util_IsValidPlayer(playerid) && Buff_Find(playerid,key) != -1;
}

stock bool:Buff_GetAt(playerid,index,name[],text[],&secondsLeft,nameSize = sizeof(name),textSize = sizeof(text))
{
	for (new i = 0, seen = 0;Util_IsValidPlayer(playerid) && i < BUFF_MAX;i++)
	{
		if (!s_Buffs[playerid][i][E_BUFF_USED])
		{
			continue;
		}

		if (seen++ == index)
		{
			strcopy(name,s_Buffs[playerid][i][E_BUFF_NAME],nameSize);
			strcopy(text,s_Buffs[playerid][i][E_BUFF_TEXT],textSize);
			secondsLeft = s_Buffs[playerid][i][E_BUFF_ENDS_AT] > 0 ? max(0,s_Buffs[playerid][i][E_BUFF_ENDS_AT] - gettime()) : 0;
			return true;
		}
	}

	return false;
}

forward Buff_HudTick();

public Buff_HudTick()
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Buff_RefreshHud(playerid);
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	for (new i = 0;i < BUFF_MAX;i++)
	{
		s_Buffs[playerid][i][E_BUFF_USED] = false;
	}
}
