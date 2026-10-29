#define WOUNDS_GUI_WIDTH (300.0)
#define WOUNDS_GUI_CHARS (60)
#define WOUNDS_GUI_TEXT_LEN (700)
#define WOUNDS_GUI_PICKER_ROWS (8)
#define WOUNDS_GUI_TREAT (1)
#define WOUNDS_GUI_CLEAN (2)
#define WOUNDS_GUI_YOURSELF (0)

static WoundsGui_FindCleaner(playerid)
{
	for (new i = 0;i < Wounds_CleanerCount();i++)
	{
		new index = Inventory_Find(playerid,ITEM_KIND_DRINK,Wounds_CleanerAt(i));

		if (index != -1)
		{
			return index;
		}
	}

	return -1;
}

static WoundsGui_Clean(playerid,index,const partName[])
{
	new slot = WoundsGui_FindCleaner(playerid);

	if (slot == -1 || !Wounds_Treat(playerid,index,WOUND_TREAT_CLEAN))
	{
		return;
	}

	new E_ITEM_KIND:kind, param, amount, name[ITEM_NAME_LEN], line[96];
	Inventory_GetSlot(playerid,slot,kind,param,amount);
	Item_GetName(kind,param,name);
	name[0] = tolower(name[0]);
	Inventory_UsePortion(playerid,slot,Item_GetPortions(kind,param));
	format(line,sizeof(line),"You clean the wound on your %s with %s.",partName,param == ITEM_WATER_SKIN ? ("water") : name);
	Gui_Notify(playerid,line);
}

static WoundsGui_Item(treatment)
{
	return treatment == WOUND_TREAT_SPLINT ? ITEM_SPLINT : ITEM_BANDAGE;
}

stock bool:WoundsGui_Needs(patientid,treatment)
{
	if (!Session_IsPlaying(patientid))
	{
		return false;
	}

	if (Wounds_IsLoaded(patientid) && Wounds_FindForTreatment(patientid,treatment) != -1)
	{
		return true;
	}

	return treatment == WOUND_TREAT_BANDAGE && Vitals_GetHealth(patientid) < VITALS_MAX;
}

