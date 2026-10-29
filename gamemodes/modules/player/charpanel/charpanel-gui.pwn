#define CHARPANEL_WIDTH (340.0)
#define CHARPANEL_ROWS (15)
#define CHARPANEL_TAB_YOU (1000)
#define CHARPANEL_TAB_HEALTH (1001)
#define CHARPANEL_TAB_SKILLS (1002)
#define CHARPANEL_TAB_BUFFS (1003)
#define CHARPANEL_TAB_FAMILY (1004)
#define CHARPANEL_TAB_LEDGER (1005)
#define CHARPANEL_TITLE "Yourself"
#define CHARPANEL_INFO_WIDTH (300.0)
#define CHARPANEL_INFO_CHARS (60)
#define CHARPANEL_INFO_LEN (1000)

#define CHARPANEL_PICK_AGE (2000)
#define CHARPANEL_PICK_PEOPLE (2001)
#define CHARPANEL_PICK_RAISED (2002)
#define CHARPANEL_PICK_LIFE (2003)
#define CHARPANEL_PICK_CHURCH (2004)
#define CHARPANEL_PICK_GROUPS (2005)
#define CHARPANEL_GROUPS_LEN (64)
#define CHARPANEL_PICK_HEALTH (3000)
#define CHARPANEL_PICK_STAMINA (3001)
#define CHARPANEL_PICK_FED (3002)
#define CHARPANEL_PICK_HYDRATED (3003)
#define CHARPANEL_PICK_WARMTH (3004)
#define CHARPANEL_PICK_WOUND (3200)
#define CHARPANEL_PICK_AILMENT (3100)
#define CHARPANEL_PICK_BUFF_PREV (4000)
#define CHARPANEL_PICK_BUFF_NEXT (4001)
#define CHARPANEL_BUFF_CHARS (64)

enum
{
	CHARPANEL_YOU,
	CHARPANEL_HEALTH,
	CHARPANEL_SKILLS,
	CHARPANEL_BUFFS,
	CHARPANEL_FAMILY,
}

static s_CharPanelGroups[MAX_PLAYERS][CHARPANEL_GROUPS_LEN];

static CharPanel_Row(playerid,Float:x,Float:y,Float:width,row,const label[],const value[],valueColour = KIT_COLOUR_TEXT)
{
	Kit_AddText(playerid,x,y + float(row) * KIT_ROW,label,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.38);
	Kit_AddText(playerid,x + width * 0.38,y + float(row) * KIT_ROW,value,valueColour,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.62);
}

static CharPanel_Choice(playerid,Float:x,Float:y,Float:width,row,const label[],const value[],pick,valueColour = KIT_COLOUR_TEXT)
{
	Kit_AddChoice(playerid,x,y + float(row) * KIT_ROW,width,label,pick,KIT_COLOUR_MUTED,value,valueColour,0.38);
}

