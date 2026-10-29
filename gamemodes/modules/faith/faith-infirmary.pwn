#define INFIRMARY_BED_RANGE (1.6)
#define INFIRMARY_BED_STRAY (1.5)
#define INFIRMARY_TEND_RANGE (2.0)
#define INFIRMARY_RADIUS (8.0)
#define INFIRMARY_REST_BONUS (100)
#define INFIRMARY_REST_SECONDS (600)
#define INFIRMARY_BUFF_KEY "infirmary"
#define INFIRMARY_LIE_LIB "CRACK"
#define INFIRMARY_LIE_ANIM "crckidle2"
#define INFIRMARY_LIE_Z (1.0)
#define INFIRMARY_LIE_ANGLE (0.0)
#define INFIRMARY_LIE_HEAD (0.15)
#define INFIRMARY_LIE_OPEN (0.15)
#define INFIRMARY_SIDE (0.9)
#define INFIRMARY_PROMPT_TEND (1000)
#define INFIRMARY_RANGE_BED_OBJECT (60.0)
#define INFIRMARY_LIST_LEN (96)

enum
{
	INFIRMARY_TEND_EXAMINE,
	INFIRMARY_TEND_REMEDY,
	INFIRMARY_TEND_STITCH,
	INFIRMARY_TEND_SET,
	INFIRMARY_TEND_LANCE,
	INFIRMARY_TEND_RITES,
	INFIRMARY_TEND_COUNT,
}

enum
{
	INFIRMARY_OK,
	INFIRMARY_NOT_ALLOWED,
	INFIRMARY_CANON,
	INFIRMARY_NO_NEED,
	INFIRMARY_NO_TOOL,
	INFIRMARY_NO_SUPPLY,
	INFIRMARY_TOO_FAR,
	INFIRMARY_BUSY,
}

static const Float:s_InfirmaryCentre[3] = {709.5, -3637.3, 18.5};

static const Float:s_InfirmaryBeds[][4] = {
	{706.0, -3638.35, 17.49, 180.0},
	{708.6, -3638.35, 17.49, 180.0},
	{711.2, -3638.35, 17.49, 180.0}
};

static const s_InfirmaryRemedies[] = {ITEM_REMEDY_RARE, ITEM_TINCTURE, ITEM_SALVE, ITEM_POULTICE};

static STREAMER_TAG_OBJECT:s_InfirmaryBedObjects[sizeof(s_InfirmaryBeds)];
static s_InfirmaryBedPatient[sizeof(s_InfirmaryBeds)];
static s_InfirmaryBed[MAX_PLAYERS];
static s_InfirmaryRest[MAX_PLAYERS];
static s_InfirmaryPrompt[MAX_PLAYERS];
static s_InfirmaryPromptInfobox[MAX_PLAYERS];
static s_InfirmaryLyingInfobox[MAX_PLAYERS];
static bool:s_InfirmaryLyingRites[MAX_PLAYERS];

stock Infirmary_CountBeds()
{
	return sizeof(s_InfirmaryBeds);
}

stock Infirmary_GetBed(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_InfirmaryBed[playerid] : -1;
}

stock bool:Infirmary_IsLying(playerid)
{
	return Infirmary_GetBed(playerid) != -1;
}

stock Infirmary_GetBedPatient(bed)
{
	return bed >= 0 && bed < sizeof(s_InfirmaryBeds) ? s_InfirmaryBedPatient[bed] : INVALID_PLAYER_ID;
}

stock Infirmary_GetBedPos(bed,&Float:x,&Float:y,&Float:z,&Float:a)
{
	bed = clamp(bed,0,sizeof(s_InfirmaryBeds) - 1);
	x = s_InfirmaryBeds[bed][0];
	y = s_InfirmaryBeds[bed][1];
	z = s_InfirmaryBeds[bed][2];
	a = s_InfirmaryBeds[bed][3];
}

stock Infirmary_BedsidePos(bed,&Float:x,&Float:y,&Float:z,&Float:a)
{
	new Float:bedX, Float:bedY, Float:bedZ, Float:bedA;
	Infirmary_GetBedPos(bed,bedX,bedY,bedZ,bedA);
	x = bedX + floatsin(bedA,degrees) * INFIRMARY_SIDE;
	y = bedY - floatcos(bedA,degrees) * INFIRMARY_SIDE;
	z = bedZ + 1.0;
	a = bedA;
}

stock bool:Infirmary_IsInside(playerid)
{
	return Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && GetPlayerInterior(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,INFIRMARY_RADIUS,s_InfirmaryCentre[0],s_InfirmaryCentre[1],s_InfirmaryCentre[2]);
}

stock bool:Infirmary_CanNurse(playerid)
{
	new E_CLERGY_RANK:rank = Clergy_GetRank(playerid);
	return rank == CLERGY_BROTHER || rank == CLERGY_DEACON || rank == CLERGY_PRIEST || rank == CLERGY_PRIOR || rank == CLERGY_ABBOT;
}

