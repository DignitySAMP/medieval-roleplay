#define LINEAGE_GRAVE_ROWS (8)
#define LINEAGE_GRAVE_TEXT_LEN (700)
#define LINEAGE_GRAVE_CHARS (60)
#define LINEAGE_GUI_RETIRE (1)
#define LINEAGE_GUI_HEIR (2)

static s_GraveIds[MAX_PLAYERS][LINEAGE_GRAVE_ROWS];

static LineageGui_AddParagraph(dest[],const text[],size = sizeof(dest))
{
	new wrapped[LINEAGE_GRAVE_TEXT_LEN];
	Util_WrapText(text,wrapped,sizeof(wrapped),LINEAGE_GRAVE_CHARS,"~n~");

	if (dest[0] != EOS)
	{
		strcat(dest,"~n~~n~",size);
	}

	strcat(dest,wrapped,size);
}

static bool:LineageGui_GraveHeirButton(playerid,const title[],const text[])
{
	new Float:x, Float:y, Float:contentWidth, Float:textHeight = Gui_TextHeight(text,300.0);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,textHeight + KIT_ROW + 10.0,title,x,y,contentWidth);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,contentWidth);
	Kit_AddButton(playerid,x,y + textHeight + 8.0,contentWidth * 0.45,"Choose an heir",LINEAGE_GUI_HEIR,KIT_COLOUR_ACCENT);
	Kit_AddButton(playerid,x + contentWidth * 0.55,y + textHeight + 8.0,contentWidth * 0.45,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick == LINEAGE_GUI_HEIR;
}

static bool:LineageGui_ShowGrave(playerid,characterid)
{
	new token = Account_GetToken(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT name, surname, IFNULL(died_age, age) AS died_age, IFNULL(died_day, -1) AS died_day, IFNULL(death_cause, 'unknown') AS cause, retired, last_rites, culture, origin, lifestyle, trait_a, trait_b, willpower, craftmanship, intelligence, honor_grace, piety FROM characters WHERE id = %d AND account_id = %d AND alive = 0 LIMIT 1",characterid,Account_GetId(playerid)));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || cache_num_rows() == 0)
	{
		return false;
	}

	new name[CHARACTER_NAME_MAX + 1], surname[CHARACTER_NAME_MAX + 1], title[CHARACTER_NAME_MAX * 2 + 2], cause[LINEAGE_CAUSE_LEN], age, diedDay, retired, rites, culture, origin, lifestyle, traitA, traitB, attributes[_:ATTR_COUNT];
	cache_get_value_name(0,"name",name);
	cache_get_value_name(0,"surname",surname);
	cache_get_value_name(0,"cause",cause);
	cache_get_value_name_int(0,"died_age",age);
	cache_get_value_name_int(0,"died_day",diedDay);
	cache_get_value_name_int(0,"retired",retired);
	cache_get_value_name_int(0,"last_rites",rites);
	cache_get_value_name_int(0,"culture",culture);
	cache_get_value_name_int(0,"origin",origin);
	cache_get_value_name_int(0,"lifestyle",lifestyle);
	cache_get_value_name_int(0,"trait_a",traitA);
	cache_get_value_name_int(0,"trait_b",traitB);
	cache_get_value_name_int(0,"willpower",attributes[_:ATTR_WILLPOWER]);
	cache_get_value_name_int(0,"craftmanship",attributes[_:ATTR_CRAFTMANSHIP]);
	cache_get_value_name_int(0,"intelligence",attributes[_:ATTR_INTELLIGENCE]);
	cache_get_value_name_int(0,"honor_grace",attributes[_:ATTR_HONOR_GRACE]);
	cache_get_value_name_int(0,"piety",attributes[_:ATTR_PIETY]);
	format(title,sizeof(title),"%s %s",name,surname);

	new text[LINEAGE_GRAVE_TEXT_LEN], line[200], part[64], other[64];

	if (retired != 0)
	{
		Calendar_FormatDay(max(diedDay,0),part);
		format(line,sizeof(line),"~y~%s~w~ retired at ~y~%d~w~ years old, on ~y~%s~w~, and lived out their days in peace.",title,age,part);
	}
	else if (diedDay >= 0)
	{
		Calendar_FormatDay(diedDay,part);
		format(line,sizeof(line),"~y~%s~w~ died at ~y~%d~w~ years old, on ~y~%s~w~. Cause of death: ~r~%s~w~.",title,age,part,cause);
	}
	else
	{
		format(line,sizeof(line),"~y~%s~w~ died at ~y~%d~w~ years old. Cause of death: ~r~%s~w~.",title,age,cause);
	}

	LineageGui_AddParagraph(text,line);

	if (rites != 0 && retired == 0)
	{
		LineageGui_AddParagraph(text,"They received the ~y~last rites~w~ and died absolved.");
	}

	Culture_GetName(culture,part);
	Creator_OriginName(E_ORIGIN:origin,other);
	other[0] = tolower(other[0]);
	format(line,sizeof(line),"~y~%s~w~ by blood, %s ~y~%s~w~ by birth.",part,Util_StartsWithVowel(other) ? ("an") : ("a"),other);

	Creator_LifestyleName(E_LIFESTYLE:lifestyle,part);

	if (part[0] != EOS)
	{
		part[0] = tolower(part[0]);
		format(line,sizeof(line),"%s Started out as %s ~y~%s~w~.",line,Util_StartsWithVowel(part) ? ("an") : ("a"),part);
	}

	LineageGui_AddParagraph(text,line);

	Creator_TraitName(E_TRAIT:traitA,part);
	Creator_TraitName(E_TRAIT:traitB,other);

	if (part[0] != EOS && other[0] != EOS)
	{
		format(line,sizeof(line),"Traits: ~y~%s~w~ and ~y~%s~w~.",part,other);
		LineageGui_AddParagraph(text,line);
	}
	else if (part[0] != EOS || other[0] != EOS)
	{
		format(line,sizeof(line),"Trait: ~y~%s~w~.",part[0] != EOS ? part : other);
		LineageGui_AddParagraph(text,line);
	}

	line[0] = EOS;

	for (new E_ATTRIBUTE:attr = ATTR_WILLPOWER;attr < ATTR_COUNT;attr++)
	{
		Creator_AttributeName(attr,part);
		format(line,sizeof(line),"%s%s%s ~y~%d~w~",line,line[0] != EOS ? (", ") : (""),part,attributes[_:attr]);
	}

	strcat(line,".");
	LineageGui_AddParagraph(text,line);

	new bool:canChoose;
	FamilyGui_GraveLines(characterid,text,canChoose);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return false;
	}

	new slot = canChoose ? Family_FindFreeSlot(Account_GetId(playerid)) : -1;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return false;
	}

	if (slot == -1)
	{
		Gui_ShowMessage(playerid,title,text,GUI_BUTTON_BACK,300.0);
		return IsPlayerConnected(playerid) && Account_GetToken(playerid) == token;
	}

	if (!LineageGui_GraveHeirButton(playerid,title,text))
	{
		return IsPlayerConnected(playerid) && Account_GetToken(playerid) == token;
	}

	new heirid = FamilyGui_OfferHeir(playerid,characterid,slot);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return false;
	}

	if (heirid > 0)
	{
		Character_Load(playerid,heirid);
		return false;
	}

	return true;
}

