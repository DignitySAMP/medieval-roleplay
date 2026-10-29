enum
{
	CREATOR_ROW_SEX,
	CREATOR_ROW_LOOK,
	CREATOR_ROW_GIVEN,
	CREATOR_ROW_FAMILY,
	CREATOR_ROW_AGE,
	CREATOR_ROW_CULTURE,
	CREATOR_ROW_ORIGIN,
	CREATOR_ROW_CONTINUE,
}

#define CREATOR_GUI_LABEL_LEN (48)
#define CREATOR_ROW_CONTINUE_VALUE (100)
#define CREATOR_ROW_RESET_VALUE (101)

static bool:s_CreatorLooking[MAX_PLAYERS];
static s_CreatorLastLeftRight[MAX_PLAYERS];

static bool:CreatorGui_IsCurrent(playerid,epoch)
{
	return Gui_IsFlowCurrent(playerid,epoch) && Creator_IsActive(playerid);
}

static CreatorGui_FormatName(const name[],dest[],size = sizeof(dest))
{
	if (name[0] == EOS)
	{
		strcopy(dest,"Not chosen",size);
		return;
	}

	strcopy(dest,name,size);
}

static CreatorGui_AddFooter(playerid,Float:x,Float:y,Float:width,bool:isReady,const reason[])
{
	if (isReady)
	{
		Kit_AddButton(playerid,x,y,width * 0.62,"Continue",CREATOR_ROW_CONTINUE_VALUE,KIT_COLOUR_GOOD);
	}
	else
	{
		Kit_AddButton(playerid,x,y,width * 0.62,reason,CREATOR_ROW_CONTINUE_VALUE,KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width * 0.68,y,width * 0.32,GUI_BUTTON_BACK,KIT_BACK);
}

#define CREATOR_GUI_DEATH_TITLE "Death is final"
#define CREATOR_GUI_DEATH_ROWS (12)
#define CREATOR_GUI_DEATH_UNDERSTOOD (1)
#define CREATOR_GUI_DEATH_READ_SECONDS (3)

static bool:s_CreatorGuiWarned[MAX_PLAYERS];

stock CreatorGui_ResetWarning(playerid)
{
	s_CreatorGuiWarned[playerid] = false;
}

static bool:CreatorGui_WarnDeath(playerid,epoch)
{
	new Float:x, Float:y, Float:width, Float:bodyHeight = float(CREATOR_GUI_DEATH_ROWS) * KIT_ROW, wait = CREATOR_GUI_DEATH_READ_SECONDS, label[24];

	for (;;)
	{
		Kit_Begin(playerid,KIT_LAYER_SCREEN,CREATOR_GUI_DEATH_TITLE);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,360.0,bodyHeight + KIT_ROW + 16.0,CREATOR_GUI_DEATH_TITLE,x,y,width);
		Kit_AddText(playerid,x,y,"~w~Every character here has ~r~one life~w~. At first you wake up again after dying, but each death takes one off your ~r~life clock~w~. How many deaths the clock holds depends on your age. Dying of a grave illness takes ~r~two~w~.~n~~n~When the clock runs out you're ~r~marked by death~w~, a mark a priest can see on you, and your ~r~next death is permanent~w~. The character is buried and can't be played again. What you leave behind can pass to an ~y~heir~w~.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		if (wait > 0)
		{
			format(label,sizeof(label),"Read on: %d",wait);
			Kit_AddButton(playerid,x + width / 2.0 - 50.0,y + bodyHeight + 8.0,100.0,label,KIT_NONE,KIT_COLOUR_MUTED);
		}
		else
		{
			Kit_AddButton(playerid,x + width / 2.0 - 50.0,y + bodyHeight + 8.0,100.0,"I understand",CREATOR_GUI_DEATH_UNDERSTOOD,KIT_COLOUR_ACCENT);
		}

		new Task:shown = Kit_Present(playerid);

		if (wait > 0)
		{
			Kit_ArmAfter(playerid,1000);
		}

		new pick = await shown;

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return false;
		}

		if (pick == KIT_ARMED)
		{
			wait--;
			continue;
		}

		if (wait <= 0)
		{
			return true;
		}
	}

	return false;
}