stock bool:Infirmary_CanCut(playerid)
{
	return Clergy_GetRank(playerid) == CLERGY_LAY;
}

stock bool:Infirmary_IsHealer(playerid)
{
	return Infirmary_CanNurse(playerid) || Infirmary_CanCut(playerid);
}

stock bool:Infirmary_IsHealerOnline(exceptid = INVALID_PLAYER_ID)
{
	foreach (new i : Player)
	{
		if (i != exceptid && !IsPlayerNPC(i) && Session_IsPlaying(i) && Infirmary_IsHealer(i))
		{
			return true;
		}
	}

	return false;
}

stock bool:Infirmary_NeedsLastRites(playerid)
{
	return Session_IsPlaying(playerid) && Lineage_IsLoaded(playerid) && !Lineage_HasLastRites(playerid) && (Ailment_IsLethalNow(playerid) || Lineage_IsMarked(playerid));
}

static Infirmary_FindRemedy(playerid)
{
	for (new i = 0;i < sizeof(s_InfirmaryRemedies);i++)
	{
		new slot = Inventory_Find(playerid,ITEM_KIND_TOOL,s_InfirmaryRemedies[i]);

		if (slot != -1)
		{
			return slot;
		}
	}

	return -1;
}

static Infirmary_FindCleaner(playerid)
{
	for (new i = 0;i < Wounds_CleanerCount();i++)
	{
		new slot = Inventory_Find(playerid,ITEM_KIND_DRINK,Wounds_CleanerAt(i));

		if (slot != -1)
		{
			return slot;
		}
	}

	return -1;
}

stock Infirmary_FindRemedyTarget(playerid)
{
	new best = -1, bestStage = -1;

	for (new i = 0;i < Ailment_GetCount(playerid);i++)
	{
		new ailment = Ailment_GetAt(playerid,i);

		if (!Ailment_IsDiagnosed(playerid,ailment) || Ailment_IsTreated(playerid,ailment))
		{
			continue;
		}

		if (Ailment_GetStage(playerid,ailment) > bestStage)
		{
			best = ailment;
			bestStage = Ailment_GetStage(playerid,ailment);
		}
	}

	return best;
}

stock Infirmary_CountUndiagnosed(playerid)
{
	new count = 0;

	for (new i = 0;i < Ailment_GetCount(playerid);i++)
	{
		if (!Ailment_IsDiagnosed(playerid,Ailment_GetAt(playerid,i)))
		{
			count++;
		}
	}

	return count;
}

static bool:Infirmary_InReach(healerid,patientid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(healerid,x,y,z);
	return healerid != patientid && Session_IsPlaying(healerid) && Session_IsPlaying(patientid) && GetPlayerVirtualWorld(healerid) == GetPlayerVirtualWorld(patientid) && IsPlayerInRangeOfPoint(patientid,INFIRMARY_TEND_RANGE,x,y,z) && Infirmary_IsInside(patientid);
}

static Infirmary_WoundTreatment(action)
{
	switch (action)
	{
		case INFIRMARY_TEND_STITCH:
		{
			return WOUND_TREAT_STITCH;
		}
		case INFIRMARY_TEND_SET:
		{
			return WOUND_TREAT_SET;
		}
	}

	return WOUND_TREAT_LANCE;
}

