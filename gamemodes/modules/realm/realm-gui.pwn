static const s_RealmDecreeDays[3] = {1, 3, 7};

stock bool:Realm_AskText(playerid,const title[],const prompt[],dest[],size)
{
	new token = Account_GetToken(playerid), response[DIALOG_RESPONSE], body[256];
	format(body,sizeof(body),GUI_TEXT "%s",prompt);
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,title,body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
	{
		return false;
	}

	strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);
	return true;
}

forward Task:Realm_LoadCarried(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Realm_LoadCarried(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT coin FROM dues_carried WHERE character_id = %d",characterid));
	new coin = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"coin",coin);
	}

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid)
	{
		Realm_SetCarried(playerid,coin);
	}

	return async coin;
}
#pragma warning pop

static Realm_Lines(playerid,const title[],const lines[][],count)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,REALM_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * float(i),lines[i],i == 0 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

stock Realm_OpenBooks(playerid)
{
	new lines[12][96], count = 0, money[24];
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM crimes WHERE county_id = %d AND at > %d",REALM_COUNTY,gettime() - 7 * 86400));
	new crimes = 0;
	cache_get_value_name_int(0,"n",crimes);
	await mysql_aquery_s(g_Mysql,str_new("SELECT COALESCE(SUM(coin), 0) AS n FROM dues_carried"));
	new carried = 0;
	cache_get_value_name_int(0,"n",carried);
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM law_guards WHERE county_id = %d",REALM_COUNTY));
	new guards = 0;
	cache_get_value_name_int(0,"n",guards);

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	strcopy(lines[count++],Realm_IsVacant() ? ("The county of Talmberg, held by the duke's steward") : ("The county of Talmberg"),96);
	Economy_Format(Realm_TreasuryCoin(),money);
	format(lines[count++],96,"Treasury: %s and %d sacks of grain",money,Realm_TreasuryGrain());

	for (new village = 0;village < REALM_VILLAGES;village++)
	{
		Economy_Format(Realm_GetDues(village),money);
		format(lines[count++],96,"Owed in %s: %s",g_RealmVillageNames[village],money);
	}

	Economy_Format(carried,money);
	format(lines[count++],96,"Collected and not yet delivered: %s",money);
	format(lines[count++],96,"Guards sworn: %d. Crimes this week: %d.",guards,crimes);
	format(lines[count++],96,"Decrees in force: %d.",Realm_CountDecrees());
	strcopy(lines[count++],Realm_IsVacant() ? ("Petitions go to the duke while the seat is empty.") : ("Petitions go to the count."),96);
	Realm_Lines(playerid,"The county's books",lines,count);
}

stock Realm_OpenDecrees(playerid)
{
	new lines[REALM_DECREES_MAX + 1][96], count = 0, now = gettime();
	strcopy(lines[count++],"Decrees in force",96);

	for (new i = 0;i < REALM_DECREES_MAX && count < sizeof(lines);i++)
	{
		new kind, text[REALM_DECREE_TEXT], starts, ends;

		if (Realm_GetDecree(i,kind,text,starts,ends) == 0 || now >= ends)
		{
			continue;
		}

		format(lines[count++],96,"%s: %.60s (%d days left)",g_RealmDecreeNames[kind],text,(ends - now) / 86400 + 1);
	}

	if (count == 1)
	{
		strcopy(lines[count++],"None. The duke has decreed nothing.",96);
	}

	Realm_Lines(playerid,"Decrees",lines,count);
}

stock Realm_OpenPolicy(playerid,bool:canEdit,bool:boundsMode = false)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[32] = "The county's policy";

		if (boundsMode)
		{
			title = "The duke's bounds";
		}

		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,REALM_PANEL_WIDTH + 40.0,float(REALM_POLICY_COUNT) * KIT_ROW * 0.82 + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		for (new policy = 0;policy < REALM_POLICY_COUNT;policy++)
		{
			new value[32], lo[24], hi[24];

			if (boundsMode)
			{
				Realm_PolicyText(policy,Realm_GetBound(policy,false),lo);
				Realm_PolicyText(policy,Realm_GetBound(policy,true),hi);
				format(value,sizeof(value),"%s to %s",lo,hi);
			}
			else
			{
				Realm_PolicyText(policy,Realm_GetPolicy(REALM_COUNTY,policy),value);
			}

			Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(policy),width,g_RealmPolicyDefs[policy][E_RP_NAME],policy,canEdit ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,value,KIT_COLOUR_ACCENT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(REALM_POLICY_COUNT) * KIT_ROW * 0.82 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= REALM_POLICY_COUNT || !canEdit)
		{
			return;
		}

		if (boundsMode)
		{
			Realm_EditBounds(playerid,pick);
		}
		else
		{
			Realm_EditPolicy(playerid,pick);
		}
	}
}

