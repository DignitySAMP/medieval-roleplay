#define FAMILY_PICK_TRY (4000)
#define FAMILY_PICK_CHILD (4100)
#define FAMILY_GUI_TEXT_LEN (700)
#define FAMILY_GUI_CHARS (60)
#define FAMILY_GUI_HEIR (2)

static FamilyGui_ChildWord(sex,dest[],size = sizeof(dest))
{
	strcopy(dest,sex == 1 ? ("daughter") : ("son"),size);
}

static FamilyGui_TraitLine(traitA,traitB,dest[],size = sizeof(dest))
{
	new a[32], b[32];
	Creator_TraitName(E_TRAIT:traitA,a);
	Creator_TraitName(E_TRAIT:traitB,b);

	if (a[0] != EOS && b[0] != EOS)
	{
		format(dest,size,"%s and %s",a,b);
	}
	else
	{
		strcopy(dest,a[0] != EOS ? a : b,size);
	}
}

static FamilyGui_AttributeLine(const attributes[5],dest[],size = sizeof(dest))
{
	new part[32];
	dest[0] = EOS;

	for (new E_ATTRIBUTE:attr = ATTR_WILLPOWER;attr < ATTR_COUNT;attr++)
	{
		Creator_AttributeName(attr,part);
		format(dest,size,"%s%s%s ~y~%d~w~",dest,dest[0] != EOS ? (", ") : (""),part,attributes[_:attr]);
	}
}

