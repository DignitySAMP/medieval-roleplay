#define AILMENT_NAME_LEN (24)
#define AILMENT_CUE_LEN (80)
#define AILMENT_MAX_STAGES (5)
#define AILMENT_MAX_ACTIVE (6)
#define AILMENT_SEVERITY_MAX (100)
#define AILMENT_SEVERITY_LETHAL (50)
#define AILMENT_SEVERITY_STEP (15)
#define AILMENT_CARE_RECEDE (4)
#define AILMENT_REST_CARE (2)
#define AILMENT_TREAT_SEVERITY (15)
#define AILMENT_WOUND_DAMAGE (15.0)
#define AILMENT_WOUND_INFECTS (60)
#define AILMENT_SPREAD_RANGE (3.0)
#define AILMENT_SPREAD_PERCENT (10)
#define AILMENT_TURNS_CHRONIC (0)

enum
{
	AILMENT_CHILLS = 0,
	AILMENT_FROSTBITE,
	AILMENT_HEATSTROKE,
	AILMENT_FLUX,
	AILMENT_STING,
	AILMENT_WOUND,
	AILMENT_BROKEN_BONE,
	AILMENT_DUST_LUNG,
	AILMENT_ALCOHOLISM,
	AILMENT_COLD,
	AILMENT_FEVER,
	AILMENT_AGUE,
	AILMENT_ROTTEN_TEETH,
	AILMENT_GANGRENE,
	AILMENT_SCURVY,
	AILMENT_PLAGUE,
	AILMENT_POX,
	AILMENT_MELANCHOLY,
	AILMENT_MADNESS,
	AILMENT_OPIATE,
	AILMENT_COUNT,
}

enum
{
	MARK_NONE = 0,
	MARK_SCAR,
	MARK_LOST_FINGERS,
	MARK_CROOKED_LIMB,
	MARK_POCKMARKS,
	MARK_MISSING_TEETH,
	MARK_COUNT,
}

enum E_AILMENT_DEF
{
	E_AILMENT_DEF_NAME[AILMENT_NAME_LEN],
	E_AILMENT_DEF_STAGES,
	E_AILMENT_DEF_MARK,
}

enum E_AILMENT_STAGE
{
	E_STAGE_CUE[AILMENT_CUE_LEN],
	E_STAGE_SELF[AILMENT_CUE_LEN],
	E_STAGE_TURNS,
	E_STAGE_STAMINA,
	E_STAGE_HUNGER,
	E_STAGE_THIRST,
	E_STAGE_HEALTH,
	Float:E_STAGE_DRAIN,
	E_STAGE_WORK,
	bool:E_STAGE_LETHAL,
	bool:E_STAGE_DOWNED,
	bool:E_STAGE_SPREADS,
}

static const s_AilmentDefs[AILMENT_COUNT][E_AILMENT_DEF] = {
	{"Chills", 3, MARK_NONE},
	{"Frostbite", 3, MARK_LOST_FINGERS},
	{"Heatstroke", 3, MARK_NONE},
	{"Flux", 3, MARK_NONE},
	{"Sting swelling", 2, MARK_NONE},
	{"Lingering wound", 2, MARK_SCAR},
	{"Broken bone", 2, MARK_NONE},
	{"Dust lung", 2, MARK_NONE},
	{"Alcoholism", 3, MARK_NONE},
	{"Cough", 3, MARK_NONE},
	{"Fever", 3, MARK_NONE},
	{"Ague", 1, MARK_NONE},
	{"Rotten teeth", 3, MARK_MISSING_TEETH},
	{"Infected wound", 3, MARK_LOST_FINGERS},
	{"Scurvy", 3, MARK_NONE},
	{"Plague", 3, MARK_NONE},
	{"Pox", 3, MARK_POCKMARKS},
	{"Melancholy", 2, MARK_NONE},
	{"Madness", 1, MARK_NONE},
	{"Poppy hunger", 4, MARK_NONE}
};

