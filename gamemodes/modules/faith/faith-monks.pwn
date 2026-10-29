#define MONKS_SETTLE_MS (2200)
#define MONKS_STEP_MS (2600)
#define MONKS_AFTER_MS (1800)
#define MONKS_WALK_MS (14000)
#define MONKS_WALK_POLL_MS (250)
#define MONKS_HOME_MS (20000)
#define MONKS_WALK_SPEED (1.3)
#define MONKS_PANEL_WIDTH (260.0)
#define MONKS_VALUE_SHARE (0.62)
#define MONKS_PICK_PAY (1)
#define MONKS_LINE_LEN (176)
#define MONKS_TEXT_LEN (300)
#define MONKS_STEP_SLOTS (5)
#define MONKS_FREE_FIRST_SECONDS (10)
#define MONKS_FREE_STEP_SECONDS (60)
#define MONKS_FREE_VISIT_MS (8000)
#define MONKS_FEE_EXAMINE (3)
#define MONKS_FEE_BANDAGE (3)
#define MONKS_FEE_CLEAN (2)
#define MONKS_FEE_SPLINT (4)
#define MONKS_FEE_REMEDY (6)
#define MONKS_FEE_LANCE (6)
#define MONKS_FEE_STITCH (6)
#define MONKS_FEE_SET (8)

enum
{
	MONK_HUGH,
	MONK_LAY,
	MONK_COUNT,
}

enum
{
	MONK_STEP_EXAMINE,
	MONK_STEP_BANDAGE,
	MONK_STEP_CLEAN,
	MONK_STEP_SPLINT,
	MONK_STEP_REMEDY,
	MONK_STEP_LANCE,
	MONK_STEP_STITCH,
	MONK_STEP_SET,
	MONK_STEP_COUNT,
}

enum
{
	MONK_OK,
	MONK_NOTHING,
	MONK_HEALER,
	MONK_BUSY,
	MONK_NO_BED,
	MONK_UNFIT,
	MONK_SHORT,
	MONK_ABSENT,
}

enum
{
	MONK_PHASE_IDLE,
	MONK_PHASE_SERVING,
	MONK_PHASE_HOMING,
	MONK_PHASE_FREE,
}

static const s_MonkKeys[MONK_COUNT][16] = {"infirmary:monk", "infirmary:lay"};
static const s_MonkNames[MONK_COUNT][32] = {"Brother Hugh", "Brother Osmund"};
static const s_MonkTitles[MONK_COUNT][24] = {"Infirmary monk", "Infirmary lay brother"};
static const s_MonkSkins[MONK_COUNT] = {20071, 20072};
static const Float:s_MonkPosts[MONK_COUNT][4] = {{713.6, -3637.2, 18.49, 90.0}, {704.4, -3637.2, 18.49, 270.0}};

static const s_MonkSteps[MONK_COUNT][MONKS_STEP_SLOTS] = {
	{MONK_STEP_EXAMINE, MONK_STEP_BANDAGE, MONK_STEP_CLEAN, MONK_STEP_SPLINT, MONK_STEP_REMEDY},
	{MONK_STEP_LANCE, MONK_STEP_STITCH, MONK_STEP_SET, -1, -1}
};

static const s_MonkFees[MONK_STEP_COUNT] = {MONKS_FEE_EXAMINE, MONKS_FEE_BANDAGE, MONKS_FEE_CLEAN, MONKS_FEE_SPLINT, MONKS_FEE_REMEDY, MONKS_FEE_LANCE, MONKS_FEE_STITCH, MONKS_FEE_SET};

static const s_MonkLabelOne[MONK_STEP_COUNT][28] = {
	"Look you over",
	"Bind a bleeding wound",
	"Wash a wound",
	"Splint a broken bone",
	"A herb draught",
	"Lance a festering wound",
	"Stitch an open wound",
	"Set a broken bone"
};

static const s_MonkLabelMany[MONK_STEP_COUNT][28] = {
	"Look you over",
	"Bind %d bleeding wounds",
	"Wash %d wounds",
	"Splint %d broken bones",
	"%d herb draughts",
	"Lance %d festering wounds",
	"Stitch %d open wounds",
	"Set %d broken bones"
};

static s_MonkActor[MONK_COUNT] = {-1, ...};
static s_MonkPlayer[MONK_COUNT] = {INVALID_PLAYER_ID, ...};
static s_MonkPhase[MONK_COUNT];
static s_MonkHomeToken[MONK_COUNT];
static s_MonkFreeWait[MAX_PLAYERS];
static bool:s_MonkFreeSeen[MAX_PLAYERS];
static s_MonkFreeVisit;
static s_MonksSettleMs = MONKS_SETTLE_MS;
static s_MonksStepMs = MONKS_STEP_MS;
static s_MonksAfterMs = MONKS_AFTER_MS;

