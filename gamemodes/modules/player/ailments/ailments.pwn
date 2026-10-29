enum E_AILMENT_ROW
{
	E_AILMENT_ROW_ID,
	E_AILMENT_ROW_STAGE,
	E_AILMENT_ROW_TURN,
	E_AILMENT_ROW_SEVERITY,
	bool:E_AILMENT_ROW_DIAGNOSED,
	bool:E_AILMENT_ROW_TREATED,
	E_AILMENT_ROW_SOURCE[32],
}

static s_Ailments[MAX_PLAYERS][AILMENT_MAX_ACTIVE][E_AILMENT_ROW];
static s_AilmentCount[MAX_PLAYERS];
static bool:s_AilmentMarks[MAX_PLAYERS][MARK_COUNT];
static bool:s_AilmentLoaded[MAX_PLAYERS];
static bool:s_AilmentRested[MAX_PLAYERS];

stock bool:Ailment_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_AilmentLoaded[playerid];
}

stock Ailment_GetCount(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_AilmentCount[playerid] : 0;
}

static Ailment_Index(playerid,ailment)
{
	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		if (s_Ailments[playerid][i][E_AILMENT_ROW_ID] == ailment)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Ailment_Has(playerid,ailment)
{
	return Util_IsValidPlayer(playerid) && Ailment_Index(playerid,ailment) != -1;
}

stock Ailment_GetAt(playerid,index)
{
	return Util_IsValidPlayer(playerid) && index >= 0 && index < s_AilmentCount[playerid] ? s_Ailments[playerid][index][E_AILMENT_ROW_ID] : -1;
}

stock Ailment_GetStage(playerid,ailment)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	return index == -1 ? -1 : s_Ailments[playerid][index][E_AILMENT_ROW_STAGE];
}

stock Ailment_GetStageTurn(playerid,ailment)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	return index == -1 ? 0 : s_Ailments[playerid][index][E_AILMENT_ROW_TURN];
}

stock Ailment_GetSeverity(playerid,ailment)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	return index == -1 ? 0 : s_Ailments[playerid][index][E_AILMENT_ROW_SEVERITY];
}

stock bool:Ailment_IsDiagnosed(playerid,ailment)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	return index != -1 && s_Ailments[playerid][index][E_AILMENT_ROW_DIAGNOSED];
}

stock bool:Ailment_HasMark(playerid,mark)
{
	return Util_IsValidPlayer(playerid) && mark > MARK_NONE && mark < MARK_COUNT && s_AilmentMarks[playerid][mark];
}

stock Ailment_GetWorkPenalty(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	new tiers = 0;
	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		tiers += Ailment_GetStageWork(s_Ailments[playerid][i][E_AILMENT_ROW_ID],s_Ailments[playerid][i][E_AILMENT_ROW_STAGE]);
	}

	if (s_AilmentMarks[playerid][MARK_LOST_FINGERS] || s_AilmentMarks[playerid][MARK_CROOKED_LIMB])
	{
		tiers++;
	}

	return tiers;
}

static Ailment_Persist(playerid,index)
{
	if (!Session_HasCharacter(playerid))
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO character_ailments (character_id, ailment, stage, stage_turn, severity, diagnosed, source) VALUES (%d, %d, %d, %d, %d, %d, '%e')",Character_GetId(playerid),s_Ailments[playerid][index][E_AILMENT_ROW_ID],s_Ailments[playerid][index][E_AILMENT_ROW_STAGE],s_Ailments[playerid][index][E_AILMENT_ROW_TURN],s_Ailments[playerid][index][E_AILMENT_ROW_SEVERITY],s_Ailments[playerid][index][E_AILMENT_ROW_DIAGNOSED] ? 1 : 0,s_Ailments[playerid][index][E_AILMENT_ROW_SOURCE]));
}

static Ailment_Erase(playerid,index)
{
	if (Session_HasCharacter(playerid))
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_ailments WHERE character_id = %d AND ailment = %d",Character_GetId(playerid),s_Ailments[playerid][index][E_AILMENT_ROW_ID]));
	}

	for (new i = index; i < s_AilmentCount[playerid] - 1; i++)
	{
		s_Ailments[playerid][i] = s_Ailments[playerid][i + 1];
	}

	s_AilmentCount[playerid]--;
}