static bool:WoundsGui_InReach(healerid,patientid)
{
	if (healerid == patientid)
	{
		return true;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(healerid,x,y,z);
	return GetPlayerVirtualWorld(healerid) == GetPlayerVirtualWorld(patientid) && IsPlayerInRangeOfPoint(patientid,WOUND_TREAT_RANGE,x,y,z);
}

stock bool:Wounds_TreatWith(healerid,patientid,treatment)
{
	new item = WoundsGui_Item(treatment);

	if (!WoundsGui_InReach(healerid,patientid) || !WoundsGui_Needs(patientid,treatment) || Inventory_Count(healerid,ITEM_KIND_TOOL,item) <= 0)
	{
		return false;
	}

	new index = Wounds_FindForTreatment(patientid,treatment), part, kind, severity, flags, Float:bleed, partName[12];

	if (index != -1)
	{
		Wounds_GetAt(patientid,index,part,kind,severity,flags,bleed);
		Wounds_PartName(part,partName);
		partName[0] = tolower(partName[0]);
	}

	Inventory_Take(healerid,ITEM_KIND_TOOL,item,1);

	if (!Character_IsBusy(healerid))
	{
		ApplyAnimation(healerid,healerid == patientid ? ("BOMBER") : ("MEDIC"),healerid == patientid ? ("BOM_Plant") : ("CPR"),4.1,false,false,false,false,0,SYNC_ALL);
	}

	if (treatment == WOUND_TREAT_BANDAGE)
	{
		Vitals_Heal(patientid,float(Item_GetValue(ITEM_KIND_TOOL,item)),"bandage");
	}

	if (index != -1)
	{
		Wounds_Treat(patientid,index,treatment);
	}

	new verb[12], text[96], name[NAMETAG_LEN];
	strcopy(verb,treatment == WOUND_TREAT_SPLINT ? ("splint") : ("bandage"));

	if (healerid == patientid)
	{
		if (index != -1)
		{
			format(text,sizeof(text),"You %s your %s.",verb,partName);
		}
		else
		{
			format(text,sizeof(text),"You %s yourself.",verb);
		}

		Gui_Notify(healerid,text);
		return true;
	}

	Nametag_GetKnownName(healerid,patientid,name);

	if (index != -1)
	{
		format(text,sizeof(text),"You %s %s's %s.",verb,name,partName);
	}
	else
	{
		format(text,sizeof(text),"You %s %s.",verb,name);
	}

	Gui_Notify(healerid,text);
	Nametag_GetKnownName(patientid,healerid,name);

	if (index != -1)
	{
		format(text,sizeof(text),"%s %ss your %s.",name,verb,partName);
	}
	else
	{
		format(text,sizeof(text),"%s %ss you.",name,verb);
	}

	Gui_Notify(patientid,text);
	return true;
}

static WoundsGui_PickPatient(playerid,treatment)
{
	yield 1;

	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), patients[WOUNDS_GUI_PICKER_ROWS], count = 0, Float:x, Float:y, Float:width, title[32], label[NAMETAG_LEN];
	strcopy(title,treatment == WOUND_TREAT_SPLINT ? ("Who do you splint") : ("Who do you bandage"));

	if (WoundsGui_Needs(playerid,treatment))
	{
		patients[count++] = playerid;
	}

	foreach (new i : Player)
	{
		if (count < WOUNDS_GUI_PICKER_ROWS && i != playerid && WoundsGui_InReach(playerid,i) && WoundsGui_Needs(i,treatment))
		{
			patients[count++] = i;
		}
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new row = 0;row < count;row++)
	{
		new patientid = patients[row];

		if (patientid == playerid)
		{
			strcopy(label,"Yourself");
		}
		else
		{
			Nametag_GetKnownName(playerid,patientid,label);
		}

		Kit_AddChoice(playerid,x,y + float(row) * KIT_ROW,width,label,row,KIT_COLOUR_TEXT,Wounds_IsBleeding(patientid) ? ("bleeding") : ("hurt"),Wounds_IsBleeding(patientid) ? KIT_COLOUR_BAD : KIT_COLOUR_MUTED,0.62);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return;
	}

	if (!Wounds_TreatWith(playerid,patients[pick],treatment))
	{
		Gui_Notify(playerid,"They're too far away or don't need it anymore.");
	}
}

stock WoundsGui_Offer(playerid,treatment)
{
	new others = 0;

	foreach (new i : Player)
	{
		if (i != playerid && WoundsGui_InReach(playerid,i) && WoundsGui_Needs(i,treatment))
		{
			others++;
		}
	}

	if (others == 0)
	{
		if (!Wounds_TreatWith(playerid,playerid,treatment))
		{
			Gui_Notify(playerid,treatment == WOUND_TREAT_SPLINT ? ("Nobody here has a broken bone to set.") : ("Nobody here needs a bandage."));
		}

		return;
	}

	SetTimerEx("WoundsGui_PickDeferred",0,false,"dd",playerid,treatment);
}

static WoundsGui_AddParagraph(dest[],const text[],size = sizeof(dest))
{
	new wrapped[WOUNDS_GUI_TEXT_LEN];
	Util_WrapText(text,wrapped,sizeof(wrapped),WOUNDS_GUI_CHARS,"~n~");

	if (dest[0] != EOS)
	{
		strcat(dest,"~n~",size);
	}

	strcat(dest,wrapped,size);
}

