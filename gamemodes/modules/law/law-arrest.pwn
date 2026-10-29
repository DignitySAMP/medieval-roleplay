#define LAW_TARGET_REACH (1.8)
#define LAW_PICK_BIND (1)
#define LAW_PICK_UNTIE (2)
#define LAW_PICK_ARREST (3)
#define LAW_PICK_SENTENCE (10)

enum
{
	LAW_PROMPT_NONE,
	LAW_PROMPT_REGISTER,
	LAW_PROMPT_TARGET,
}

static s_LawBoundBy[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};
static s_LawPromptKind[MAX_PLAYERS];
static s_LawPromptTarget[MAX_PLAYERS];
static s_LawPromptInfobox[MAX_PLAYERS];
static s_LawLooseIn[MAX_PLAYERS];

stock bool:Law_IsBound(playerid)
{
	return Util_IsValidPlayer(playerid) && s_LawBoundBy[playerid] != INVALID_PLAYER_ID;
}

stock Law_Bind(playerid,byid)
{
	if (Combat_IsStruckDown(playerid))
	{
		Combat_Revive(playerid,byid);
	}

	s_LawBoundBy[playerid] = byid;
	SetPlayerSpecialAction(playerid,SPECIAL_ACTION_CUFFED);
	Law_UpdateCue(playerid);
	pawn_call_public("Law_OnBound","dd",playerid,byid);
}

stock Law_Untie(playerid)
{
	if (!Law_IsBound(playerid))
	{
		return;
	}

	s_LawBoundBy[playerid] = INVALID_PLAYER_ID;

	if (IsPlayerConnected(playerid))
	{
		SetPlayerSpecialAction(playerid,SPECIAL_ACTION_NONE);
	}

	Law_UpdateCue(playerid);
}

static Law_ClearPrompt(playerid)
{
	if (s_LawPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_LawPromptInfobox[playerid]);
	}

	s_LawPromptKind[playerid] = LAW_PROMPT_NONE;
	s_LawPromptTarget[playerid] = INVALID_PLAYER_ID;
	s_LawPromptInfobox[playerid] = 0;
}

static bool:Law_IsDown(playerid)
{
	return Wounds_IsDown(playerid) || Combat_IsStruckDown(playerid);
}

static Law_FindTarget(playerid)
{
	new Float:x, Float:y, Float:z, best = INVALID_PLAYER_ID, Float:bestDistance = LAW_TARGET_REACH;
	GetPlayerPos(playerid,x,y,z);

	foreach (new i : Player)
	{
		if (i == playerid || IsPlayerNPC(i) || !Session_IsPlaying(i) || GetPlayerVirtualWorld(i) != GetPlayerVirtualWorld(playerid) || Law_IsServing(i))
		{
			continue;
		}

		if (!Law_IsDown(i) && !Law_IsBound(i))
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(i,x,y,z);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Law_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Mount_IsRiding(playerid) || Law_IsDown(playerid) || Law_IsBound(playerid) || Law_IsServing(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Law_ClearPrompt(playerid);
		return;
	}

	new kind = LAW_PROMPT_NONE, target, text[200];

	if (Law_IsAtRegister(playerid))
	{
		kind = LAW_PROMPT_REGISTER;
		target = INVALID_PLAYER_ID;
		strcopy(text,"Press ~y~Y~w~ to open the gaol register.");
	}
	else if ((Law_IsGuard(playerid) || Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_ROPE) > 0) && (target = Law_FindTarget(playerid)) != INVALID_PLAYER_ID)
	{
		new known[LAW_DESCRIPTION_LEN + 8];
		kind = LAW_PROMPT_TARGET;
		Law_GetKnownOrLook(playerid,target,known,sizeof(known),true);
		format(text,sizeof(text),"%s is %s.~n~Press ~y~Y~w~ to deal with them.",known,Law_IsBound(target) ? ("bound") : ("down"));
	}

	if (kind == LAW_PROMPT_NONE)
	{
		Law_ClearPrompt(playerid);
		return;
	}

	if (kind == s_LawPromptKind[playerid] && target == s_LawPromptTarget[playerid] && Infobox_IsShown(playerid,s_LawPromptInfobox[playerid]))
	{
		return;
	}

	s_LawPromptKind[playerid] = kind;
	s_LawPromptTarget[playerid] = target;
	s_LawPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_LawPromptInfobox[playerid],kind == LAW_PROMPT_REGISTER ? ("Gaol register") : ("The law"),text,2);
}