stock Monks_GetActor(monk)
{
	return monk >= 0 && monk < MONK_COUNT ? s_MonkActor[monk] : -1;
}

stock Monks_GetPlayer(monk)
{
	return monk >= 0 && monk < MONK_COUNT ? s_MonkPlayer[monk] : INVALID_PLAYER_ID;
}

stock Monks_GetFee(step)
{
	return step >= 0 && step < MONK_STEP_COUNT ? s_MonkFees[step] : 0;
}

stock Monks_FindByActor(index)
{
	for (new monk = 0;monk < MONK_COUNT;monk++)
	{
		if (index != -1 && s_MonkActor[monk] == index)
		{
			return monk;
		}
	}

	return -1;
}

stock Monks_SetPace(settleMs,stepMs,afterMs)
{
	s_MonksSettleMs = settleMs;
	s_MonksStepMs = stepMs;
	s_MonksAfterMs = afterMs;
}

stock Monks_Place()
{
	for (new monk = 0;monk < MONK_COUNT;monk++)
	{
		new index = Actors_Register(s_MonkKeys[monk],ACTOR_ROLE_HEALER,ACTOR_KIND_STATIC,0,s_MonkSkins[monk],s_MonkNames[monk],s_MonkTitles[monk],0,-1,false);

		if (index == -1)
		{
			continue;
		}

		s_MonkActor[monk] = index;
		s_MonkPlayer[monk] = INVALID_PLAYER_ID;
		s_MonkPhase[monk] = MONK_PHASE_IDLE;
		Actors_SetInvulnerable(index,true);
		Actors_SetPlace(index,s_MonkPosts[monk][0],s_MonkPosts[monk][1],s_MonkPosts[monk][2],s_MonkPosts[monk][3]);
		Actors_Place(index);
	}
}

stock Monks_BuildPlan(playerid,monk,counts[MONK_STEP_COUNT])
{
	for (new step = 0;step < MONK_STEP_COUNT;step++)
	{
		counts[step] = 0;
	}

	if (!Session_IsPlaying(playerid) || monk < 0 || monk >= MONK_COUNT)
	{
		return 0;
	}

	if (monk == MONK_HUGH)
	{
		if (Infirmary_CountUndiagnosed(playerid) > 0)
		{
			counts[MONK_STEP_EXAMINE] = 1;
		}

		for (new i = 0;i < Ailment_GetCount(playerid);i++)
		{
			if (!Ailment_IsTreated(playerid,Ailment_GetAt(playerid,i)))
			{
				counts[MONK_STEP_REMEDY]++;
			}
		}
	}

	for (new i = 0;i < Wounds_Count(playerid);i++)
	{
		new part, kind, severity, flags, Float:bleed;

		if (!Wounds_GetAt(playerid,i,part,kind,severity,flags,bleed))
		{
			continue;
		}

		if (monk == MONK_HUGH)
		{
			if (Wounds_Needs(kind,severity,flags,WOUND_TREAT_BANDAGE))
			{
				counts[MONK_STEP_BANDAGE]++;
			}

			if (Wounds_Needs(kind,severity,flags,WOUND_TREAT_CLEAN))
			{
				counts[MONK_STEP_CLEAN]++;
			}

			if (Wounds_Needs(kind,severity,flags,WOUND_TREAT_SPLINT))
			{
				counts[MONK_STEP_SPLINT]++;
			}

			continue;
		}

		if (Wounds_Needs(kind,severity,flags,WOUND_TREAT_LANCE))
		{
			counts[MONK_STEP_LANCE]++;
		}

		if (Wounds_KindBleeds(kind) && severity >= WOUND_OPEN && !(flags & WOUND_FLAG_STITCHED))
		{
			counts[MONK_STEP_STITCH]++;
		}

		if (Wounds_Needs(kind,severity,flags,WOUND_TREAT_SET))
		{
			counts[MONK_STEP_SET]++;
		}
	}

	new total = 0;

	for (new step = 0;step < MONK_STEP_COUNT;step++)
	{
		total += counts[step] * s_MonkFees[step];
	}

	return total;
}