stock LineageGui_ShowGraveyard(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid), epoch = Gui_BeginFlow(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, name, surname, IFNULL(died_age, age) AS died_age, retired FROM characters WHERE account_id = %d AND alive = 0 ORDER BY died_at DESC LIMIT %d",Account_GetId(playerid),LINEAGE_GRAVE_ROWS));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	new rows = min(cache_num_rows(),LINEAGE_GRAVE_ROWS), names[LINEAGE_GRAVE_ROWS][CHARACTER_NAME_MAX * 2 + 2], ages[LINEAGE_GRAVE_ROWS], retired[LINEAGE_GRAVE_ROWS];

	for (new r = 0;r < rows;r++)
	{
		new name[CHARACTER_NAME_MAX + 1], surname[CHARACTER_NAME_MAX + 1];
		cache_get_value_name_int(r,"id",s_GraveIds[playerid][r]);
		cache_get_value_name(r,"name",name);
		cache_get_value_name(r,"surname",surname);
		cache_get_value_name_int(r,"died_age",ages[r]);
		cache_get_value_name_int(r,"retired",retired[r]);
		format(names[r],sizeof(names[]),"%s %s",name,surname);
	}

	for (;;)
	{
		new Float:x, Float:y, Float:width, died[24];
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Graveyard");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(max(rows,1)) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Graveyard",x,y,width);

		if (rows == 0)
		{
			Kit_AddText(playerid,x,y,"Nobody rests here yet.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		for (new r = 0;r < rows;r++)
		{
			format(died,sizeof(died),retired[r] != 0 ? ("retired at %d") : ("died at %d"),ages[r]);
			Kit_AddChoice(playerid,x,y + float(r) * KIT_ROW,width,names[r],r,KIT_COLOUR_TEXT,died,KIT_COLOUR_MUTED,0.65);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(max(rows,1)) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Gui_IsFlowCurrent(playerid,epoch) || Session_GetState(playerid) != SESSION_CHARACTER_SELECT)
		{
			return;
		}

		if (pick < 0 || pick >= rows)
		{
			Kit_Close(playerid);
			Character_ShowSelect(playerid);
			return;
		}

		if (!LineageGui_ShowGrave(playerid,s_GraveIds[playerid][pick]) || !Gui_IsFlowCurrent(playerid,epoch) || Session_GetState(playerid) != SESSION_CHARACTER_SELECT)
		{
			return;
		}
	}
}

static bool:LineageGui_Confirm(playerid,const title[],const text[],const button[],Float:width)
{
	new Float:x, Float:y, Float:contentWidth, Float:textHeight = Gui_TextHeight(text,width);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,width,textHeight + KIT_ROW + 10.0,title,x,y,contentWidth);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,contentWidth);
	Kit_AddButton(playerid,x,y + textHeight + 8.0,contentWidth * 0.45,button,LINEAGE_GUI_RETIRE,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + contentWidth * 0.55,y + textHeight + 8.0,contentWidth * 0.45,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick == LINEAGE_GUI_RETIRE;
}

stock bool:LineageGui_ShowYears(playerid,const title[],const text[],Float:width)
{
	if (!LineageGui_Confirm(playerid,title,text,"Retire",width) || !Lineage_IsMarked(playerid))
	{
		return false;
	}

	new name[CHARACTER_NAME_MAX * 2 + 2], line[256];
	Character_GetName(playerid,name);
	format(line,sizeof(line),"Retiring ends ~y~%s~w~'s story for good, the same as a last death: you can't play them again, and the slot is freed.",name);

	if (!LineageGui_Confirm(playerid,"Retire for good",line,"Retire",300.0))
	{
		return false;
	}

	return Lineage_Retire(playerid);
}
