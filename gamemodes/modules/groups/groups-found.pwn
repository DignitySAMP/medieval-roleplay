forward bool:Groups_StewardWouldJudge(playerid);

stock bool:Groups_IsGoodName(const name[])
{
	new len = strlen(name);

	if (len < 4 || len > GROUPS_NAME_LEN - 8)
	{
		return false;
	}

	for (new i = 0;i < len;i++)
	{
		new c = name[i];

		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == ' ' || c == '\'' || c == '-'))
		{
			return false;
		}
	}

	return name[0] != ' ' && name[len - 1] != ' ';
}

stock bool:Groups_AskConsent(targetid,const title[],const text[],const yes[] = "Agree",const no[] = "Refuse")
{
	if (!Session_IsPlaying(targetid) || Gui_IsBusy(targetid))
	{
		return false;
	}

	new token = Account_GetToken(targetid), epoch = Gui_BeginFlow(targetid), Float:x, Float:y, Float:width;
	Kit_Begin(targetid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(targetid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 40.0,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(targetid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddChoice(targetid,x,y + KIT_ROW * 3.0,width * 0.48,yes,1,KIT_COLOUR_GOOD);
	Kit_AddChoice(targetid,x + width * 0.52,y + KIT_ROW * 3.0,width * 0.48,no,2,KIT_COLOUR_BAD);
	new pick = await Kit_Present(targetid);

	if (!IsPlayerConnected(targetid) || Account_GetToken(targetid) != token)
	{
		return false;
	}

	if (Gui_IsFlowCurrent(targetid,epoch))
	{
		Kit_Close(targetid);
	}

	return pick == 1;
}

stock bool:Groups_IsBeside(playerid,otherid,Float:range = GROUPS_NEAR)
{
	if (!Util_IsValidPlayer(playerid) || !Util_IsValidPlayer(otherid) || !Session_IsPlaying(otherid) || GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(otherid))
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(otherid,x,y,z);
	return IsPlayerInRangeOfPoint(playerid,range,x,y,z);
}

stock Groups_Nearby(playerid,list[],size = sizeof(list),Float:range = GROUPS_NEAR)
{
	new count = 0, Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new other : Player)
	{
		if (other != playerid && count < size && !IsPlayerNPC(other) && Session_IsPlaying(other) && GetPlayerVirtualWorld(other) == GetPlayerVirtualWorld(playerid) && IsPlayerInRangeOfPoint(other,range,x,y,z))
		{
			list[count++] = other;
		}
	}

	return count;
}

stock Groups_PickNearby(playerid,const title[],const nearby[],count)
{
	if (count == 0)
	{
		return INVALID_PLAYER_ID;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[MAX_PLAYER_NAME];
		Nametag_GetKnownName(playerid,nearby[i],name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || !IsPlayerConnected(nearby[pick]))
	{
		return INVALID_PLAYER_ID;
	}

	return nearby[pick];
}

stock bool:Groups_MayJoinKind(playerid,kind,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	if (Groups_FindMineOfKind(playerid,kind) != GROUP_INVALID)
	{
		format(reason,size,"already sworn to a %s",g_GroupKindNames[kind]);
		return false;
	}

	if (Groups_CountRolled(playerid) >= GROUPS_PER_CHARACTER)
	{
		strcopy(reason,"already in three groups",size);
		return false;
	}

	return true;
}

stock Groups_PickTrade(playerid)
{
	new trades[TRADE_COUNT], count = 0;

	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		if (Work_GetLevel(playerid,trade) >= GROUPS_GUILD_LEVEL && Groups_FindGuild(trade) == GROUP_INVALID)
		{
			trades[count++] = trade;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,sprintf("A charter is for a trade you've reached level %d in, and that has no guild in the county yet.",GROUPS_GUILD_LEVEL));
		return -1;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Which trade?");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(count) * KIT_ROW * 0.82 + 6.0 + KIT_ROW + 12.0,"Which trade?",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[32];
		Trade_GetName(trades[i],name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(i),width,name,i,KIT_COLOUR_TEXT,sprintf("level %d",Work_GetLevel(playerid,trades[i])),KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW * 0.82 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return -1;
	}

	return trades[pick];
}

stock Groups_StartFounding(playerid,kind,hideout)
{
	new reason[48];

	if (!Groups_MayJoinKind(playerid,kind,reason))
	{
		Gui_Notify(playerid,sprintf("You can't found one: you're %s.",reason));
		return;
	}

	switch (kind)
	{
		case GROUP_KIND_HOUSEHOLD:
		{
			if (!Realm_IsRuler(playerid) && !Realm_IsDuke(playerid))
			{
				Gui_Notify(playerid,"Only a lord of the realm keeps a household.");
				return;
			}
		}
		case GROUP_KIND_ORDER:
		{
			if (Clergy_GetRank(playerid) < CLERGY_PRIOR)
			{
				Gui_Notify(playerid,"Only a prior or an abbot founds an order, under the bishop.");
				return;
			}
		}
		case GROUP_KIND_OUTLAW:
		{
			if (hideout < 0 || hideout >= GROUPS_SEED_HIDEOUTS || Groups_HideoutHolder(hideout) != GROUP_INVALID)
			{
				return;
			}
		}
	}

	new trade = -1;

	if (kind == GROUP_KIND_GUILD)
	{
		trade = Groups_PickTrade(playerid);

		if (trade == -1)
		{
			return;
		}
	}

	new fee = g_GroupFoundFees[kind], money[24];

	if (fee > 0 && Economy_Worth(playerid) < fee)
	{
		Economy_Format(fee,money);
		Gui_Notify(playerid,sprintf("The fee is %s.",money));
		return;
	}

	new founders[GROUPS_GUILD_FOUNDERS], count = 0;

	if (g_GroupFoundersNeeded[kind] > 1)
	{
		new nearby[8], near = Groups_Nearby(playerid,nearby), tradeName[32], text[160], name[MAX_PLAYER_NAME];
		Trade_GetName(trade,tradeName);
		Character_GetName(playerid,name);

		for (new i = 0;i < near && count < g_GroupFoundersNeeded[kind] - 1;i++)
		{
			new other = nearby[i];

			if (Work_GetLevel(other,trade) < GROUPS_GUILD_LEVEL || !Groups_MayJoinKind(other,GROUP_KIND_GUILD,reason))
			{
				continue;
			}

			format(text,sizeof(text),"%s asks you to found a guild of the %s trade with them and swear to it as a master.",name,tradeName);

			if (Groups_AskConsent(other,"A guild charter",text))
			{
				founders[count++] = other;
			}
		}

		if (count < g_GroupFoundersNeeded[kind] - 1)
		{
			Gui_Notify(playerid,sprintf("A charter needs %d of the trade at level %d or more, standing here and willing.",GROUPS_GUILD_FOUNDERS,GROUPS_GUILD_LEVEL));
			return;
		}
	}

	new name[GROUPS_NAME_LEN];

	if (!Groups_AskText(playerid,"A name","What is it called? Letters, spaces, apostrophes and hyphens.",name,sizeof(name)))
	{
		return;
	}

	if (!Groups_IsGoodName(name) || Groups_FindByName(name) != GROUP_INVALID)
	{
		Gui_Notify(playerid,"That name won't do: four to twenty-four letters, and not one already taken.");
		return;
	}

	if (fee > 0 && Economy_Pay(playerid,fee,Realm_GetTreasury(),"group charter") != PAY_OK)
	{
		Gui_Notify(playerid,"You can't pay the fee.");
		return;
	}

	new group = await Groups_Create(kind,name,Character_GetId(playerid),trade);

	if (group == GROUP_INVALID || !IsPlayerConnected(playerid))
	{
		return;
	}

	await Groups_AddMember(group,Character_GetId(playerid),0);

	for (new i = 0;i < count;i++)
	{
		if (IsPlayerConnected(founders[i]))
		{
			await Groups_AddMember(group,Character_GetId(founders[i]),1);
		}
	}

	if (kind == GROUP_KIND_OUTLAW)
	{
		Groups_ClaimHideout(group,hideout);
		Gui_Notify(playerid,"You make camp. The fire pit is your band's now: its stores are kept here.");
		return;
	}

	new text[144], now = gettime();

	switch (kind)
	{
		case GROUP_KIND_GUILD:
		{
			new tradeName[32];
			Trade_GetName(trade,tradeName);
			format(text,sizeof(text),"The count's steward grants a charter to %s, a guild of the %s trade.",name,tradeName);
			Notices_Post(NOTICE_TAB_REALM,Character_GetId(playerid),"A guild is chartered",text,now,now + GROUPS_CRIER_DAYS * 86400);
		}
		case GROUP_KIND_MERCENARY:
		{
			format(text,sizeof(text),"%s are registered with the steward as a band of sworn swords for hire.",name);
			Notices_Post(NOTICE_TAB_REALM,Character_GetId(playerid),"A band for hire",text,now,now + GROUPS_CRIER_DAYS * 86400);
		}
		case GROUP_KIND_ORDER:
		{
			format(text,sizeof(text),"The church gives its blessing to a new order: %s.",name);
			Notices_Post(NOTICE_TAB_CHURCH,Character_GetId(playerid),"A new order",text,now,now + GROUPS_CRIER_DAYS * 86400);
		}
	}

	Gui_Notify(playerid,sprintf("%s is founded. Its roll, its ranks and its stores are in your character panel under Groups.",name));
}

forward Groups_MenuDesk(playerid,index,data);

public Groups_MenuDesk(playerid,index,data)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, rows = 0, picks[5], labels[5][48], money[24];
	Economy_Format(GROUPS_CHARTER_FEE,money);
	format(labels[rows],48,"Ask for a guild charter (%s)",money);
	picks[rows++] = 1;
	Economy_Format(GROUPS_BAND_FEE,money);
	format(labels[rows],48,"Register a band for hire (%s)",money);
	picks[rows++] = 2;

	if (Realm_IsRuler(playerid) || Realm_IsDuke(playerid))
	{
		labels[rows] = "Found your household";
		picks[rows++] = 3;
	}

	if (Realm_IsRuler(playerid))
	{
		labels[rows] = "Revoke a guild's charter";
		picks[rows++] = 4;
	}

	if (Groups_StewardWouldJudge(playerid))
	{
		labels[rows] = "Have the steward judge a masterpiece";
		picks[rows++] = 5;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"The steward's desk");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"The steward's desk",x,y,width);

	for (new i = 0;i < rows;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i],picks[i] == 4 ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return 1;
	}

	switch (pick)
	{
		case 1: Groups_StartFounding(playerid,GROUP_KIND_GUILD,-1);
		case 2: Groups_StartFounding(playerid,GROUP_KIND_MERCENARY,-1);
		case 3: Groups_StartFounding(playerid,GROUP_KIND_HOUSEHOLD,-1);
		case 4: Groups_MenuRevoke(playerid,index,0);
		case 5: Groups_StewardJudges(playerid);
	}

	return 1;
}

