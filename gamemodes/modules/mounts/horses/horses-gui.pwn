#define HORSES_TAB_HORSE (0)
#define HORSES_TAB_KIN (1)
#define HORSES_TAB_TRAITS (2)
#define HORSES_TAB_CARE (3)
#define HORSES_TAB_BREEDING (4)
#define HORSES_TABS (5)
#define HORSES_PICK_TAB (100)
#define HORSES_GUI_LINES (9)

enum
{
	HORSES_CARE_FEED = 1,
	HORSES_CARE_WATER,
	HORSES_CARE_GROOM,
	HORSES_CARE_SHOE,
	HORSES_CARE_LEAD,
	HORSES_CARE_UNLEAD,
	HORSES_CARE_LEND,
	HORSES_CARE_UNLEND,
	HORSES_CARE_RENAME,
	HORSES_CARE_SADDLEBAGS,
	HORSES_CARE_BLANKET_ON,
	HORSES_CARE_BLANKET_OFF,
}

static const s_HorseTabNames[HORSES_TABS][12] = {"Horse", "Kin", "Traits", "Care", "Breeding"};

stock bool:Horses_AskText(playerid,const title[],const prompt[],dest[],size)
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

stock bool:Horses_IsGoodName(const name[])
{
	new length = strlen(name);

	if (length < 2 || length > 20)
	{
		return false;
	}

	for (new i = 0;i < length;i++)
	{
		new c = name[i];

		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == ' ' || c == '\'' || c == '-'))
		{
			return false;
		}
	}

	return true;
}

stock Horses_AskName(playerid,horseid)
{
	new name[HORSES_NAME_LEN];

	while (Horses_IsOwner(playerid,horseid))
	{
		if (!Horses_AskText(playerid,"Name your horse","What will you call it? Two to twenty letters.",name,sizeof(name)))
		{
			new current[HORSES_NAME_LEN];
			Horses_GetHorseName(horseid,current);

			if (current[0] == EOS || !strcmp(current,"Wild horse"))
			{
				Horses_SetName(horseid,"Nameless");
				Horses_Save(horseid);
			}

			return;
		}

		if (Horses_IsGoodName(name))
		{
			name[0] = toupper(name[0]);
			Horses_SetName(horseid,name);
			Horses_Save(horseid);
			Gui_Notify(playerid,sprintf("You call it %s.",name));
			return;
		}

		Gui_Notify(playerid,"Use two to twenty letters for its name.");
	}
}

static Horses_Pick(bool:first,const a[],const b[],dest[],size = sizeof(dest))
{
	if (first)
	{
		strcopy(dest,a,size);
	}
	else
	{
		strcopy(dest,b,size);
	}
}

static Horses_NeedWord(Float:value,const words[][],dest[],size)
{
	new index = 0;

	if (value <= 0.0)
	{
		index = 3;
	}
	else if (value < 20.0)
	{
		index = 2;
	}
	else if (value < 60.0)
	{
		index = 1;
	}

	strcopy(dest,words[index],size);
}

static const s_HungerWords[4][12] = {"full", "fed", "hungry", "starving"};
static const s_ThirstWords[4][12] = {"watered", "dry", "thirsty", "parched"};
static const s_ConditionWords[4][16] = {"in fine fettle", "in fair shape", "thin", "wasting"};
static const s_TierReasons[5][72] = {
	"It barely knows you. Ride it, feed it and groom it each day.",
	"It's learning you. Keep at it: a ride, a meal and a rub a day.",
	"It knows you now and won't throw you on flat ground.",
	"It trusts you and stays steady when blows land.",
	"Devoted: it comes from far off and follows you at a walk."
};