static Law_PayBounty(playerid,targetid)
{
	new bounty = Law_GetBounty(targetid);

	if (bounty <= 0 || playerid == targetid)
	{
		return;
	}

	new money[24], text[128];
	Economy_Format(bounty,money);
	Economy_GiveOrClaim(playerid,Character_GetId(playerid),bounty,"bounty");
	format(text,sizeof(text),"The county pays you the bounty: %s.",money);
	Gui_Notify(playerid,text);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO bounties_paid (character_id, target_character_id, amount, at) VALUES (%d, %d, %d, %d)",Character_GetId(playerid),Character_GetId(targetid),bounty,gettime()));
}

stock Law_HandOver(playerid,targetid)
{
	if (!Law_IsBound(targetid))
	{
		Gui_Notify(playerid,"They aren't bound.");
		return;
	}

	new known[LAW_DESCRIPTION_LEN + 8], text[200];
	Law_GetKnownOrLook(playerid,targetid,known,sizeof(known),true);

	if (!Law_IsWanted(targetid))
	{
		Law_Untie(targetid);
		format(text,sizeof(text),"%s isn't on the roll of the wanted. The watch unties them and sends them on their way.",known);
		Gui_Notify(playerid,text);
		Gui_Notify(targetid,"The watch finds nothing against you and lets you go.");
		return;
	}

	new crime = Law_GetWantedCrime(targetid);
	Law_PayBounty(playerid,targetid);
	Law_Untie(targetid);
	Law_Sentence(targetid,g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_SENTENCE],g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_MINUTES],g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_FINE],playerid);
	format(text,sizeof(text),"You hand %s over. The watch deals with them by the county's table.",known);
	Gui_Notify(playerid,text);
}

static Law_ArrestFlow(playerid,epoch,targetid)
{
	new crime = Law_IsWanted(targetid) ? Law_GetWantedCrime(targetid) : LAW_CRIME_ASSAULT;
	new minutes = max(g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_MINUTES],15), fine = g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_FINE];

	for (;;)
	{
		new picks[6], labels[6][72], count = 0, money[24], crimeName[LAW_NAME_LEN], title[48];
		Economy_Format(fine,money);
		Law_GetCrimeName(crime,crimeName);
		format(title,sizeof(title),Law_IsWanted(targetid) ? ("Wanted for %s") : ("Not on the roll"),crimeName);
		format(labels[count],72,"The gaol, %d minutes",g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_SENTENCE] == LAW_SENTENCE_GAOL ? minutes : 30);
		picks[count++] = LAW_PICK_SENTENCE + LAW_SENTENCE_GAOL;
		format(labels[count],72,"The pillory, %d minutes",min(minutes,Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_PILLORY_MINUTES)));
		picks[count++] = LAW_PICK_SENTENCE + LAW_SENTENCE_PILLORY;
		format(labels[count],72,"The stocks, %d minutes",min(minutes,30));
		picks[count++] = LAW_PICK_SENTENCE + LAW_SENTENCE_STOCKS;
		format(labels[count],72,"A fine of %s",money);
		picks[count++] = LAW_PICK_SENTENCE + LAW_SENTENCE_FINE;

		if (Law_GetRank(playerid) == LAW_RANK_SERGEANT)
		{
			strcopy(labels[count],"A flogging",72);
			picks[count++] = LAW_PICK_SENTENCE + LAW_SENTENCE_FLOG;
		}

		new Float:x, Float:y, Float:width;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LAW_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		for (new i = 0;i < count;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i]);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			return;
		}

		if (!IsPlayerConnected(targetid) || (!Law_IsBound(targetid) && !Law_IsDown(targetid)) || !Law_IsGuard(playerid))
		{
			Kit_Close(playerid);
			Gui_Notify(playerid,"You can't arrest them now.");
			return;
		}

		new kind = pick - LAW_PICK_SENTENCE, length = kind == LAW_SENTENCE_GAOL ? (g_LawCrimeDefs[crime][E_LAW_CRIME_DEF_SENTENCE] == LAW_SENTENCE_GAOL ? minutes : 30) : min(minutes,kind == LAW_SENTENCE_PILLORY ? Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_PILLORY_MINUTES) : 30);
		Kit_Close(playerid);

		if (Law_IsWanted(targetid))
		{
			Law_PayBounty(playerid,targetid);
		}

		Law_Untie(targetid);

		if (!Law_Sentence(targetid,kind,length,fine,playerid))
		{
			Gui_Notify(playerid,"There's no free place for them right now.");
			return;
		}

		new known[LAW_DESCRIPTION_LEN + 8], text[200];
		Law_GetKnownOrLook(playerid,targetid,known,sizeof(known),true);
		format(text,sizeof(text),"%s is taken away: %s.",known,g_LawSentenceNames[kind]);
		Gui_Notify(playerid,text);
		return;
	}
}