stock Realm_EditPolicy(playerid,policy)
{
	new value = Realm_GetPolicy(REALM_COUNTY,policy), step = g_RealmPolicyDefs[policy][E_RP_STEP];

	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, text[32], line[96], lo[24], hi[24];
		Realm_PolicyText(policy,value,text);
		Realm_PolicyText(policy,Realm_GetBound(policy,false),lo);
		Realm_PolicyText(policy,Realm_GetBound(policy,true),hi);
		format(line,sizeof(line),"The duke allows %s to %s.",lo,hi);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,g_RealmPolicyDefs[policy][E_RP_NAME]);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,REALM_PANEL_WIDTH,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,g_RealmPolicyDefs[policy][E_RP_NAME],x,y,width);
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		Kit_AddChoice(playerid,x,y + KIT_ROW,width,"Less",1,KIT_COLOUR_TEXT,text,KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width,"More",2,KIT_COLOUR_TEXT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,"Proclaim it",3,KIT_COLOUR_GOOD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 4.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Realm_IsRuler(playerid))
		{
			return;
		}

		switch (pick)
		{
			case 1: value = max(value - step,Realm_GetBound(policy,false));
			case 2: value = min(value + step,Realm_GetBound(policy,true));
			case 3:
			{
				Realm_SetPolicy(REALM_COUNTY,policy,value,Character_GetId(playerid));
				Gui_Notify(playerid,"It's proclaimed and posted on the county's boards.");
				return;
			}
		}
	}
}

stock Realm_EditBounds(playerid,policy)
{
	new lo = Realm_GetBound(policy,false), hi = Realm_GetBound(policy,true), step = g_RealmPolicyDefs[policy][E_RP_STEP], floorValue = g_RealmPolicyDefs[policy][E_RP_MIN], ceiling = g_RealmPolicyDefs[policy][E_RP_MAX] * 2;

	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, a[24], b[24];
		Realm_PolicyText(policy,lo,a);
		Realm_PolicyText(policy,hi,b);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,g_RealmPolicyDefs[policy][E_RP_NAME]);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,REALM_PANEL_WIDTH,KIT_ROW * 5.0 + 6.0 + KIT_ROW + 12.0,g_RealmPolicyDefs[policy][E_RP_NAME],x,y,width);
		Kit_AddChoice(playerid,x,y,width,"Lower the floor",1,KIT_COLOUR_TEXT,a,KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW,width,"Raise the floor",2,KIT_COLOUR_TEXT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width,"Lower the ceiling",3,KIT_COLOUR_TEXT,b,KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,"Raise the ceiling",4,KIT_COLOUR_TEXT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Bind the counties to it",5,KIT_COLOUR_GOOD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 5.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Realm_IsDuke(playerid))
		{
			return;
		}

		switch (pick)
		{
			case 1: lo = max(lo - step,floorValue);
			case 2: lo = min(lo + step,hi);
			case 3: hi = max(hi - step,lo);
			case 4: hi = min(hi + step,ceiling);
			case 5:
			{
				Realm_SetBound(policy,lo,hi,Character_GetId(playerid));
				Gui_Notify(playerid,"The bounds are set for every county.");
				return;
			}
		}
	}
}

stock Realm_OpenIssue(playerid)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Issue a decree");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,280.0,float(REALM_DECREE_KINDS) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Issue a decree",x,y,width);

	for (new kind = 0;kind < REALM_DECREE_KINDS;kind++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(kind),width,g_RealmDecreeNames[kind],kind,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(REALM_DECREE_KINDS) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new kind = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || kind < 0 || kind >= REALM_DECREE_KINDS)
	{
		return;
	}

	new text[REALM_DECREE_TEXT];

	if (!Realm_AskText(playerid,g_RealmDecreeNames[kind],"Write the decree as it will be posted and cried.",text,sizeof(text)) || strlen(text) < 8)
	{
		return;
	}

	epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"For how long?");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,220.0,KIT_ROW * 3.0 + 6.0 + KIT_ROW + 12.0,"For how long?",x,y,width);

	for (new i = 0;i < sizeof(s_RealmDecreeDays);i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,sprintf("%d days",s_RealmDecreeDays[i]),i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 3.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= sizeof(s_RealmDecreeDays) || !Realm_IsDuke(playerid))
	{
		return;
	}

	new row = await Realm_IssueDecree(kind,text,gettime(),gettime() + s_RealmDecreeDays[pick] * 86400,Character_GetId(playerid));

	if (row > 0)
	{
		Gui_Notify(playerid,"The decree is posted on every board and cried in the villages.");
	}
}

