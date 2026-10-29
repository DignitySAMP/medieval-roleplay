stock Staff_Inspect(staffid,targetid)
{
	if (!IsPlayerConnected(targetid))
	{
		return;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM warnings WHERE account_id = %d",Account_GetId(targetid)));
	new warnings = 0;
	cache_get_value_name_int(0,"n",warnings);

	if (!IsPlayerConnected(staffid) || !IsPlayerConnected(targetid))
	{
		return;
	}

	new lines[18][112], count = 0, name[64], money[24];
	Staff_TargetName(targetid,name);
	format(lines[count++],112,"%s, %s, age %d",name,g_StaffLevelNames[Util_ClampInt(Account_GetAdminLevel(targetid),0,ADMIN_LEVEL_MANAGER)],Character_GetAge(targetid));
	format(lines[count++],112,"Health %.0f, hunger %d, thirst %d, warmth %d, fatigue %.0f, dirt %d",Vitals_GetHealth(targetid),Needs_Get(targetid,NEED_HUNGER),Needs_Get(targetid,NEED_THIRST),Warmth_Get(targetid),Fatigue_Get(targetid),Hygiene_GetDirt(targetid));

	new ailments[96];

	for (new i = 0, total = Ailment_GetCount(targetid);i < total;i++)
	{
		new ailmentName[24];
		Ailment_GetName(Ailment_GetAt(targetid,i),ailmentName);
		format(ailments,sizeof(ailments),"%s%s%s",ailments,i > 0 ? (", ") : (""),ailmentName);
	}

	format(lines[count++],112,"Ailments: %s",ailments[0] != EOS ? ailments : ("none"));
	Economy_Format(Economy_Worth(targetid),money);
	format(lines[count++],112,"Purse %s, %d things in the bag",money,Inventory_GetCount(targetid));

	new bag[112];

	for (new index = 0, shown = 0, total = Inventory_GetCount(targetid);index < total && shown < 6;index++)
	{
		new E_ITEM_KIND:kind, param, amount, itemName[ITEM_NAME_LEN];

		if (Inventory_GetSlot(targetid,index,kind,param,amount) && amount > 0)
		{
			Item_GetName(kind,param,itemName);
			format(bag,sizeof(bag),"%s%s%d %s",bag,shown > 0 ? (", ") : (""),amount,itemName);
			shown++;
		}
	}

	format(lines[count++],112,"  %s",bag[0] != EOS ? bag : ("an empty bag"));

	new best[3] = {-1, -1, -1};

	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		for (new slot = 0;slot < 3;slot++)
		{
			if (best[slot] == -1 || Work_GetLevel(targetid,trade) > Work_GetLevel(targetid,best[slot]))
			{
				for (new move = 2;move > slot;move--)
				{
					best[move] = best[move - 1];
				}

				best[slot] = trade;
				break;
			}
		}
	}

	new skills[112];

	for (new slot = 0;slot < 3;slot++)
	{
		if (best[slot] != -1)
		{
			new tradeName[32];
			Trade_GetName(best[slot],tradeName);
			format(skills,sizeof(skills),"%s%s%s %d",skills,slot > 0 ? (", ") : (""),tradeName,Work_GetLevel(targetid,best[slot]));
		}
	}

	format(lines[count++],112,"Best trades: %s",skills);

	new title[CLERGY_TITLE_LEN], room = Houses_FindRoomOf(Character_GetId(targetid)), roomName[48];
	Clergy_GetTitle(targetid,title);

	if (room != -1)
	{
		Houses_FormatRoomName(room,roomName);
	}

	format(lines[count++],112,"Church: %s. Lodging: %s",title[0] != EOS ? title : ("lay"),room != -1 ? roomName : ("none"));
	format(lines[count++],112,"Law: %s%s",Law_IsWanted(targetid) ? ("wanted") : ("not wanted"),Law_GetRank(targetid) > LAW_RANK_NONE ? (", sworn to the guard") : (""));

	new groups[GROUPS_PER_CHARACTER + 2], groupCount = Groups_GetMine(targetid,groups), groupLine[96];

	for (new i = 0;i < groupCount;i++)
	{
		new groupName[GROUPS_NAME_LEN];
		Groups_GetName(groups[i],groupName);
		format(groupLine,sizeof(groupLine),"%s%s%s",groupLine,i > 0 ? (", ") : (""),groupName);
	}

	format(lines[count++],112,"Groups: %s",groupCount > 0 ? groupLine : ("none"));
	format(lines[count++],112,"Record: %d warnings%s%s",warnings,Staff_IsJailed(targetid) ? sprintf(", in OOC jail %d more minutes",Staff_GetJailLeft(targetid) / 60 + 1) : (""),Staff_IsFrozen(targetid) ? (", frozen") : (""));

	new Float:x, Float:y, Float:z;
	GetPlayerPos(targetid,x,y,z);
	format(lines[count++],112,"At %.1f, %.1f, %.1f, world %d, interior %d",x,y,z,GetPlayerVirtualWorld(targetid),GetPlayerInterior(targetid));

	new epoch = Gui_BeginFlow(staffid), Float:px, Float:py, Float:width;
	Kit_Begin(staffid,KIT_LAYER_SCREEN,"Inspect");
	Kit_OpenPanel(staffid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH + 120.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Inspect",px,py,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(staffid,px,py + KIT_ROW * float(i),lines[i],i == 0 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(staffid,px + width / 2.0 - 40.0,py + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(staffid);

	if (Gui_IsFlowCurrent(staffid,epoch))
	{
		Kit_Close(staffid);
	}

	Staff_Log(staffid,"inspect",name);
}
