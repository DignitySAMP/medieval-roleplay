#define CULTURE_GUI_MORE (1000)

stock CultureGui_PickCulture(playerid,epoch,current)
{
	new name[CULTURE_NAME_LEN], count[24], bool:isShowingAll = false, Float:x, Float:y, Float:width;

	for (;;)
	{
		new rows = 0, hidden = 0, groups[CULTURE_GROUP_COUNT];

		for (new group = 0;group < CULTURE_GROUP_COUNT;group++)
		{
			if (isShowingAll || Culture_CountAvailableInGroup(playerid,group) > 0 || (Culture_IsValid(current) && Culture_GetGroup(current) == group))
			{
				groups[rows++] = group;
			}
			else
			{
				hidden++;
			}
		}

		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Where are your people from");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,250.0,float(rows + (hidden > 0 ? 1 : 0)) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Where are your people from",x,y,width);

		for (new row = 0;row < rows;row++)
		{
			new group = groups[row];
			Culture_GetGroupName(group,name);
			format(count,sizeof(count),"%d of %d open%s",Culture_CountAvailableInGroup(playerid,group),Culture_CountInGroup(group),(Culture_IsValid(current) && Culture_GetGroup(current) == group) ? (", yours") : (""));
			Kit_AddChoice(playerid,x,y + float(row) * KIT_ROW,width,name,group,Culture_GetGroupColour(group),count,KIT_COLOUR_MUTED,0.55);
		}

		if (hidden > 0)
		{
			format(count,sizeof(count),"and %d more",hidden);
			Kit_AddChoice(playerid,x,y + float(rows) * KIT_ROW,width,count,CULTURE_GUI_MORE,KIT_COLOUR_MUTED);
			rows++;
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new group = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || group == KIT_BACK)
		{
			return -1;
		}

		if (group == CULTURE_GUI_MORE)
		{
			if (Culture_GetUnlockPoints(playerid) > 0)
			{
				isShowingAll = true;
			}
			else
			{
				Gui_Notify(playerid,"The other cultures are locked. Ask a loremaster for a culture unlock point to open one.");
			}

			continue;
		}

		new picked = CultureGui_PickFromGroup(playerid,epoch,group,current);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return -1;
		}

		if (picked != -1)
		{
			return picked;
		}
	}
}

#define CULTURE_GUI_UNLOCK (1)

static bool:CultureGui_OfferUnlock(playerid,epoch,culture)
{
	new name[CULTURE_NAME_LEN], points = Culture_GetUnlockPoints(playerid), label[48], Float:x, Float:y, Float:width;
	Culture_GetName(culture,name);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,4.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
	Kit_AddText(playerid,x,y,"This culture is locked. Spend a culture unlock point to unlock it permanently for every character on your account.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (points > 0)
	{
		format(label,sizeof(label),"Use a culture unlock point (%d left)",points);
		Kit_AddChoice(playerid,x,y + 3.0 * KIT_ROW,width,label,CULTURE_GUI_UNLOCK,KIT_COLOUR_ACCENT);
	}
	else
	{
		Kit_AddText(playerid,x,y + 3.0 * KIT_ROW,"You have no culture unlock points. Ask a loremaster for one.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 4.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick != CULTURE_GUI_UNLOCK)
	{
		return false;
	}

	if (!Culture_SpendUnlockPoint(playerid,culture))
	{
		return false;
	}

	Gui_Notify(playerid,sprintf("%s is now unlocked for every character on your account.",name));
	return true;
}

static CultureGui_PickFromGroup(playerid,epoch,group,current)
{
	if (!Culture_IsValidGroup(group))
	{
		return -1;
	}

	new name[CULTURE_NAME_LEN], groupName[CULTURE_NAME_LEN], title[40], count = Culture_CountInGroup(group), Float:x, Float:y, Float:width;
	Culture_GetGroupName(group,groupName);
	format(title,sizeof(title),"%s cultures",groupName);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,230.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new culture = Culture_GetFromGroup(group,i);
		Culture_GetName(culture,name);
		new bool:isOpen = Culture_IsAvailable(playerid,culture);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,isOpen ? Culture_GetColour(culture) : KIT_COLOUR_MUTED,culture == current ? ("yours") : (isOpen ? ("") : ("locked")),KIT_COLOUR_MUTED,0.70);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return -1;
	}

	new culture = Culture_GetFromGroup(group,pick);

	if (!Culture_IsAvailable(playerid,culture) && !CultureGui_OfferUnlock(playerid,epoch,culture))
	{
		return -1;
	}

	return culture;
}

enum
{
	CULTURE_GUI_COMMON,
	CULTURE_GUI_NATIVE,
}

static CultureGui_ShowLanguage(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), nativeLanguage = Language_GetNative(Character_GetCulture(playerid)), name[CULTURE_NAME_LEN], who[40], Float:x, Float:y, Float:width;
	Language_GetName(nativeLanguage,name);
	format(who,sizeof(who),"only %s speakers",name);

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your language");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,230.0,2.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Your language",x,y,width);
	Kit_AddChoice(playerid,x,y,width,"Common",CULTURE_GUI_COMMON,Language_GetSpoken(playerid) == LANGUAGE_COMMON ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,"everyone",KIT_COLOUR_MUTED,0.45);
	Kit_AddChoice(playerid,x,y + KIT_ROW,width,name,CULTURE_GUI_NATIVE,Language_GetColour(nativeLanguage),who,KIT_COLOUR_MUTED,0.45);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 2.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_CLOSE,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	Kit_Close(playerid);

	if (pick == KIT_BACK || !Session_IsPlaying(playerid))
	{
		return;
	}

	new language = pick == CULTURE_GUI_COMMON ? LANGUAGE_COMMON : nativeLanguage;

	if (Language_SetSpoken(playerid,language))
	{
		Language_GetName(language,name);
		Gui_Notify(playerid,sprintf("You now speak %s.",name));
	}
}

forward CultureGui_LanguageDeferred(playerid);

public CultureGui_LanguageDeferred(playerid)
{
	if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid))
	{
		return 1;
	}

	CultureGui_ShowLanguage(playerid);
	return 1;
}