static CharPanel_DrawYou(playerid,Float:x,Float:y,Float:width)
{
	new line[64], culture[CULTURE_NAME_LEN], row = 0;
	Character_GetName(playerid,line);
	CharPanel_Row(playerid,x,y,width,row++,"Name",line,KIT_COLOUR_ACCENT);
	format(line,sizeof(line),"%s, %d years old",Character_GetSex(playerid) ? ("a woman") : ("a man"),Lineage_GetAge(playerid));
	CharPanel_Choice(playerid,x,y,width,row++,"Age",line,CHARPANEL_PICK_AGE);
	Culture_GetName(Character_GetCulture(playerid),culture);
	CharPanel_Choice(playerid,x,y,width,row++,"People",culture,CHARPANEL_PICK_PEOPLE);
	Creator_OriginName(E_ORIGIN:Character_GetOrigin(playerid),line);
	CharPanel_Choice(playerid,x,y,width,row++,"Raised",line,CHARPANEL_PICK_RAISED);
	Creator_LifestyleName(E_LIFESTYLE:Character_GetLifestyle(playerid),line);
	CharPanel_Choice(playerid,x,y,width,row++,"Life",line,CHARPANEL_PICK_LIFE);
	Clergy_GetTitle(playerid,line);

	if (line[0] != EOS)
	{
		CharPanel_Choice(playerid,x,y,width,row++,"Church",line,CHARPANEL_PICK_CHURCH);
	}
	else
	{
		row++;
	}

	for (new E_ATTRIBUTE:attr = ATTR_WILLPOWER;attr < ATTR_COUNT;attr++)
	{
		Creator_AttributeName(attr,line);
		Kit_AddText(playerid,x,y + float(row) * KIT_ROW,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.38);
		Kit_AddPips(playerid,x + width * 0.38,y + float(row) * KIT_ROW + 2.0,Character_GetAttribute(playerid,_:attr),5,Creator_AttributeColour(attr));
		row++;
	}

	if (s_CharPanelGroups[playerid][0] != EOS)
	{
		CharPanel_Choice(playerid,x,y,width,row,"Groups",s_CharPanelGroups[playerid],CHARPANEL_PICK_GROUPS,KIT_COLOUR_ACCENT);
	}

	row++;

	for (new i = 0;i < 2;i++)
	{
		new raw = Character_GetTrait(playerid,i == 1), E_TRAIT:trait = E_TRAIT:raw, text[96];

		if (raw >= 0 && trait < TRAIT_COUNT)
		{
			Creator_TraitName(trait,line);
			Creator_TraitText(trait,text);
			CharPanel_Row(playerid,x,y,width,row++,line,text);
		}
	}

	Kit_AddText(playerid,x,y + float(CHARPANEL_ROWS - 1) * KIT_ROW,"Click a line to read more.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
}

stock CharPanel_SetGroups(playerid,const text[])
{
	if (Util_IsValidPlayer(playerid))
	{
		strcopy(s_CharPanelGroups[playerid],text,CHARPANEL_GROUPS_LEN);
	}
}

static CharPanel_Percent(Float:value,dest[],size = sizeof(dest))
{
	format(dest,size,"%d%%",floatround(value));
}

static CharPanel_Duration(seconds,dest[],size = sizeof(dest))
{
	if (seconds >= 5400)
	{
		format(dest,size,"%d hours",(seconds + 1800) / 3600);
	}
	else if (seconds >= 3000)
	{
		strcopy(dest,"an hour",size);
	}
	else
	{
		format(dest,size,"%d minutes",max(5,(seconds + 150) / 300 * 5));
	}
}

static CharPanel_NeedLine(playerid,E_NEED:need,dest[],size = sizeof(dest))
{
	new value = Needs_Get(playerid,need), left = Needs_GetSecondsUntilLow(playerid,need), duration[16];

	if (value <= 0)
	{
		format(dest,size,"0%%, it's costing you health");
	}
	else if (left <= 0)
	{
		format(dest,size,"%d%%, you're %s",value,need == NEED_HUNGER ? ("hungry") : ("thirsty"));
	}
	else
	{
		CharPanel_Duration(left,duration);
		format(dest,size,"%d%%, %s in about %s",value,need == NEED_HUNGER ? ("hungry") : ("thirsty"),duration);
	}
}

static CharPanel_WoundLine(playerid,index,dest[],size = sizeof(dest))
{
	new part, kind, severity, flags, Float:bleed;
	Wounds_GetAt(playerid,index,part,kind,severity,flags,bleed);
	Wounds_Describe(kind,severity,dest,size);

	if (bleed > 0.0)
	{
		strcat(dest,", bleeding",size);
	}
	else if (flags & WOUND_FLAG_FESTERING)
	{
		strcat(dest,", festering",size);
	}
	else if (flags & WOUND_FLAG_SPLINTED)
	{
		strcat(dest,", splinted",size);
	}
	else if (flags & WOUND_FLAG_BANDAGED)
	{
		strcat(dest,", bandaged",size);
	}

	return (bleed > 0.0 || (flags & WOUND_FLAG_FESTERING) || severity == WOUND_GRAVE) ? KIT_COLOUR_BAD : KIT_COLOUR_ACCENT;
}

static CharPanel_WorstWoundOn(playerid,part,&count)
{
	new worst = -1, worstScore = -1;
	count = 0;

	for (new i = 0;i < Wounds_Count(playerid);i++)
	{
		new woundPart, kind, severity, flags, Float:bleed;
		Wounds_GetAt(playerid,i,woundPart,kind,severity,flags,bleed);

		if (woundPart != part)
		{
			continue;
		}

		new score = severity * 10 + (bleed > 0.0 ? 5 : 0) + ((flags & WOUND_FLAG_FESTERING) ? 3 : 0);
		count++;

		if (score > worstScore)
		{
			worst = i;
			worstScore = score;
		}
	}

	return worst;
}

static CharPanel_DrawHealth(playerid,Float:x,Float:y,Float:width)
{
	new line[96], row = 0, season[16], interior = GetPlayerInterior(playerid), Float:px, Float:py, Float:pz;
	CharPanel_Percent(Vitals_GetHealth(playerid),line);

	if (Vitals_GetHealthLimit(playerid) < VITALS_MAX)
	{
		format(line,sizeof(line),"%s, at most %d%% while you're ill",line,floatround(Vitals_GetHealthLimit(playerid)));
	}

	CharPanel_Choice(playerid,x,y,width,row++,"Health",line,CHARPANEL_PICK_HEALTH);
	CharPanel_Percent(Vitals_GetStamina(playerid),line);

	if (Vitals_GetStaminaCap(playerid) < VITALS_MAX)
	{
		format(line,sizeof(line),"%s, at most %d%%",line,floatround(Vitals_GetStaminaCap(playerid)));
	}

	CharPanel_Choice(playerid,x,y,width,row++,"Stamina",line,CHARPANEL_PICK_STAMINA);
	CharPanel_NeedLine(playerid,NEED_HUNGER,line);
	CharPanel_Choice(playerid,x,y,width,row++,"Fed",line,CHARPANEL_PICK_FED,Needs_IsLow(playerid,NEED_HUNGER) ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
	CharPanel_NeedLine(playerid,NEED_THIRST,line);
	CharPanel_Choice(playerid,x,y,width,row++,"Hydrated",line,CHARPANEL_PICK_HYDRATED,Needs_IsLow(playerid,NEED_THIRST) ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
	Warmth_BandName(Warmth_GetBand(playerid),line);
	format(line,sizeof(line),"%s (your clothes give %d)",line,Warmth_GetClothing(playerid));
	CharPanel_Choice(playerid,x,y,width,row++,"Warmth",line,CHARPANEL_PICK_WARMTH);
	GetPlayerPos(playerid,px,py,pz);
	Calendar_SeasonName(Calendar_GetSeason(),season);
	format(line,sizeof(line),"%s, %.0f degrees%s",season,Calendar_GetTemperature(px,py,pz,interior),interior != 0 ? (" indoors") : (""));
	CharPanel_Row(playerid,x,y,width,row++,"Outside",line);
	Hygiene_Describe(playerid,line);
	CharPanel_Row(playerid,x,y,width,row++,"Clean",line,Hygiene_IsStinking(playerid) ? KIT_COLOUR_BAD : (Hygiene_GetDirt(playerid) >= HYGIENE_GRIMY ? KIT_COLOUR_ACCENT : KIT_COLOUR_GOOD));
	Carry_Describe(playerid,line);
	CharPanel_Row(playerid,x,y,width,row++,"Load",line,Carry_GetBand(playerid) == 2 ? KIT_COLOUR_BAD : (Carry_GetBand(playerid) == 1 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT));
	Fatigue_Describe(playerid,line);
	CharPanel_Row(playerid,x,y,width,row++,"Rest",line,Fatigue_GetBand(playerid) == 2 ? KIT_COLOUR_BAD : (Fatigue_GetBand(playerid) == 1 ? KIT_COLOUR_ACCENT : KIT_COLOUR_GOOD));

	new ailments = 0;

	for (new i = 0;i < Ailment_GetCount(playerid);i++)
	{
		Ailment_GetStageCue(Ailment_GetAt(playerid,i),Ailment_GetStage(playerid,Ailment_GetAt(playerid,i)),line);

		if (line[0] != EOS)
		{
			ailments++;
		}
	}

	for (new part = WOUND_PART_HEAD;part < WOUND_PART_COUNT;part++)
	{
		new partName[12], count, worst = CharPanel_WorstWoundOn(playerid,part,count);
		Wounds_PartName(part,partName);

		if (worst < 0)
		{
			CharPanel_Row(playerid,x,y,width,row++,partName,"unhurt",KIT_COLOUR_GOOD);
			continue;
		}

		new colour = CharPanel_WoundLine(playerid,worst,line);

		if (count > 1)
		{
			format(line,sizeof(line),"%s (%d wounds)",line,count);
		}

		CharPanel_Choice(playerid,x,y,width,row++,partName,line,CHARPANEL_PICK_WOUND + worst,colour);
	}

	if (Wounds_IsBleeding(playerid))
	{
		format(line,sizeof(line),"%.1f health a minute",Wounds_GetBleedRate(playerid) * 60.0);
		CharPanel_Row(playerid,x,y,width,row++,"Bleeding",line,KIT_COLOUR_BAD);
	}

	for (new i = 0;i < Ailment_GetCount(playerid) && row < CHARPANEL_ROWS - 1;i++)
	{
		new ailment = Ailment_GetAt(playerid,i), label[AILMENT_NAME_LEN];
		Ailment_GetStageCue(ailment,Ailment_GetStage(playerid,ailment),line);

		if (line[0] == EOS)
		{
			continue;
		}

		if (Ailment_IsDiagnosed(playerid,ailment))
		{
			Ailment_GetName(ailment,label);
		}
		else
		{
			strcopy(label,"You feel");
		}

		CharPanel_Choice(playerid,x,y,width,row++,label,line,CHARPANEL_PICK_AILMENT + i,KIT_COLOUR_BAD);
	}

	if (ailments == 0 && row < CHARPANEL_ROWS - 1)
	{
		CharPanel_Row(playerid,x,y,width,row++,"Illness","none",KIT_COLOUR_GOOD);
	}

	Kit_AddText(playerid,x,y + float(CHARPANEL_ROWS - 1) * KIT_ROW,"Click a line to read more.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
}

static CharPanel_DrawSkills(playerid,Float:x,Float:y,Float:width)
{
	new line[48], name[JOB_NAME_LEN], row = 0, shown = 0;
	format(line,sizeof(line),"%d to spend",Talent_GetPoints(playerid));
	CharPanel_Row(playerid,x,y,width,row++,"Talent points",line,KIT_COLOUR_ACCENT);
	row++;

	for (new trade = 0;trade < TRADE_COUNT && row < CHARPANEL_ROWS;trade++)
	{
		new level = Work_GetLevel(playerid,trade);

		if (level <= 0 && Work_GetPractice(playerid,trade) <= 0)
		{
			continue;
		}

		Trade_GetName(trade,name);
		format(line,sizeof(line),"level %d of %d",level,Work_GetLevelCap(playerid,trade));
		CharPanel_Row(playerid,x,y,width,row++,name,line);
		shown++;
	}

	if (shown == 0)
	{
		CharPanel_Row(playerid,x,y,width,row,"Trades","none yet. Work at a station to learn one.",KIT_COLOUR_MUTED);
	}
}

static CharPanel_GetBuffOrder(playerid,order[],size = sizeof(order))
{
	new name[BUFF_NAME_LEN], text[BUFF_TEXT_LEN], left, count = 0;

	for (new pass = 0;pass < 2;pass++)
	{
		for (new i = 0;count < size && Buff_GetAt(playerid,i,name,text,left);i++)
		{
			if ((left > 0) == (pass == 0))
			{
				order[count++] = i;
			}
		}
	}

	return count;
}

static CharPanel_GetBuffRows(playerid,index,label[],wrapped[],labelSize,wrappedSize)
{
	new name[BUFF_NAME_LEN], text[BUFF_TEXT_LEN], left, lines = 1;

	if (!Buff_GetAt(playerid,index,name,text,left))
	{
		return 0;
	}

	if (left > 0)
	{
		format(label,labelSize,"%s, %d min left",name,(left + 59) / 60);
	}
	else
	{
		strcopy(label,name,labelSize);
	}

	Util_WrapText(text,wrapped,wrappedSize,CHARPANEL_BUFF_CHARS,"~n~");

	for (new at = strfind(wrapped,"~n~");at != -1;at = strfind(wrapped,"~n~",false,at + 3))
	{
		lines++;
	}

	return lines + 2;
}

static CharPanel_DrawBuffs(playerid,Float:x,Float:y,Float:width,&page)
{
	new order[BUFF_MAX], count = CharPanel_GetBuffOrder(playerid,order), label[48], wrapped[BUFF_TEXT_LEN + 32], budget = CHARPANEL_ROWS - 1, pages = 1, used = 0, current = 0;

	if (count == 0)
	{
		page = 0;
		Kit_AddText(playerid,x,y,"Nothing is helping you right now.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		return;
	}

	for (new i = 0, rows;i < count;i++)
	{
		rows = CharPanel_GetBuffRows(playerid,order[i],label,wrapped,sizeof(label),sizeof(wrapped));

		if (used > 0 && used + rows - 1 > budget)
		{
			pages++;
			used = 0;
		}

		used += rows;
	}

	page = Util_ClampInt(page,0,pages - 1);
	used = 0;

	for (new i = 0, rows;i < count;i++)
	{
		rows = CharPanel_GetBuffRows(playerid,order[i],label,wrapped,sizeof(label),sizeof(wrapped));

		if (used > 0 && used + rows - 1 > budget)
		{
			current++;
			used = 0;
		}

		if (current == page)
		{
			Kit_AddText(playerid,x,y + float(used) * KIT_ROW,label,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
			Kit_AddText(playerid,x + 6.0,y + float(used + 1) * KIT_ROW,wrapped,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width - 6.0);
		}

		used += rows;
	}

	if (pages > 1)
	{
		new Float:pageY = y + float(CHARPANEL_ROWS - 1) * KIT_ROW, text[16];
		format(text,sizeof(text),"%d of %d",page + 1,pages);
		Kit_AddText(playerid,x,pageY,text,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.4);

		if (page > 0)
		{
			Kit_AddChoice(playerid,x + width * 0.4,pageY,width * 0.3,"< Back",CHARPANEL_PICK_BUFF_PREV,KIT_COLOUR_ACCENT);
		}

		if (page < pages - 1)
		{
			Kit_AddChoice(playerid,x + width * 0.7,pageY,width * 0.3,"More >",CHARPANEL_PICK_BUFF_NEXT,KIT_COLOUR_ACCENT);
		}
	}
}

static CharPanel_AddParagraph(dest[],const text[],size = sizeof(dest))
{
	new wrapped[CHARPANEL_INFO_LEN];
	Util_WrapText(text,wrapped,sizeof(wrapped),CHARPANEL_INFO_CHARS,"~n~");

	if (dest[0] != EOS)
	{
		strcat(dest,"~n~~n~",size);
	}

	strcat(dest,wrapped,size);
}

static CharPanel_AddLine(dest[],const text[],size = sizeof(dest))
{
	new wrapped[CHARPANEL_INFO_LEN];
	Util_WrapText(text,wrapped,sizeof(wrapped),CHARPANEL_INFO_CHARS,"~n~");

	if (dest[0] != EOS)
	{
		strcat(dest,"~n~",size);
	}

	strcat(dest,wrapped,size);
}

static CharPanel_ExplainAilment(playerid,index,title[],text[],titleSize,textSize)
{
	new ailment = Ailment_GetAt(playerid,index), stage = Ailment_GetStage(playerid,ailment), line[128];

	if (Ailment_IsDiagnosed(playerid,ailment))
	{
		Ailment_GetName(ailment,title,titleSize);
	}
	else
	{
		strcopy(title,"How you feel",titleSize);
	}

	Ailment_GetStageSelfText(ailment,stage,line);
	CharPanel_AddParagraph(text,line,textSize);
	strcat(text,"~n~",textSize);

	if (Ailment_GetStageStamina(ailment,stage) > 0)
	{
		format(line,sizeof(line),"Your stamina tops out ~r~%d lower~w~.",Ailment_GetStageStamina(ailment,stage));
		CharPanel_AddLine(text,line,textSize);
	}

	if (Ailment_GetStageHealth(ailment,stage) > 0)
	{
		format(line,sizeof(line),"Your health tops out ~r~%d lower~w~.",Ailment_GetStageHealth(ailment,stage));
		CharPanel_AddLine(text,line,textSize);
	}

	if (Ailment_GetStageHunger(ailment,stage) > 100)
	{
		format(line,sizeof(line),"You get hungry ~r~%d%% faster~w~.",Ailment_GetStageHunger(ailment,stage) - 100);
		CharPanel_AddLine(text,line,textSize);
	}

	if (Ailment_GetStageThirst(ailment,stage) > 100)
	{
		format(line,sizeof(line),"You get thirsty ~r~%d%% faster~w~.",Ailment_GetStageThirst(ailment,stage) - 100);
		CharPanel_AddLine(text,line,textSize);
	}

	if (Ailment_GetStageDrain(ailment,stage) > 0.0)
	{
		CharPanel_AddLine(text,"It slowly ~r~takes your health~w~.",textSize);
	}

	if (Ailment_GetStageWork(ailment,stage) > 0)
	{
		CharPanel_AddLine(text,"Your ~r~work at stations~w~ gets harder.",textSize);
	}

	if (Ailment_StageSpreads(ailment,stage))
	{
		CharPanel_AddLine(text,"It can ~r~pass to the people close to you~w~.",textSize);
	}

	if (Ailment_IsLethal(ailment))
	{
		CharPanel_AddLine(text,"~r~If it isn't treated, it can kill you.~w~",textSize);
	}
}

static CharPanel_AddSentences(dest[],const text[],size = sizeof(dest))
{
	new sentence[CHARPANEL_INFO_LEN], length = 0;

	for (new i = 0;text[i] != EOS;i++)
	{
		sentence[length++] = text[i];

		if ((text[i] == '.' || text[i] == '!') && (text[i + 1] == ' ' || text[i + 1] == EOS))
		{
			sentence[length] = EOS;
			new line[CHARPANEL_INFO_LEN];
			format(line,sizeof(line),"~y~-~w~ %s",sentence);
			CharPanel_AddLine(dest,line,size);
			length = 0;

			while (text[i + 1] == ' ')
			{
				i++;
			}
		}
	}

	if (length > 0)
	{
		sentence[length] = EOS;
		new line[CHARPANEL_INFO_LEN];
		format(line,sizeof(line),"~y~-~w~ %s",sentence);
		CharPanel_AddLine(dest,line,size);
	}
}

stock bool:CharPanel_Explain(playerid,pick,title[],text[],titleSize = sizeof(title),textSize = sizeof(text))
{
	new line[256], name[64], other[64];
	title[0] = EOS;
	text[0] = EOS;

	switch (pick)
	{
		case CHARPANEL_PICK_AGE:
		{
			new age = Lineage_GetAge(playerid), clock = Lineage_GetLifeClock(playerid);
			strcopy(title,"Your years",titleSize);

			if (clock > 0)
			{
				format(line,sizeof(line),"You're ~y~%d years~w~ old. Your life clock has ~r~%d %s~w~ left.",age,clock,clock == 1 ? ("death") : ("deaths"));
			}
			else
			{
				format(line,sizeof(line),"You're ~y~%d years~w~ old and ~r~marked by death~w~. Your next death is your last.",age);
			}

			CharPanel_AddParagraph(text,line,textSize);
			CharPanel_AddParagraph(text,"Dying in a fight, to a beast or by accident takes ~r~one~w~ death off your life clock. Dying of a grave illness takes ~r~two~w~. When the clock hits zero, ~r~your next death is permanent~w~.",textSize);
			CharPanel_AddParagraph(text,"The older you are, the fewer deaths your life clock holds. It starts at ~y~five~w~ for the young and drops to ~y~one~w~ past sixty-five. ~y~Willpower 5~w~ adds one more.",textSize);
			CharPanel_AddParagraph(text,"A year passes every month of the calendar. Each birthday can shorten the clock, never lengthen it.",textSize);

			if (clock <= 0)
			{
				CharPanel_AddParagraph(text,"Marked, you can also ~y~retire~w~: lay down your work and live out your days in peace. It ends the character like a last death, but on your own terms.",textSize);
			}
		}
		case CHARPANEL_PICK_PEOPLE:
		{
			new culture = Character_GetCulture(playerid), cultureName[CULTURE_NAME_LEN];
			Culture_GetName(culture,cultureName);
			strcopy(title,cultureName,titleSize);
			Culture_GetGroupName(Culture_GetGroup(culture),other);
			Language_GetName(Language_GetNative(culture),name);
			format(line,sizeof(line),"You're ~y~%s~w~, one of the ~y~%s~w~ cultures. Your native language is ~y~%s~w~.",cultureName,other,name);
			CharPanel_AddParagraph(text,line,textSize);
			new ways[CULTURE_WAYS_LEN];
			Culture_GetWays(culture,ways);
			strcat(text,"~n~",textSize);
			CharPanel_AddSentences(text,ways,textSize);
			CharPanel_AddParagraph(text,"Only people who speak your language understand it. Everyone understands ~y~Common~w~.",textSize);
		}
		case CHARPANEL_PICK_RAISED:
		{
			new E_ORIGIN:origin = E_ORIGIN:Character_GetOrigin(playerid);
			Creator_OriginName(origin,title,titleSize);
			Creator_OriginText(origin,line);
			CharPanel_AddParagraph(text,line,textSize);
		}
		case CHARPANEL_PICK_LIFE:
		{
			new E_LIFESTYLE:lifestyle = E_LIFESTYLE:Character_GetLifestyle(playerid);
			Creator_LifestyleName(lifestyle,title,titleSize);
			Creator_LifestyleText(lifestyle,line);
			CharPanel_AddParagraph(text,line,textSize);
			CharPanel_AddParagraph(text,"It's the ~y~way of life~w~ you picked in the character creator. It also decided where you first spawned.",textSize);
		}
		case CHARPANEL_PICK_HEALTH:
		{
			strcopy(title,"Health",titleSize);
			format(line,sizeof(line),"Your health is ~y~%d%%~w~.",floatround(Vitals_GetHealth(playerid)));
			CharPanel_AddParagraph(text,line,textSize);

			if (Vitals_GetHealthLimit(playerid) < VITALS_MAX)
			{
				format(line,sizeof(line),"While you're ill, it can't go above ~r~%d%%~w~.",floatround(Vitals_GetHealthLimit(playerid)));
				CharPanel_AddLine(text,line,textSize);
			}

			format(line,sizeof(line),"~r~Blows~w~, ~r~bleeding~w~, ~r~cold~w~, ~r~hunger~w~ and ~r~thirst~w~ all take health. Below ~r~%.0f%%~w~ you're struck down and need someone to help you up. At ~r~0%%~w~ you die.",COMBAT_STRUCK_THRESHOLD);
			CharPanel_AddParagraph(text,line,textSize);

			if (Wounds_IsBleeding(playerid))
			{
				format(line,sizeof(line),"You're bleeding ~r~%.2f health a second~w~. A ~y~bandage~w~ stops a wound bleeding straight away.",Wounds_GetBleedRate(playerid));
				CharPanel_AddParagraph(text,line,textSize);
			}

			if (Wounds_Count(playerid) > 0)
			{
				format(line,sizeof(line),"You have ~y~%d %s~w~, listed below by body part.",Wounds_Count(playerid),Wounds_Count(playerid) == 1 ? ("wound") : ("wounds"));
			}
			else
			{
				strcopy(line,"You have ~y~no wounds~w~.");
			}

			CharPanel_AddParagraph(text,line,textSize);
			format(line,sizeof(line),"A ~y~bandage~w~ from your bag gives back ~y~%d~w~ health. Wounds heal while you play, once they've stopped bleeding.",Item_GetValue(ITEM_KIND_TOOL,ITEM_BANDAGE));
			CharPanel_AddParagraph(text,line,textSize);
		}
		case CHARPANEL_PICK_STAMINA:
		{
			strcopy(title,"Stamina",titleSize);
			format(line,sizeof(line),"Your stamina is ~y~%d%%~w~.",floatround(Vitals_GetStamina(playerid)));
			CharPanel_AddParagraph(text,line,textSize);
			CharPanel_AddParagraph(text,"~y~Running~w~, ~y~swinging~w~ and ~y~blocking~w~ use up stamina. It refills quickly once you stop.~n~~n~With no stamina left you can't swing or sprint. When it's low, a single punch will knock you down.",textSize);

			if (Vitals_GetStaminaCap(playerid) < VITALS_MAX)
			{
				format(line,sizeof(line),"~r~Hunger, thirst, illness or a wound~w~ is holding it down. Right now it can't go above ~r~%d%%~w~.",floatround(Vitals_GetStaminaCap(playerid)));
				CharPanel_AddParagraph(text,line,textSize);
			}
		}
		case CHARPANEL_PICK_FED:
		{
			strcopy(title,"Fed",titleSize);
			format(line,sizeof(line),"You are ~y~%d%%~w~ fed.",Needs_GetHunger(playerid));
			CharPanel_AddParagraph(text,line,textSize);
			CharPanel_AddParagraph(text,"You get hungry over time, faster when you ~y~work~w~ or you're ~r~ill~w~. Eat food from your ~y~bag~w~. ~y~Cooked food~w~ fills you up the most. ~r~Starving costs health.~w~",textSize);
		}
		case CHARPANEL_PICK_HYDRATED:
		{
			strcopy(title,"Hydrated",titleSize);
			format(line,sizeof(line),"You are ~y~%d%%~w~ hydrated.",Needs_GetThirst(playerid));
			CharPanel_AddParagraph(text,line,textSize);
			CharPanel_AddParagraph(text,"You get thirsty over time, faster in the ~y~heat~w~. Drink water from your ~y~bag~w~. ~r~Unclean water can make you sick.~w~ ~r~Thirst costs health.~w~",textSize);
		}
		case CHARPANEL_PICK_WARMTH:
		{
			strcopy(title,"Warmth",titleSize);
			Warmth_BandName(Warmth_GetBand(playerid),name);
			format(line,sizeof(line),"You are ~y~%s~w~. How much warmth you need depends on the weather and the season. Your clothes give you ~y~%d~w~. Standing near a ~y~fire~w~ gives you more.",name,Warmth_GetClothing(playerid));
			CharPanel_AddParagraph(text,line,textSize);
			CharPanel_AddParagraph(text,"~r~Freezing~w~ costs health and can give you ~r~chills~w~ or ~r~frostbite~w~. When you're ~r~too hot~w~, you can get ~r~heatstroke~w~.",textSize);
		}
		default:
		{
			if (pick >= CHARPANEL_PICK_AILMENT && pick < CHARPANEL_PICK_AILMENT + Ailment_GetCount(playerid))
			{
				CharPanel_ExplainAilment(playerid,pick - CHARPANEL_PICK_AILMENT,title,text,titleSize,textSize);
			}
		}
	}

	return text[0] != EOS;
}

CharPanel_Open(playerid,tab = CHARPANEL_YOU)
{
	yield 1;

	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), bool:isFirst = true, Float:x, Float:y, Float:width, buffPage = 0;

	for (;;)
	{
		Kit_Begin(playerid,KIT_LAYER_SCREEN,CHARPANEL_TITLE);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,CHARPANEL_WIDTH,float(CHARPANEL_ROWS) * KIT_ROW + 6.0 + KIT_ROW + 12.0,CHARPANEL_TITLE,x,y,width);

		switch (tab)
		{
			case CHARPANEL_HEALTH: CharPanel_DrawHealth(playerid,x,y,width);
			case CHARPANEL_SKILLS: CharPanel_DrawSkills(playerid,x,y,width);
			case CHARPANEL_BUFFS: CharPanel_DrawBuffs(playerid,x,y,width,buffPage);
			case CHARPANEL_FAMILY: FamilyGui_DrawTab(playerid,x,y,width,CHARPANEL_ROWS);
			default: CharPanel_DrawYou(playerid,x,y,width);
		}

		new Float:footerY = y + float(CHARPANEL_ROWS) * KIT_ROW + 8.0, Float:button = (width - 56.0 - 12.0) / 6.0;
		Kit_AddButton(playerid,x,footerY,button - 3.0,"You",CHARPANEL_TAB_YOU,tab == CHARPANEL_YOU ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + button,footerY,button - 3.0,"Health",CHARPANEL_TAB_HEALTH,tab == CHARPANEL_HEALTH ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + button * 2.0,footerY,button - 3.0,"Skills",CHARPANEL_TAB_SKILLS,tab == CHARPANEL_SKILLS ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + button * 3.0,footerY,button - 3.0,"Buffs",CHARPANEL_TAB_BUFFS,tab == CHARPANEL_BUFFS ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + button * 4.0,footerY,button - 3.0,"Family",CHARPANEL_TAB_FAMILY,tab == CHARPANEL_FAMILY ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + button * 5.0,footerY,button - 3.0,"Ledger",CHARPANEL_TAB_LEDGER,KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + width - 56.0,footerY,56.0,GUI_BUTTON_CLOSE,KIT_BACK);

		new Task:shown = Kit_Present(playerid);

		if (isFirst)
		{
			isFirst = false;
			pawn_call_public("CharPanel_OnOpened","d",playerid);
		}

		pawn_call_public("CharPanel_OnTab","dd",playerid,tab);

		new pick = await shown;

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			pawn_call_public("CharPanel_OnClosed","d",playerid);
			return;
		}

		switch (pick)
		{
			case CHARPANEL_TAB_YOU: tab = CHARPANEL_YOU;
			case CHARPANEL_TAB_HEALTH: tab = CHARPANEL_HEALTH;
			case CHARPANEL_TAB_SKILLS: tab = CHARPANEL_SKILLS;
			case CHARPANEL_TAB_BUFFS: { tab = CHARPANEL_BUFFS; buffPage = 0; }
			case CHARPANEL_PICK_BUFF_PREV: buffPage--;
			case CHARPANEL_PICK_BUFF_NEXT: buffPage++;
			case CHARPANEL_TAB_FAMILY: tab = CHARPANEL_FAMILY;
			case CHARPANEL_TAB_LEDGER:
			{
				Kit_Close(playerid);
				pawn_call_public("CharPanel_OnClosed","d",playerid);
				pawn_call_public("CharPanel_OnLedger","d",playerid);
				return;
			}
			case CHARPANEL_PICK_GROUPS:
			{
				Kit_Close(playerid);
				pawn_call_public("CharPanel_OnClosed","d",playerid);
				pawn_call_public("CharPanel_OnGroups","d",playerid);
				return;
			}
			default:
			{
				new title[48], text[CHARPANEL_INFO_LEN];

				if (FamilyGui_OnPick(playerid,epoch,pick))
				{
					if (!Gui_IsFlowCurrent(playerid,epoch))
					{
						pawn_call_public("CharPanel_OnClosed","d",playerid);
						return;
					}
				}
				else if (pick == CHARPANEL_PICK_CHURCH)
				{
					ClergyGui_Open(playerid,epoch);

					if (!Gui_IsFlowCurrent(playerid,epoch))
					{
						pawn_call_public("CharPanel_OnClosed","d",playerid);
						return;
					}
				}
				else if (pick >= CHARPANEL_PICK_WOUND && pick < CHARPANEL_PICK_WOUND + WOUND_MAX)
				{
					WoundsGui_ShowWound(playerid,epoch,pick - CHARPANEL_PICK_WOUND);

					if (!Gui_IsFlowCurrent(playerid,epoch))
					{
						pawn_call_public("CharPanel_OnClosed","d",playerid);
						return;
					}
				}
				else if (pick == CHARPANEL_PICK_AGE && Lineage_IsMarked(playerid) && CharPanel_Explain(playerid,pick,title,text))
				{
					if (LineageGui_ShowYears(playerid,title,text,CHARPANEL_INFO_WIDTH) || !Gui_IsFlowCurrent(playerid,epoch))
					{
						pawn_call_public("CharPanel_OnClosed","d",playerid);
						return;
					}
				}
				else if (CharPanel_Explain(playerid,pick,title,text))
				{
					Gui_ShowMessage(playerid,title,text,GUI_BUTTON_BACK,CHARPANEL_INFO_WIDTH);

					if (!Gui_IsFlowCurrent(playerid,epoch))
					{
						pawn_call_public("CharPanel_OnClosed","d",playerid);
						return;
					}
				}
			}
		}
	}
}

forward CharPanel_OnOpened(playerid);

public CharPanel_OnOpened(playerid)
{
	return 1;
}

forward CharPanel_OnTab(playerid,tab);

public CharPanel_OnTab(playerid,tab)
{
	return 1;
}

forward CharPanel_OnGroups(playerid);

public CharPanel_OnGroups(playerid)
{
	return 1;
}

forward CharPanel_OnLedger(playerid);

public CharPanel_OnLedger(playerid)
{
	return 1;
}

forward CharPanel_OnClosed(playerid);

public CharPanel_OnClosed(playerid)
{
	return 1;
}

forward CharPanel_OpenDeferred(playerid);

public CharPanel_OpenDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Work_IsWorking(playerid))
	{
		CharPanel_Open(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	new KEY:both = KEY_SPRINT | KEY_WALK;

	if ((newkeys & both) != both || (oldkeys & both) == both || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid))
	{
		return;
	}

	SetTimerEx("CharPanel_OpenDeferred",0,false,"d",playerid);
}