stock Law_OpenTarget(playerid,targetid)
{
	new epoch = Gui_BeginFlow(playerid);

	for (;;)
	{
		if (!IsPlayerConnected(targetid) || (!Law_IsDown(targetid) && !Law_IsBound(targetid)))
		{
			Kit_Close(playerid);
			return;
		}

		new picks[4], labels[4][48], count = 0, known[MAX_PLAYER_NAME + 8];
		Nametag_GetKnownName(playerid,targetid,known);

		if (!Law_IsBound(targetid))
		{
			strcopy(labels[count],Law_IsGuard(playerid) ? ("Shackle their hands") : ("Bind their hands with rope"),48);
			picks[count++] = LAW_PICK_BIND;
		}
		else
		{
			strcopy(labels[count],"Untie them",48);
			picks[count++] = LAW_PICK_UNTIE;
		}

		if (Law_IsGuard(playerid))
		{
			strcopy(labels[count],"Arrest them",48);
			picks[count++] = LAW_PICK_ARREST;
		}

		new Float:x, Float:y, Float:width;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,known);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LAW_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,known,x,y,width);

		for (new i = 0;i < count;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i]);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case LAW_PICK_BIND:
			{
				if (!Law_IsGuard(playerid) && !Inventory_Take(playerid,ITEM_KIND_MISC,ITEM_ROPE,1))
				{
					Gui_Notify(playerid,"You need a rope.");
					continue;
				}

				Law_Bind(targetid,playerid);
				Gui_Notify(targetid,"Your hands are bound.");
				Chat_Speak(playerid,CHAT_ME,"binds their hands.");
			}
			case LAW_PICK_UNTIE:
			{
				Law_Untie(targetid);
				Gui_Notify(targetid,"Your hands are untied.");
				Chat_Speak(playerid,CHAT_ME,"unties the rope.");
			}
			case LAW_PICK_ARREST:
			{
				Law_ArrestFlow(playerid,epoch,targetid);
				Kit_Close(playerid);
				return;
			}
		}
	}
}

Timer_Declare(Law_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Law_UpdatePrompt(playerid);
		}
	}

	return 1;
}

Timer_Declare(Law_Tick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Law_ServeTick(playerid,LAW_TICK_MS / 1000);

			if (Law_IsBound(playerid) && GetPlayerSpecialAction(playerid) != SPECIAL_ACTION_CUFFED && !Law_IsDown(playerid))
			{
				SetPlayerSpecialAction(playerid,SPECIAL_ACTION_CUFFED);
			}

			if (s_LawBoundBy[playerid] == playerid && --s_LawLooseIn[playerid] <= 0)
			{
				Law_Untie(playerid);
				Gui_Notify(playerid,"With nobody watching, you work the rope loose.");
			}
		}
	}

	return 1;
}

forward Law_TargetDeferred(playerid,targetid);

public Law_TargetDeferred(playerid,targetid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Law_OpenTarget(playerid,targetid);
	}

	return 1;
}

forward bool:Law_PromptContext(playerid);

public bool:Law_PromptContext(playerid)
{
	return s_LawPromptKind[playerid] != LAW_PROMPT_NONE && !Combat_IsInMode(playerid);
}

forward bool:Law_BusyCheck(playerid);

public bool:Law_BusyCheck(playerid)
{
	return Law_IsBound(playerid) || Pillory_IsLocked(playerid);
}

forward Law_OnBound(playerid,byid);

public Law_OnBound(playerid,byid)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LawBoundBy[playerid] = INVALID_PLAYER_ID;
	s_LawPromptKind[playerid] = LAW_PROMPT_NONE;
	s_LawPromptTarget[playerid] = INVALID_PLAYER_ID;
	s_LawPromptInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	foreach (new i : Player)
	{
		if (s_LawBoundBy[i] == playerid)
		{
			s_LawBoundBy[i] = i;
			s_LawLooseIn[i] = 60;
		}
	}

	s_LawBoundBy[playerid] = INVALID_PLAYER_ID;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_LawPromptKind[playerid] == LAW_PROMPT_NONE || Infobox_IsPromptBlocked(playerid,s_LawPromptInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new kind = s_LawPromptKind[playerid], target = s_LawPromptTarget[playerid];
	Law_ClearPrompt(playerid);

	if (kind == LAW_PROMPT_REGISTER)
	{
		SetTimerEx("Law_RegisterDeferred",0,false,"d",playerid);
	}
	else
	{
		SetTimerEx("Law_TargetDeferred",0,false,"dd",playerid,target);
	}
}