forward Groups_MenuRevoke(playerid,index,data);

public Groups_MenuRevoke(playerid,index,data)
{
	new guilds[GROUPS_MAX], count = 0;

	for (new group = 0;group < GROUPS_MAX && count < 12;group++)
	{
		if (Groups_GetKind(group) == GROUP_KIND_GUILD && Groups_IsChartered(group))
		{
			guilds[count++] = group;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"No guild holds a charter.");
		return 1;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Revoke a charter");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Revoke a charter",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[GROUPS_NAME_LEN];
		Groups_GetName(guilds[i],name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || !Realm_IsRuler(playerid))
	{
		return 1;
	}

	new name[GROUPS_NAME_LEN], text[144], now = gettime();
	Groups_GetName(guilds[pick],name);
	Groups_SetChartered(guilds[pick],false);
	format(text,sizeof(text),"By the count's word %s no longer holds a charter. Its mark is not to be honoured.",name);
	Notices_Post(NOTICE_TAB_REALM,Character_GetId(playerid),"A charter revoked",text,now,now + GROUPS_CRIER_DAYS * 86400);
	Gui_Notify(playerid,"The charter is revoked and posted.");
	return 1;
}

#include <pp-hooks>

hook Actors_OnMenuBuild(playerid,index)
{
	if (index != -1 && index == Realm_GetSteward())
	{
		Actors_MenuAdd(playerid,"Charters, bands and masterpieces","Groups_MenuDesk");
	}
}