CreatorGui_ShowIdentity(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), label[CREATOR_GUI_LABEL_LEN], Float:x, Float:y, Float:width;

	while (!s_CreatorGuiWarned[playerid])
	{
		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		s_CreatorGuiWarned[playerid] = CreatorGui_WarnDeath(playerid,epoch);
	}

	for (;;)
	{
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Who are you");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,250.0,7.0 * KIT_ROW + 8.0 + KIT_ROW + 12.0,"Who are you",x,y,width);

		Kit_AddChoice(playerid,x,y,width,"Sex",CREATOR_ROW_SEX,KIT_COLOUR_TEXT,g_CreatorDraft[playerid][E_CREATE_SEX] ? ("Woman") : ("Man"));
		format(label,sizeof(label),"%d of %d",g_CreatorDraft[playerid][E_CREATE_LOOK] + 1,Skins_CountStarter(g_CreatorDraft[playerid][E_CREATE_SEX]));
		Kit_AddChoice(playerid,x,y + KIT_ROW,width,"Look",CREATOR_ROW_LOOK,KIT_COLOUR_TEXT,label);
		CreatorGui_FormatName(g_CreatorDraft[playerid][E_CREATE_NAME],label);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width,"Given name",CREATOR_ROW_GIVEN,KIT_COLOUR_TEXT,label,g_CreatorDraft[playerid][E_CREATE_NAME][0] != EOS ? KIT_COLOUR_ACCENT : KIT_COLOUR_BAD);
		CreatorGui_FormatName(g_CreatorDraft[playerid][E_CREATE_SURNAME],label);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,"Family name",CREATOR_ROW_FAMILY,KIT_COLOUR_TEXT,label,g_CreatorDraft[playerid][E_CREATE_SURNAME][0] != EOS ? KIT_COLOUR_ACCENT : KIT_COLOUR_BAD);
		format(label,sizeof(label),"%d years",g_CreatorDraft[playerid][E_CREATE_AGE]);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Age",CREATOR_ROW_AGE,KIT_COLOUR_TEXT,label);

		if (Culture_IsValid(g_CreatorDraft[playerid][E_CREATE_CULTURE]))
		{
			Culture_GetName(g_CreatorDraft[playerid][E_CREATE_CULTURE],label);
			Kit_AddChoice(playerid,x,y + KIT_ROW * 5.0,width,"Culture",CREATOR_ROW_CULTURE,KIT_COLOUR_TEXT,label,Culture_GetColour(g_CreatorDraft[playerid][E_CREATE_CULTURE]));
		}
		else
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * 5.0,width,"Culture",CREATOR_ROW_CULTURE,KIT_COLOUR_TEXT,"Not chosen",KIT_COLOUR_BAD);
		}

		Creator_OriginName(g_CreatorDraft[playerid][E_CREATE_ORIGIN],label);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 6.0,width,"Origin",CREATOR_ROW_ORIGIN,KIT_COLOUR_TEXT,label);
		CreatorGui_AddFooter(playerid,x,y + KIT_ROW * 7.0 + 8.0,width,Creator_HasIdentity(playerid),"Name and culture first");

		new pick = await Kit_Present(playerid);

		if (!CreatorGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		switch (pick)
		{
			case KIT_BACK:
			{
				Kit_Clear(playerid);
				Character_ShowSelect(playerid);
				return;
			}
			case CREATOR_ROW_SEX:
			{
				Creator_SetSex(playerid,g_CreatorDraft[playerid][E_CREATE_SEX] ? 0 : 1);
			}
			case CREATOR_ROW_LOOK:
			{
				Kit_Close(playerid);
				CreatorGui_EnterLook(playerid);
				return;
			}
			case CREATOR_ROW_GIVEN:
			{
				Kit_Suspend(playerid);
				CreatorGui_AskName(playerid,epoch,false);
			}
			case CREATOR_ROW_FAMILY:
			{
				Kit_Suspend(playerid);
				CreatorGui_AskName(playerid,epoch,true);
			}
			case CREATOR_ROW_AGE:
			{
				CreatorGui_AskAge(playerid,epoch);
			}
			case CREATOR_ROW_CULTURE:
			{
				new culture = CultureGui_PickCulture(playerid,epoch,g_CreatorDraft[playerid][E_CREATE_CULTURE]);

				if (Culture_IsValid(culture))
				{
					g_CreatorDraft[playerid][E_CREATE_CULTURE] = culture;
				}
			}
			case CREATOR_ROW_ORIGIN:
			{
				CreatorGui_AskOrigin(playerid,epoch);
			}
			case CREATOR_ROW_CONTINUE_VALUE:
			{
				if (!Creator_HasIdentity(playerid))
				{
					Gui_Notify(playerid,"Give yourself a given name, a family name and a culture first.");
					continue;
				}

				new bool:isTaken = Creator_IsNameTaken(playerid);

				if (!CreatorGui_IsCurrent(playerid,epoch))
				{
					return;
				}

				if (isTaken)
				{
					Gui_Notify(playerid,"Someone in the realm already bears that name. Change your given or family name.");
					continue;
				}

				if (CreatorGui_ShowNature(playerid,epoch))
				{
					return;
				}
			}
		}

		if (!CreatorGui_IsCurrent(playerid,epoch))
		{
			return;
		}
	}
}

