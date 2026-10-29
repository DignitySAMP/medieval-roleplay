enum E_LAW_SERVING
{
	E_LAW_SERVING_ROW,
	E_LAW_SERVING_KIND,
	E_LAW_SERVING_TOTAL,
	E_LAW_SERVING_SERVED,
	E_LAW_SERVING_SAVE_IN,
	bool:E_LAW_SERVING_PENDING,
}

static s_LawServing[MAX_PLAYERS][E_LAW_SERVING];
static s_LawFlogged[MAX_PLAYERS];
static bool:s_LawBranded[MAX_PLAYERS];

stock bool:Law_IsServing(playerid)
{
	return Util_IsValidPlayer(playerid) && s_LawServing[playerid][E_LAW_SERVING_KIND] != LAW_SENTENCE_NONE;
}

stock Law_GetServingKind(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_LawServing[playerid][E_LAW_SERVING_KIND] : LAW_SENTENCE_NONE;
}

stock Law_GetServingLeft(playerid)
{
	return Law_IsServing(playerid) ? max(s_LawServing[playerid][E_LAW_SERVING_TOTAL] - s_LawServing[playerid][E_LAW_SERVING_SERVED],0) : 0;
}

stock bool:Law_IsBranded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_LawBranded[playerid];
}

stock Law_GetFlogged(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_LawFlogged[playerid] : 0;
}

static Law_ClearServing(playerid)
{
	s_LawServing[playerid][E_LAW_SERVING_ROW] = 0;
	s_LawServing[playerid][E_LAW_SERVING_KIND] = LAW_SENTENCE_NONE;
	s_LawServing[playerid][E_LAW_SERVING_TOTAL] = 0;
	s_LawServing[playerid][E_LAW_SERVING_SERVED] = 0;
	s_LawServing[playerid][E_LAW_SERVING_SAVE_IN] = LAW_SAVE_SECONDS;
	s_LawServing[playerid][E_LAW_SERVING_PENDING] = false;
}

