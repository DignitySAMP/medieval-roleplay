#define GROUPS_PICK_ROLL (1)
#define GROUPS_PICK_INVITE (2)
#define GROUPS_PICK_RANKS (3)
#define GROUPS_PICK_PAY (4)
#define GROUPS_PICK_WORD (5)
#define GROUPS_PICK_LIVERY (6)
#define GROUPS_PICK_DUTY (7)
#define GROUPS_PICK_HALL (8)
#define GROUPS_PICK_KITS (9)
#define GROUPS_PICK_RULES (10)
#define GROUPS_PICK_PIECES (11)
#define GROUPS_PICK_CONTRACTS (12)
#define GROUPS_PICK_COLOUR (13)
#define GROUPS_PICK_LEAVE (14)
#define GROUPS_PICK_DISBAND (15)
#define GROUPS_PICK_STORES (16)
#define GROUPS_PICK_CHAT (17)
#define GROUPS_PICK_ROWS (17)

stock Groups_Word(playerid,group,const text[])
{
	new account[MAX_PLAYER_NAME], name[GROUPS_NAME_LEN], line[160];
	Account_GetName(playerid,account);
	Groups_GetName(group,name);
	format(line,sizeof(line),"(( %s | %s (%d): %s ))",name,account,playerid,text);

	foreach (new other : Player)
	{
		if (Session_IsPlaying(other) && Groups_IsMember(other,group))
		{
			SendClientMessage(other,GROUPS_CHAT_COLOUR,line);
		}
	}
}

stock Groups_OpenMine(playerid)
{
	new list[GROUPS_PER_CHARACTER + 2], count = Groups_GetMine(playerid,list);

	if (count == 0)
	{
		Gui_Notify(playerid,"You belong to no group.");
		return;
	}

	if (count == 1)
	{
		Groups_OpenGroup(playerid,list[0]);
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your groups");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Your groups",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[GROUPS_NAME_LEN], rank[GROUPS_RANK_NAME_LEN];
		Groups_GetName(list[i],name);
		Groups_GetRankName(list[i],Groups_GetRank(playerid,list[i]),rank);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT,rank,KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick >= 0 && pick < count)
	{
		Groups_OpenGroup(playerid,list[pick]);
	}
}

static Groups_AddRow(picks[],labels[][],&rows,pick,const label[])
{
	if (rows < GROUPS_PICK_ROWS)
	{
		picks[rows] = pick;
		strcopy(labels[rows],label,40);
		rows++;
	}
}