static Horses_TabLines(horseid,tab,lines[HORSES_GUI_LINES][96])
{
	new count = 0, name[HORSES_NAME_LEN], coat[MOUNT_NAME_LEN], word[16], word2[16], word3[16];
	Horses_GetHorseName(horseid,name);
	Gene_CoatName(Horse_GetType(horseid),coat);

	switch (tab)
	{
		case HORSES_TAB_HORSE:
		{
			Horses_UpdateNeeds(horseid);

			if (Horses_IsFoal(horseid))
			{
				format(lines[count++],96,"%s, a %s foal, %d days old",name,g_HorsesSexNames[Horses_GetSex(horseid)],Horses_GetAgeDays(horseid));
			}
			else
			{
				format(lines[count++],96,"%s, a %d year old %s",name,Horses_GetAgeYears(horseid),g_HorsesSexNames[Horses_GetSex(horseid)]);
			}

			format(lines[count++],96,"%s, %s",coat,g_HorsesBreedNames[Horses_GetBreed(horseid)]);
			format(lines[count++],96,"%s: %s",g_HorsesTierNames[Horses_GetTier(horseid)],s_TierReasons[Horses_GetTier(horseid)]);
			Horses_NeedWord(Horses_GetHunger(horseid),s_HungerWords,word,sizeof(word));
			Horses_NeedWord(Horses_GetThirst(horseid),s_ThirstWords,word2,sizeof(word2));
			Horses_NeedWord(Horses_GetCondition(horseid),s_ConditionWords,word3,sizeof(word3));
			format(lines[count++],96,"It's %s and %s, and %s.",word,word2,word3);

			if (Horses_GetShoes(horseid) == HORSES_UNSHOD)
			{
				strcopy(lines[count++],"Unshod: slower, and it can go lame.",96);
			}
			else
			{
				format(lines[count++],96,"Shod, the shoes %d%% worn.",Horses_GetShoes(horseid) * 100 / HORSES_SHOES_LIFE);
			}

			new today[3][16];
			Horses_Pick(Horses_FedToday(horseid),"fed","not fed",today[0]);
			Horses_Pick(Horses_RiddenToday(horseid),"ridden","not ridden",today[1]);
			Horses_Pick(Horses_GroomedToday(horseid),"groomed","not groomed",today[2]);
			format(lines[count++],96,"Today: %s, %s, %s.",today[0],today[1],today[2]);

			if (Horses_IsLame(horseid))
			{
				strcopy(lines[count++],"Lame: walk it and rest it.",96);
			}

			if (Horses_IsSick(horseid))
			{
				strcopy(lines[count++],"Sick: a stable keeper can treat it.",96);
			}

			if (Horses_GetLendChar(horseid) > 0)
			{
				strcopy(lines[count++],"Lent out for the day: the borrower may ride it.",96);
			}
		}
		case HORSES_TAB_TRAITS:
		{
			new genes[HORSES_LOCI];
			Horses_GetGenes(horseid,genes);

			for (new locus = 0;locus < 4;locus++)
			{
				new tier = Horses_StatTier(horseid,locus);
				format(lines[count++],96,"%s: %s. %s",g_HorsesStatNames[locus],g_HorsesStatWords[locus][tier],g_HorsesStatLines[locus][tier]);
			}

			for (new locus = 0;locus < 4;locus++)
			{
				if (Gene_IsCarrier(genes,locus) && (Horses_IsRevealed(horseid) || Horses_IsProven(horseid,locus)))
				{
					format(lines[count++],96,"Carries %s: its foals may be %s.",g_HorsesStatWords[locus][0],g_HorsesStatWords[locus][0]);
				}
			}

			if (Horses_IsInbred(horseid))
			{
				strcopy(lines[count++],"Inbred: its health is a step weaker.",96);
			}

			if (!Horses_IsRevealed(horseid))
			{
				strcopy(lines[count++],"Hidden blood shows when a foal proves it, or a keeper reads it.",96);
			}

			if (Horses_IsOld(horseid))
			{
				strcopy(lines[count++],"Old: its speed and stamina are fading.",96);
			}
		}
		case HORSES_TAB_BREEDING:
		{
			switch (Horses_GetSex(horseid))
			{
				case HORSES_SEX_GELDING: strcopy(lines[count++],"A gelding can't breed.",96);
				case HORSES_SEX_STALLION:
				{
					if (Horses_GetStudFee(horseid) >= 0)
					{
						new money[24];
						Economy_Format(Horses_GetStudFee(horseid),money);
						format(lines[count++],96,"At stud for %s.",money);
					}
					else
					{
						strcopy(lines[count++],"Not offered at stud. A stable keeper can list him.",96);
					}

					format(lines[count++],96,"Covered %d of %d mares this season.",Horses_GetCovers(horseid),HORSES_STALLION_COVERS);
				}
				default:
				{
					new reason[64];

					if (Horses_IsInFoal(horseid))
					{
						format(lines[count++],96,"In foal: due in %d days.",Horses_DaysToFoal(horseid));
					}
					else if (Horses_MareReady(horseid,reason))
					{
						strcopy(lines[count++],"In season now: book a covering with a stable keeper.",96);
					}
					else
					{
						strcopy(lines[count++],reason,96);
					}
				}
			}

			strcopy(lines[count++],"Mares come in season three days in twelve, in spring and summer.",96);
			strcopy(lines[count++],"A foal takes eleven days and is grown ten days after birth.",96);
		}
	}

	return count;
}

