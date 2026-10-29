#define FAITH_FONT_RANGE (1.4)
#define FAITH_FONT_PRIEST_BACK (0.9)
#define FAITH_FONT_PARENT_FRONT (0.8)

static const Float:s_FaithFont[4] = {681.8, -3603.7, 18.5, 0.0};
stock Faith_GetFontSpot(&Float:x,&Float:y,&Float:z)
{
	x = s_FaithFont[0];
	y = s_FaithFont[1];
	z = s_FaithFont[2];
}

static s_FaithFontPrompt[MAX_PLAYERS];
static s_FaithFontInfobox[MAX_PLAYERS];
static s_FaithBaptismChild[MAX_PLAYERS];

static Faith_FindUnbaptised(playerid,indices[],max = sizeof(indices))
{
	new count = 0, childid, name[FAMILY_NAME_LEN], sex, age, bool:isGrown;

	for (new i = 0;i < Family_CountChildren(playerid) && count < max;i++)
	{
		if (!Family_GetChild(playerid,i,childid,name,sex,age,isGrown) || isGrown || name[0] == EOS || Family_IsChildBaptised(playerid,i))
		{
			continue;
		}

		indices[count++] = i;
	}

	return count;
}

static Faith_ClearFontPrompt(playerid)
{
	if (s_FaithFontInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_FaithFontInfobox[playerid]);
	}

	s_FaithFontPrompt[playerid] = -1;
	s_FaithFontInfobox[playerid] = 0;
}

stock Faith_UpdateFontPrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Faith_IsPraying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || Wounds_IsDown(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || Faith_IsServiceRunning() || Faith_IsRiteRunning() || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || !IsPlayerInRangeOfPoint(playerid,FAITH_FONT_RANGE,s_FaithFont[0],s_FaithFont[1],s_FaithFont[2]))
	{
		Faith_ClearFontPrompt(playerid);
		return;
	}

	new indices[FAMILY_MAX_CHILDREN];

	if (Faith_FindUnbaptised(playerid,indices) == 0)
	{
		Faith_ClearFontPrompt(playerid);
		return;
	}

	if (s_FaithFontPrompt[playerid] == 0 && Infobox_IsShown(playerid,s_FaithFontInfobox[playerid]))
	{
		return;
	}

	s_FaithFontPrompt[playerid] = 0;
	s_FaithFontInfobox[playerid] = Infobox_ShowPrompt(playerid,s_FaithFontInfobox[playerid],"The font","Press Y to have your child baptised here.",2);
}

static Faith_BaptismLines(playerid,index)
{
	new parent[CHARACTER_NAME_MAX + 1], child[FAMILY_NAME_LEN], childid, sex, age, bool:isGrown, line[FAITH_RITE_TEXT_LEN], english[FAITH_RITE_TEXT_LEN];
	Faith_GivenName(playerid,parent);
	Family_GetChild(playerid,index,childid,child,sex,age,isGrown);

	format(line,sizeof(line),"takes %s from %s's arms at the font.",child,parent);
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,line);
	format(line,sizeof(line),"%s, abrenuntias Satanae?",child);
	format(english,sizeof(english),"%s, dost thou renounce Satan?",child);
	Faith_RiteAdd(FAITH_SAY_PRIEST,line,english);
	Faith_RiteAdd(FAITH_SAY_PLAYER,"Abrenuntio.","I do renounce him.","You answer for the child. Press ~y~Y~w~ to say ~y~Abrenuntio~w~: I renounce him.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Et omnibus operibus eius? Et omnibus pompis eius?","And all his works? And all his pomps?");
	Faith_RiteAdd(FAITH_SAY_PLAYER,"Abrenuntio.","I do renounce them.","Press ~y~Y~w~ to say ~y~Abrenuntio~w~ again.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Credis in Deum, Patrem omnipotentem, Creatorem caeli et terrae?","Dost thou believe in God the Father Almighty, Creator of heaven and earth?");
	Faith_RiteAdd(FAITH_SAY_PLAYER,"Credo.","I believe.","Press ~y~Y~w~ to say ~y~Credo~w~: I believe.");
	format(line,sizeof(line),"%s, vis baptizari?",child);
	format(english,sizeof(english),"%s, wilt thou be baptised?",child);
	Faith_RiteAdd(FAITH_SAY_PRIEST,line,english);
	Faith_RiteAdd(FAITH_SAY_PLAYER,"Volo.","I will.","Press ~y~Y~w~ to say ~y~Volo~w~: I will.");
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,"pours water three times over the child's head.");
	format(line,sizeof(line),"%s, ego te baptizo in nomine Patris, et Filii, et Spiritus Sancti.",child);
	format(english,sizeof(english),"%s, I baptise thee in the name of the Father, and of the Son, and of the Holy Ghost.",child);
	Faith_RiteAdd(FAITH_SAY_PRIEST,line,english);
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Vade in pace, et Dominus sit tecum. Amen.","Go in peace, and the Lord be with thee. Amen.");
}