stock Groups_OpenGroup(playerid,group)
{
	for (;;)
	{
		if (!Groups_IsMember(playerid,group))
		{
			return;
		}

		new picks[GROUPS_PICK_ROWS], labels[GROUPS_PICK_ROWS][40], rows = 0, kind = Groups_GetKind(group), bool:system = Groups_IsSystem(group), bool:head = Groups_IsHead(playerid,group), bool:atSeat = Groups_IsAtSeat(playerid,group);
		Groups_AddRow(picks,labels,rows,GROUPS_PICK_ROLL,system ? ("Who's on duty") : ("The roll"));

		if (!system && Groups_HasPerm(playerid,group,GROUP_PERM_INVITE))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_INVITE,"Swear in someone beside you");
		}

		if (!system && Groups_HasPerm(playerid,group,GROUP_PERM_RANKS))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_RANKS,"Ranks and what they may do");
		}

		if (atSeat && (Groups_HasPerm(playerid,group,GROUP_PERM_STORE) || Groups_HasPerm(playerid,group,GROUP_PERM_TREASURY)))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_STORES,"The stores and the treasury");
		}

		if (atSeat && Groups_HasPerm(playerid,group,GROUP_PERM_TREASURY))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_PAY,"Pay a member from the treasury");
		}

		Groups_AddRow(picks,labels,rows,GROUPS_PICK_WORD,"Send word to the members (OOC)");

		new mine[GROUPS_PER_CHARACTER + 2];

		if (Groups_GetMine(playerid,mine) > 1 && Groups_GetChatGroup(playerid) != group)
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_CHAT,"Make /g speak to this group");
		}

		if (Groups_HasFeature(group,GROUP_FEATURE_DUTY))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_DUTY,Groups_IsOnDuty(playerid,group) ? ("Go off duty") : ("Go on duty"));
		}
		else if (Groups_HasFeature(group,GROUP_FEATURE_UNIFORM))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_LIVERY,Groups_GetWearing(playerid) == group ? ("Take off the livery") : ("Wear the livery"));
		}

		if (kind != GROUP_KIND_OUTLAW && Groups_HasFeature(group,GROUP_FEATURE_HALL) && Groups_HasPerm(playerid,group,GROUP_PERM_HALL))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_HALL,Groups_HasHall(group) ? ("Move the hall to here") : ("Make this place the hall"));
		}

		if (Groups_HasFeature(group,GROUP_FEATURE_ARMOURY) && Groups_HasPerm(playerid,group,GROUP_PERM_HALL))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_KITS,"Kit for each rank");
		}

		if (kind == GROUP_KIND_GUILD && Groups_HasFeature(group,GROUP_FEATURE_CHARTER))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_RULES,"The guild's rules");
		}

		if (kind == GROUP_KIND_GUILD && Groups_IsChartered(group))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_PIECES,"Masterpieces");
		}

		if (Groups_HasFeature(group,GROUP_FEATURE_CONTRACTS) && Groups_HasPerm(playerid,group,GROUP_PERM_CONTRACTS))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_CONTRACTS,"Contracts");
		}

		if (head && Groups_HasFeature(group,GROUP_FEATURE_UNIFORM))
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_COLOUR,"The livery's colours");
		}

		if (!system && !head)
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_LEAVE,"Leave");
		}

		if (!system && head && Groups_GetMemberCount(group) <= 1)
		{
			Groups_AddRow(picks,labels,rows,GROUPS_PICK_DISBAND,"Disband");
		}

		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[GROUPS_NAME_LEN], rank[GROUPS_RANK_NAME_LEN], line[96];
		Groups_GetName(group,title);
		Groups_GetRankName(group,Groups_GetRank(playerid,group),rank);

		if (system)
		{
			format(line,sizeof(line),"%s. You're a %s. %d on duty.",g_GroupKindNames[kind],rank,Groups_CountOnDuty(group));
		}
		else
		{
			format(line,sizeof(line),"%s. You're a %s. %d of %d sworn%s.",g_GroupKindNames[kind],rank,Groups_GetMemberCount(group),Groups_GetCap(group),Groups_IsReviewed(group) ? ("") : (", awaiting review"));
		}

		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 20.0,float(rows + 1) * KIT_ROW * 0.86 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new i = 0;i < rows;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * 0.86 * float(i + 1),width,labels[i],picks[i],picks[i] == GROUPS_PICK_LEAVE || picks[i] == GROUPS_PICK_DISBAND ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows + 1) * KIT_ROW * 0.86 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Groups_IsMember(playerid,group))
		{
			return;
		}

		switch (pick)
		{
			case GROUPS_PICK_ROLL: Groups_OpenRoll(playerid,group);
			case GROUPS_PICK_INVITE: Groups_Invite(playerid,group);
			case GROUPS_PICK_RANKS: Groups_OpenRanks(playerid,group);
			case GROUPS_PICK_STORES:
			{
				Groups_OpenHall(playerid,group);
				return;
			}
			case GROUPS_PICK_PAY: Groups_OpenPay(playerid,group);
			case GROUPS_PICK_WORD:
			{
				new text[112];

				if (Groups_AskText(playerid,"Word to the members","Out of character, to every member online.",text,sizeof(text)) && text[0] != EOS)
				{
					Groups_Word(playerid,group,text);
				}
			}
			case GROUPS_PICK_CHAT:
			{
				Groups_SetChatGroup(playerid,group);
				Gui_Notify(playerid,"/g now speaks to this group.");
			}
			case GROUPS_PICK_DUTY: Groups_SetDuty(playerid,group,!Groups_IsOnDuty(playerid,group));
			case GROUPS_PICK_LIVERY: Groups_SetWearing(playerid,group,Groups_GetWearing(playerid) != group);
			case GROUPS_PICK_HALL:
			{
				if (!Groups_CanSetHall(playerid,group))
				{
					Gui_Notify(playerid,"Another group's hall is too close.");
					continue;
				}

				new Float:px, Float:py, Float:pz, Float:pa;
				GetPlayerPos(playerid,px,py,pz);
				GetPlayerFacingAngle(playerid,pa);
				Groups_SetHall(group,px,py,pz,pa,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));
				Groups_Log(group,Character_GetId(playerid),"set the hall");
				Gui_Notify(playerid,"This is the group's hall now: its stores, board and duty are kept here.");
			}
			case GROUPS_PICK_KITS: Groups_OpenKits(playerid,group);
			case GROUPS_PICK_RULES: Groups_OpenRules(playerid,group);
			case GROUPS_PICK_PIECES: Groups_OpenMasterpieces(playerid,group);
			case GROUPS_PICK_CONTRACTS: Groups_OpenContracts(playerid,group);
			case GROUPS_PICK_COLOUR: Groups_OpenColours(playerid,group);
			case GROUPS_PICK_LEAVE:
			{
				new name[GROUPS_NAME_LEN];
				Groups_GetName(group,name);

				if (Groups_AskConsent(playerid,"Leave",sprintf("Leave %s? Your rank goes with you.",name),"Leave","Stay"))
				{
					Groups_RemoveMember(group,Character_GetId(playerid));
					Gui_Notify(playerid,sprintf("You leave %s.",name));
					return;
				}
			}
			case GROUPS_PICK_DISBAND:
			{
				if (Groups_AskConsent(playerid,"Disband","Disband the group for good? The treasury and the storehouse must be empty.","Disband","Keep it"))
				{
					if (Groups_Disband(group))
					{
						Gui_Notify(playerid,"The group is no more.");
					}
					else
					{
						Gui_Notify(playerid,"Empty the treasury and the storehouse first.");
					}

					return;
				}
			}
		}
	}
}