static CreatorGui_AskName(playerid,epoch,bool:isFamily)
{
	new response[DIALOG_RESPONSE], body[256], error[128];
	error[0] = EOS;

	for (;;)
	{
		format(body,sizeof(body),GUI_TEXT "%s\n\n" GUI_MUTED "Letters only, the first one a capital.",isFamily ? ("Your family name.") : ("Your given name, as your mother called you."));

		if (error[0] != EOS)
		{
			format(body,sizeof(body),"%s\n\n" GUI_BAD "%s",body,error);
		}

		await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,isFamily ? ("Family name") : ("Given name"),body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

		if (!CreatorGui_IsCurrent(playerid,epoch) || !response[DIALOG_RESPONSE_RESPONSE])
		{
			return;
		}

		if (!Character_ValidateName(response[DIALOG_RESPONSE_INPUTTEXT]))
		{
			format(error,sizeof(error),"That is not a name a priest would write down. Use %d to %d letters and start with a capital.",CHARACTER_NAME_MIN,CHARACTER_NAME_MAX);
			continue;
		}

		if (isFamily)
		{
			strcopy(g_CreatorDraft[playerid][E_CREATE_SURNAME],response[DIALOG_RESPONSE_INPUTTEXT],CHARACTER_NAME_MAX + 1);
		}
		else
		{
			strcopy(g_CreatorDraft[playerid][E_CREATE_NAME],response[DIALOG_RESPONSE_INPUTTEXT],CHARACTER_NAME_MAX + 1);
		}

		return;
	}
}

static CreatorGui_AskAge(playerid,epoch)
{
	new label[CREATOR_GUI_LABEL_LEN], count = Creator_AgeChoiceCount(), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"How old are you");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,200.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"How old are you",x,y,width);

	for (new i = 0;i < count;i++)
	{
		format(label,sizeof(label),"%d years",Creator_AgeChoice(i));
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,label,i,Creator_AgeChoice(i) == g_CreatorDraft[playerid][E_CREATE_AGE] ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!CreatorGui_IsCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return;
	}

	g_CreatorDraft[playerid][E_CREATE_AGE] = Creator_AgeChoice(pick);
}