stock Monks_Check(playerid,monk,fee)
{
	if (monk < 0 || monk >= MONK_COUNT || !Actors_IsPlaced(s_MonkActor[monk]))
	{
		return MONK_ABSENT;
	}

	if (s_MonkPlayer[monk] != INVALID_PLAYER_ID || s_MonkPhase[monk] != MONK_PHASE_IDLE)
	{
		return MONK_BUSY;
	}

	if (fee <= 0)
	{
		return MONK_NOTHING;
	}

	if (Infirmary_IsHealerOnline(playerid))
	{
		return MONK_HEALER;
	}

	if (!Infirmary_CanLieDown(playerid))
	{
		return MONK_UNFIT;
	}

	new Float:x, Float:y, Float:z;
	Actors_GetPos(s_MonkActor[monk],x,y,z);

	if (Infirmary_FindFreeBedNear(x,y,z) == -1)
	{
		return MONK_NO_BED;
	}

	return Economy_Worth(playerid) < fee ? MONK_SHORT : MONK_OK;
}

static Monks_Explain(monk,status,dest[],size = sizeof(dest))
{
	switch (status)
	{
		case MONK_NOTHING:
		{
			if (monk == MONK_HUGH)
			{
				format(dest,size,"%s looks you over and finds nothing he can treat. Open wounds to stitch, bones to set and festering sores are the lay brother's work.",s_MonkNames[monk]);
			}
			else
			{
				format(dest,size,"%s looks you over and finds nothing he can treat. Bleeding wounds, splints and illness are for Brother Hugh.",s_MonkNames[monk]);
			}
		}
		case MONK_HEALER:
		{
			strcopy(dest,"A healer of the Church is on duty, so the brothers leave the sick to them. Ask them for help, or come back once they've gone.",size);
		}
		case MONK_BUSY:
		{
			format(dest,size,"%s is busy with another patient. Wait your turn, friend, and ask again.",s_MonkNames[monk]);
		}
		case MONK_NO_BED:
		{
			strcopy(dest,"Every bed in the infirmary is taken. Wait for one to be free, then ask again.",size);
		}
		case MONK_UNFIT:
		{
			strcopy(dest,"You can't lie down right now. Put your weapon away, get off your horse and get on your feet first.",size);
		}
		case MONK_SHORT:
		{
			strcopy(dest,"You haven't the coin for the whole treatment. Bring more, or ask the other brother for part of it.",size);
		}
		case MONK_ABSENT:
		{
			strcopy(dest,"He isn't here right now. Try again in a moment.",size);
		}
		default:
		{
			format(dest,size,"%s will tend you for a fee. You lie on a free bed, he comes to you and treats each wound in turn, and you pay before he starts.",s_MonkNames[monk]);
		}
	}
}

static Monks_AddRow(playerid,Float:x,Float:y,Float:width,const label[],const value[],labelColour = KIT_COLOUR_TEXT,valueColour = KIT_COLOUR_ACCENT)
{
	Kit_AddText(playerid,x,y,label,labelColour,KIT_TEXT_ROW);
	Kit_AddText(playerid,x + width * MONKS_VALUE_SHARE,y,value,valueColour,KIT_TEXT_ROW);
}

static Monks_StepLabel(step,count,dest[],size = sizeof(dest))
{
	if (count == 1)
	{
		strcopy(dest,s_MonkLabelOne[step],size);
		return;
	}

	format(dest,size,s_MonkLabelMany[step],count);
}

