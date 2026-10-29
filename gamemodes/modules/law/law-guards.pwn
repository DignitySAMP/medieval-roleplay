#define LAW_REGISTER_REACH (1.6)
#define LAW_REGISTER_LABEL_RANGE (6.0)
#define LAW_HANDOVER_REACH (5.0)
#define LAW_PICK_DUTY (1)
#define LAW_PICK_WANTED (2)
#define LAW_PICK_PAY (3)
#define LAW_PICK_HANDOVER (100)
#define LAW_PICK_ROLL (4)

static s_LawRank[MAX_PLAYERS];
static bool:s_LawOnDuty[MAX_PLAYERS];
static bool:s_LawIssued[MAX_PLAYERS];
static STREAMER_TAG_OBJECT:s_LawRegisterObject = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
static STREAMER_TAG_3D_TEXT_LABEL:s_LawRegisterLabel = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

stock bool:Law_IsGuard(playerid)
{
	return Util_IsValidPlayer(playerid) && s_LawOnDuty[playerid] && Session_IsPlaying(playerid);
}

stock Law_GetRank(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_LawRank[playerid] : LAW_RANK_NONE;
}

stock Law_CountGuardsOnDuty()
{
	new count = 0;

	foreach (new i : Player)
	{
		if (Law_IsGuard(i))
		{
			count++;
		}
	}

	return count;
}

stock Law_GetRegisterStand(&Float:x,&Float:y,&Float:z)
{
	new Float:a = g_LawSeedRegister[3];
	x = g_LawSeedRegister[0] + 0.55 * floatsin(a,degrees);
	y = g_LawSeedRegister[1] - 0.55 * floatcos(a,degrees);
	z = g_LawSeedRegister[2];
}

stock bool:Law_IsAtRegister(playerid)
{
	new Float:x, Float:y, Float:z;
	Law_GetRegisterStand(x,y,z);
	return GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,LAW_REGISTER_REACH,x,y,z + 1.0);
}

stock Law_PlaceRegister()
{
	if (IsValidDynamicObject(s_LawRegisterObject))
	{
		DestroyDynamicObject(s_LawRegisterObject);
	}

	if (IsValidDynamic3DTextLabel(s_LawRegisterLabel))
	{
		DestroyDynamic3DTextLabel(s_LawRegisterLabel);
	}

	s_LawRegisterObject = CreateDynamicObject(MODEL_WRITING_LEDGER_LECTERN,g_LawSeedRegister[0],g_LawSeedRegister[1],g_LawSeedRegister[2],0.0,0.0,g_LawSeedRegister[3],0,0,-1,80.0,80.0);
	s_LawRegisterLabel = CreateDynamic3DTextLabel("Gaol register",0xD8CCB2AA,g_LawSeedRegister[0],g_LawSeedRegister[1],g_LawSeedRegister[2] + 1.5,LAW_REGISTER_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,true,0,0);
}

static Law_IssueArms(playerid,bool:isIssuing)
{
	new weapon = -1, bool:hasShield = false, bool:hasTorch = false;

	switch (s_LawRank[playerid])
	{
		case LAW_RANK_WATCHMAN:
		{
			weapon = WEAPON_KNIFE_CLUB;
			hasTorch = true;
		}
		case LAW_RANK_GUARD:
		{
			weapon = WEAPON_SPEAR;
			hasShield = true;
		}
		case LAW_RANK_SERGEANT:
		{
			weapon = WEAPON_SHORTSWORD_LONGSWORD;
			hasShield = true;
		}
	}

	if (isIssuing)
	{
		if (weapon != -1)
		{
			Inventory_Give(playerid,ITEM_KIND_WEAPON,weapon);
		}

		if (hasShield)
		{
			Inventory_Give(playerid,ITEM_KIND_SHIELD,0);
		}

		if (hasTorch)
		{
			Inventory_Give(playerid,ITEM_KIND_MISC,ITEM_TORCH,2);
		}

		return;
	}

	if (weapon != -1)
	{
		Inventory_Take(playerid,ITEM_KIND_WEAPON,weapon,1);
	}

	if (hasShield)
	{
		Inventory_Take(playerid,ITEM_KIND_SHIELD,0,1);
	}

	if (hasTorch)
	{
		Inventory_Take(playerid,ITEM_KIND_MISC,ITEM_TORCH,min(Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_TORCH),2));
	}
}