static CreatorGui_AskOrigin(playerid,epoch)
{
	new name[CREATOR_LABEL_LEN], text[CREATOR_TEXT_LEN], Float:x, Float:y, Float:width;
	new Float:originHeight = float(CREATOR_ORIGIN_ROWS) * KIT_ROW;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Where were you raised");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,380.0,float(_:ORIGIN_COUNT) * originHeight + 6.0 + KIT_ROW + 12.0,"Where were you raised",x,y,width);

	for (new E_ORIGIN:o = ORIGIN_VILLAGE;o < ORIGIN_COUNT;o++)
	{
		new Float:rowY = y + float(_:o) * originHeight;
		Creator_OriginName(o,name);
		Creator_OriginText(o,text);
		Kit_AddHit(playerid,x - 3.0,rowY - 1.0,width + 6.0,originHeight - 2.0,_:o);
		Kit_AddText(playerid,x,rowY,name,o == g_CreatorDraft[playerid][E_CREATE_ORIGIN] ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.30);
		Kit_AddText(playerid,x + width * 0.30,rowY,text,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.70);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(_:ORIGIN_COUNT) * originHeight + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!CreatorGui_IsCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= _:ORIGIN_COUNT)
	{
		return;
	}

	g_CreatorDraft[playerid][E_CREATE_ORIGIN] = E_ORIGIN:pick;
}

static bool:CreatorGui_ShowNature(playerid,epoch)
{
	new name[CREATOR_LABEL_LEN], title[32], Float:x, Float:y, Float:width;

	for (;;)
	{
		new left = CREATOR_ATTR_POOL - Creator_GetAttributeTotal(playerid);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"What are you made of");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,250.0,7.0 * KIT_ROW + 8.0 + KIT_ROW + 12.0,"What are you made of",x,y,width);
		format(title,sizeof(title),"%d point%s left",left,left == 1 ? ("") : ("s"));
		Kit_AddText(playerid,x,y,title,left == 0 ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,KIT_TEXT_ROW);

		for (new E_ATTRIBUTE:a = ATTR_WILLPOWER;a < ATTR_COUNT;a++)
		{
			new Float:rowY = y + float(_:a + 1) * KIT_ROW;
			Creator_AttributeName(a,name);
			Kit_AddHit(playerid,x - 3.0,rowY - 1.0,width + 6.0,KIT_ROW,_:a);
			Kit_AddText(playerid,x,rowY,name,KIT_COLOUR_TEXT,KIT_TEXT_ROW);
			Kit_AddBar(playerid,x + width * 0.46,rowY + 1.0,width * 0.54,7.0,g_CreatorDraft[playerid][E_CREATE_ATTR][a],CREATOR_ATTR_MAX,Creator_AttributeColour(a));
		}

		Kit_AddChoice(playerid,x,y + 6.0 * KIT_ROW,width,"Start over",CREATOR_ROW_RESET_VALUE,KIT_COLOUR_MUTED,"resets every attribute to 1",KIT_COLOUR_MUTED,0.46);
		CreatorGui_AddFooter(playerid,x,y + 7.0 * KIT_ROW + 8.0,width,left == 0,"Spend every point first");

		new pick = await Kit_Present(playerid);

		if (!CreatorGui_IsCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			return false;
		}

		if (pick >= 0 && pick < _:ATTR_COUNT)
		{
			Creator_BumpAttribute(playerid,E_ATTRIBUTE:pick);
		}
		else if (pick == CREATOR_ROW_RESET_VALUE)
		{
			Creator_ResetAttributes(playerid);
		}
		else if (pick == CREATOR_ROW_CONTINUE_VALUE && Creator_HasValidAttributes(playerid))
		{
			if (CreatorGui_ShowMarks(playerid,epoch))
			{
				return true;
			}

			if (!CreatorGui_IsCurrent(playerid,epoch))
			{
				return false;
			}
		}
	}
}