static Ailment_Worst(playerid)
{
	new worst = -1, score = -1;
	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		new here = s_Ailments[playerid][i][E_AILMENT_ROW_STAGE] * 100 + s_Ailments[playerid][i][E_AILMENT_ROW_SEVERITY];
		if (here > score)
		{
			score = here;
			worst = i;
		}
	}

	return worst;
}

stock Ailment_GetCue(playerid,dest[],size = sizeof(dest))
{
	new worst = Util_IsValidPlayer(playerid) ? Ailment_Worst(playerid) : -1;
	if (worst == -1)
	{
		dest[0] = EOS;
		return;
	}

	Ailment_GetStageCue(s_Ailments[playerid][worst][E_AILMENT_ROW_ID],s_Ailments[playerid][worst][E_AILMENT_ROW_STAGE],dest,size);
}

static Ailment_RefreshLabel(playerid)
{
	new cue[AILMENT_CUE_LEN];
	Ailment_GetCue(playerid,cue);
	Nametag_SetCue(playerid,NAMETAG_CUE_AILMENT,cue);
}

static Ailment_Apply(playerid)
{
	new stamina = 0, hunger = 100, thirst = 100, health = 0;
	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		new ailment = s_Ailments[playerid][i][E_AILMENT_ROW_ID], stage = s_Ailments[playerid][i][E_AILMENT_ROW_STAGE];
		if (Ailment_GetStageStamina(ailment,stage) > stamina)
		{
			stamina = Ailment_GetStageStamina(ailment,stage);
		}
		if (Ailment_GetStageHunger(ailment,stage) > hunger)
		{
			hunger = Ailment_GetStageHunger(ailment,stage);
		}
		if (Ailment_GetStageThirst(ailment,stage) > thirst)
		{
			thirst = Ailment_GetStageThirst(ailment,stage);
		}
		if (Ailment_GetStageHealth(ailment,stage) > health)
		{
			health = Ailment_GetStageHealth(ailment,stage);
		}
	}

	Vitals_SetStaminaLimit(playerid,VITALS_MAX - float(stamina));
	Vitals_SetHealthLimit(playerid,VITALS_MAX - float(health));
	Needs_SetDrainFactor(playerid,NEED_HUNGER,hunger);
	Needs_SetDrainFactor(playerid,NEED_THIRST,thirst);
	Ailment_RefreshLabel(playerid);
}

static Ailment_EnterStage(playerid,index,stage)
{
	new ailment = s_Ailments[playerid][index][E_AILMENT_ROW_ID], text[AILMENT_CUE_LEN];
	s_Ailments[playerid][index][E_AILMENT_ROW_STAGE] = stage;
	s_Ailments[playerid][index][E_AILMENT_ROW_TURN] = 0;
	Ailment_Persist(playerid,index);
	Ailment_Apply(playerid);

	Ailment_GetStageSelfText(ailment,stage,text);
	if (text[0] != EOS && Session_IsPlaying(playerid))
	{
		Gui_Notify(playerid,text);
	}

	if (Ailment_StageDowns(ailment,stage) && Session_IsPlaying(playerid) && !Combat_IsStruckDown(playerid))
	{
		Combat_StrikeDown(playerid);
	}

	pawn_call_public("Ailment_OnStage","ddd",playerid,ailment,stage);
}

stock bool:Ailment_Give(playerid,ailment,const source[] = "",stage = 0)
{
	if (!Util_IsValidPlayer(playerid) || !s_AilmentLoaded[playerid] || !Ailment_IsValidStage(ailment,stage) || !Session_HasCharacter(playerid))
	{
		return false;
	}

	if (Ailment_Index(playerid,ailment) != -1 || s_AilmentCount[playerid] >= AILMENT_MAX_ACTIVE)
	{
		return false;
	}

	new index = s_AilmentCount[playerid]++;
	s_Ailments[playerid][index][E_AILMENT_ROW_ID] = ailment;
	s_Ailments[playerid][index][E_AILMENT_ROW_SEVERITY] = 0;
	s_Ailments[playerid][index][E_AILMENT_ROW_DIAGNOSED] = false;
	s_Ailments[playerid][index][E_AILMENT_ROW_TREATED] = false;
	strcopy(s_Ailments[playerid][index][E_AILMENT_ROW_SOURCE],source,32);
	Ailment_EnterStage(playerid,index,stage);
	pawn_call_public("Ailment_OnGiven","dds",playerid,ailment,source);
	return true;
}