static Law_SaveServing(playerid)
{
	if (s_LawServing[playerid][E_LAW_SERVING_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE sentences SET served = %d, ticked_at = %d WHERE id = %d",s_LawServing[playerid][E_LAW_SERVING_SERVED],gettime(),s_LawServing[playerid][E_LAW_SERVING_ROW]));
	}
}

static Law_RefreshCue(playerid)
{
	new cue[48];

	switch (s_LawServing[playerid][E_LAW_SERVING_KIND])
	{
		case LAW_SENTENCE_PILLORY: strcopy(cue,"in the pillory");
		case LAW_SENTENCE_STOCKS: strcopy(cue,"in the stocks");
		default:
		{
			if (Law_IsBound(playerid))
			{
				strcopy(cue,"hands bound");
			}
			else if (s_LawBranded[playerid])
			{
				strcopy(cue,"branded");
			}
		}
	}

	Nametag_SetCue(playerid,NAMETAG_CUE_LAW,cue);
}

stock Law_UpdateCue(playerid)
{
	Law_RefreshCue(playerid);
}

stock bool:Law_LockServing(playerid)
{
	switch (s_LawServing[playerid][E_LAW_SERVING_KIND])
	{
		case LAW_SENTENCE_PILLORY, LAW_SENTENCE_STOCKS:
		{
			new bool:isStocks = s_LawServing[playerid][E_LAW_SERVING_KIND] == LAW_SENTENCE_STOCKS, device = Pillory_FindFree(isStocks);

			if (device == -1)
			{
				device = Pillory_FindFree(!isStocks);
				isStocks = !isStocks;
			}

			if (device != -1 && Pillory_Lock(playerid,device,isStocks))
			{
				s_LawServing[playerid][E_LAW_SERVING_KIND] = isStocks ? LAW_SENTENCE_STOCKS : LAW_SENTENCE_PILLORY;
				Law_RefreshCue(playerid);
				return true;
			}

			s_LawServing[playerid][E_LAW_SERVING_KIND] = LAW_SENTENCE_GAOL;
			return Gaol_Lock(playerid);
		}
		case LAW_SENTENCE_GAOL:
		{
			return Gaol_Lock(playerid);
		}
	}

	return false;
}

stock Law_Release(playerid,const why[])
{
	if (!Law_IsServing(playerid))
	{
		return;
	}

	new kind = s_LawServing[playerid][E_LAW_SERVING_KIND];

	if (kind == LAW_SENTENCE_GAOL)
	{
		Gaol_Unlock(playerid);
	}
	else
	{
		Pillory_Unlock(playerid);
	}

	if (s_LawServing[playerid][E_LAW_SERVING_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE sentences SET served = %d, done = 1, ticked_at = %d, outcome = '%e' WHERE id = %d",s_LawServing[playerid][E_LAW_SERVING_SERVED],gettime(),why,s_LawServing[playerid][E_LAW_SERVING_ROW]));
	}

	Law_ClearServing(playerid);
	Law_RefreshCue(playerid);
	pawn_call_public("Law_OnReleased","ds",playerid,why);
}

stock Law_AddServingMinutes(playerid,minutes)
{
	if (Law_IsServing(playerid))
	{
		s_LawServing[playerid][E_LAW_SERVING_TOTAL] += minutes * 60;
		mysql_tquery_s(g_Mysql,str_format("UPDATE sentences SET minutes = %d WHERE id = %d",s_LawServing[playerid][E_LAW_SERVING_TOTAL] / 60,s_LawServing[playerid][E_LAW_SERVING_ROW]));
	}
}

stock Law_ServeTick(playerid,seconds)
{
	if (!Law_IsServing(playerid) || s_LawServing[playerid][E_LAW_SERVING_PENDING] || !Session_IsPlaying(playerid))
	{
		return;
	}

	s_LawServing[playerid][E_LAW_SERVING_SERVED] += seconds;
	s_LawServing[playerid][E_LAW_SERVING_SAVE_IN] -= seconds;

	if (s_LawServing[playerid][E_LAW_SERVING_SERVED] >= s_LawServing[playerid][E_LAW_SERVING_TOTAL])
	{
		Law_Release(playerid,"served");
		Gui_Notify(playerid,"Your time is served. You're free to go.");
		return;
	}

	if (s_LawServing[playerid][E_LAW_SERVING_SAVE_IN] <= 0)
	{
		s_LawServing[playerid][E_LAW_SERVING_SAVE_IN] = LAW_SAVE_SECONDS;
		Law_SaveServing(playerid);
	}
}

static Law_ApplyMark(playerid,bool:isBrand)
{
	if (isBrand)
	{
		s_LawBranded[playerid] = true;
	}
	else
	{
		s_LawFlogged[playerid]++;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO law_marks (character_id, flogged, branded) VALUES (%d, %d, %d) ON DUPLICATE KEY UPDATE flogged = VALUES(flogged), branded = VALUES(branded)",Character_GetId(playerid),s_LawFlogged[playerid],_:s_LawBranded[playerid]));
	Law_RefreshCue(playerid);
}

stock bool:Law_Sentence(playerid,kind,minutes,fine,byid = INVALID_PLAYER_ID)
{
	if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid) || kind <= LAW_SENTENCE_NONE || kind >= LAW_SENTENCE_COUNT || Law_IsServing(playerid))
	{
		return false;
	}

	new by = Util_IsValidPlayer(byid) ? Character_GetId(byid) : 0, text[160], money[24];

	switch (kind)
	{
		case LAW_SENTENCE_FINE:
		{
			Economy_Format(fine,money);

			if (Economy_Pay(playerid,fine,INVALID_CONTAINER_ID,"fine") != PAY_OK)
			{
				format(text,sizeof(text),"You can't pay the fine of %s, so you're put in the stocks instead.",money);
				Gui_Notify(playerid,text);
				return Law_Sentence(playerid,LAW_SENTENCE_STOCKS,max(10,fine / 6),0,byid);
			}

			format(text,sizeof(text),"You pay a fine of %s to the county.",money);
			Gui_Notify(playerid,text);
			Law_ClearWanted(playerid);
		}
		case LAW_SENTENCE_FLOG:
		{
			new Float:health = Vitals_GetHealth(playerid);

			if (health > LAW_FLOG_FLOOR)
			{
				Vitals_Damage(playerid,Util_Clamp(health - LAW_FLOG_FLOOR,0.0,LAW_FLOG_HEALTH),"flogging");
			}

			Law_ApplyMark(playerid,false);
			ApplyAnimation(playerid,"PED","KO_shot_stom",4.1,false,false,false,true,0,SYNC_ALL);
			Gui_Notify(playerid,"You're flogged before the crowd. The lash marks will scar.");
			Law_ClearWanted(playerid);
		}
		case LAW_SENTENCE_BRAND:
		{
			Law_ApplyMark(playerid,true);
			Gui_Notify(playerid,"You're branded. Everyone who looks at you will see it.");
			Law_ClearWanted(playerid);
		}
		case LAW_SENTENCE_BANISH:
		{
			mysql_tquery_s(g_Mysql,str_format("INSERT INTO banishments (character_id, county_id, until) VALUES (%d, %d, NULL) ON DUPLICATE KEY UPDATE until = NULL",Character_GetId(playerid),LAW_COUNTY));
			Gui_Notify(playerid,"You're banished from the county. Coming back makes you an outlaw.");
			Law_ClearWanted(playerid);
		}
		case LAW_SENTENCE_EXECUTE:
		{
			Law_ClearWanted(playerid);
			Lineage_SetLifeClock(playerid,0);
			Vitals_Damage(playerid,1000.0,"execution");
		}
		default:
		{
			s_LawServing[playerid][E_LAW_SERVING_KIND] = kind;
			s_LawServing[playerid][E_LAW_SERVING_TOTAL] = max(minutes,1) * 60;
			s_LawServing[playerid][E_LAW_SERVING_SERVED] = 0;
			s_LawServing[playerid][E_LAW_SERVING_SAVE_IN] = LAW_SAVE_SECONDS;
			s_LawServing[playerid][E_LAW_SERVING_PENDING] = false;

			if (!Law_LockServing(playerid))
			{
				Law_ClearServing(playerid);
				return false;
			}

			Law_ClearWanted(playerid);
			Law_InsertServing(playerid,s_LawServing[playerid][E_LAW_SERVING_KIND],minutes,by);
			if (s_LawServing[playerid][E_LAW_SERVING_KIND] == LAW_SENTENCE_GAOL)
			{
				format(text,sizeof(text),"You're put in the gaol for %d minutes. Time counts in full while you play, half while you're away.",minutes);
			}
			else
			{
				format(text,sizeof(text),"You're locked in the %s for %d minutes. Time only counts while you play.",g_LawSentenceNames[s_LawServing[playerid][E_LAW_SERVING_KIND]],minutes);
			}

			Gui_Notify(playerid,text);
		}
	}

	if (kind != LAW_SENTENCE_PILLORY && kind != LAW_SENTENCE_STOCKS && kind != LAW_SENTENCE_GAOL)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO sentences (character_id, kind, county_id, minutes, served, fine, sentenced_by, at, done, outcome) VALUES (%d, %d, %d, 0, 0, %d, %d, %d, 1, 'given')",Character_GetId(playerid),kind,LAW_COUNTY,fine,by,gettime()));
	}

	pawn_call_public("Law_OnSentenced","ddd",playerid,kind,minutes);
	return true;
}