stock Groups_Invite(playerid,group)
{
	if (Groups_GetMemberCount(group) >= Groups_GetCap(group))
	{
		Gui_Notify(playerid,Groups_IsReviewed(group) ? ("The roll is full.") : ("Eight are sworn. The faction team reviews the group before it grows further."));
		return;
	}

	new nearby[8], count = Groups_Nearby(playerid,nearby), others[8], otherCount = 0;

	for (new i = 0;i < count;i++)
	{
		if (!Groups_IsMember(nearby[i],group))
		{
			others[otherCount++] = nearby[i];
		}
	}

	if (otherCount == 0)
	{
		Gui_Notify(playerid,"Have the one you'd swear in stand beside you.");
		return;
	}

	new targetid = Groups_PickNearby(playerid,"Swear in",others,otherCount), reason[48], kind = Groups_GetKind(group);

	if (targetid == INVALID_PLAYER_ID)
	{
		return;
	}

	if (!Groups_MayJoinKind(targetid,kind,reason))
	{
		Gui_Notify(playerid,sprintf("They can't swear to you: they're %s.",reason));
		return;
	}

	new lowest = Groups_CountRanks(group) - 1, name[GROUPS_NAME_LEN], rank[GROUPS_RANK_NAME_LEN], who[MAX_PLAYER_NAME], text[160];
	Groups_GetName(group,name);
	Groups_GetRankName(group,lowest,rank);
	Character_GetName(playerid,who);
	format(text,sizeof(text),"%s asks you to swear to %s as a %s.",who,name,rank);

	if (!Groups_AskConsent(targetid,name,text,"Swear","Refuse"))
	{
		Gui_Notify(playerid,"They don't swear.");
		return;
	}

	new added = await Groups_AddMember(group,Character_GetId(targetid),lowest);

	if (added)
	{
		Gui_Notify(targetid,sprintf("You're sworn to %s as a %s. See Groups in your character panel.",name,rank));
		Gui_Notify(playerid,"They're sworn in.");
	}
}