static Monks_Offer(playerid,monk)
{
	yield 1;

	if (!Session_IsPlaying(playerid) || monk < 0 || monk >= MONK_COUNT)
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), counts[MONK_STEP_COUNT], fee = Monks_BuildPlan(playerid,monk,counts), status = Monks_Check(playerid,monk,fee), intro[MONKS_TEXT_LEN], rows = 0, Float:x, Float:y, Float:width;
	Monks_Explain(monk,status == MONK_SHORT ? MONK_OK : status,intro);

	for (new step = 0;step < MONK_STEP_COUNT;step++)
	{
		if (counts[step] > 0)
		{
			rows++;
		}
	}

	new bool:hasPay = status == MONK_OK, Float:textHeight = Gui_TextHeight(intro,MONKS_PANEL_WIDTH), Float:content = textHeight + 4.0 + float(rows) * KIT_ROW + (fee > 0 ? KIT_ROW + 2.0 : 0.0) + (hasPay || status == MONK_SHORT ? KIT_ROW + 2.0 : 0.0) + 6.0 + KIT_ROW + 12.0;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,s_MonkNames[monk]);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,MONKS_PANEL_WIDTH,content,s_MonkNames[monk],x,y,width);
	Kit_AddText(playerid,x,y,intro,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new Float:rowY = y + textHeight + 4.0;

	for (new slot = 0;slot < MONKS_STEP_SLOTS;slot++)
	{
		new step = s_MonkSteps[monk][slot];

		if (step == -1 || counts[step] <= 0)
		{
			continue;
		}

		new label[32], price[ECONOMY_FORMAT_LEN];
		Monks_StepLabel(step,counts[step],label);
		Economy_Format(counts[step] * s_MonkFees[step],price);
		Monks_AddRow(playerid,x,rowY,width,label,price);
		rowY += KIT_ROW;
	}

	if (fee > 0)
	{
		new total[ECONOMY_FORMAT_LEN];
		Economy_Format(fee,total);
		Monks_AddRow(playerid,x,rowY + 2.0,width,"In all",total,KIT_COLOUR_ACCENT,KIT_COLOUR_ACCENT);
		rowY += KIT_ROW + 2.0;
	}

	if (hasPay)
	{
		Kit_AddChoice(playerid,x,rowY + 2.0,width,"Pay and lie down on a bed",MONKS_PICK_PAY,KIT_COLOUR_GOOD);
		rowY += KIT_ROW + 2.0;
	}
	else if (status == MONK_SHORT)
	{
		new have[ECONOMY_FORMAT_LEN];
		Economy_Format(Economy_Worth(playerid),have);
		Monks_AddRow(playerid,x,rowY + 2.0,width,"You carry",have,KIT_COLOUR_BAD,KIT_COLOUR_BAD);
		rowY += KIT_ROW + 2.0;
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,rowY + 6.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick != MONKS_PICK_PAY)
	{
		return;
	}

	SetTimerEx("Monks_PayDeferred",0,false,"dddd",playerid,monk,fee,Account_GetToken(playerid));
}

static bool:Monks_Gone(playerid,token)
{
	return !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Session_IsPlaying(playerid) || !Infirmary_IsLying(playerid);
}

static Monks_Release(monk)
{
	s_MonkPlayer[monk] = INVALID_PLAYER_ID;
	s_MonkPhase[monk] = MONK_PHASE_IDLE;
	Actors_SetOpen(s_MonkActor[monk],true);
}

static Monks_SendHome(monk)
{
	new actor = s_MonkActor[monk];
	Actors_SetAnim(actor,"","");
	s_MonkPhase[monk] = MONK_PHASE_HOMING;
	s_MonkHomeToken[monk]++;
	SetTimerEx("Monks_HomeCheck",MONKS_HOME_MS,false,"dd",monk,s_MonkHomeToken[monk]);
	Actors_WalkTo(actor,s_MonkPosts[monk][0],s_MonkPosts[monk][1],s_MonkPosts[monk][2],s_MonkPosts[monk][3],MONKS_WALK_SPEED,true);
}

static bool:Monks_FindTarget(playerid,step,&target)
{
	switch (step)
	{
		case MONK_STEP_EXAMINE:
		{
			target = 0;
			return Infirmary_CountUndiagnosed(playerid) > 0;
		}
		case MONK_STEP_REMEDY:
		{
			target = Infirmary_FindRemedyTarget(playerid);
			return target != -1;
		}
	}

	new treatment = WOUND_TREAT_BANDAGE;

	switch (step)
	{
		case MONK_STEP_CLEAN: treatment = WOUND_TREAT_CLEAN;
		case MONK_STEP_SPLINT: treatment = WOUND_TREAT_SPLINT;
		case MONK_STEP_LANCE: treatment = WOUND_TREAT_LANCE;
		case MONK_STEP_STITCH: treatment = WOUND_TREAT_STITCH;
		case MONK_STEP_SET: treatment = WOUND_TREAT_SET;
	}

	target = Wounds_FindForTreatment(playerid,treatment);
	return target != -1;
}

static Monks_WoundPart(playerid,index,dest[],size = sizeof(dest))
{
	new part, kind, severity, flags, Float:bleed;

	if (!Wounds_GetAt(playerid,index,part,kind,severity,flags,bleed))
	{
		strcopy(dest,"body",size);
		return;
	}

	Wounds_PartName(part,dest,size);
	dest[0] = tolower(dest[0]);
}