stock bool:Ailment_GiveMark(playerid,mark)
{
	if (!Util_IsValidPlayer(playerid) || mark <= MARK_NONE || mark >= MARK_COUNT || !Session_HasCharacter(playerid) || s_AilmentMarks[playerid][mark])
	{
		return false;
	}

	s_AilmentMarks[playerid][mark] = true;
	mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO character_marks (character_id, mark, since_turn) VALUES (%d, %d, %d)",Character_GetId(playerid),mark,Ailment_CurrentTurn()));
	pawn_call_public("Ailment_OnMark","dd",playerid,mark);
	return true;
}

stock bool:Ailment_HealMark(playerid,mark)
{
	if (!Ailment_HasMark(playerid,mark))
	{
		return false;
	}

	s_AilmentMarks[playerid][mark] = false;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_marks WHERE character_id = %d AND mark = %d",Character_GetId(playerid),mark));
	return true;
}

stock Ailment_CurrentTurn()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Calendar_DaysSinceEpoch(day,month,year);
}

stock bool:Ailment_Cure(playerid,ailment,const source[] = "cured")
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	if (index == -1)
	{
		return false;
	}

	Ailment_Erase(playerid,index);
	Ailment_Apply(playerid);
	pawn_call_public("Ailment_OnCured","dds",playerid,ailment,source);
	return true;
}

stock bool:Ailment_Diagnose(playerid,ailment)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	if (index == -1)
	{
		return false;
	}

	s_Ailments[playerid][index][E_AILMENT_ROW_DIAGNOSED] = true;
	Ailment_Persist(playerid,index);
	return true;
}

stock Ailment_MarkRested(playerid)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_AilmentRested[playerid] = true;
	}
}

stock bool:Ailment_HasRested(playerid)
{
	return Util_IsValidPlayer(playerid) && s_AilmentRested[playerid];
}

stock bool:Ailment_IsLethalNow(playerid)
{
	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_AilmentCount[playerid];i++)
	{
		if (Ailment_StageIsLethal(s_Ailments[playerid][i][E_AILMENT_ROW_ID],s_Ailments[playerid][i][E_AILMENT_ROW_STAGE]))
		{
			return true;
		}
	}

	return false;
}

stock bool:Ailment_IsTreated(playerid,ailment)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	return index != -1 && s_Ailments[playerid][index][E_AILMENT_ROW_TREATED];
}

stock bool:Ailment_Treat(playerid,ailment,quality = 1)
{
	new index = Util_IsValidPlayer(playerid) ? Ailment_Index(playerid,ailment) : -1;
	if (index == -1 || quality < 1)
	{
		return false;
	}

	if (quality > ITEM_STARS_MAX)
	{
		quality = ITEM_STARS_MAX;
	}

	s_Ailments[playerid][index][E_AILMENT_ROW_TREATED] = true;
	s_Ailments[playerid][index][E_AILMENT_ROW_SEVERITY] = Util_ClampInt(s_Ailments[playerid][index][E_AILMENT_ROW_SEVERITY] - quality * AILMENT_TREAT_SEVERITY,0,AILMENT_SEVERITY_MAX);
	Ailment_Persist(playerid,index);
	pawn_call_public("Ailment_OnTreated","ddd",playerid,ailment,quality);
	return true;
}

static Ailment_Care(playerid,index)
{
	new care = 0;
	if (Needs_GetHunger(playerid) >= 50)
	{
		care++;
	}
	if (Needs_GetThirst(playerid) >= 50)
	{
		care++;
	}
	if (Warmth_GetBand(playerid) == WARMTH_BAND_FINE || Warmth_GetBand(playerid) == WARMTH_BAND_WARM)
	{
		care++;
	}
	if (Character_GetAttribute(playerid,_:ATTR_WILLPOWER) >= 4)
	{
		care++;
	}
	if (s_Ailments[playerid][index][E_AILMENT_ROW_TREATED])
	{
		care += 2;
	}

	if (s_AilmentRested[playerid])
	{
		care += AILMENT_REST_CARE;
	}

	return care;
}