stock Infirmary_Check(healerid,patientid,action)
{
	if (!Infirmary_InReach(healerid,patientid))
	{
		return INFIRMARY_TOO_FAR;
	}

	switch (action)
	{
		case INFIRMARY_TEND_EXAMINE:
		{
			return Infirmary_CanNurse(healerid) ? INFIRMARY_OK : INFIRMARY_NOT_ALLOWED;
		}
		case INFIRMARY_TEND_REMEDY:
		{
			if (!Infirmary_CanNurse(healerid))
			{
				return INFIRMARY_NOT_ALLOWED;
			}

			if (Infirmary_FindRemedyTarget(patientid) == -1)
			{
				return INFIRMARY_NO_NEED;
			}

			return Infirmary_FindRemedy(healerid) == -1 ? INFIRMARY_NO_SUPPLY : INFIRMARY_OK;
		}
		case INFIRMARY_TEND_STITCH, INFIRMARY_TEND_SET, INFIRMARY_TEND_LANCE:
		{
			if (!Infirmary_CanCut(healerid))
			{
				return Infirmary_CanNurse(healerid) ? INFIRMARY_CANON : INFIRMARY_NOT_ALLOWED;
			}

			if (Wounds_FindForTreatment(patientid,Infirmary_WoundTreatment(action)) == -1)
			{
				return INFIRMARY_NO_NEED;
			}

			if (action == INFIRMARY_TEND_STITCH)
			{
				if (Inventory_Count(healerid,ITEM_KIND_TOOL,ITEM_NEEDLE) <= 0)
				{
					return INFIRMARY_NO_TOOL;
				}

				return Inventory_Count(healerid,ITEM_KIND_MATERIAL,ITEM_THREAD) <= 0 ? INFIRMARY_NO_SUPPLY : INFIRMARY_OK;
			}

			if (action == INFIRMARY_TEND_SET)
			{
				return Inventory_Count(healerid,ITEM_KIND_TOOL,ITEM_SPLINT) <= 0 ? INFIRMARY_NO_SUPPLY : INFIRMARY_OK;
			}

			if (Inventory_Count(healerid,ITEM_KIND_TOOL,ITEM_LANCET) <= 0)
			{
				return INFIRMARY_NO_TOOL;
			}

			return Infirmary_FindCleaner(healerid) == -1 ? INFIRMARY_NO_SUPPLY : INFIRMARY_OK;
		}
		case INFIRMARY_TEND_RITES:
		{
			if (!Clergy_CanLead(healerid))
			{
				return INFIRMARY_NOT_ALLOWED;
			}

			if (!Infirmary_NeedsLastRites(patientid))
			{
				return INFIRMARY_NO_NEED;
			}

			return Faith_IsRiteRunning() || Faith_IsServiceRunning() ? INFIRMARY_BUSY : INFIRMARY_OK;
		}
	}

	return INFIRMARY_NOT_ALLOWED;
}

stock Infirmary_Reason(action,status,dest[],size = sizeof(dest))
{
	switch (status)
	{
		case INFIRMARY_OK:
		{
			strcopy(dest,"",size);
		}
		case INFIRMARY_NOT_ALLOWED:
		{
			if (action == INFIRMARY_TEND_RITES)
			{
				strcopy(dest,"Priests only",size);
			}
			else if (action == INFIRMARY_TEND_EXAMINE || action == INFIRMARY_TEND_REMEDY)
			{
				strcopy(dest,"Brothers and sisters",size);
			}
			else
			{
				strcopy(dest,"Lay brothers only",size);
			}
		}
		case INFIRMARY_CANON:
		{
			strcopy(dest,"Lay brothers only",size);
		}
		case INFIRMARY_NO_NEED:
		{
			strcopy(dest,"Not needed",size);
		}
		case INFIRMARY_NO_TOOL:
		{
			strcopy(dest,action == INFIRMARY_TEND_STITCH ? ("Needs a needle") : ("Needs a lancet"),size);
		}
		case INFIRMARY_NO_SUPPLY:
		{
			switch (action)
			{
				case INFIRMARY_TEND_REMEDY:
				{
					strcopy(dest,"Needs a remedy",size);
				}
				case INFIRMARY_TEND_STITCH:
				{
					strcopy(dest,"Needs thread",size);
				}
				case INFIRMARY_TEND_SET:
				{
					strcopy(dest,"Needs a splint",size);
				}
				default:
				{
					strcopy(dest,"Needs water or drink",size);
				}
			}
		}
		case INFIRMARY_TOO_FAR:
		{
			strcopy(dest,"Too far away",size);
		}
		case INFIRMARY_BUSY:
		{
			strcopy(dest,"After the mass",size);
		}
	}
}

stock Infirmary_ListAilments(playerid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	for (new i = 0;i < Ailment_GetCount(playerid);i++)
	{
		new name[AILMENT_NAME_LEN];
		Ailment_GetName(Ailment_GetAt(playerid,i),name);
		name[0] = tolower(name[0]);

		if (i > 0)
		{
			strcat(dest,i == Ailment_GetCount(playerid) - 1 ? (" and ") : (", "),size);
		}

		strcat(dest,name,size);
	}
}

static Infirmary_PlayTending(healerid)
{
	if (!Character_IsBusy(healerid))
	{
		ApplyAnimation(healerid,"MEDIC","CPR",4.1,false,false,false,false,0,SYNC_ALL);
	}
}

static Infirmary_TellBoth(healerid,patientid,const toHealer[],const toPatient[])
{
	new healerName[NAMETAG_LEN], patientName[NAMETAG_LEN], line[160];
	Nametag_GetKnownName(healerid,patientid,patientName);
	Nametag_GetKnownName(patientid,healerid,healerName);
	format(line,sizeof(line),toHealer,patientName);
	Gui_Notify(healerid,line);
	format(line,sizeof(line),toPatient,healerName);
	Gui_Notify(patientid,line);
}