static Monks_StepBegin(playerid,monk,step)
{
	new target, actor = s_MonkActor[monk], who[16], part[12], line[MONKS_LINE_LEN];

	if (!Monks_FindTarget(playerid,step,target))
	{
		return false;
	}

	Nametag_Token(playerid,who);

	if (step != MONK_STEP_EXAMINE && step != MONK_STEP_REMEDY)
	{
		Monks_WoundPart(playerid,target,part);
	}

	switch (step)
	{
		case MONK_STEP_EXAMINE:
		{
			format(line,sizeof(line),"lays a hand on %s's brow and counts the pulse at the wrist.",who);
		}
		case MONK_STEP_REMEDY:
		{
			format(line,sizeof(line),"pours a herb draught into a cup and holds it to %s's lips.",who);
		}
		case MONK_STEP_BANDAGE:
		{
			format(line,sizeof(line),"winds a strip of clean linen around the wound on %s's %s.",who,part);
		}
		case MONK_STEP_CLEAN:
		{
			format(line,sizeof(line),"washes the wound on %s's %s from his flask.",who,part);
		}
		case MONK_STEP_SPLINT:
		{
			format(line,sizeof(line),"lays two straight sticks along %s's %s and ties them fast.",who,part);
		}
		case MONK_STEP_STITCH:
		{
			format(line,sizeof(line),"threads a bone needle and stitches the wound on %s's %s.",who,part);
		}
		case MONK_STEP_SET:
		{
			format(line,sizeof(line),"takes %s's %s in both hands and sets the bone with one sharp pull.",who,part);
		}
		default:
		{
			format(line,sizeof(line),"lances the festering wound on %s's %s and washes the poison out.",who,part);
		}
	}

	if (step == MONK_STEP_EXAMINE || step == MONK_STEP_REMEDY)
	{
		Actors_SetAnim(actor,"MEDIC","CPR",true);
	}
	else
	{
		Actors_SetAnim(actor,"BOMBER","BOM_Plant",true);
	}

	Actors_Do(actor,line);
	return true;
}

static Monks_StepEnd(playerid,monk,step)
{
	new target, actor = s_MonkActor[monk], line[MONKS_LINE_LEN];

	if (!Monks_FindTarget(playerid,step,target))
	{
		return false;
	}

	switch (step)
	{
		case MONK_STEP_EXAMINE:
		{
			new list[INFIRMARY_LIST_LEN], count = Ailment_GetCount(playerid);

			for (new i = 0;i < count;i++)
			{
				Ailment_Diagnose(playerid,Ailment_GetAt(playerid,i));
			}

			Infirmary_ListAilments(playerid,list);
			format(line,sizeof(line),"You suffer from %s. Your Health tab names %s now.",list,count == 1 ? ("it") : ("them"));
		}
		case MONK_STEP_REMEDY:
		{
			new name[AILMENT_NAME_LEN];
			Ailment_GetName(target,name);
			name[0] = tolower(name[0]);
			Ailment_Treat(playerid,target,1);
			format(line,sizeof(line),"Drink it all. It eases the %s a little. One draught a day is all it can do.",name);
		}
		case MONK_STEP_BANDAGE:
		{
			Wounds_Treat(playerid,target,WOUND_TREAT_BANDAGE);
			strcopy(line,"That stops the bleeding. Keep the cloth dry.");
		}
		case MONK_STEP_CLEAN:
		{
			Wounds_Treat(playerid,target,WOUND_TREAT_CLEAN);
			strcopy(line,"A clean wound festers less often.");
		}
		case MONK_STEP_SPLINT:
		{
			Wounds_Treat(playerid,target,WOUND_TREAT_SPLINT);
			strcopy(line,"The bone will knit straight now. Only a lay brother can set it so it heals faster.");
		}
		case MONK_STEP_STITCH:
		{
			Wounds_Treat(playerid,target,WOUND_TREAT_STITCH);
			strcopy(line,"Stitched, it heals in half the time. Don't pick at it.");
		}
		case MONK_STEP_SET:
		{
			Wounds_Treat(playerid,target,WOUND_TREAT_SET);
			strcopy(line,"There. It heals straight now, and in half the time.");
		}
		default:
		{
			Wounds_Treat(playerid,target,WOUND_TREAT_LANCE);
			strcopy(line,"The rot is out. Now it can heal.");
		}
	}

	Actors_Say(actor,line);
	return true;
}