static Ailment_Finish(playerid,index)
{
	new ailment = s_Ailments[playerid][index][E_AILMENT_ROW_ID], stage = s_Ailments[playerid][index][E_AILMENT_ROW_STAGE];
	if (Ailment_StageIsLethal(ailment,stage) && s_Ailments[playerid][index][E_AILMENT_ROW_SEVERITY] >= AILMENT_SEVERITY_LETHAL)
	{
		new name[AILMENT_NAME_LEN];
		Ailment_GetName(ailment,name);
		Ailment_Erase(playerid,index);
		Ailment_Apply(playerid);
		pawn_call_public("Ailment_OnDeath","dd",playerid,ailment);
		Vitals_SetHealth(playerid,0.0,name);
		return;
	}

	new mark = Ailment_GetMark(ailment);
	if (mark != MARK_NONE)
	{
		Ailment_GiveMark(playerid,mark);
	}

	Ailment_Cure(playerid,ailment,"recovered");
	if (ailment == AILMENT_ROTTEN_TEETH)
	{
		Ailment_Give(playerid,AILMENT_FEVER,"abscess");
	}
}

stock Ailment_Turn(playerid)
{
	if (!Util_IsValidPlayer(playerid) || !s_AilmentLoaded[playerid] || !Session_HasCharacter(playerid))
	{
		return;
	}

	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		new ailment = s_Ailments[playerid][i][E_AILMENT_ROW_ID], stage = s_Ailments[playerid][i][E_AILMENT_ROW_STAGE], care = Ailment_Care(playerid,i);
		s_Ailments[playerid][i][E_AILMENT_ROW_SEVERITY] = Util_ClampInt(s_Ailments[playerid][i][E_AILMENT_ROW_SEVERITY] + (2 - care) * AILMENT_SEVERITY_STEP,0,AILMENT_SEVERITY_MAX);
		s_Ailments[playerid][i][E_AILMENT_ROW_TREATED] = false;

		if (care >= AILMENT_CARE_RECEDE && stage > 0)
		{
			Ailment_EnterStage(playerid,i,stage - 1);
			continue;
		}

		new turns = Ailment_GetStageTurns(ailment,stage);
		s_Ailments[playerid][i][E_AILMENT_ROW_TURN]++;
		if (turns == AILMENT_TURNS_CHRONIC || s_Ailments[playerid][i][E_AILMENT_ROW_TURN] < turns)
		{
			Ailment_Persist(playerid,i);
			continue;
		}

		if (ailment == AILMENT_WOUND && stage == 0 && s_Ailments[playerid][i][E_AILMENT_ROW_SEVERITY] >= AILMENT_WOUND_INFECTS)
		{
			Ailment_Erase(playerid,i);
			Ailment_Give(playerid,AILMENT_GANGRENE,"dirty wound");
			i--;
			continue;
		}

		if (stage + 1 < Ailment_GetStageCount(ailment))
		{
			Ailment_EnterStage(playerid,i,stage + 1);
			continue;
		}

		new before = s_AilmentCount[playerid];
		Ailment_Finish(playerid,i);
		if (s_AilmentCount[playerid] < before)
		{
			i--;
		}
	}

	s_AilmentRested[playerid] = false;
}

static Ailment_HourDrain(playerid)
{
	new Float:drain = 0.0;
	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		drain += Ailment_GetStageDrain(s_Ailments[playerid][i][E_AILMENT_ROW_ID],s_Ailments[playerid][i][E_AILMENT_ROW_STAGE]);
	}

	if (drain > 0.0 && Session_IsPlaying(playerid))
	{
		new worst = Ailment_Worst(playerid), name[AILMENT_NAME_LEN];
		Ailment_GetName(s_Ailments[playerid][worst][E_AILMENT_ROW_ID],name);
		Vitals_Damage(playerid,drain,name);
	}
}