stock Groups_OpenRoll(playerid,group)
{
	if (Groups_IsSystem(group))
	{
		new lines[16][64], count = 0;

		foreach (new other : Player)
		{
			if (count < sizeof(lines) && Session_IsPlaying(other) && Groups_IsMember(other,group))
			{
				new name[MAX_PLAYER_NAME], rank[GROUPS_RANK_NAME_LEN];
				Character_GetName(other,name);
				Groups_GetRankName(group,Groups_GetRank(other,group),rank);
				format(lines[count++],64,"%s, %s%s",name,rank,Groups_IsOnDuty(other,group) || (Groups_GetKind(group) == GROUP_KIND_GUARD && Law_IsGuard(other)) ? (", on duty") : (""));
			}
		}

		Groups_ShowLines(playerid,"Who's about",lines,count);
		return;
	}

	for (;;)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT m.character_id, m.`rank`, CONCAT(c.name, ' ', c.surname) AS who FROM group_members m LEFT JOIN characters c ON c.id = m.character_id WHERE m.group_id = %d ORDER BY m.`rank`, m.joined_at LIMIT %d",Groups_GetId(group),GROUPS_CAP));

		if (!IsPlayerConnected(playerid))
		{
			return;
		}

		new rows = min(cache_num_rows(),GROUPS_CAP), ids[GROUPS_CAP], ranks[GROUPS_CAP], names[GROUPS_CAP][44];

		for (new r = 0;r < rows;r++)
		{
			cache_get_value_name_int(r,"character_id",ids[r]);
			cache_get_value_name_int(r,"rank",ranks[r]);
			cache_get_value_name(r,"who",names[r]);
		}

		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, myRank = Groups_GetRank(playerid,group), bool:manage = Groups_HasPerm(playerid,group,GROUP_PERM_RANKS) || Groups_HasPerm(playerid,group,GROUP_PERM_EXPEL), Float:row = KIT_ROW * 0.78;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"The roll");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 40.0,float(max(rows,1)) * row + 6.0 + KIT_ROW + 12.0,"The roll",x,y,width);

		for (new r = 0;r < rows;r++)
		{
			new rank[GROUPS_RANK_NAME_LEN], online = Groups_PlayerByCharacter(ids[r]), detail[48];
			Groups_GetRankName(group,ranks[r],rank);
			format(detail,sizeof(detail),"%s%s",rank,online == INVALID_PLAYER_ID ? ("") : (Groups_IsOnDuty(online,group) ? (", on duty") : (", about")));
			Kit_AddChoice(playerid,x,y + row * float(r),width,names[r],r,manage && ranks[r] > myRank ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,detail,online == INVALID_PLAYER_ID ? KIT_COLOUR_MUTED : KIT_COLOUR_GOOD);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(max(rows,1)) * row + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= rows)
		{
			return;
		}

		if (manage && ranks[pick] > myRank)
		{
			Groups_OpenMember(playerid,group,ids[pick],ranks[pick],names[pick]);
		}
	}
}

stock Groups_OpenMember(playerid,group,characterid,rank,const name[])
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, myRank = Groups_GetRank(playerid,group), count = Groups_CountRanks(group), rows = 0;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,name,x,y,width);

	if (Groups_HasPerm(playerid,group,GROUP_PERM_RANKS) && rank - 1 > myRank)
	{
		new above[GROUPS_RANK_NAME_LEN];
		Groups_GetRankName(group,rank - 1,above);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,sprintf("Raise to %s",above),1,KIT_COLOUR_GOOD);
	}

	if (Groups_HasPerm(playerid,group,GROUP_PERM_RANKS) && rank + 1 < count)
	{
		new below[GROUPS_RANK_NAME_LEN];
		Groups_GetRankName(group,rank + 1,below);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,sprintf("Lower to %s",below),2,KIT_COLOUR_TEXT);
	}

	if (Groups_IsHead(playerid,group))
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,"Hand them the headship",3,KIT_COLOUR_ACCENT);
	}

	if (Groups_HasPerm(playerid,group,GROUP_PERM_EXPEL))
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,"Strike them from the roll",4,KIT_COLOUR_BAD);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 4.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || Groups_GetRank(playerid,group) != myRank)
	{
		return;
	}

	switch (pick)
	{
		case 1: Groups_SetMemberRank(group,characterid,rank - 1);
		case 2: Groups_SetMemberRank(group,characterid,rank + 1);
		case 3:
		{
			if (Groups_AskConsent(playerid,"The headship",sprintf("Hand the headship to %s? You become their second.",name),"Hand it over","Keep it"))
			{
				Groups_SetMemberRank(group,characterid,0);
				Groups_SetMemberRank(group,Character_GetId(playerid),1);
				Groups_Tell(group,sprintf("%s is the group's head now.",name));
			}
		}
		case 4:
		{
			Groups_RemoveMember(group,characterid);
			Gui_Notify(playerid,sprintf("%s is struck from the roll.",name));
		}
	}
}