static Horses_KinLines(horseid,lines[HORSES_GUI_LINES][96])
{
	new sire, dam, count = 0;
	Horses_GetParents(horseid,sire,dam);

	if (sire <= 0 && dam <= 0)
	{
		strcopy(lines[count++],"Unknown blood: bought or caught wild.",96);

		if (Horses_IsInbred(horseid))
		{
			strcopy(lines[count++],"Inbred.",96);
		}

		return count;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT h.id, h.name, h.type, h.genes, h.status, h.proven, s.name AS sname, d.name AS dname FROM horses h LEFT JOIN horses s ON s.id = h.sire_id LEFT JOIN horses d ON d.id = h.dam_id WHERE h.id IN (%d, %d)",sire > 0 ? sire : -1,dam > 0 ? dam : -1));

	for (new r = 0;r < cache_num_rows() && count < HORSES_GUI_LINES - 1;r++)
	{
		new id, type, status, proven, name[HORSES_NAME_LEN], sname[HORSES_NAME_LEN], dname[HORSES_NAME_LEN], hex[HORSES_GENES_HEX], genes[HORSES_LOCI], coat[MOUNT_NAME_LEN], words[64];
		cache_get_value_name_int(r,"id",id);
		cache_get_value_name_int(r,"type",type);
		cache_get_value_name_int(r,"status",status);
		cache_get_value_name_int(r,"proven",proven);
		cache_get_value_name(r,"name",name);
		cache_get_value_name(r,"sname",sname);
		cache_get_value_name(r,"dname",dname);
		cache_get_value_name(r,"genes",hex);
		Gene_Decode(hex,genes);
		Gene_CoatName(type,coat);
		format(words,sizeof(words),"%s, %s",g_HorsesStatWords[0][Gene_Tier(genes,0)],g_HorsesStatWords[1][Gene_Tier(genes,1)]);

		if (name[0] == EOS)
		{
			strcopy(name,"Unnamed");
		}

		format(lines[count++],96,"%s: %s, %s, %s",id == sire ? ("Sire") : ("Dam "),name,coat,words);

		if (status == HORSES_STATUS_DEAD)
		{
			strcat(lines[count - 1],", deceased",96);
		}

		if (sname[0] != EOS || dname[0] != EOS)
		{
			if (dname[0] == EOS)
			{
				strcopy(dname,"unknown");
			}

			if (sname[0] == EOS)
			{
				strcopy(sname,"unknown");
			}

			format(lines[count++],96,"   out of %s by %s",dname,sname);
		}

		for (new locus = 0;locus < 4;locus++)
		{
			if (proven & (1 << locus))
			{
				format(lines[count++],96,"   carries %s",g_HorsesStatWords[locus][0]);
			}
		}
	}

	if (Horses_IsInbred(horseid) && count < HORSES_GUI_LINES)
	{
		strcopy(lines[count++],"Inbred: its parents share blood.",96);
	}

	return count;
}

stock Horses_OpenPanel(playerid,horseid,tab = HORSES_TAB_HORSE)
{
	while (Horses_MayRide(playerid,horseid))
	{
		new lines[HORSES_GUI_LINES][96], count = 0, name[HORSES_NAME_LEN], bool:owner = Horses_IsOwner(playerid,horseid);
		Horses_GetHorseName(horseid,name);

		if (tab == HORSES_TAB_KIN)
		{
			count = Horses_KinLines(horseid,lines);

			if (!Horses_MayRide(playerid,horseid))
			{
				return;
			}
		}
		else if (tab != HORSES_TAB_CARE)
		{
			count = Horses_TabLines(horseid,tab,lines);
		}

		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, Float:tabWidth;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,380.0,float(HORSES_GUI_LINES + 2) * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
		tabWidth = width / float(HORSES_TABS);

		for (new t = 0;t < HORSES_TABS;t++)
		{
			Kit_AddButton(playerid,x + tabWidth * float(t),y,tabWidth - 4.0,s_HorseTabNames[t],HORSES_PICK_TAB + t,t == tab ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		}

		if (tab == HORSES_TAB_CARE)
		{
			new rows = 0, labels[10][48], picks[10];
			strcopy(labels[rows],"Feed it oats or hay");
			picks[rows++] = HORSES_CARE_FEED;
			strcopy(labels[rows],"Water it");
			picks[rows++] = HORSES_CARE_WATER;
			strcopy(labels[rows],"Groom it with straw");
			picks[rows++] = HORSES_CARE_GROOM;
			strcopy(labels[rows],"Shoe it");
			picks[rows++] = HORSES_CARE_SHOE;

			if (Horses_GetLeading(playerid) == horseid)
			{
				strcopy(labels[rows],"Stop leading it");
				picks[rows++] = HORSES_CARE_UNLEAD;
			}
			else
			{
				if (Horses_GetTier(horseid) >= HORSES_TIER_DEVOTED)
				{
					strcopy(labels[rows],"Lead it (it follows you)");
				}
				else
				{
					strcopy(labels[rows],"Lead it on a rope");
				}

				picks[rows++] = HORSES_CARE_LEAD;
			}

			if (owner)
			{
				if (Horses_GetLendChar(horseid) > 0)
				{
					strcopy(labels[rows],"Take back the loan");
					picks[rows++] = HORSES_CARE_UNLEND;
				}
				else
				{
					strcopy(labels[rows],"Lend it for a day");
					picks[rows++] = HORSES_CARE_LEND;
				}

				strcopy(labels[rows],"Rename it");
				picks[rows++] = HORSES_CARE_RENAME;
			}

			if (owner && Horses_HasBlanket(horseid))
			{
				strcopy(labels[rows],"Take off the blanket");
				picks[rows++] = HORSES_CARE_BLANKET_OFF;
			}
			else if (owner && Horse_GetType(horseid) != MOUNT_DONKEY_TYPE)
			{
				strcopy(labels[rows],"Put a blanket on it");
				picks[rows++] = HORSES_CARE_BLANKET_ON;
			}

			if (Horses_GetSaddlebag(horseid) != INVALID_CONTAINER_ID || owner)
			{
				strcopy(labels[rows],"Saddlebags");
				picks[rows++] = HORSES_CARE_SADDLEBAGS;
			}

			for (new i = 0;i < rows;i++)
			{
				Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1) + 6.0,width,labels[i],picks[i],KIT_COLOUR_TEXT);
			}
		}
		else
		{
			for (new i = 0;i < count;i++)
			{
				Kit_AddText(playerid,x,y + KIT_ROW * float(i + 1) + 6.0,lines[i],i == 0 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
			}
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(HORSES_GUI_LINES + 2) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Horses_MayRide(playerid,horseid))
		{
			return;
		}

		if (pick >= HORSES_PICK_TAB && pick < HORSES_PICK_TAB + HORSES_TABS)
		{
			tab = pick - HORSES_PICK_TAB;
			continue;
		}

		switch (pick)
		{
			case HORSES_CARE_FEED:
			{
				Horses_TryFeed(playerid,horseid);
				return;
			}
			case HORSES_CARE_WATER:
			{
				Horses_TryWater(playerid,horseid);
				return;
			}
			case HORSES_CARE_GROOM:
			{
				Horses_TryGroom(playerid,horseid);
				return;
			}
			case HORSES_CARE_SHOE:
			{
				Horses_TryShoe(playerid,horseid);
				return;
			}
			case HORSES_CARE_LEAD:
			{
				if (Horses_StartLead(playerid,horseid))
				{
					Gui_Notify(playerid,sprintf("%s walks after you. Mount anything or open its panel to stop.",name));
				}
				else
				{
					Gui_Notify(playerid,"You need a halter and rope to lead it until it's devoted to you. The market traders sell them.");
				}

				return;
			}
			case HORSES_CARE_UNLEAD:
			{
				Horses_StopLead(playerid);
			}
			case HORSES_CARE_LEND:
			{
				Horses_LendTo(playerid,horseid);
				return;
			}
			case HORSES_CARE_UNLEND:
			{
				Horses_Lend(horseid,0,0);
				Horses_Save(horseid);
				Gui_Notify(playerid,sprintf("%s is yours alone again.",name));
			}
			case HORSES_CARE_BLANKET_ON:
			{
				if (!Inventory_Take(playerid,Item_GetDefKind(ITEM_HORSE_BLANKET),ITEM_HORSE_BLANKET,1))
				{
					Gui_Notify(playerid,"You have no horse blanket.");
					return;
				}

				Horses_SetBlanket(horseid,true);
				Gui_Notify(playerid,sprintf("You throw the blanket over %s. The cold bites it half as hard.",name));
			}
			case HORSES_CARE_BLANKET_OFF:
			{
				if (!Inventory_Give(playerid,Item_GetDefKind(ITEM_HORSE_BLANKET),ITEM_HORSE_BLANKET,1))
				{
					Gui_Notify(playerid,"There's no room in your bag for the blanket.");
					return;
				}

				Horses_SetBlanket(horseid,false);
			}
			case HORSES_CARE_RENAME:
			{
				Horses_AskName(playerid,horseid);
			}
			case HORSES_CARE_SADDLEBAGS:
			{
				pawn_call_public("Horses_OnSaddlebags","dd",playerid,horseid);
				return;
			}
		}
	}
}

stock Horses_LendTo(playerid,horseid)
{
	new nearby[HORSES_LIST_MAX], count = 0, Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	foreach (new other : Player)
	{
		if (other != playerid && count < HORSES_LIST_MAX && Session_IsPlaying(other) && IsPlayerInRangeOfPoint(other,6.0,px,py,pz))
		{
			nearby[count++] = other;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"Stand by the person you want to lend it to.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Lend it to");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Lend it to",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[MAX_PLAYER_NAME];
		Character_GetName(nearby[i],name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count || !IsPlayerConnected(nearby[pick]) || !Horses_IsOwner(playerid,horseid))
	{
		return;
	}

	new name[HORSES_NAME_LEN], who[MAX_PLAYER_NAME];
	Horses_GetHorseName(horseid,name);
	Character_GetName(nearby[pick],who);
	Horses_Lend(horseid,Character_GetId(nearby[pick]),1);
	Horses_Save(horseid);
	Gui_Notify(playerid,sprintf("You lend %s to %s for a day.",name,who));
	Gui_Notify(nearby[pick],sprintf("You may ride %s for a day. Hold the mount key with no horse near to whistle for it.",name));
}

forward Horses_OnSaddlebags(playerid,horseid);

public Horses_OnSaddlebags(playerid,horseid)
{
	return 1;
}