static const s_AilmentStages[AILMENT_COUNT][AILMENT_MAX_STAGES][E_AILMENT_STAGE] = {
	{
		{"shivers and sneezes", "You've caught a chill and can't stop shivering.", 1, 10, 120, 100, 0, 0.0, 0, false, false, true},
		{"looks chilled to the bone", "The chill has settled in your chest.", 2, 10, 120, 100, 0, 0.0, 0, false, false, true},
		{"sniffs, but looks better", "The chill is passing.", 1, 5, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"rubs numb, grey fingers", "You have frostbite. You can't feel your fingers.", 1, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"limps on frostbitten feet", "Your fingers and toes burn and ache.", 2, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"has blackened fingers", "Your fingertips have gone black. You could lose them.", 2, 0, 100, 100, 10, 0.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"is flushed and sweating", "You have heatstroke. The heat is making you dizzy.", 1, 30, 100, 200, 0, 0.0, 0, false, false, false},
		{"staggers, drenched in sweat", "Your head pounds and the ground sways.", 1, 30, 100, 200, 0, 0.0, 1, false, false, false},
		{"has collapsed in the heat", "You collapse from the heat. Heatstroke can kill you.", 1, 30, 100, 200, 0, 2.0, 3, true, true, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"is doubled over with cramps", "You have the flux. Your gut twists with cramps.", 1, 20, 150, 200, 0, 0.0, 0, false, false, true},
		{"runs for the ditch again", "Nothing stays in you.", 3, 20, 150, 200, 0, 0.0, 1, false, false, true},
		{"is wasting away", "You're wasting away. The flux can kill you now.", 2, 20, 150, 200, 10, 2.0, 2, true, false, true},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"has a swollen face", "Your face throbs where the bee got you.", 1, 10, 100, 100, 0, 0.0, 0, false, false, false},
		{"has a fading swelling", "The swelling is going down.", 1, 5, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"favours a fresh wound", "The wound is open and sore.", 2, 0, 100, 100, 10, 0.0, 0, false, false, false},
		{"has a wound closing over", "The wound is closing.", 2, 0, 100, 100, 5, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"holds a broken limb", "The bone is broken.", 3, 0, 100, 100, 0, 0.0, 2, false, false, false},
		{"wears a splint", "The bone is knitting.", 4, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"has a dry cough", "You cough up dust.", 5, 10, 100, 100, 10, 0.0, 0, false, false, false},
		{"wheezes with every breath", "Every breath is work.", 0, 30, 100, 100, 20, 0.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"has a red nose", "You could do with a drink.", 5, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"has shaking hands", "Your hands won't stop shaking.", 5, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"is thin and yellow", "The drink is ruining your health.", 0, 10, 100, 100, 20, 0.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"has a runny nose", "Your nose is running.", 1, 10, 100, 100, 0, 0.0, 0, false, false, true},
		{"coughs wetly", "You can't stop coughing.", 2, 10, 100, 100, 0, 0.0, 0, false, false, true},
		{"clears their throat", "The cough is clearing.", 1, 5, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"is warm to the touch", "You feel warm and weak.", 1, 30, 100, 150, 0, 0.0, 1, false, false, true},
		{"looks pale and sweating", "You have a fever.", 2, 30, 100, 150, 0, 0.0, 1, false, false, true},
		{"burns with fever", "Your fever is at its worst and can kill you.", 1, 30, 100, 150, 0, 3.0, 2, true, false, true},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"shakes with a fit", "The shaking fits come and go.", 8, 40, 100, 100, 0, 0.0, 2, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"holds their jaw", "A tooth aches.", 5, 0, 80, 100, 0, 0.0, 0, false, false, false},
		{"winces at every bite", "The tooth is rotting.", 10, 0, 80, 100, 0, 0.0, 0, false, false, false},
		{"has a swollen jaw", "Your jaw is hot and swollen.", 2, 10, 80, 100, 0, 1.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"has an angry red wound", "Your wound is infected. It's red and hot.", 1, 0, 100, 100, 5, 0.0, 0, false, false, false},
		{"has a wound weeping pus", "Your wound is weeping pus.", 2, 10, 100, 100, 10, 1.0, 1, false, false, false},
		{"smells of rot", "The flesh around your wound is dying. It can kill you.", 2, 30, 100, 100, 20, 2.0, 2, true, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"looks pale and tired", "You tire quickly.", 5, 20, 100, 100, 0, 0.0, 0, false, false, false},
		{"has bleeding gums", "Your gums bleed.", 5, 20, 100, 100, 0, 0.0, 0, false, false, false},
		{"has old wounds reopening", "Old wounds are opening again. Scurvy can kill you.", 5, 20, 100, 100, 10, 0.5, 1, true, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"looks feverish", "You feel feverish.", 2, 20, 100, 150, 0, 0.0, 1, false, false, true},
		{"has swellings at the neck", "Swellings rise at your neck and groin.", 2, 50, 100, 150, 10, 1.0, 2, false, false, true},
		{"is marked with black spots", "Black spots cover your skin. The plague is at its worst and can kill you.", 2, 50, 100, 150, 20, 3.0, 3, true, false, true},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"is flushed with fever", "You feel feverish.", 2, 30, 100, 150, 0, 0.0, 1, false, false, false},
		{"has spotted skin", "You have the pox. Spots cover your skin.", 3, 30, 100, 100, 0, 0.0, 1, false, false, true},
		{"is covered in scabs", "The spots have scabbed.", 3, 10, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"walks with slumped shoulders", "Nothing seems worth the trouble.", 3, 15, 100, 100, 0, 0.0, 1, false, false, false},
		{"sighs and stares at nothing", "The days are grey.", 5, 15, 100, 100, 0, 0.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"mutters at the air", "The voices are back.", 0, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	},
	{
		{"has glassy eyes", "The world is soft and far away.", 2, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"seems restless", "The poppy does less each time.", 3, 0, 100, 100, 0, 0.0, 1, false, false, false},
		{"scratches and sweats", "You need the poppy.", 5, 10, 100, 100, 0, 0.0, 1, false, false, false},
		{"shakes and sweats", "You're in withdrawal. Every bone aches.", 3, 40, 100, 150, 0, 0.0, 2, false, false, false},
		{"", "", 0, 0, 100, 100, 0, 0.0, 0, false, false, false}
	}
};