stock WoundsGui_ShowWound(playerid,epoch,index)
{
	new part, kind, severity, flags, Float:bleed;

	if (!Wounds_GetAt(playerid,index,part,kind,severity,flags,bleed))
	{
		return;
	}

	new title[40], partName[12], wound[WOUND_NAME_LEN], text[WOUNDS_GUI_TEXT_LEN], line[160], treatment = kind == WOUND_BROKEN ? WOUND_TREAT_SPLINT : WOUND_TREAT_BANDAGE;
	Wounds_PartName(part,partName);
	Wounds_Describe(kind,severity,wound);
	format(title,sizeof(title),"%s: %s",partName,wound);

	if (bleed > 0.0)
	{
		format(line,sizeof(line),"It's ~r~bleeding~w~, about ~r~%.2f health a second~w~. A ~y~bandage~w~ stops it straight away.",bleed);
		WoundsGui_AddParagraph(text,line);
	}
	else if (flags & WOUND_FLAG_STITCHED)
	{
		WoundsGui_AddParagraph(text,"It's been ~y~stitched~w~ at the infirmary, so it heals in half the time.");
	}
	else if (flags & WOUND_FLAG_BANDAGED)
	{
		WoundsGui_AddParagraph(text,"It's ~y~bandaged~w~ and clean.");
	}
	else if (Wounds_KindBleeds(kind))
	{
		WoundsGui_AddParagraph(text,"It's stopped bleeding. An open wound can still ~r~fester~w~. A ~y~bandage~w~ keeps it clean.");
	}

	if (flags & WOUND_FLAG_CLEANED)
	{
		WoundsGui_AddParagraph(text,"It's been ~y~cleaned~w~, so it's less likely to fester.");
	}
	else if (Wounds_CanBeCleaned(kind,severity,flags))
	{
		WoundsGui_AddParagraph(text,"Cleaning it with ~y~water or strong drink~w~ makes it less likely to fester.");
	}

	if (kind == WOUND_BROKEN)
	{
		if (flags & WOUND_FLAG_SET)
		{
			WoundsGui_AddParagraph(text,"The bone was ~y~set~w~ at the infirmary. It heals straight, in half the time.");
		}
		else
		{
			WoundsGui_AddParagraph(text,(flags & WOUND_FLAG_SPLINTED) ? ("It's ~y~splinted~w~ and healing.") : ("~y~Splint it~w~, or it ~r~heals crooked~w~."));
		}

		if (Wounds_IsLeg(part) && !(flags & WOUND_FLAG_SPLINTED))
		{
			WoundsGui_AddParagraph(text,"You ~r~limp~w~ and ~r~can't ride~w~ until it's splinted.");
		}
		else if (part == WOUND_PART_LEFT_ARM && !(flags & WOUND_FLAG_SPLINTED))
		{
			WoundsGui_AddParagraph(text,"You ~r~can't block~w~ with it.");
		}
	}

	if (part == WOUND_PART_RIGHT_ARM)
	{
		WoundsGui_AddParagraph(text,"Your ~r~swings are weaker~w~ while your weapon arm is hurt.");
	}
	else if (part == WOUND_PART_TORSO)
	{
		format(line,sizeof(line),"It ~r~tires you out~w~: your stamina can't go above ~r~%d%%~w~ while it lasts.",floatround(Wounds_TorsoStaminaCapFor(severity)));
		WoundsGui_AddParagraph(text,line);
	}

	if (flags & WOUND_FLAG_FESTERING)
	{
		WoundsGui_AddParagraph(text,"~r~It's festering.~w~ It won't heal until the infection is treated. A lay brother or sister at the monastery infirmary can lance it.");
	}
	else if (bleed > 0.0)
	{
		WoundsGui_AddParagraph(text,"It ~r~won't start healing~w~ while it bleeds.");
	}
	else
	{
		format(line,sizeof(line),"It heals in about ~y~%d minutes~w~ of playtime.",(Wounds_GetHealLeft(playerid,index) + 59) / 60);
		WoundsGui_AddParagraph(text,line);

		if (Wounds_GetRestBonus(playerid) > 0)
		{
			WoundsGui_AddParagraph(text,"You're resting in an ~y~infirmary bed~w~, so it heals twice as fast.");
		}
	}

	new bool:canTreat = Inventory_Count(playerid,ITEM_KIND_TOOL,WoundsGui_Item(treatment)) > 0 && Wounds_FindForTreatment(playerid,treatment) != -1 && (treatment == WOUND_TREAT_SPLINT ? !(flags & WOUND_FLAG_SPLINTED) : (Wounds_KindBleeds(kind) && !(flags & WOUND_FLAG_BANDAGED)));
	new Float:x, Float:y, Float:width, Float:textHeight = Gui_TextHeight(text,WOUNDS_GUI_WIDTH);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,WOUNDS_GUI_WIDTH,textHeight + KIT_ROW + 10.0,title,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new bool:canClean = Wounds_CanBeCleaned(kind,severity,flags) && WoundsGui_FindCleaner(playerid) != -1;

	if (canTreat && canClean)
	{
		Kit_AddButton(playerid,x,y + textHeight + 8.0,width * 0.31,treatment == WOUND_TREAT_SPLINT ? ("Splint it") : ("Bandage it"),WOUNDS_GUI_TREAT,KIT_COLOUR_ACCENT);
		Kit_AddButton(playerid,x + width * 0.345,y + textHeight + 8.0,width * 0.31,"Clean it",WOUNDS_GUI_CLEAN,KIT_COLOUR_ACCENT);
		Kit_AddButton(playerid,x + width * 0.69,y + textHeight + 8.0,width * 0.31,GUI_BUTTON_BACK,KIT_BACK);
	}
	else if (canTreat || canClean)
	{
		Kit_AddButton(playerid,x,y + textHeight + 8.0,width * 0.45,canClean ? ("Clean it") : (treatment == WOUND_TREAT_SPLINT ? ("Splint it") : ("Bandage it")),canClean ? WOUNDS_GUI_CLEAN : WOUNDS_GUI_TREAT,KIT_COLOUR_ACCENT);
		Kit_AddButton(playerid,x + width * 0.55,y + textHeight + 8.0,width * 0.45,GUI_BUTTON_BACK,KIT_BACK);
	}
	else
	{
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + textHeight + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	}

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	if (pick == WOUNDS_GUI_CLEAN)
	{
		partName[0] = tolower(partName[0]);
		WoundsGui_Clean(playerid,index,partName);
		return;
	}

	if (pick != WOUNDS_GUI_TREAT)
	{
		return;
	}

	new item = WoundsGui_Item(treatment);

	if (Inventory_Count(playerid,ITEM_KIND_TOOL,item) > 0 && Wounds_Treat(playerid,index,treatment))
	{
		Inventory_Take(playerid,ITEM_KIND_TOOL,item,1);

		if (treatment == WOUND_TREAT_BANDAGE)
		{
			Vitals_Heal(playerid,float(Item_GetValue(ITEM_KIND_TOOL,item)),"bandage");
		}

		partName[0] = tolower(partName[0]);
		format(line,sizeof(line),"You %s your %s.",treatment == WOUND_TREAT_SPLINT ? ("splint") : ("bandage"),partName);
		Gui_Notify(playerid,line);
	}
}

forward WoundsGui_PickDeferred(playerid,treatment);

public WoundsGui_PickDeferred(playerid,treatment)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid))
	{
		WoundsGui_PickPatient(playerid,treatment);
	}

	return 1;
}

#include <pp-hooks>

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars, index

	if (E_ITEM_KIND:kind != ITEM_KIND_TOOL)
	{
		return;
	}

	if (param == ITEM_BANDAGE)
	{
		WoundsGui_Offer(playerid,WOUND_TREAT_BANDAGE);
	}
	else if (param == ITEM_SPLINT)
	{
		WoundsGui_Offer(playerid,WOUND_TREAT_SPLINT);
	}
}