stock Law_SetDuty(playerid,bool:isOn)
{
	if (s_LawRank[playerid] == LAW_RANK_NONE || s_LawOnDuty[playerid] == isOn)
	{
		return;
	}

	s_LawOnDuty[playerid] = isOn;
	Law_IssueArms(playerid,isOn);
	s_LawIssued[playerid] = isOn;
	mysql_tquery_s(g_Mysql,str_format("UPDATE law_guards SET issued = %d WHERE character_id = %d",_:isOn,Character_GetId(playerid)));

	if (isOn)
	{
		new text[128];
		format(text,sizeof(text),"You take the county's arms and go on duty as a %s.",g_LawRankNames[s_LawRank[playerid]]);
		Gui_Notify(playerid,text);
	}
	else
	{
		Gui_Notify(playerid,"You hand back the county's arms and go off duty.");
	}
	pawn_call_public("Law_OnDuty","dd",playerid,_:isOn);
}

stock Law_Appoint(playerid,rank,byid)
{
	if (s_LawOnDuty[playerid])
	{
		Law_SetDuty(playerid,false);
	}

	s_LawRank[playerid] = Util_ClampInt(rank,LAW_RANK_NONE,LAW_RANK_SERGEANT);

	if (s_LawRank[playerid] == LAW_RANK_NONE)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM law_guards WHERE character_id = %d",Character_GetId(playerid)));
		Gui_Notify(playerid,"You're no longer one of the county's guards.");
		pawn_call_public("Law_OnAppointed","dd",playerid,LAW_RANK_NONE);
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO law_guards (character_id, county_id, rank, appointed_by, since, issued) VALUES (%d, %d, %d, %d, %d, 0) ON DUPLICATE KEY UPDATE rank = VALUES(rank), appointed_by = VALUES(appointed_by)",Character_GetId(playerid),LAW_COUNTY,s_LawRank[playerid],Util_IsValidPlayer(byid) ? Character_GetId(byid) : 0,gettime()));

	new text[144];
	format(text,sizeof(text),"You're made a %s of the county. Go on duty at the gaol register by the guardhouse.",g_LawRankNames[s_LawRank[playerid]]);
	Gui_Notify(playerid,text);
	pawn_call_public("Law_OnAppointed","dd",playerid,s_LawRank[playerid]);
}