stock bool:Ailment_IsValid(ailment)
{
	return ailment >= AILMENT_CHILLS && ailment < AILMENT_COUNT;
}

stock Ailment_GetName(ailment,dest[],size = sizeof(dest))
{
	if (!Ailment_IsValid(ailment))
	{
		strcopy(dest,"Nothing",size);
		return;
	}

	strcopy(dest,s_AilmentDefs[ailment][E_AILMENT_DEF_NAME],size);
}

stock Ailment_GetStageCount(ailment)
{
	return Ailment_IsValid(ailment) ? s_AilmentDefs[ailment][E_AILMENT_DEF_STAGES] : 0;
}

stock Ailment_GetMark(ailment)
{
	return Ailment_IsValid(ailment) ? s_AilmentDefs[ailment][E_AILMENT_DEF_MARK] : MARK_NONE;
}

stock bool:Ailment_IsValidStage(ailment,stage)
{
	return Ailment_IsValid(ailment) && stage >= 0 && stage < s_AilmentDefs[ailment][E_AILMENT_DEF_STAGES];
}

stock Ailment_GetStageTurns(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_TURNS] : 0;
}

stock bool:Ailment_IsChronic(ailment)
{
	new last = Ailment_GetStageCount(ailment) - 1;
	return last >= 0 && s_AilmentStages[ailment][last][E_STAGE_TURNS] == AILMENT_TURNS_CHRONIC;
}

stock bool:Ailment_IsLethal(ailment)
{
	new last = Ailment_GetStageCount(ailment) - 1;
	return last >= 0 && s_AilmentStages[ailment][last][E_STAGE_LETHAL];
}

stock bool:Ailment_StageIsLethal(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) && s_AilmentStages[ailment][stage][E_STAGE_LETHAL];
}

stock bool:Ailment_StageDowns(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) && s_AilmentStages[ailment][stage][E_STAGE_DOWNED];
}

stock bool:Ailment_StageSpreads(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) && s_AilmentStages[ailment][stage][E_STAGE_SPREADS];
}

stock Ailment_GetStageCue(ailment,stage,dest[],size = sizeof(dest))
{
	if (!Ailment_IsValidStage(ailment,stage))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_AilmentStages[ailment][stage][E_STAGE_CUE],size);
}

stock Ailment_GetStageSelfText(ailment,stage,dest[],size = sizeof(dest))
{
	if (!Ailment_IsValidStage(ailment,stage))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_AilmentStages[ailment][stage][E_STAGE_SELF],size);
}

stock Ailment_GetStageStamina(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_STAMINA] : 0;
}

stock Ailment_GetStageHunger(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_HUNGER] : 100;
}

stock Ailment_GetStageThirst(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_THIRST] : 100;
}

stock Ailment_GetStageHealth(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_HEALTH] : 0;
}

stock Float:Ailment_GetStageDrain(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_DRAIN] : 0.0;
}

stock Ailment_GetStageWork(ailment,stage)
{
	return Ailment_IsValidStage(ailment,stage) ? s_AilmentStages[ailment][stage][E_STAGE_WORK] : 0;
}