static Ailment_Spread(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	for (new i = 0; i < s_AilmentCount[playerid]; i++)
	{
		new ailment = s_Ailments[playerid][i][E_AILMENT_ROW_ID];
		if (!Ailment_StageSpreads(ailment,s_Ailments[playerid][i][E_AILMENT_ROW_STAGE]))
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		foreach(new other : Player)
		{
			if (other == playerid || !Session_IsPlaying(other) || GetPlayerVirtualWorld(other) != GetPlayerVirtualWorld(playerid) || Ailment_Has(other,ailment))
			{
				continue;
			}

			if (IsPlayerInRangeOfPoint(other,AILMENT_SPREAD_RANGE,x,y,z) && random(100) < AILMENT_SPREAD_PERCENT && Ailment_Give(other,ailment,"caught"))
			{
				pawn_call_public("Ailment_OnSpread","ddd",playerid,other,ailment);
			}
		}
	}
}

Ailment_Reset(playerid)
{
	s_AilmentCount[playerid] = 0;
	s_AilmentLoaded[playerid] = false;
	s_AilmentRested[playerid] = false;
	for (new mark = 0; mark < MARK_COUNT; mark++)
	{
		s_AilmentMarks[playerid][mark] = false;
	}

	Nametag_SetCue(playerid,NAMETAG_CUE_AILMENT,"");
}

static Ailment_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT ailment, stage, stage_turn, severity, diagnosed, source FROM character_ailments WHERE character_id = %d ORDER BY ailment LIMIT %d",characterid,AILMENT_MAX_ACTIVE));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new rows = cache_num_rows();
	s_AilmentCount[playerid] = 0;
	for (new r = 0; r < rows; r++)
	{
		new slot = s_AilmentCount[playerid], diagnosed;
		cache_get_value_name_int(r,"ailment",s_Ailments[playerid][slot][E_AILMENT_ROW_ID]);
		cache_get_value_name_int(r,"stage",s_Ailments[playerid][slot][E_AILMENT_ROW_STAGE]);
		cache_get_value_name_int(r,"stage_turn",s_Ailments[playerid][slot][E_AILMENT_ROW_TURN]);
		cache_get_value_name_int(r,"severity",s_Ailments[playerid][slot][E_AILMENT_ROW_SEVERITY]);
		cache_get_value_name_int(r,"diagnosed",diagnosed);
		cache_get_value_name(r,"source",s_Ailments[playerid][slot][E_AILMENT_ROW_SOURCE],32);
		s_Ailments[playerid][slot][E_AILMENT_ROW_DIAGNOSED] = diagnosed != 0;
		s_Ailments[playerid][slot][E_AILMENT_ROW_TREATED] = false;
		if (!Ailment_IsValidStage(s_Ailments[playerid][slot][E_AILMENT_ROW_ID],s_Ailments[playerid][slot][E_AILMENT_ROW_STAGE]))
		{
			continue;
		}

		s_AilmentCount[playerid]++;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT mark FROM character_marks WHERE character_id = %d",characterid));
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	rows = cache_num_rows();
	for (new r = 0; r < rows; r++)
	{
		new mark;
		cache_get_value_name_int(r,"mark",mark);
		if (mark > MARK_NONE && mark < MARK_COUNT)
		{
			s_AilmentMarks[playerid][mark] = true;
		}
	}

	s_AilmentLoaded[playerid] = true;
	Ailment_Apply(playerid);
	pawn_call_public("Ailment_OnLoaded","d",playerid);
}

static Ailment_DescribeTo(playerid,targetid)
{
	new line[96], name[AILMENT_NAME_LEN];
	if (s_AilmentCount[targetid] == 0)
	{
		SendClientMessage(playerid,-1,"No ailments.");
	}

	for (new i = 0; i < s_AilmentCount[targetid]; i++)
	{
		Ailment_GetName(s_Ailments[targetid][i][E_AILMENT_ROW_ID],name);
		format(line,sizeof(line),"%d %s: stage %d, turn %d, severity %d%s",s_Ailments[targetid][i][E_AILMENT_ROW_ID],name,s_Ailments[targetid][i][E_AILMENT_ROW_STAGE],s_Ailments[targetid][i][E_AILMENT_ROW_TURN],s_Ailments[targetid][i][E_AILMENT_ROW_SEVERITY],s_Ailments[targetid][i][E_AILMENT_ROW_TREATED] ? (" (treated)") : (""));
		SendClientMessage(playerid,-1,line);
	}
}