stock Realm_OpenAppoint(playerid)
{
	new nearby[8], count = 0, Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	foreach (new other : Player)
	{
		if (other != playerid && count < sizeof(nearby) && !IsPlayerNPC(other) && Session_IsPlaying(other) && IsPlayerInRangeOfPoint(other,6.0,px,py,pz))
		{
			nearby[count++] = other;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"Have the one you'd swear in stand beside you.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Swear in a guard");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Swear in a guard",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[MAX_PLAYER_NAME];
		Character_GetName(nearby[i],name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT,Law_IsGuard(nearby[i]) ? ("sworn") : (""),KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || !Realm_IsRuler(playerid) || !IsPlayerConnected(nearby[pick]))
	{
		return;
	}

	Law_Appoint(nearby[pick],Law_IsGuard(nearby[pick]) ? LAW_RANK_NONE : LAW_RANK_GUARD,playerid);
}

forward Realm_MenuBooks(playerid,index,data);

public Realm_MenuBooks(playerid,index,data)
{
	Realm_OpenBooks(playerid);
	return 1;
}

forward Realm_MenuPolicy(playerid,index,data);

public Realm_MenuPolicy(playerid,index,data)
{
	Realm_OpenPolicy(playerid,Realm_IsRuler(playerid) && data == 1);
	return 1;
}

forward Realm_MenuBounds(playerid,index,data);

public Realm_MenuBounds(playerid,index,data)
{
	Realm_OpenPolicy(playerid,Realm_IsDuke(playerid),true);
	return 1;
}

forward Realm_MenuDecrees(playerid,index,data);

public Realm_MenuDecrees(playerid,index,data)
{
	if (data == 1)
	{
		Realm_OpenIssue(playerid);
	}
	else
	{
		Realm_OpenDecrees(playerid);
	}

	return 1;
}

forward Realm_MenuLevy(playerid,index,data);

public Realm_MenuLevy(playerid,index,data)
{
	if (!Realm_IsDuke(playerid))
	{
		return 1;
	}

	new taken = Realm_Levy(Character_GetId(playerid),REALM_LEVY_COIN_PERCENT,REALM_LEVY_GRAIN_PERCENT);

	if (taken < 0)
	{
		Gui_Notify(playerid,"The levy was raised this season already.");
	}
	else
	{
		new money[24];
		Economy_Format(taken,money);
		Gui_Notify(playerid,sprintf("The steward moves %s into the duchy's treasury.",money));
	}

	return 1;
}

forward Realm_MenuAppoint(playerid,index,data);

public Realm_MenuAppoint(playerid,index,data)
{
	Realm_OpenAppoint(playerid);
	return 1;
}

forward Realm_MenuDeliver(playerid,index,data);

public Realm_MenuDeliver(playerid,index,data)
{
	Realm_Deliver(playerid);
	return 1;
}

#include <pp-hooks>

hook Actors_OnMenuBuild(playerid,index)
{
	if (index == -1 || index != Realm_GetSteward())
	{
		return;
	}

	new bool:ruler = Realm_IsRuler(playerid), bool:duke = Realm_IsDuke(playerid), bool:staff = Account_GetAdminLevel(playerid) >= ADMIN_LEVEL_TRIAL;
	Actors_MenuAdd(playerid,"Read the decrees","Realm_MenuDecrees",0);
	Actors_MenuAdd(playerid,ruler ? ("Set the county's policy") : ("Read the county's policy"),"Realm_MenuPolicy",ruler ? 1 : 0,ruler ? KIT_COLOUR_GOOD : KIT_COLOUR_TEXT);

	if (ruler || duke || staff)
	{
		Actors_MenuAdd(playerid,"The county's books","Realm_MenuBooks");
	}

	if (ruler)
	{
		Actors_MenuAdd(playerid,"Swear in or dismiss a guard","Realm_MenuAppoint");
	}

	if (duke)
	{
		Actors_MenuAdd(playerid,"The duke's bounds","Realm_MenuBounds",0,KIT_COLOUR_ACCENT);
		Actors_MenuAdd(playerid,"Issue a decree","Realm_MenuDecrees",1,KIT_COLOUR_ACCENT);
		Actors_MenuAdd(playerid,"Raise the season's levy","Realm_MenuLevy",0,KIT_COLOUR_ACCENT);
	}

	if (Realm_GetCarried(playerid) > 0)
	{
		new money[24];
		Economy_Format(Realm_GetCarried(playerid),money);
		Actors_MenuAdd(playerid,sprintf("Deliver the dues (%s)",money),"Realm_MenuDeliver",0,KIT_COLOUR_GOOD);
	}
}