stock Groups_OpenRanks(playerid,group)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, count = Groups_CountRanks(group), lines = count + (count < GROUPS_RANKS ? 1 : 0);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Ranks");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(lines) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Ranks",x,y,width);

		for (new rank = 0;rank < count;rank++)
		{
			new name[GROUPS_RANK_NAME_LEN], perms = 0, mask = Groups_GetRankPerms(group,rank);
			Groups_GetRankName(group,rank,name);

			for (new bit = 0;bit < GROUP_PERM_COUNT;bit++)
			{
				if (mask & (1 << bit))
				{
					perms++;
				}
			}

			Kit_AddChoice(playerid,x,y + KIT_ROW * float(rank),width,name[0] != EOS ? name : ("(unnamed)"),rank,KIT_COLOUR_TEXT,rank == 0 ? ("the head") : sprintf("%d rights",perms),KIT_COLOUR_MUTED);
		}

		if (count < GROUPS_RANKS)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(count),width,"Add a rank below",100,KIT_COLOUR_GOOD);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(lines) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Groups_HasPerm(playerid,group,GROUP_PERM_RANKS))
		{
			return;
		}

		if (pick == 100)
		{
			new name[GROUPS_RANK_NAME_LEN];

			if (Groups_AskText(playerid,"A new rank","What is the rank called?",name,sizeof(name)) && strlen(name) >= 3 && Groups_IsGoodName(sprintf("%s rank",name)))
			{
				Groups_SetRankName(group,count,name);
				Groups_SetRankPerms(group,count,0);
			}

			continue;
		}

		if (pick >= 0 && pick < count)
		{
			Groups_EditRank(playerid,group,pick);
		}
	}
}

stock Groups_EditRank(playerid,group,rank)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[GROUPS_RANK_NAME_LEN], mask = Groups_GetRankPerms(group,rank), bool:editable = rank > Groups_GetRank(playerid,group), lines = 1 + (rank > 0 ? GROUP_PERM_COUNT : 0);
		Groups_GetRankName(group,rank,title);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(lines) * KIT_ROW * 0.82 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddChoice(playerid,x,y,width,"Rename",100,KIT_COLOUR_TEXT);

		for (new bit = 0;rank > 0 && bit < GROUP_PERM_COUNT;bit++)
		{
			new bool:has = (mask & (1 << bit)) != 0;
			Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(bit + 1),width,g_GroupPermNames[bit],bit,editable ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,has ? ("yes") : ("no"),has ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(lines) * KIT_ROW * 0.82 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Groups_HasPerm(playerid,group,GROUP_PERM_RANKS))
		{
			return;
		}

		if (pick == 100)
		{
			new name[GROUPS_RANK_NAME_LEN];

			if (Groups_AskText(playerid,"Rename the rank","What is the rank called?",name,sizeof(name)) && strlen(name) >= 3 && Groups_IsGoodName(sprintf("%s rank",name)))
			{
				Groups_SetRankName(group,rank,name);
			}

			continue;
		}

		if (editable && pick >= 0 && pick < GROUP_PERM_COUNT)
		{
			Groups_SetRankPerms(group,rank,mask ^ (1 << pick));
		}
	}
}