stock FamilyGui_DrawTab(playerid,Float:x,Float:y,Float:width,rows)
{
	new line[64], name[FAMILY_NAME_LEN], row = 0;

	if (Family_HasSpouse(playerid))
	{
		Family_GetSpouseName(playerid,name);
		format(line,sizeof(line),"%s, %d",name,Family_GetSpouseAge(playerid));
		Kit_AddText(playerid,x,y,Family_GetSpouseSex(playerid) == 1 ? ("Wife") : ("Husband"),KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.38);
		Kit_AddText(playerid,x + width * 0.38,y,line,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.62);
	}
	else
	{
		Kit_AddText(playerid,x,y,"Spouse",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.38);
		Kit_AddText(playerid,x + width * 0.38,y,"unmarried",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.62);
	}

	row++;
	new due = Family_GetDueDays(playerid);

	if (due >= 0)
	{
		if (due == 0)
		{
			strcopy(line,"a child any day now");
		}
		else
		{
			format(line,sizeof(line),"a child in %d %s",due,due == 1 ? ("day") : ("days"));
		}

		Kit_AddText(playerid,x,y + float(row) * KIT_ROW,"Expecting",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.38);
		Kit_AddText(playerid,x + width * 0.38,y + float(row) * KIT_ROW,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.62);
		row++;
	}

	row++;

	for (new i = 0;i < Family_CountChildren(playerid) && row < rows - 4;i++)
	{
		new childid, sex, age, bool:isGrown, word[12];
		Family_GetChild(playerid,i,childid,name,sex,age,isGrown);
		FamilyGui_ChildWord(sex,word);

		if (name[0] == EOS)
		{
			format(name,sizeof(name),"Unnamed %s",word);
		}

		if (isGrown)
		{
			format(line,sizeof(line),"grown %s, 18",word);
		}
		else
		{
			format(line,sizeof(line),"%s, %d",word,age);
		}

		Kit_AddChoice(playerid,x,y + float(row) * KIT_ROW,width,name,FAMILY_PICK_CHILD + i,KIT_COLOUR_TEXT,line,isGrown ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,0.38);
		row++;
	}

	new E_FAMILY_TRY:canTry = Family_CanTry(playerid), Float:footY = y + float(rows - 3) * KIT_ROW, note[160];

	switch (canTry)
	{
		case FAMILY_TRY_OK:
		{
			Kit_AddButton(playerid,x,footY,110.0,"Try for a child",FAMILY_PICK_TRY,KIT_COLOUR_ACCENT);
			Family_GetSpouseName(playerid,name);
			format(note,sizeof(note),"Children grow up four times as fast as you. At 18 a child can carry the family on.");
		}
		case FAMILY_TRY_NO_SPOUSE: strcopy(note,"You're unmarried. Ask for the banns at the monastery church altar, and the priest will wed you once they've been read.");
		case FAMILY_TRY_EXPECTING: strcopy(note,"A child is on the way. Children grow up four times as fast as you, and at 18 one can carry the family on.");
		case FAMILY_TRY_FULL: format(note,sizeof(note),"%d children is as many as your household can raise.",FAMILY_MAX_CHILDREN);
		case FAMILY_TRY_TOO_OLD: strcopy(note,"You're both past the age for more children.");
		default: note[0] = EOS;
	}

	if (note[0] != EOS)
	{
		Kit_AddText(playerid,x,footY + (canTry == FAMILY_TRY_OK ? KIT_ROW + 2.0 : 0.0),note,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}
}

stock bool:FamilyGui_OnPick(playerid,epoch,pick)
{
	#pragma unused epoch

	if (pick == FAMILY_PICK_TRY)
	{
		new name[FAMILY_NAME_LEN];
		Family_GetSpouseName(playerid,name);

		if (Family_TryForChild(playerid) == FAMILY_TRY_OK)
		{
			Gui_Notify(playerid,sprintf("You and %s hope for a child. If all goes well, one is born in about %d days.",name,FAMILY_TERM_DAYS));
		}

		return true;
	}

	if (pick < FAMILY_PICK_CHILD || pick >= FAMILY_PICK_CHILD + FAMILY_ROWS)
	{
		return false;
	}

	new index = pick - FAMILY_PICK_CHILD, childid, name[FAMILY_NAME_LEN], sex, age, bool:isGrown, word[12], text[FAMILY_GUI_TEXT_LEN], line[256];

	if (!Family_GetChild(playerid,index,childid,name,sex,age,isGrown))
	{
		return true;
	}

	FamilyGui_ChildWord(sex,word);

	if (name[0] == EOS)
	{
		FamilyGui_AskName(playerid,Account_GetToken(playerid));
		return true;
	}

	if (isGrown)
	{
		new attributes[5], traitA, traitB, traits[72];
		Family_GetChildStats(playerid,index,attributes,traitA,traitB);
		FamilyGui_AttributeLine(attributes,line);
		FamilyGui_TraitLine(traitA,traitB,traits);
		format(text,sizeof(text),"~y~%s~w~ is a grown %s of 18.~n~~n~%s.~n~~n~Traits: ~y~%s~w~.~n~~n~If you die for good or retire, %s can carry the family on as your heir.",name,word,line,traits,name);
	}
	else
	{
		new days = Family_GetChildDaysToGrown(playerid,index);
		format(text,sizeof(text),"~y~%s~w~ is your %s, %d years old, and comes of age in about ~y~%d~w~ %s.~n~~n~Only a grown child can carry the family on. %s",name,word,age,days,days == 1 ? ("day") : ("days"),Family_IsChildBaptised(playerid,index) ? ("They're baptised, so as your heir they'd carry one more death on the life clock.") : ("Bring them to the font at the monastery church to be baptised: as your heir they'd carry one more death on the life clock."));
	}

	new wrapped[FAMILY_GUI_TEXT_LEN];
	Util_WrapText(text,wrapped,sizeof(wrapped),FAMILY_GUI_CHARS,"~n~");
	Gui_ShowMessage(playerid,name,wrapped,GUI_BUTTON_BACK,300.0);
	return true;
}

stock FamilyGui_AskName(playerid,token)
{
	yield 1;

	new response[DIALOG_RESPONSE], body[320], error[128], word[12], spouse[FAMILY_NAME_LEN];
	error[0] = EOS;
	Family_BeginNaming(playerid);

	for (;;)
	{
		new index = Family_FindUnnamed(playerid), childid, name[FAMILY_NAME_LEN], sex, age, bool:isGrown;

		if (index == -1 || !Family_GetChild(playerid,index,childid,name,sex,age,isGrown))
		{
			Family_EndNaming(playerid);
			return;
		}

		FamilyGui_ChildWord(sex,word);
		Family_GetSpouseName(playerid,spouse);

		if (spouse[0] != EOS)
		{
			format(body,sizeof(body),GUI_TEXT "A %s, born to you and %s. What will you call %s?\n\n" GUI_MUTED "Letters only, the first one a capital.",word,spouse,sex == 1 ? ("her") : ("him"));
		}
		else
		{
			format(body,sizeof(body),GUI_TEXT "Your %s still has no name. What will you call %s?\n\n" GUI_MUTED "Letters only, the first one a capital.",word,sex == 1 ? ("her") : ("him"));
		}

		if (error[0] != EOS)
		{
			format(body,sizeof(body),"%s\n\n" GUI_BAD "%s",body,error);
		}

		await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,sex == 1 ? ("Name your daughter") : ("Name your son"),body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		if (!response[DIALOG_RESPONSE_RESPONSE])
		{
			Family_EndNaming(playerid);
			return;
		}

		if (!Character_ValidateName(response[DIALOG_RESPONSE_INPUTTEXT]))
		{
			format(error,sizeof(error),"That is not a name a priest would write down. Use %d to %d letters and start with a capital.",CHARACTER_NAME_MIN,CHARACTER_NAME_MAX);
			continue;
		}

		if (Family_IsNameTaken(playerid,response[DIALOG_RESPONSE_INPUTTEXT]))
		{
			if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
			{
				return;
			}

			strcopy(error,"Someone of your family already goes by that name. Choose another.");
			continue;
		}

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		Family_NameChild(playerid,index,response[DIALOG_RESPONSE_INPUTTEXT]);
		Gui_Notify(playerid,sprintf("The priest writes %s into the parish book.",response[DIALOG_RESPONSE_INPUTTEXT]));
		error[0] = EOS;
	}
}

stock Family_FindFreeSlot(accountid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT slot FROM characters WHERE account_id = %d AND slot IS NOT NULL",accountid));

	new bool:used[ACCOUNT_CHARACTER_SLOTS];

	for (new r = 0;r < cache_num_rows();r++)
	{
		new slot;
		cache_get_value_name_int(r,"slot",slot);

		if (slot >= 0 && slot < ACCOUNT_CHARACTER_SLOTS)
		{
			used[slot] = true;
		}
	}

	for (new slot = 0;slot < ACCOUNT_CHARACTER_SLOTS;slot++)
	{
		if (!used[slot])
		{
			return slot;
		}
	}

	return -1;
}

stock FamilyGui_GraveLines(deceasedid,text[],&bool:canChoose,size = sizeof(text))
{
	canChoose = false;
	await mysql_aquery_s(g_Mysql,str_format("SELECT name, sex, born_day, heir_character_id IS NOT NULL AS is_heir FROM character_children WHERE parent_character_id = %d AND name <> '' ORDER BY born_day, id LIMIT %d",deceasedid,FAMILY_ROWS));

	new rows = cache_num_rows(), today = Family_Today(), bool:hasHeir = false, grown = 0, line[256];

	if (rows == 0)
	{
		return;
	}

	line[0] = EOS;

	for (new r = 0;r < rows;r++)
	{
		new name[FAMILY_NAME_LEN], sex, bornDay, isHeir, part[64];
		cache_get_value_name(r,"name",name);
		cache_get_value_name_int(r,"sex",sex);
		cache_get_value_name_int(r,"born_day",bornDay);
		cache_get_value_name_int(r,"is_heir",isHeir);

		new age = Family_ChildAge(bornDay,today);

		if (isHeir != 0)
		{
			hasHeir = true;
			format(part,sizeof(part),"~y~%s~w~ (the heir)",name);
		}
		else if (age >= FAMILY_GROWN_AGE)
		{
			grown++;
			format(part,sizeof(part),"~y~%s~w~ (grown)",name);
		}
		else
		{
			format(part,sizeof(part),"~y~%s~w~ (%d)",name,age);
		}

		format(line,sizeof(line),"%s%s%s",line,line[0] != EOS ? (", ") : (""),part);
	}

	format(line,sizeof(line),"Children: %s.",line);

	new wrapped[FAMILY_GUI_TEXT_LEN];
	Util_WrapText(line,wrapped,sizeof(wrapped),FAMILY_GUI_CHARS,"~n~");

	if (text[0] != EOS)
	{
		strcat(text,"~n~~n~",size);
	}

	strcat(text,wrapped,size);
	canChoose = !hasHeir && grown > 0;
}

stock FamilyGui_OfferHeir(playerid,deceasedid,slot)
{
	new token = Account_GetToken(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, name, sex, born_day, grown, trait_a, trait_b FROM character_children WHERE parent_character_id = %d AND heir_character_id IS NULL AND name <> '' ORDER BY born_day, id LIMIT %d",deceasedid,FAMILY_ROWS));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 0;
	}

	new rows = cache_num_rows(), today = Family_Today(), ids[FAMILY_ROWS], labels[FAMILY_ROWS][FAMILY_NAME_LEN], details[FAMILY_ROWS][72], count = 0, young = 0;

	for (new r = 0;r < rows;r++)
	{
		new bornDay, grown, sex, traitA, traitB;
		cache_get_value_name_int(r,"born_day",bornDay);
		cache_get_value_name_int(r,"grown",grown);
		cache_get_value_name_int(r,"sex",sex);
		cache_get_value_name_int(r,"trait_a",traitA);
		cache_get_value_name_int(r,"trait_b",traitB);

		if (Family_ChildAge(bornDay,today) < FAMILY_GROWN_AGE)
		{
			young++;
			continue;
		}

		cache_get_value_name_int(r,"id",ids[count]);
		cache_get_value_name(r,"name",labels[count],FAMILY_NAME_LEN);

		if (grown != 0)
		{
			FamilyGui_TraitLine(traitA,traitB,details[count],72);
		}
		else
		{
			strcopy(details[count],sex == 1 ? ("a grown daughter") : ("a grown son"),72);
		}

		count++;
	}

	if (count == 0)
	{
		if (young > 0)
		{
			Gui_ShowMessage(playerid,"The family goes on","Your children are still too young to carry the family on.~n~~n~When one of them comes of age, open the ~y~Graveyard~w~ on your character list and choose them as your heir.",GUI_BUTTON_CONTINUE,300.0);
		}

		return 0;
	}

	for (;;)
	{
		new Float:x, Float:y, Float:width, Float:intro = GUI_MESSAGE_LINE * 3.0;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Choose your heir");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,intro + float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Choose your heir",x,y,width);
		Kit_AddText(playerid,x,y,"Your child takes up the family name and goes on from here.~n~They learn your trades at half your level and inherit~n~most of your coin. Your inventory stays with you.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new i = 0;i < count;i++)
		{
			Kit_AddChoice(playerid,x,y + intro + float(i) * KIT_ROW,width,labels[i],i,KIT_COLOUR_TEXT,details[i],KIT_COLOUR_ACCENT,0.4);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + intro + float(count) * KIT_ROW + 8.0,80.0,"No heir",KIT_BACK);

		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || pick < 0 || pick >= count)
		{
			return 0;
		}

		new heirid = Family_CreateHeir(Account_GetId(playerid),ids[pick],deceasedid,slot);

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return 0;
		}

		if (heirid > 0)
		{
			return heirid;
		}

		Gui_ShowMessage(playerid,"Choose your heir","The priest couldn't find that child in the parish book. Try again, or choose no heir.",GUI_BUTTON_BACK,300.0);
	}
}