static bool:CreatorGui_ShowMarks(playerid,epoch)
{
	new name[CREATOR_LABEL_LEN], text[CREATOR_TEXT_LEN], title[32], Float:x, Float:y, Float:width;

	for (;;)
	{
		new picked = Creator_CountTraits(playerid);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"What marks you");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,400.0,float(_:TRAIT_COUNT + 1) * KIT_ROW + 8.0 + KIT_ROW + 12.0,"What marks you",x,y,width);
		format(title,sizeof(title),"%d of %d taken",picked,CREATOR_TRAIT_PICKS);
		Kit_AddText(playerid,x,y,title,picked == CREATOR_TRAIT_PICKS ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,KIT_TEXT_ROW);

		for (new E_TRAIT:tr = TRAIT_HARDY;tr < TRAIT_COUNT;tr++)
		{
			new bool:isTaken = Creator_HasTrait(playerid,tr);
			Creator_TraitName(tr,name);
			Creator_TraitText(tr,text);
			Kit_AddChoice(playerid,x,y + float(_:tr + 1) * KIT_ROW,width,name,_:tr,isTaken ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,text,isTaken ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,0.24);
		}

		CreatorGui_AddFooter(playerid,x,y + float(_:TRAIT_COUNT + 1) * KIT_ROW + 8.0,width,picked == CREATOR_TRAIT_PICKS,"Pick two traits first");

		new pick = await Kit_Present(playerid);

		if (!CreatorGui_IsCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			return false;
		}

		if (pick >= 0 && pick < _:TRAIT_COUNT)
		{
			if (!Creator_HasTrait(playerid,E_TRAIT:pick) && picked == CREATOR_TRAIT_PICKS)
			{
				Gui_Notify(playerid,"You can only have two traits. Click one of yours again to drop it, then pick the new one.");
				continue;
			}

			Creator_ToggleTrait(playerid,E_TRAIT:pick);
		}
		else if (pick == CREATOR_ROW_CONTINUE_VALUE && picked == CREATOR_TRAIT_PICKS)
		{
			if (CreatorGui_ShowTrade(playerid,epoch))
			{
				return true;
			}

			if (!CreatorGui_IsCurrent(playerid,epoch))
			{
				return false;
			}
		}
	}
}

static bool:CreatorGui_ShowTrade(playerid,epoch)
{
	new name[CREATOR_LABEL_LEN], text[CREATOR_TEXT_LEN], Float:x, Float:y, Float:width;

	for (;;)
	{
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"How do you earn your bread");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,340.0,float(_:LIFESTYLE_COUNT) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"How do you earn your bread",x,y,width);

		for (new E_LIFESTYLE:l = LIFESTYLE_FARMHAND;l < LIFESTYLE_COUNT;l++)
		{
			Creator_LifestyleName(l,name);
			Creator_LifestyleText(l,text);
			Kit_AddChoice(playerid,x,y + float(_:l) * KIT_ROW,width,name,_:l,l == g_CreatorDraft[playerid][E_CREATE_LIFESTYLE] ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,text,KIT_COLOUR_MUTED,0.28);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(_:LIFESTYLE_COUNT) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!CreatorGui_IsCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			return false;
		}

		if (pick < 0 || pick >= _:LIFESTYLE_COUNT)
		{
			continue;
		}

		g_CreatorDraft[playerid][E_CREATE_LIFESTYLE] = E_LIFESTYLE:pick;

		if (CreatorGui_ShowSummary(playerid,epoch))
		{
			return true;
		}

		if (!CreatorGui_IsCurrent(playerid,epoch))
		{
			return false;
		}
	}
}