static Monks_Begin(playerid,monk,quoted,token)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Session_IsPlaying(playerid))
	{
		return;
	}

	new counts[MONK_STEP_COUNT], fee = Monks_BuildPlan(playerid,monk,counts), status = Monks_Check(playerid,monk,fee), text[MONKS_TEXT_LEN];

	if (status != MONK_OK || fee != quoted)
	{
		if (status == MONK_OK)
		{
			strcopy(text,"Your wounds changed while you thought about it. Ask again to hear the new price.");
		}
		else
		{
			Monks_Explain(monk,status,text);
		}

		Gui_Notify(playerid,text);
		return;
	}

	new actor = s_MonkActor[monk], characterid = Character_GetId(playerid), Float:mx, Float:my, Float:mz, Float:bx, Float:by, Float:bz, Float:ba, money[ECONOMY_FORMAT_LEN];
	Actors_GetPos(actor,mx,my,mz);
	new bed = Infirmary_FindFreeBedNear(mx,my,mz);

	if (Economy_Pay(playerid,fee,INVALID_CONTAINER_ID,"infirmary") != PAY_OK)
	{
		Gui_Notify(playerid,"You couldn't pay. Your coin is still with you.");
		return;
	}

	Economy_Format(fee,money);
	format(text,sizeof(text),"You pay %s to %s.",money,s_MonkNames[monk]);
	Gui_Notify(playerid,text);
	s_MonkPlayer[monk] = playerid;
	s_MonkPhase[monk] = MONK_PHASE_SERVING;
	Actors_SetOpen(actor,false);
	Actors_Say(actor,monk == MONK_HUGH ? ("Lie down on that bed, friend, and I'll come to you.") : ("Lie down on that bed, friend. Hold still and this will soon be over."));

	if (!Infirmary_LieDown(playerid,bed))
	{
		Economy_GiveOrClaim(playerid,characterid,fee,"infirmary refund");
		Gui_Notify(playerid,"You couldn't lie down, so your coin was given back.");
		Monks_Release(monk);
		return;
	}

	new remaining = fee, bool:isGone = false;
	await task_ms(s_MonksSettleMs);

	if (Monks_Gone(playerid,token))
	{
		isGone = true;
	}

	if (!isGone)
	{
		Infirmary_BedsidePos(bed,bx,by,bz,ba);
		Actors_WalkTo(actor,bx,by,bz,ba,MONKS_WALK_SPEED,true);

		for (new waited = 0;waited < MONKS_WALK_MS && Actors_IsWalking(actor);waited += MONKS_WALK_POLL_MS)
		{
			await task_ms(MONKS_WALK_POLL_MS);

			if (Monks_Gone(playerid,token))
			{
				isGone = true;
				break;
			}
		}

		if (!isGone && Actors_IsWalking(actor))
		{
			Actors_MoveTo(actor,bx,by,bz,ba);
		}
	}

	if (!isGone)
	{
		Actors_Do(actor,monk == MONK_HUGH ? ("kneels beside the bed and rolls up his sleeves.") : ("comes over from the wall, wiping his hands on his apron."));
		await task_ms(s_MonksSettleMs);
		isGone = Monks_Gone(playerid,token);
	}

	for (new slot = 0;slot < MONKS_STEP_SLOTS && !isGone && s_MonkSteps[monk][slot] != -1;slot++)
	{
		new step = s_MonkSteps[monk][slot];

		for (new n = 0;n < counts[step] && !isGone;n++)
		{
			if (!Monks_StepBegin(playerid,monk,step))
			{
				Economy_GiveOrClaim(playerid,characterid,s_MonkFees[step],"infirmary refund");
				remaining -= s_MonkFees[step];
				continue;
			}

			await task_ms(s_MonksStepMs);

			if (Monks_Gone(playerid,token))
			{
				isGone = true;
				break;
			}

			if (!Monks_StepEnd(playerid,monk,step))
			{
				Economy_GiveOrClaim(playerid,characterid,s_MonkFees[step],"infirmary refund");
			}

			remaining -= s_MonkFees[step];
			await task_ms(s_MonksAfterMs);
			isGone = Monks_Gone(playerid,token);
		}
	}

	if (!isGone)
	{
		Actors_SetAnim(actor,"","");
		Actors_Do(actor,"gets to his feet and wipes his hands.");
		Actors_Say(actor,"That's all I can do. Rest here a while, friend, and press N when you want to get up.");
		await task_ms(s_MonksAfterMs);
	}

	if (remaining > 0)
	{
		Economy_GiveOrClaim(playerid,characterid,remaining,"infirmary refund");

		if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_IsPlaying(playerid))
		{
			Economy_Format(remaining,money);
			format(text,sizeof(text),"You left the bed before %s was done. The treatment he didn't give was paid back: %s.",s_MonkNames[monk],money);
			Gui_Notify(playerid,text);
		}
	}

	Monks_SendHome(monk);
}

static Monks_FreeSays(playerid,const text[])
{
	new line[144];
	format(line,sizeof(line),"%s %s",s_MonkNames[MONK_HUGH],text);
	Gui_Notify(playerid,line);
}