static Infirmary_TendWound(healerid,patientid,action)
{
	new treatment = Infirmary_WoundTreatment(action), index = Wounds_FindForTreatment(patientid,treatment), part, kind, severity, flags, Float:bleed, partName[12], toHealer[112], toPatient[112];

	if (index == -1 || !Wounds_GetAt(patientid,index,part,kind,severity,flags,bleed))
	{
		return INFIRMARY_NO_NEED;
	}

	Wounds_PartName(part,partName);
	partName[0] = tolower(partName[0]);

	switch (action)
	{
		case INFIRMARY_TEND_STITCH:
		{
			Inventory_Take(healerid,ITEM_KIND_MATERIAL,ITEM_THREAD,1);
			format(toHealer,sizeof(toHealer),"You stitch the wound on %%s's %s. It heals in half the time now.",partName);
			format(toPatient,sizeof(toPatient),"%%s stitches the wound on your %s. It heals in half the time now.",partName);
		}
		case INFIRMARY_TEND_SET:
		{
			Inventory_Take(healerid,ITEM_KIND_TOOL,ITEM_SPLINT,1);
			format(toHealer,sizeof(toHealer),"You set the bone in %%s's %s and splint it. It heals straight, in half the time.",partName);
			format(toPatient,sizeof(toPatient),"%%s sets the bone in your %s and splints it. It heals straight, in half the time.",partName);
		}
		default:
		{
			new slot = Infirmary_FindCleaner(healerid), E_ITEM_KIND:itemKind, param, amount;
			Inventory_GetSlot(healerid,slot,itemKind,param,amount);
			Inventory_UsePortion(healerid,slot,Item_GetPortions(itemKind,param));
			format(toHealer,sizeof(toHealer),"You lance the festering wound on %%s's %s and wash it out. It can heal now.",partName);
			format(toPatient,sizeof(toPatient),"%%s lances the festering wound on your %s and washes it out. It can heal now.",partName);
		}
	}

	Wounds_Treat(patientid,index,treatment);
	Infirmary_TellBoth(healerid,patientid,toHealer,toPatient);
	return INFIRMARY_OK;
}

static Infirmary_Examine(healerid,patientid)
{
	for (new i = 0;i < Ailment_GetCount(patientid);i++)
	{
		Ailment_Diagnose(patientid,Ailment_GetAt(patientid,i));
	}

	new list[INFIRMARY_LIST_LEN], toHealer[160], toPatient[160];

	if (Ailment_GetCount(patientid) == 0)
	{
		Infirmary_TellBoth(healerid,patientid,"You examine %s and find no illness.","%s examines you and finds no illness.");
		return;
	}

	Infirmary_ListAilments(patientid,list);
	format(toHealer,sizeof(toHealer),"You examine %%s. They suffer from %s.",list);
	format(toPatient,sizeof(toPatient),"%%s examines you. You suffer from %s. Your Health tab names %s now.",list,Ailment_GetCount(patientid) == 1 ? ("it") : ("them"));
	Infirmary_TellBoth(healerid,patientid,toHealer,toPatient);
}

static Infirmary_GiveRemedy(healerid,patientid)
{
	new ailment = Infirmary_FindRemedyTarget(patientid), slot = Infirmary_FindRemedy(healerid), E_ITEM_KIND:itemKind, param, amount;

	if (ailment == -1 || slot == -1 || !Inventory_GetSlot(healerid,slot,itemKind,param,amount))
	{
		return INFIRMARY_NO_NEED;
	}

	new stars = Inventory_GetSlotStars(healerid,slot), quality = clamp(stars + (param == ITEM_REMEDY_RARE ? 1 : 0),1,ITEM_STARS_MAX), item[ITEM_NAME_LEN], name[AILMENT_NAME_LEN], toHealer[160], toPatient[160];
	Item_GetName(itemKind,param,item);
	item[0] = tolower(item[0]);
	Ailment_GetName(ailment,name);
	name[0] = tolower(name[0]);
	Inventory_Take(healerid,itemKind,param,1,stars);
	Ailment_Treat(patientid,ailment,quality);
	format(toHealer,sizeof(toHealer),"You give %%s %s %s for the %s.",Util_StartsWithVowel(item) ? ("an") : ("a"),item,name);
	format(toPatient,sizeof(toPatient),"%%s gives you %s %s for the %s. It eases the illness.",Util_StartsWithVowel(item) ? ("an") : ("a"),item,name);
	Infirmary_TellBoth(healerid,patientid,toHealer,toPatient);
	return INFIRMARY_OK;
}