CMD:ailment(cmdid, playerid, params[])
{
	new targetid, ailment, name[AILMENT_NAME_LEN];
	if (sscanf(params,"ui",targetid,ailment) || !Ailment_IsValid(ailment))
	{
		Command_Usage(playerid,cmdid,"<player> <0..19>");
		return 1;
	}

	Ailment_GetName(ailment,name);
	SendClientMessage(playerid,-1,Ailment_Give(targetid,ailment,"staff") ? name : ("Not given."));
	return 1;
}

CMD:ailturn(cmdid, playerid, params[])
{
	new targetid;
	if (sscanf(params,"u",targetid) || !Session_HasCharacter(targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Ailment_Turn(targetid);
	Ailment_DescribeTo(playerid,targetid);
	return 1;
}

CMD:ails(cmdid, playerid, params[])
{
	new targetid;
	if (sscanf(params,"u",targetid) || !Session_HasCharacter(targetid))
	{
		Command_Usage(playerid,cmdid,"<player>");
		return 1;
	}

	Ailment_DescribeTo(playerid,targetid);
	return 1;
}

CMD:treat(cmdid, playerid, params[])
{
	new targetid, ailment, quality = 1;
	if (sscanf(params,"uiI(1)",targetid,ailment,quality))
	{
		Command_Usage(playerid,cmdid,"<player> <ailment> [quality 1-5]");
		return 1;
	}

	SendClientMessage(playerid,-1,Ailment_Treat(targetid,ailment,quality) ? ("Treated.") : ("Nothing to treat."));
	return 1;
}

CMD:cure(cmdid, playerid, params[])
{
	new targetid, ailment;
	if (sscanf(params,"ui",targetid,ailment))
	{
		Command_Usage(playerid,cmdid,"<player> <ailment>");
		return 1;
	}

	SendClientMessage(playerid,-1,Ailment_Cure(targetid,ailment,"staff") ? ("Cured.") : ("Nothing to cure."));
	return 1;
}

forward Ailment_OnLoaded(playerid);

public Ailment_OnLoaded(playerid)
{
	return 1;
}

forward Ailment_OnGiven(playerid,ailment,const source[]);

public Ailment_OnGiven(playerid,ailment,const source[])
{
	return 1;
}

forward Ailment_OnStage(playerid,ailment,stage);

public Ailment_OnStage(playerid,ailment,stage)
{
	return 1;
}

forward Ailment_OnTreated(playerid,ailment,quality);

public Ailment_OnTreated(playerid,ailment,quality)
{
	return 1;
}

forward Ailment_OnCured(playerid,ailment,const source[]);

public Ailment_OnCured(playerid,ailment,const source[])
{
	return 1;
}

forward Ailment_OnDeath(playerid,ailment);

public Ailment_OnDeath(playerid,ailment)
{
	return 1;
}

forward Ailment_OnSpread(fromid,toid,ailment);

public Ailment_OnSpread(fromid,toid,ailment)
{
	return 1;
}

forward Ailment_OnMark(playerid,mark);

public Ailment_OnMark(playerid,mark)
{
	return 1;
}

forward Ailment_LoadDeferred(playerid,token);

public Ailment_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Ailment_Load(playerid,token);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Ailment_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Ailment_Reset(playerid);
	SetTimerEx("Ailment_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Ailment_Reset(playerid);
}

hook OnPlayerSpawn(playerid)
{
	if (s_AilmentLoaded[playerid])
	{
		Ailment_Apply(playerid);
	}
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year

	foreach(new i : Player)
	{
		Ailment_Turn(i);
	}
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour

	foreach(new i : Player)
	{
		if (!s_AilmentLoaded[i])
		{
			continue;
		}

		Ailment_HourDrain(i);
		Ailment_Spread(i);
		if (Warmth_GetBand(i) == WARMTH_BAND_FREEZING && Ailment_Has(i,AILMENT_CHILLS))
		{
			Ailment_Give(i,AILMENT_FROSTBITE,"cold");
		}
	}
}

hook Warmth_OnBandChanged(playerid,from,to)
{
	#pragma unused from

	if (E_WARMTH_BAND:to == WARMTH_BAND_FREEZING)
	{
		Ailment_Give(playerid,AILMENT_CHILLS,"cold");
	}
	else if (E_WARMTH_BAND:to == WARMTH_BAND_HOT)
	{
		Ailment_Give(playerid,AILMENT_HEATSTROKE,"heat");
	}
}