static Monks_FreeVisit(playerid)
{
	new bed = Infirmary_GetBed(playerid), actor = s_MonkActor[MONK_HUGH];

	if (bed == -1 || !Actors_IsPlaced(actor) || Actors_IsTalkingTo(actor) || (s_MonkPhase[MONK_HUGH] != MONK_PHASE_IDLE && s_MonkPhase[MONK_HUGH] != MONK_PHASE_FREE))
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Infirmary_BedsidePos(bed,x,y,z,a);
	s_MonkPhase[MONK_HUGH] = MONK_PHASE_FREE;
	Actors_MoveTo(actor,x,y,z,a);
	Actors_SetAnim(actor,"MEDIC","CPR",true);
	SetTimerEx("Monks_FreeReturn",MONKS_FREE_VISIT_MS,false,"d",++s_MonkFreeVisit);
}

stock bool:Monks_FreeStep(playerid)
{
	if (!Infirmary_IsLying(playerid) || (s_MonkPhase[MONK_HUGH] != MONK_PHASE_IDLE && s_MonkPhase[MONK_HUGH] != MONK_PHASE_FREE) || !Actors_IsPlaced(s_MonkActor[MONK_HUGH]))
	{
		return false;
	}

	new index = Wounds_FindForTreatment(playerid,WOUND_TREAT_BANDAGE), part, kind, severity, flags, Float:bleed, partName[12], text[112];

	if (index != -1 && Wounds_GetAt(playerid,index,part,kind,severity,flags,bleed) && bleed > 0.0)
	{
		Wounds_PartName(part,partName);
		partName[0] = tolower(partName[0]);
		Wounds_Treat(playerid,index,WOUND_TREAT_BANDAGE);
		Monks_FreeVisit(playerid);
		format(text,sizeof(text),"binds the wound on your %s. The bleeding stops.",partName);
		Monks_FreeSays(playerid,text);
		return true;
	}

	index = Wounds_FindForTreatment(playerid,WOUND_TREAT_SPLINT);

	if (index != -1 && Wounds_GetAt(playerid,index,part,kind,severity,flags,bleed))
	{
		Wounds_PartName(part,partName);
		partName[0] = tolower(partName[0]);
		Wounds_Treat(playerid,index,WOUND_TREAT_SPLINT);
		Monks_FreeVisit(playerid);
		format(text,sizeof(text),"splints your %s so it heals straight. Only a lay brother sets a bone to heal faster.",partName);
		Monks_FreeSays(playerid,text);
		return true;
	}

	if (Infirmary_CountUndiagnosed(playerid) > 0)
	{
		new list[INFIRMARY_LIST_LEN];

		for (new i = 0;i < Ailment_GetCount(playerid);i++)
		{
			Ailment_Diagnose(playerid,Ailment_GetAt(playerid,i));
		}

		Infirmary_ListAilments(playerid,list);
		Monks_FreeVisit(playerid);
		format(text,sizeof(text),"looks you over. You suffer from %s. Your Health tab names %s now.",list,Ailment_GetCount(playerid) == 1 ? ("it") : ("them"));
		Monks_FreeSays(playerid,text);
		return true;
	}

	new ailment = Infirmary_FindRemedyTarget(playerid);

	if (ailment != -1)
	{
		new name[AILMENT_NAME_LEN];
		Ailment_GetName(ailment,name);
		name[0] = tolower(name[0]);
		Ailment_Treat(playerid,ailment,1);
		Monks_FreeVisit(playerid);
		format(text,sizeof(text),"gives you a plain herb draught for the %s. It eases the illness a little.",name);
		Monks_FreeSays(playerid,text);
		return true;
	}

	return false;
}

static Monks_FreeTick(playerid)
{
	if (!Infirmary_IsLying(playerid))
	{
		s_MonkFreeSeen[playerid] = false;
		s_MonkFreeWait[playerid] = 0;
		return;
	}

	if (!s_MonkFreeSeen[playerid])
	{
		s_MonkFreeSeen[playerid] = true;
		s_MonkFreeWait[playerid] = MONKS_FREE_FIRST_SECONDS;
	}

	if (Infirmary_IsHealerOnline() || Faith_IsRiteRunning() || s_MonkPlayer[MONK_HUGH] == playerid || s_MonkPlayer[MONK_LAY] == playerid)
	{
		return;
	}

	if (--s_MonkFreeWait[playerid] <= 0)
	{
		s_MonkFreeWait[playerid] = MONKS_FREE_STEP_SECONDS;
		Monks_FreeStep(playerid);
	}
}

forward Monks_AskDeferred(playerid,index,monk);