static Infirmary_LastRitesLines()
{
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,"comes to the bedside with the stole and the oil of the sick.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Pax huic domui.","Peace be to this house.");
	Faith_RiteAdd(FAITH_SAY_PLAYER,"Confiteor Deo omnipotenti, quia peccavi nimis cogitatione, verbo et opere: mea culpa.","I confess to almighty God that I have sinned exceedingly in thought, word and deed, through my fault.","The priest hears your last confession. Press ~y~Y~w~ to make it.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Ego te absolvo a peccatis tuis, in nomine Patris, et Filii, et Spiritus Sancti.","I absolve thee from thy sins, in the name of the Father, and of the Son, and of the Holy Ghost.");
	Faith_RiteAdd(FAITH_SAY_PLAYER,"Amen.","","Press ~y~Y~w~ to answer ~y~Amen~w~.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Oremus. Domine Deus, qui per Apostolum tuum Jacobum locutus es:","Let us pray. O Lord God, who hast spoken by Thine Apostle James, saying:");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Infirmatur quis in vobis? inducat presbyteros Ecclesiae, et orent super eum,","Is any man sick among you? Let him call in the priests of the Church, and let them pray over him,");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"ungentes eum oleo in nomine Domini: et oratio fidei salvabit infirmum,","anointing him with oil in the name of the Lord: and the prayer of faith shall save the sick man,");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"et alleviabit eum Dominus; et si in peccatis sit, remittentur ei:","and the Lord will raise him up; and if he be in sins, they shall be forgiven him:");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"cura, quaesumus, Redemptor noster, gratia Sancti Spiritus languores istius infirmi,","cure, we beseech Thee, O our Redeemer, by the grace of the Holy Ghost, the ailments of this sick man;");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"ejusque sana vulnera, et dimitte peccata, atque dolores cunctos mentis et corporis ab eo expelle.","heal his wounds, and forgive his sins; drive out from him all pains of body and mind.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Per Christum Dominum nostrum. Amen.","Through Christ our Lord. Amen.");
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,"anoints the eyes, ears, nostrils, lips, hands and feet with the holy oil.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Per istam sanctam unctionem, et suam piissimam misericordiam,","Through this holy unction, and of His most tender mercy,");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"indulgeat tibi Dominus quidquid deliquisti. Amen.","may the Lord pardon thee whatsoever sins thou hast committed. Amen.");
}

stock bool:Infirmary_StartLastRites(playerid,Float:x,Float:y,Float:z,Float:a,lineMs = FAITH_RITE_LINE_MS)
{
	if (!Infirmary_NeedsLastRites(playerid) || !Faith_RiteBegin(FAITH_RITE_LAST_RITES,playerid,0,x,y,z,a,"The last rites",true,lineMs))
	{
		return false;
	}

	Infirmary_LastRitesLines();
	Faith_RiteStart();
	Log_Info("faith","last rites for player %d begin",playerid);
	return true;
}

stock bool:Infirmary_AskLastRites(playerid,lineMs = FAITH_RITE_LINE_MS)
{
	new bed = Infirmary_GetBed(playerid);

	if (bed == -1 || !Infirmary_NeedsLastRites(playerid))
	{
		return false;
	}

	if (Faith_IsServiceRunning() || Faith_IsRiteRunning())
	{
		Gui_Notify(playerid,"The priest is busy in the church. Ask again once the mass or the rite there is over.");
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Infirmary_BedsidePos(bed,x,y,z,a);
	return Infirmary_StartLastRites(playerid,x,y,z,a,lineMs);
}

stock Infirmary_Tend(healerid,patientid,action)
{
	new status = Infirmary_Check(healerid,patientid,action);

	if (status != INFIRMARY_OK)
	{
		return status;
	}

	if (action != INFIRMARY_TEND_RITES)
	{
		Infirmary_PlayTending(healerid);
	}

	switch (action)
	{
		case INFIRMARY_TEND_EXAMINE:
		{
			Infirmary_Examine(healerid,patientid);
		}
		case INFIRMARY_TEND_REMEDY:
		{
			status = Infirmary_GiveRemedy(healerid,patientid);
		}
		case INFIRMARY_TEND_RITES:
		{
			new Float:x, Float:y, Float:z, Float:a;
			GetPlayerPos(healerid,x,y,z);
			GetPlayerFacingAngle(healerid,a);
			status = Infirmary_StartLastRites(patientid,x,y,z,a) ? INFIRMARY_OK : INFIRMARY_BUSY;
		}
		default:
		{
			status = Infirmary_TendWound(healerid,patientid,action);
		}
	}

	if (status == INFIRMARY_OK)
	{
		pawn_call_public("Infirmary_OnTended","ddd",healerid,patientid,action);
	}

	return status;
}

static Infirmary_ShowLyingBox(playerid)
{
	if (s_InfirmaryLyingInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_InfirmaryLyingInfobox[playerid]);
	}

	s_InfirmaryLyingRites[playerid] = Infirmary_NeedsLastRites(playerid);
	s_InfirmaryLyingInfobox[playerid] = Infobox_Show(playerid,"Infirmary bed",s_InfirmaryLyingRites[playerid] ? ("You're resting. Press ~y~Y~w~ to ask for a priest and the last rites. ~y~N~w~ gets up.") : ("You're resting. Your wounds heal twice as fast here. ~y~N~w~ gets up."),3);
}