stock bool:Faith_StartBaptism(playerid,index,lineMs = FAITH_RITE_LINE_MS)
{
	new childid, name[FAMILY_NAME_LEN], sex, age, bool:isGrown;

	if (!Family_GetChild(playerid,index,childid,name,sex,age,isGrown) || isGrown || name[0] == EOS || Family_IsChildBaptised(playerid,index))
	{
		return false;
	}

	new Float:priestX = s_FaithFont[0] - floatsin(-s_FaithFont[3],degrees) * FAITH_FONT_PRIEST_BACK, Float:priestY = s_FaithFont[1] - floatcos(-s_FaithFont[3],degrees) * FAITH_FONT_PRIEST_BACK;

	if (!Faith_RiteBegin(FAITH_RITE_BAPTISM,playerid,0,priestX,priestY,s_FaithFont[2],s_FaithFont[3],"A baptism",false,lineMs))
	{
		return false;
	}

	s_FaithBaptismChild[playerid] = index;
	Faith_ClearFontPrompt(playerid);
	SetPlayerPos(playerid,s_FaithFont[0] + floatsin(-s_FaithFont[3],degrees) * FAITH_FONT_PARENT_FRONT,s_FaithFont[1] + floatcos(-s_FaithFont[3],degrees) * FAITH_FONT_PARENT_FRONT,s_FaithFont[2]);
	SetPlayerFacingAngle(playerid,s_FaithFont[3] + 180.0);
	Faith_BaptismLines(playerid,index);
	Faith_RiteStart();
	return true;
}

stock Faith_OnBaptismDone(playerid,church,const priest[])
{
	#pragma unused church

	new index = s_FaithBaptismChild[playerid], childid, child[FAMILY_NAME_LEN], sex, age, bool:isGrown, parent[CHARACTER_NAME_MAX * 2 + 2];

	if (!IsPlayerConnected(playerid) || !Family_GetChild(playerid,index,childid,child,sex,age,isGrown) || !Family_MarkBaptised(playerid,index))
	{
		return;
	}

	Character_GetName(playerid,parent);
	Gui_Notify(playerid,sprintf("%s is baptised. If %s ever carries the family on as your heir, the Church's grace gives one more death on the life clock.",child,sex == 1 ? ("she") : ("he")));
	Crier_Announce(CRIER_KIND_FAITH,"A baptism at the monastery church",sprintf("%s, %s of %s, was baptised at the font by %s.",child,sex == 1 ? ("daughter") : ("son"),parent,priest));
	Log_Info("faith","%s baptised %s (child %d, %s)",parent,child,childid,priest);
}

static FaithBaptism_Choose(playerid)
{
	yield 1;

	new indices[FAMILY_MAX_CHILDREN], count = Faith_FindUnbaptised(playerid,indices);

	if (count == 0)
	{
		return;
	}

	new pick = 0;

	if (count > 1)
	{
		new Float:x, Float:y, Float:width, childid, name[FAMILY_NAME_LEN], sex, age, bool:isGrown, detail[24];
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Which child");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,220.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Which child",x,y,width);

		for (new i = 0;i < count;i++)
		{
			Family_GetChild(playerid,indices[i],childid,name,sex,age,isGrown);
			format(detail,sizeof(detail),"%s, %d",sex == 1 ? ("daughter") : ("son"),age);
			Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,KIT_COLOUR_TEXT,detail,KIT_COLOUR_MUTED,0.5);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!IsPlayerConnected(playerid) || pick < 0 || pick >= count)
		{
			return;
		}
	}

	if (Faith_IsServiceRunning() || Faith_SecondsToNextService() < FAITH_WEDDING_MASS_GAP)
	{
		Gui_Notify(playerid,"Mass is about to begin. Come back to the font after it.");
		return;
	}

	if (!Faith_StartBaptism(playerid,indices[pick]))
	{
		Gui_Notify(playerid,"The priest can't baptise now. Try again in a moment.");
	}
}

forward FaithBaptism_ChooseDeferred(playerid,token);

public FaithBaptism_ChooseDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && !Gui_IsBusy(playerid))
	{
		FaithBaptism_Choose(playerid);
	}

	return 1;
}

forward bool:Faith_FontContext(playerid);

public bool:Faith_FontContext(playerid)
{
	return s_FaithFontPrompt[playerid] != -1 && !Combat_IsInMode(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_FaithFontPrompt[playerid] = -1;
	s_FaithFontInfobox[playerid] = 0;
	s_FaithBaptismChild[playerid] = -1;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !Faith_IsRiteWaiting(playerid) && s_FaithFontPrompt[playerid] != -1 && !Infobox_IsPromptBlocked(playerid,s_FaithFontInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		SetTimerEx("FaithBaptism_ChooseDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
	}
}