stock Groups_OpenPay(playerid,group)
{
	new nearby[8], count = Groups_Nearby(playerid,nearby), members[8], memberCount = 0;

	for (new i = 0;i < count;i++)
	{
		if (Groups_IsMember(nearby[i],group))
		{
			members[memberCount++] = nearby[i];
		}
	}

	if (memberCount == 0)
	{
		Gui_Notify(playerid,"Pay is handed over in person: have the member stand beside you.");
		return;
	}

	new targetid = Groups_PickNearby(playerid,"Pay whom?",members,memberCount), amountText[12], money[24];

	if (targetid == INVALID_PLAYER_ID)
	{
		return;
	}

	Economy_Format(Groups_TreasuryWorth(group),money);

	if (!Groups_AskText(playerid,"Pay",sprintf("How many pfennig? The treasury holds %s.",money),amountText,sizeof(amountText)))
	{
		return;
	}

	new amount = strval(amountText);

	if (amount <= 0 || !Groups_PayOut(group,targetid,amount,"group pay"))
	{
		Gui_Notify(playerid,"The treasury can't make that sum.");
		return;
	}

	new who[MAX_PLAYER_NAME];
	Economy_Format(amount,money);
	Character_GetName(playerid,who);
	Gui_Notify(targetid,sprintf("%s pays you %s from the treasury.",who,money));
	Gui_Notify(playerid,sprintf("You pay out %s.",money));
	Groups_Log(group,Character_GetId(targetid),sprintf("paid %d pf",amount));
}

stock Groups_OpenColours(playerid,group)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"The livery");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(GROUPS_LIVERY_COUNT) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"The livery",x,y,width);

	for (new i = 0;i < GROUPS_LIVERY_COUNT;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,g_GroupLiveryNames[i],i,(g_GroupLiveryColours[i] << 8) | 0xFF,Groups_GetLivery(group) == i ? ("worn now") : (""),KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(GROUPS_LIVERY_COUNT) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick >= 0 && pick < GROUPS_LIVERY_COUNT && Groups_IsHead(playerid,group))
	{
		Groups_SetLivery(group,pick);
		Gui_Notify(playerid,sprintf("The livery is %s now.",g_GroupLiveryNames[pick]));
	}
}

stock Groups_OpenKits(playerid,group)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, count = Groups_CountRanks(group);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Kit for each rank");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 60.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Kit for each rank",x,y,width);

		for (new rank = 0;rank < count;rank++)
		{
			new name[GROUPS_RANK_NAME_LEN], kit[64];

			for (new line = 0;line < GROUPS_KIT_LINES;line++)
			{
				new E_ITEM_KIND:kind, param, amount, item[ITEM_NAME_LEN];
				Groups_GetKitLine(group,rank,line,kind,param,amount);

				if (amount > 0)
				{
					Item_GetName(kind,param,item);
					format(kit,sizeof(kit),"%s%s%d %s",kit,kit[0] != EOS ? (", ") : (""),amount,item);
				}
			}

			Groups_GetRankName(group,rank,name);
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(rank),width,name,rank,KIT_COLOUR_TEXT,kit[0] != EOS ? kit : ("nothing"),KIT_COLOUR_MUTED,0.6);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || !Groups_HasPerm(playerid,group,GROUP_PERM_HALL))
		{
			return;
		}

		Groups_EditKit(playerid,group,pick);
	}
}