public Monks_AskDeferred(playerid,index,monk)
{
	if (Session_IsPlaying(playerid) && Actors_IsOpen(index) && Monks_FindByActor(index) == monk && !Gui_IsBusy(playerid))
	{
		Monks_Offer(playerid,monk);
	}

	return 1;
}

forward Monks_FreeAskDeferred(playerid,index,monk);

public Monks_FreeAskDeferred(playerid,index,monk)
{
	if (Session_IsPlaying(playerid) && Actors_IsOpen(index) && Monks_FindByActor(index) == monk && monk == MONK_HUGH)
	{
		Actors_Say(index,"Lie down on that empty bed by the wall and rest, friend. I'll come by when I can.");
		Gui_Notify(playerid,"Walk to a free bed in the infirmary and press Y to lie down. Brother Hugh looks in on the sick now and then, and he asks nothing for it.");
	}

	return 1;
}

forward Monks_FreeReturn(visit);

public Monks_FreeReturn(visit)
{
	new actor = s_MonkActor[MONK_HUGH];

	if (visit != s_MonkFreeVisit || s_MonkPhase[MONK_HUGH] != MONK_PHASE_FREE || !Actors_IsPlaced(actor))
	{
		return 1;
	}

	if (Actors_IsTalkingTo(actor))
	{
		SetTimerEx("Monks_FreeReturn",500,false,"d",visit);
		return 1;
	}

	Actors_SetAnim(actor,"","");
	Actors_MoveTo(actor,s_MonkPosts[MONK_HUGH][0],s_MonkPosts[MONK_HUGH][1],s_MonkPosts[MONK_HUGH][2],s_MonkPosts[MONK_HUGH][3]);
	s_MonkPhase[MONK_HUGH] = MONK_PHASE_IDLE;
	return 1;
}

forward Monks_PayDeferred(playerid,monk,fee,token);

public Monks_PayDeferred(playerid,monk,fee,token)
{
	Monks_Begin(playerid,monk,fee,token);
	return 1;
}

forward Monks_HomeCheck(monk,token);

public Monks_HomeCheck(monk,token)
{
	if (monk < 0 || monk >= MONK_COUNT || s_MonkPhase[monk] != MONK_PHASE_HOMING || s_MonkHomeToken[monk] != token)
	{
		return 1;
	}

	Actors_MoveTo(s_MonkActor[monk],s_MonkPosts[monk][0],s_MonkPosts[monk][1],s_MonkPosts[monk][2],s_MonkPosts[monk][3]);
	Monks_Release(monk);
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	Monks_Place();
	new answer[HELP_ANSWER_LEN];
	format(answer,sizeof(answer),"~w~Press ~y~Y~w~ beside ~y~Brother Hugh~w~ or the ~y~lay brother~w~ in the infirmary and choose ~y~Ask to be treated~w~. You pay first, lie on a free bed, and he comes over and treats each wound in turn. Brother Hugh: look you over %d, bind a wound %d, wash a wound %d, splint a bone %d, a herb draught %d. The lay brother does the cutting: lance %d, stitch %d, set a bone %d. All in pfennig, each time, and only when no healer of the Church is on duty. Brother Hugh also gives slow, free care to anyone resting in a bed: ask him for it.",MONKS_FEE_EXAMINE,MONKS_FEE_BANDAGE,MONKS_FEE_CLEAN,MONKS_FEE_SPLINT,MONKS_FEE_REMEDY,MONKS_FEE_LANCE,MONKS_FEE_STITCH,MONKS_FEE_SET);
	Help_Register(HELP_SECTION_FAITH,"How do the monks treat me for a fee?",answer,true);
}

hook Actors_OnMenuBuild(playerid,index)
{
	new monk = Monks_FindByActor(index);

	if (monk != -1)
	{
		Actors_MenuAdd(playerid,"Ask to be treated","Monks_AskDeferred",monk);

		if (monk == MONK_HUGH)
		{
			Actors_MenuAdd(playerid,"Ask for the free care","Monks_FreeAskDeferred",monk);
		}
	}
}

hook Tick_OnPlayerSecond(playerid)
{
	Monks_FreeTick(playerid);
}

hook OnPlayerConnect(playerid)
{
	s_MonkFreeWait[playerid] = 0;
	s_MonkFreeSeen[playerid] = false;
}

hook Actors_OnArrived(index)
{
	new monk = Monks_FindByActor(index);

	if (monk != -1 && s_MonkPhase[monk] == MONK_PHASE_HOMING)
	{
		Monks_Release(monk);
	}
}