static Infirmary_ClearPrompt(playerid)
{
	if (s_InfirmaryPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_InfirmaryPromptInfobox[playerid]);
	}

	s_InfirmaryPrompt[playerid] = -1;
	s_InfirmaryPromptInfobox[playerid] = 0;
}

stock Infirmary_FindFreeBed(playerid,Float:range = INFIRMARY_BED_RANGE)
{
	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		return -1;
	}

	for (new bed = 0;bed < sizeof(s_InfirmaryBeds);bed++)
	{
		if (s_InfirmaryBedPatient[bed] == INVALID_PLAYER_ID && IsPlayerInRangeOfPoint(playerid,range,s_InfirmaryBeds[bed][0],s_InfirmaryBeds[bed][1],s_InfirmaryBeds[bed][2] + 1.0))
		{
			return bed;
		}
	}

	return -1;
}

stock Infirmary_FindFreeBedNear(Float:x,Float:y,Float:z)
{
	new best = -1, Float:bestDistance = 0.0;

	for (new bed = 0;bed < sizeof(s_InfirmaryBeds);bed++)
	{
		if (s_InfirmaryBedPatient[bed] != INVALID_PLAYER_ID)
		{
			continue;
		}

		new Float:distance = VectorSize(s_InfirmaryBeds[bed][0] - x,s_InfirmaryBeds[bed][1] - y,s_InfirmaryBeds[bed][2] - z);

		if (best == -1 || distance < bestDistance)
		{
			best = bed;
			bestDistance = distance;
		}
	}

	return best;
}

static Infirmary_FindPatient(healerid)
{
	foreach (new i : Player)
	{
		if (i != healerid && !IsPlayerNPC(i) && Infirmary_InReach(healerid,i))
		{
			return i;
		}
	}

	return INVALID_PLAYER_ID;
}

stock bool:Infirmary_HasPrompt(playerid)
{
    return Infirmary_IsLying(playerid) || (Session_IsPlaying(playerid) && Infirmary_IsInside(playerid) && (Infirmary_FindFreeBed(playerid) != -1 || (Infirmary_IsHealer(playerid) && Infirmary_FindPatient(playerid) != INVALID_PLAYER_ID)));
}

stock Infirmary_UpdatePrompt(playerid)
{
	if (Infirmary_IsLying(playerid))
	{
		if (s_InfirmaryLyingRites[playerid] != Infirmary_NeedsLastRites(playerid) && !Faith_IsRiteRunning())
		{
			Infirmary_ShowLyingBox(playerid);
		}

		return;
	}

	if (!Session_IsPlaying(playerid) || Faith_IsPraying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || Wounds_IsDown(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || !Infirmary_IsInside(playerid))
	{
		Infirmary_ClearPrompt(playerid);
		return;
	}

	new prompt = -1, patientid = Infirmary_IsHealer(playerid) ? Infirmary_FindPatient(playerid) : INVALID_PLAYER_ID;

	if (patientid != INVALID_PLAYER_ID)
	{
		prompt = INFIRMARY_PROMPT_TEND + patientid;
	}
	else
	{
		prompt = Infirmary_FindFreeBed(playerid);
	}

	if (prompt == -1)
	{
		Infirmary_ClearPrompt(playerid);
		return;
	}

	if (prompt == s_InfirmaryPrompt[playerid] && Infobox_IsShown(playerid,s_InfirmaryPromptInfobox[playerid]))
	{
		return;
	}

	if (s_InfirmaryPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_InfirmaryPromptInfobox[playerid]);
	}

	s_InfirmaryPrompt[playerid] = prompt;

	if (prompt >= INFIRMARY_PROMPT_TEND)
	{
		new name[NAMETAG_LEN], text[64];
		Nametag_GetKnownName(playerid,patientid,name);
		format(text,sizeof(text),"Press Y to tend %s.",name);
		s_InfirmaryPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_InfirmaryPromptInfobox[playerid],"Infirmary",text,2);
		return;
	}

	s_InfirmaryPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_InfirmaryPromptInfobox[playerid],"Infirmary bed","Press Y to lie down. Wounds heal twice as fast in an infirmary bed, and 10 minutes of rest a day eases illness.",3);
}

stock bool:Infirmary_CanLieDown(playerid)
{
	return Session_IsPlaying(playerid) && !Infirmary_IsLying(playerid) && !Combat_IsInMode(playerid) && !Mount_IsRiding(playerid) && !Wounds_IsDown(playerid) && !Combat_IsStruckDown(playerid);
}