static Law_InsertServing(playerid,kind,minutes,by)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO sentences (character_id, kind, county_id, minutes, served, fine, sentenced_by, at, ticked_at, done) VALUES (%d, %d, %d, %d, 0, 0, %d, %d, %d, 0)",characterid,kind,LAW_COUNTY,minutes,by,gettime(),gettime()));

	new row = cache_insert_id();

	if (Character_GetId(playerid) == characterid && Law_IsServing(playerid))
	{
		s_LawServing[playerid][E_LAW_SERVING_ROW] = row;
	}
}

forward Task:Law_LoadServing(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Law_LoadServing(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, minutes, served, ticked_at FROM sentences WHERE character_id = %d AND done = 0 AND kind IN (%d, %d, %d) ORDER BY id DESC LIMIT 1",characterid,LAW_SENTENCE_PILLORY,LAW_SENTENCE_STOCKS,LAW_SENTENCE_GAOL));

	if (cache_num_rows() && Character_GetId(playerid) == characterid)
	{
		new row, kind, minutes, served, tickedAt;
		cache_get_value_name_int(0,"id",row);
		cache_get_value_name_int(0,"kind",kind);
		cache_get_value_name_int(0,"minutes",minutes);
		cache_get_value_name_int(0,"served",served);
		cache_get_value_name_int(0,"ticked_at",tickedAt);

		if (kind == LAW_SENTENCE_GAOL && tickedAt > 0)
		{
			served += max(gettime() - tickedAt,0) * LAW_GAOL_OFFLINE_PERCENT / 100;
		}

		s_LawServing[playerid][E_LAW_SERVING_ROW] = row;
		s_LawServing[playerid][E_LAW_SERVING_KIND] = kind;
		s_LawServing[playerid][E_LAW_SERVING_TOTAL] = minutes * 60;
		s_LawServing[playerid][E_LAW_SERVING_SERVED] = served;
		s_LawServing[playerid][E_LAW_SERVING_PENDING] = true;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT flogged, branded FROM law_marks WHERE character_id = %d",characterid));

	if (cache_num_rows() && Character_GetId(playerid) == characterid)
	{
		new branded;
		cache_get_value_name_int(0,"flogged",s_LawFlogged[playerid]);
		cache_get_value_name_int(0,"branded",branded);
		s_LawBranded[playerid] = branded != 0;
	}

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid && s_LawServing[playerid][E_LAW_SERVING_PENDING] && Session_IsPlaying(playerid))
	{
		SetTimerEx("Law_RelockDeferred",2500,false,"dd",playerid,characterid);
	}

	return async 1;
}
#pragma warning pop

forward Law_RelockDeferred(playerid,characterid);

public Law_RelockDeferred(playerid,characterid)
{
	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid || !s_LawServing[playerid][E_LAW_SERVING_PENDING] || !Session_IsPlaying(playerid))
	{
		return 1;
	}

	s_LawServing[playerid][E_LAW_SERVING_PENDING] = false;

	if (s_LawServing[playerid][E_LAW_SERVING_SERVED] >= s_LawServing[playerid][E_LAW_SERVING_TOTAL])
	{
		Law_SaveServing(playerid);
		mysql_tquery_s(g_Mysql,str_format("UPDATE sentences SET done = 1, outcome = 'served' WHERE id = %d",s_LawServing[playerid][E_LAW_SERVING_ROW]));
		Law_ClearServing(playerid);

		if (GetPlayerVirtualWorld(playerid) == GAOL_WORLD)
		{
			Gaol_Leave(playerid);
		}

		Gui_Notify(playerid,"Your time in the gaol was served while you were away. You're free.");
		Law_RefreshCue(playerid);
		return 1;
	}

	if (!Law_LockServing(playerid))
	{
		Law_ClearServing(playerid);
		return 1;
	}

	new text[128];
	format(text,sizeof(text),"You're still serving your sentence: %d minutes left.",max(Law_GetServingLeft(playerid) / 60,1));
	Gui_Notify(playerid,text);
	return 1;
}

forward Law_OnSentenced(playerid,kind,minutes);

public Law_OnSentenced(playerid,kind,minutes)
{
	return 1;
}

forward Law_OnReleased(playerid,const why[]);

public Law_OnReleased(playerid,const why[])
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Law_ClearServing(playerid);
	s_LawFlogged[playerid] = 0;
	s_LawBranded[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (Law_IsServing(playerid))
	{
		Law_SaveServing(playerid);
	}
}

hook Character_OnLoaded(playerid,characterid)
{
	Law_ClearServing(playerid);
	s_LawFlogged[playerid] = 0;
	s_LawBranded[playerid] = false;
	Law_LoadServing(playerid,characterid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to == SESSION_PLAYING)
	{
		Law_RefreshCue(playerid);

		if (s_LawServing[playerid][E_LAW_SERVING_PENDING])
		{
			SetTimerEx("Law_RelockDeferred",2500,false,"dd",playerid,Character_GetId(playerid));
		}
	}
}