stock Groups_EditKit(playerid,group,rank)
{
	new store = Groups_GetStore(group), slots = Container_GetSlots(store), choices[16][3], count = 0;

	for (new slot = 0;slot < slots && count < sizeof(choices);slot++)
	{
		new E_ITEM_KIND:kind, param, amount, stars;

		if (!Container_GetSlot(store,slot,kind,param,amount,stars) || amount <= 0 || kind == ITEM_KIND_COIN)
		{
			continue;
		}

		new bool:dup = false;

		for (new i = 0;i < count;i++)
		{
			if (choices[i][0] == _:kind && choices[i][1] == param)
			{
				dup = true;
			}
		}

		if (!dup)
		{
			choices[count][0] = _:kind;
			choices[count][1] = param;
			choices[count][2] = 1;
			count++;
		}
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[GROUPS_RANK_NAME_LEN], lines = count + 1;
	Groups_GetRankName(group,rank,title);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(lines) * KIT_ROW * 0.82 + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new item[ITEM_NAME_LEN], bool:inKit = false;
		Item_GetName(E_ITEM_KIND:choices[i][0],choices[i][1],item);

		for (new line = 0;line < GROUPS_KIT_LINES;line++)
		{
			new E_ITEM_KIND:kind, param, amount;
			Groups_GetKitLine(group,rank,line,kind,param,amount);

			if (amount > 0 && kind == E_ITEM_KIND:choices[i][0] && param == choices[i][1])
			{
				inKit = true;
			}
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(i),width,item,i,KIT_COLOUR_TEXT,inKit ? ("issued") : (""),KIT_COLOUR_GOOD);
	}

	Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(count),width,"Issue nothing",100,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(lines) * KIT_ROW * 0.82 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return;
	}

	if (pick == 100)
	{
		for (new line = 0;line < GROUPS_KIT_LINES;line++)
		{
			Groups_SetKitLine(group,rank,line,ITEM_KIND_MISC,0,0);
		}

		return;
	}

	if (pick < 0 || pick >= count)
	{
		return;
	}

	new free = -1;

	for (new line = 0;line < GROUPS_KIT_LINES;line++)
	{
		new E_ITEM_KIND:kind, param, amount;
		Groups_GetKitLine(group,rank,line,kind,param,amount);

		if (amount > 0 && kind == E_ITEM_KIND:choices[pick][0] && param == choices[pick][1])
		{
			Groups_SetKitLine(group,rank,line,kind,param,0);
			return;
		}

		if (amount <= 0 && free == -1)
		{
			free = line;
		}
	}

	if (free == -1)
	{
		Gui_Notify(playerid,sprintf("A kit holds %d things at most.",GROUPS_KIT_LINES));
		return;
	}

	Groups_SetKitLine(group,rank,free,E_ITEM_KIND:choices[pick][0],choices[pick][1],1);
}

stock Groups_OpenSettings(playerid,group)
{
	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, title[GROUPS_NAME_LEN], lines = GROUP_FEATURE_COUNT + 2;
		Groups_GetName(group,title);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(lines) * KIT_ROW * 0.82 + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		for (new bit = 0;bit < GROUP_FEATURE_COUNT;bit++)
		{
			new bool:has = Groups_HasFeature(group,1 << bit);
			Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(bit),width,g_GroupFeatureNames[bit],bit,KIT_COLOUR_TEXT,has ? ("granted") : ("no"),has ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(GROUP_FEATURE_COUNT),width,"Reviewed by the faction team",100,KIT_COLOUR_TEXT,Groups_IsReviewed(group) ? ("yes") : ("no"),Groups_IsReviewed(group) ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.82 * float(GROUP_FEATURE_COUNT + 1),width,"Chartered",101,KIT_COLOUR_TEXT,Groups_IsChartered(group) ? ("yes") : ("no"),Groups_IsChartered(group) ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(lines) * KIT_ROW * 0.82 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Groups_IsValid(group))
		{
			return;
		}

		if (pick >= 0 && pick < GROUP_FEATURE_COUNT)
		{
			Groups_SetFeature(group,1 << pick,!Groups_HasFeature(group,1 << pick));
		}
		else if (pick == 100)
		{
			Groups_SetReviewed(group,!Groups_IsReviewed(group));
		}
		else if (pick == 101)
		{
			Groups_SetChartered(group,!Groups_IsChartered(group));
		}
	}
}

stock Groups_ShowLines(playerid,const title[],const lines[][],count)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, shown = max(count,1);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(shown) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	if (count == 0)
	{
		Kit_AddText(playerid,x,y,"Nobody is about.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * float(i),lines[i],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(shown) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

forward Groups_OpenMineDeferred(playerid);

public Groups_OpenMineDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Groups_OpenMine(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook CharPanel_OnGroups(playerid)
{
	SetTimerEx("Groups_OpenMineDeferred",0,false,"d",playerid);
}