stock bool:Infirmary_LieDown(playerid,bed)
{
	if (bed < 0 || bed >= sizeof(s_InfirmaryBeds) || s_InfirmaryBedPatient[bed] != INVALID_PLAYER_ID || !Infirmary_CanLieDown(playerid))
	{
		return false;
	}

	Infirmary_ClearPrompt(playerid);
	s_InfirmaryBed[playerid] = bed;
	s_InfirmaryBedPatient[bed] = playerid;
	new Float:angle = s_InfirmaryBeds[bed][3];
	new Float:x = s_InfirmaryBeds[bed][0] + floatcos(angle,degrees) * INFIRMARY_LIE_HEAD + floatsin(angle,degrees) * INFIRMARY_LIE_OPEN, Float:y = s_InfirmaryBeds[bed][1] + floatsin(angle,degrees) * INFIRMARY_LIE_HEAD - floatcos(angle,degrees) * INFIRMARY_LIE_OPEN, Float:z = s_InfirmaryBeds[bed][2] + INFIRMARY_LIE_Z;
	SetPlayerPos(playerid,x,y,z);
	Util_RefreshTeleport(playerid,x,y,z,0,0,1500);
	SetPlayerFacingAngle(playerid,angle + INFIRMARY_LIE_ANGLE);
	ApplyAnimation(playerid,INFIRMARY_LIE_LIB,INFIRMARY_LIE_ANIM,4.1,false,false,false,false,0,SYNC_ALL);
	Wounds_SetRestBonus(playerid,INFIRMARY_REST_BONUS);
	Buff_Set(playerid,INFIRMARY_BUFF_KEY,"Infirmary bed","Your wounds heal twice as fast while you lie here. After 10 minutes of rest, your illness eases too.");
	Infirmary_ShowLyingBox(playerid);
	return true;
}

stock Infirmary_GetUp(playerid,bool:isQuiet = false)
{
	new bed = Infirmary_GetBed(playerid);

	if (bed == -1)
	{
		return;
	}

	s_InfirmaryBed[playerid] = -1;
	s_InfirmaryBedPatient[bed] = INVALID_PLAYER_ID;
	s_InfirmaryLyingRites[playerid] = false;
	Wounds_SetRestBonus(playerid,0);
	Buff_Clear(playerid,INFIRMARY_BUFF_KEY);

	if (s_InfirmaryLyingInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_InfirmaryLyingInfobox[playerid]);
	}

	s_InfirmaryLyingInfobox[playerid] = 0;

	if (isQuiet || !Session_IsPlaying(playerid))
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Infirmary_BedsidePos(bed,x,y,z,a);
	ClearAnimations(playerid,SYNC_ALL);
	SetPlayerPos(playerid,x,y,z);
	SetPlayerFacingAngle(playerid,a + 180.0);
}

stock Infirmary_OnLastRitesDone(playerid,const priest[])
{
	if (!IsPlayerConnected(playerid) || !Session_HasCharacter(playerid))
	{
		return;
	}

	Lineage_SetLastRites(playerid,true);

	for (new i = 0;i < Ailment_GetCount(playerid);i++)
	{
		Ailment_Treat(playerid,Ailment_GetAt(playerid,i),1);
	}

	Gui_Notify(playerid,"You've received the last rites. If you die now, you die absolved, and the prayer over you eases your illness today.");

	if (Infirmary_IsLying(playerid))
	{
		Infirmary_ShowLyingBox(playerid);
	}

	Log_Info("faith","last rites for player %d given by %s",playerid,priest);
}

stock Infirmary_PlaceBeds()
{
	for (new bed = 0;bed < sizeof(s_InfirmaryBeds);bed++)
	{
		s_InfirmaryBedPatient[bed] = INVALID_PLAYER_ID;
		s_InfirmaryBedObjects[bed] = CreateDynamicObject(FAITH_MODEL_BED,s_InfirmaryBeds[bed][0],s_InfirmaryBeds[bed][1],s_InfirmaryBeds[bed][2],0.0,0.0,s_InfirmaryBeds[bed][3],0,0,-1,INFIRMARY_RANGE_BED_OBJECT,INFIRMARY_RANGE_BED_OBJECT);
	}
}

stock Infirmary_CountBedObjects()
{
	new count = 0;

	for (new bed = 0;bed < sizeof(s_InfirmaryBeds);bed++)
	{
		if (IsValidDynamicObject(s_InfirmaryBedObjects[bed]))
		{
			count++;
		}
	}

	return count;
}

static Infirmary_KeepLying(playerid)
{
	new lib[16], name[24];
	GetAnimationName(GetPlayerAnimationIndex(playerid),lib,sizeof(lib),name,sizeof(name));

	if (!strcmp(name,INFIRMARY_LIE_ANIM,true))
	{
		return;
	}

	ApplyAnimation(playerid,INFIRMARY_LIE_LIB,INFIRMARY_LIE_ANIM,4.1,false,false,false,false,0,SYNC_ALL);
}