static bool:CreatorGui_ShowSummary(playerid,epoch)
{
	new line[128], culture[CULTURE_NAME_LEN], tongue[CULTURE_NAME_LEN], origin[CREATOR_LABEL_LEN], lifestyle[CREATOR_LABEL_LEN], traitA[CREATOR_LABEL_LEN], traitB[CREATOR_LABEL_LEN], bonus[CREATOR_LABEL_LEN], Float:x, Float:y, Float:width;
	Culture_GetName(g_CreatorDraft[playerid][E_CREATE_CULTURE],culture);
	Language_GetName(Language_GetNative(g_CreatorDraft[playerid][E_CREATE_CULTURE]),tongue);
	Creator_OriginName(g_CreatorDraft[playerid][E_CREATE_ORIGIN],origin);
	Creator_AttributeName(Creator_OriginBonus(g_CreatorDraft[playerid][E_CREATE_ORIGIN]),bonus);
	Creator_LifestyleName(g_CreatorDraft[playerid][E_CREATE_LIFESTYLE],lifestyle);
	Creator_TraitName(g_CreatorDraft[playerid][E_CREATE_TRAIT_A],traitA);
	Creator_TraitName(g_CreatorDraft[playerid][E_CREATE_TRAIT_B],traitB);

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Is this you");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,6.0 * KIT_ROW + 5.0 * KIT_ROW + 12.0 + KIT_ROW + 12.0,"Is this you",x,y,width);
	format(line,sizeof(line),"%s %s",g_CreatorDraft[playerid][E_CREATE_NAME],g_CreatorDraft[playerid][E_CREATE_SURNAME]);
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_ACCENT,KIT_TEXT_BODY);
	format(line,sizeof(line),"A %s of %d years, %s, raised as a %s.",g_CreatorDraft[playerid][E_CREATE_SEX] ? ("woman") : ("man"),g_CreatorDraft[playerid][E_CREATE_AGE],culture,origin);
	Kit_AddText(playerid,x,y + KIT_ROW * 1.3,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	format(line,sizeof(line),"Speaks Common and %s.",tongue);
	Kit_AddText(playerid,x,y + KIT_ROW * 2.3,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	format(line,sizeof(line),"Traits: %s and %s. Starts out as a %s.",traitA,traitB,lifestyle);
	Kit_AddText(playerid,x,y + KIT_ROW * 3.3,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	format(line,sizeof(line),"You get 1 extra %s from your upbringing.",bonus);
	Kit_AddText(playerid,x,y + KIT_ROW * 4.3,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	for (new E_ATTRIBUTE:a = ATTR_WILLPOWER;a < ATTR_COUNT;a++)
	{
		new Float:rowY = y + KIT_ROW * 5.8 + float(_:a) * KIT_ROW;
		Creator_AttributeName(a,line);
		Kit_AddText(playerid,x,rowY,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW);
		Kit_AddBar(playerid,x + width * 0.46,rowY + 1.0,width * 0.54,7.0,g_CreatorDraft[playerid][E_CREATE_ATTR][a],CREATOR_ATTR_MAX,Creator_AttributeColour(a));
	}

	Kit_AddButton(playerid,x,y + KIT_ROW * 11.0 + 12.0,width * 0.62,"Create",CREATOR_ROW_CONTINUE_VALUE,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width * 0.68,y + KIT_ROW * 11.0 + 12.0,width * 0.32,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!CreatorGui_IsCurrent(playerid,epoch) || pick != CREATOR_ROW_CONTINUE_VALUE)
	{
		return false;
	}

	Kit_Close(playerid);
	Creator_Insert(playerid);
	return true;
}

static CreatorGui_EnterLook(playerid)
{
	s_CreatorLooking[playerid] = true;
	s_CreatorLastLeftRight[playerid] = 0;
	Scene_ShowLook(playerid);
	Gui_Notify(playerid,"Use the left and right keys to change your look. Press Space when you're happy with it.");
}

forward CreatorGui_IdentityDeferred(playerid);

public CreatorGui_IdentityDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Creator_IsActive(playerid))
	{
		CreatorGui_ShowIdentity(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CreatorLooking[playerid] = false;
}

hook OnPlayerUpdate(playerid)
{
	if (!s_CreatorLooking[playerid])
	{
		return;
	}

	if (!Creator_IsActive(playerid))
	{
		s_CreatorLooking[playerid] = false;
		return;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);

	if (leftright == s_CreatorLastLeftRight[playerid])
	{
		return;
	}

	s_CreatorLastLeftRight[playerid] = leftright;

	if (leftright == KEY_LEFT)
	{
		Creator_CycleLook(playerid,-1);
		PlayerPlaySound(playerid,1052);
	}
	else if (leftright == KEY_RIGHT)
	{
		Creator_CycleLook(playerid,1);
		PlayerPlaySound(playerid,1053);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!s_CreatorLooking[playerid])
	{
		return;
	}

	if ((newkeys & KEY_SPRINT) && !(oldkeys & KEY_SPRINT))
	{
		s_CreatorLooking[playerid] = false;
		PlayerPlaySound(playerid,1054);
		Scene_ShowCreator(playerid,Creator_GetSkin(playerid));
		SetTimerEx("CreatorGui_IdentityDeferred",0,false,"d",playerid);
	}
}