static Law_FindBoundNear(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new i : Player)
	{
		if (i != playerid && Law_IsBound(i) && GetPlayerVirtualWorld(i) == GetPlayerVirtualWorld(playerid) && GetPlayerDistanceFromPoint(i,x,y,z) <= LAW_HANDOVER_REACH)
		{
			return i;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Law_ShowWanted(playerid,epoch)
{
	new text[1024], count = 0;

	foreach (new i : Player)
	{
		if (!Law_IsWanted(i) || count >= 8)
		{
			continue;
		}

		new crime[LAW_NAME_LEN], description[LAW_DESCRIPTION_LEN], line[180];
		Law_GetCrimeName(Law_GetWantedCrime(i),crime);
		Law_Describe(i,description);
		description[0] = toupper(description[0]);
		format(line,sizeof(line),"~y~%s~w~ for %s, bounty %d pfennig.~n~",description,crime,Law_GetBounty(i));
		strcat(text,line);
		count++;
	}

	if (count == 0)
	{
		strcopy(text,"Nobody wanted is about right now.");
	}

	Gui_ShowMessage(playerid,"The roll of the wanted",text,GUI_BUTTON_BACK,320.0);
	#pragma unused epoch
}

stock Law_OpenRegister(playerid)
{
	new epoch = Gui_BeginFlow(playerid);

	for (;;)
	{
		new picks[6], labels[6][72], count = 0, bound = Law_FindBoundNear(playerid);

		if (s_LawRank[playerid] != LAW_RANK_NONE)
		{
			if (s_LawOnDuty[playerid])
			{
				format(labels[count],72,"Go off duty");
			}
			else
			{
				format(labels[count],72,"Go on duty as a %s",g_LawRankNames[s_LawRank[playerid]]);
			}
			picks[count++] = LAW_PICK_DUTY;
		}

		strcopy(labels[count],"Read the roll of the wanted",72);
		picks[count++] = LAW_PICK_ROLL;

		if (Law_IsWanted(playerid))
		{
			new money[24];
			Economy_Format(Law_GetFine(Law_GetWantedCrime(playerid)),money);
			format(labels[count],72,"Pay your fine (%s) and clear your name",money);
			picks[count++] = LAW_PICK_PAY;
		}

		if (bound != INVALID_PLAYER_ID && bound != playerid)
		{
			new known[MAX_PLAYER_NAME + 8];
			Nametag_GetKnownName(playerid,bound,known);
			format(labels[count],72,"Hand %s over to the watch",known);
			picks[count++] = LAW_PICK_HANDOVER;
		}

		new Float:x, Float:y, Float:width;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Gaol register");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LAW_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Gaol register",x,y,width);

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
			case LAW_PICK_DUTY:
			{
				Law_SetDuty(playerid,!s_LawOnDuty[playerid]);
			}
			case LAW_PICK_ROLL:
			{
				Kit_Close(playerid);
				Law_ShowWanted(playerid,epoch);
				return;
			}
			case LAW_PICK_PAY:
			{
				new fine = Law_GetFine(Law_GetWantedCrime(playerid)), money[24];
				Economy_Format(fine,money);

				if (Economy_Pay(playerid,fine,INVALID_CONTAINER_ID,"fine") != PAY_OK)
				{
					Gui_Notify(playerid,"You don't have the coin to pay it.");
					continue;
				}

				Law_ClearWanted(playerid);
				mysql_tquery_s(g_Mysql,str_format("INSERT INTO sentences (character_id, kind, county_id, minutes, served, fine, sentenced_by, at, done, outcome) VALUES (%d, %d, %d, 0, 0, %d, 0, %d, 1, 'paid')",Character_GetId(playerid),LAW_SENTENCE_FINE,LAW_COUNTY,fine,gettime()));
				new text[96];
				format(text,sizeof(text),"You pay %s at the register. Your name is struck from the roll.",money);
				Gui_Notify(playerid,text);
			}
			case LAW_PICK_HANDOVER:
			{
				Kit_Close(playerid);
				Law_HandOver(playerid,bound);
				return;
			}
		}
	}
}

static Law_ReturnArms(playerid)
{
	Law_IssueArms(playerid,false);
	s_LawIssued[playerid] = false;
	mysql_tquery_s(g_Mysql,str_format("UPDATE law_guards SET issued = 0 WHERE character_id = %d",Character_GetId(playerid)));
	Gui_Notify(playerid,"The county's arms went back to the armoury when you left your post.");
}

forward Task:Law_LoadGuard(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Law_LoadGuard(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT rank, issued FROM law_guards WHERE character_id = %d AND county_id = %d",characterid,LAW_COUNTY));

	if (!cache_num_rows() || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	new issued;
	cache_get_value_name_int(0,"rank",s_LawRank[playerid]);
	cache_get_value_name_int(0,"issued",issued);
	s_LawIssued[playerid] = issued != 0;

	if (s_LawIssued[playerid] && Inventory_IsLoaded(playerid))
	{
		Law_ReturnArms(playerid);
	}

	return async 1;
}
#pragma warning pop

forward Law_OnAppointed(playerid,rank);

public Law_OnAppointed(playerid,rank)
{
	return 1;
}

forward Law_OnDuty(playerid,isOn);

public Law_OnDuty(playerid,isOn)
{
	return 1;
}

forward Law_RegisterDeferred(playerid);

public Law_RegisterDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Law_OpenRegister(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LawRank[playerid] = LAW_RANK_NONE;
	s_LawOnDuty[playerid] = false;
	s_LawIssued[playerid] = false;
}

hook Character_OnLoaded(playerid,characterid)
{
	s_LawRank[playerid] = LAW_RANK_NONE;
	s_LawOnDuty[playerid] = false;
	s_LawIssued[playerid] = false;
	Law_LoadGuard(playerid,characterid);
}

hook Inventory_OnLoaded(playerid)
{
	if (s_LawIssued[playerid] && !s_LawOnDuty[playerid])
	{
		Law_ReturnArms(playerid);
	}
}