static Infirmary_Tick(playerid)
{
	new bed = Infirmary_GetBed(playerid);

	if (bed == -1)
	{
		return;
	}

	if (!Session_IsPlaying(playerid) || Combat_IsStruckDown(playerid) || !IsPlayerInRangeOfPoint(playerid,INFIRMARY_BED_STRAY,s_InfirmaryBeds[bed][0],s_InfirmaryBeds[bed][1],s_InfirmaryBeds[bed][2] + INFIRMARY_LIE_Z))
	{
		Infirmary_GetUp(playerid,true);
		return;
	}

	Infirmary_KeepLying(playerid);

	if (++s_InfirmaryRest[playerid] == INFIRMARY_REST_SECONDS)
	{
		Ailment_MarkRested(playerid);

		if (Ailment_GetCount(playerid) > 0)
		{
			Gui_Notify(playerid,"You've rested long enough today. Your illness eases at the turn of the day.");
		}
	}
}

forward Infirmary_OnTended(healerid,patientid,action);

public Infirmary_OnTended(healerid,patientid,action)
{
	return 1;
}

forward bool:Infirmary_PromptContext(playerid);

public bool:Infirmary_PromptContext(playerid)
{
	return s_InfirmaryPrompt[playerid] != -1 && !Infirmary_IsLying(playerid) && !Combat_IsInMode(playerid);
}

forward bool:Infirmary_LyingContext(playerid);

public bool:Infirmary_LyingContext(playerid)
{
	return Infirmary_IsLying(playerid) && !Faith_IsRiteWaiting(playerid);
}

forward bool:Faith_BusyCheck(playerid);

public bool:Faith_BusyCheck(playerid)
{
	return Faith_IsPraying(playerid) || Infirmary_IsLying(playerid) || (Faith_IsServiceRunning() && Faith_HasKnelt(playerid));
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_InfirmaryBed[playerid] = -1;
	s_InfirmaryRest[playerid] = 0;
	s_InfirmaryPrompt[playerid] = -1;
	s_InfirmaryPromptInfobox[playerid] = 0;
	s_InfirmaryLyingInfobox[playerid] = 0;
	s_InfirmaryLyingRites[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Infirmary_GetUp(playerid,true);
	s_InfirmaryPrompt[playerid] = -1;
	s_InfirmaryPromptInfobox[playerid] = 0;
}

hook Character_OnUnloaded(playerid)
{
	Infirmary_GetUp(playerid,true);
	s_InfirmaryRest[playerid] = 0;
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid, reason

	Infirmary_GetUp(playerid,true);
}

hook Combat_OnStruckDown(playerid)
{
	Infirmary_GetUp(playerid,true);
}

hook Combat_OnHit(attackerid,targetid,weapon,Float:damage)
{
	#pragma unused attackerid, weapon, damage

	Infirmary_GetUp(targetid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		Infirmary_GetUp(playerid,true);
	}
}

hook Tick_OnPlayerSecond(playerid)
{
	Infirmary_Tick(playerid);
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year

	foreach (new i : Player)
	{
		s_InfirmaryRest[i] = 0;
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (Infirmary_IsLying(playerid))
	{
		if ((newkeys & KEY_NO) && !(oldkeys & KEY_NO))
		{
			Infirmary_GetUp(playerid);
		}
		else if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && Faith_RitePlayer() != playerid && s_InfirmaryLyingRites[playerid])
		{
			Infirmary_AskLastRites(playerid);
		}

		return;
	}

	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_InfirmaryPrompt[playerid] == -1 || Infobox_IsPromptBlocked(playerid,s_InfirmaryPromptInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	if (s_InfirmaryPrompt[playerid] >= INFIRMARY_PROMPT_TEND)
	{
		SetTimerEx("InfirmaryGui_TendDeferred",0,false,"ddd",playerid,s_InfirmaryPrompt[playerid] - INFIRMARY_PROMPT_TEND,Account_GetToken(playerid));
		return;
	}

	Infirmary_LieDown(playerid,s_InfirmaryPrompt[playerid]);
}

hook Clergy_OnRankChanged(playerid,from,to)
{
	#pragma unused from

	if (E_CLERGY_RANK:to != CLERGY_LAY || !Session_HasCharacter(playerid))
	{
		return;
	}

	new bool:isGiven = false;

	if (Inventory_Count(playerid,ITEM_KIND_TOOL,ITEM_NEEDLE) <= 0 && Inventory_Give(playerid,ITEM_KIND_TOOL,ITEM_NEEDLE,1))
	{
		isGiven = true;
	}

	if (Inventory_Count(playerid,ITEM_KIND_TOOL,ITEM_LANCET) <= 0 && Inventory_Give(playerid,ITEM_KIND_TOOL,ITEM_LANCET,1))
	{
		isGiven = true;
	}

	if (isGiven)
	{
		Gui_Notify(playerid,"The infirmarian gives you a needle and a lancet for the infirmary. You'll need thread to stitch and splints to set bones.");
	}
}
