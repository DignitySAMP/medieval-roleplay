#define FAITH_BANNS_READINGS (3)
#define FAITH_BANNS_MAX (3)
#define FAITH_BANNS_LINES (4)
#define FAITH_ALTAR_RANGE (3.0)
#define FAITH_WEDDING_MASS_GAP (180)
#define FAITH_WEDDING_NAME_LEN (CHARACTER_NAME_MAX * 2 + 2)

enum E_FAITH_BANNS
{
	E_FAITH_BANNS_CHARACTER,
	E_FAITH_BANNS_NAME[FAITH_WEDDING_NAME_LEN],
	E_FAITH_BANNS_SPOUSE[FAMILY_NAME_LEN],
	E_FAITH_BANNS_READ,
}

enum E_FAITH_ASKED
{
	bool:E_FAITH_ASKED_LOADED,
	bool:E_FAITH_ASKED_PENDING,
	E_FAITH_ASKED_SPOUSE[FAMILY_NAME_LEN],
	E_FAITH_ASKED_AGE,
	E_FAITH_ASKED_READ,
}

static s_FaithBanns[FAITH_BANNS_MAX][E_FAITH_BANNS];
static s_FaithBannsCount;
static s_FaithAsked[MAX_PLAYERS][E_FAITH_ASKED];

stock bool:Faith_IsBannsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FaithAsked[playerid][E_FAITH_ASKED_LOADED];
}

stock bool:Faith_HasBanns(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FaithAsked[playerid][E_FAITH_ASKED_PENDING];
}

stock Faith_GetBannsReads(playerid)
{
	return Faith_HasBanns(playerid) ? s_FaithAsked[playerid][E_FAITH_ASKED_READ] : 0;
}

stock bool:Faith_AreBannsRead(playerid)
{
	return Faith_HasBanns(playerid) && s_FaithAsked[playerid][E_FAITH_ASKED_READ] >= FAITH_BANNS_READINGS;
}

stock bool:Faith_AskBanns(playerid,const spouse[],age)
{
	if (!Session_IsPlaying(playerid) || !s_FaithAsked[playerid][E_FAITH_ASKED_LOADED] || s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] || !Family_IsLoaded(playerid) || Family_HasSpouse(playerid) || !Character_ValidateName(spouse))
	{
		return false;
	}

	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = true;
	strcopy(s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE],spouse,FAMILY_NAME_LEN);
	s_FaithAsked[playerid][E_FAITH_ASKED_AGE] = clamp(age,16,60);
	s_FaithAsked[playerid][E_FAITH_ASKED_READ] = 0;
	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO character_banns (character_id, spouse_name, spouse_age, church, asked_day, read_count) VALUES (%d, '%e', %d, 0, %d, 0)",Character_GetId(playerid),spouse,s_FaithAsked[playerid][E_FAITH_ASKED_AGE],Family_Today()));

	new full[FAITH_WEDDING_NAME_LEN];
	Character_GetName(playerid,full);
	Crier_Announce(CRIER_KIND_FAITH,"Banns of marriage",sprintf("%s and %s mean to marry at the monastery church. Their banns are read at the next three masses. If any know cause or just impediment why these two should not be joined, let them declare it.",full,spouse));
	return true;
}

stock Faith_WithdrawBanns(playerid)
{
	if (!Faith_HasBanns(playerid))
	{
		return;
	}

	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = false;
	s_FaithAsked[playerid][E_FAITH_ASKED_READ] = 0;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_banns WHERE character_id = %d",Character_GetId(playerid)));
}

stock Faith_LoadBannsState(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid), characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT spouse_name, spouse_age, read_count FROM character_banns WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = cache_num_rows() > 0;

	if (s_FaithAsked[playerid][E_FAITH_ASKED_PENDING])
	{
		cache_get_value_name(0,"spouse_name",s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE],FAMILY_NAME_LEN);
		cache_get_value_name_int(0,"spouse_age",s_FaithAsked[playerid][E_FAITH_ASKED_AGE]);
		cache_get_value_name_int(0,"read_count",s_FaithAsked[playerid][E_FAITH_ASKED_READ]);
	}

	s_FaithAsked[playerid][E_FAITH_ASKED_LOADED] = true;
}

stock Faith_LoadBanns(church)
{
	yield 1;

	s_FaithBannsCount = 0;
	await mysql_aquery_s(g_Mysql,str_format("SELECT b.character_id, b.spouse_name, b.read_count, c.name, c.surname FROM character_banns b JOIN characters c ON c.id = b.character_id WHERE b.church = %d AND b.read_count < %d AND c.alive = 1 ORDER BY b.asked_day, b.character_id LIMIT %d",church,FAITH_BANNS_READINGS,FAITH_BANNS_MAX));

	new rows = min(cache_num_rows(),FAITH_BANNS_MAX);

	for (new r = 0;r < rows;r++)
	{
		new name[CHARACTER_NAME_MAX + 1], surname[CHARACTER_NAME_MAX + 1];
		cache_get_value_name_int(r,"character_id",s_FaithBanns[r][E_FAITH_BANNS_CHARACTER]);
		cache_get_value_name(r,"spouse_name",s_FaithBanns[r][E_FAITH_BANNS_SPOUSE],FAMILY_NAME_LEN);
		cache_get_value_name_int(r,"read_count",s_FaithBanns[r][E_FAITH_BANNS_READ]);
		cache_get_value_name(r,"name",name);
		cache_get_value_name(r,"surname",surname);
		format(s_FaithBanns[r][E_FAITH_BANNS_NAME],FAITH_WEDDING_NAME_LEN,"%s %s",name,surname);
	}

	s_FaithBannsCount = rows;
}

stock Faith_CountBanns()
{
	return s_FaithBannsCount;
}

static Faith_MarkBannsRead(index)
{
	new characterid = s_FaithBanns[index][E_FAITH_BANNS_CHARACTER];
	mysql_tquery_s(g_Mysql,str_format("UPDATE character_banns SET read_count = read_count + 1 WHERE character_id = %d",characterid));

	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == characterid && s_FaithAsked[playerid][E_FAITH_ASKED_PENDING])
		{
			s_FaithAsked[playerid][E_FAITH_ASKED_READ]++;

			if (s_FaithAsked[playerid][E_FAITH_ASKED_READ] >= FAITH_BANNS_READINGS)
			{
				Gui_Notify(playerid,sprintf("Your banns with %s have been read three times, and nobody spoke against the marriage. Go to the altar to be wed.",s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE]));
			}
			else
			{
				Gui_Notify(playerid,sprintf("Your banns with %s were read at mass, %d of %d times.",s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE],s_FaithAsked[playerid][E_FAITH_ASKED_READ],FAITH_BANNS_READINGS));
			}
		}
	}
}

stock Faith_GetBannsLine(line,dest[],size = sizeof(dest))
{
	new index = line / FAITH_BANNS_LINES, part = line % FAITH_BANNS_LINES;
	dest[0] = EOS;

	if (index >= s_FaithBannsCount)
	{
		return 0;
	}

	switch (part)
	{
		case 0: format(dest,size,"I publish the banns of marriage between %s and %s, both of this parish.",s_FaithBanns[index][E_FAITH_BANNS_NAME],s_FaithBanns[index][E_FAITH_BANNS_SPOUSE]);
		case 1: strcopy(dest,"If any of you know cause or just impediment why these two persons",size);
		case 2: strcopy(dest,"should not be joined together in holy matrimony, ye are to declare it.",size);
		default:
		{
			new read = s_FaithBanns[index][E_FAITH_BANNS_READ];
			format(dest,size,"This is the %s time of asking.",read == 0 ? ("first") : (read == 1 ? ("second") : ("third")));
			Faith_MarkBannsRead(index);
		}
	}

	return 1;
}

stock bool:Faith_CanUseAltar(playerid)
{
    if (!Session_IsPlaying(playerid) || Faith_IsPraying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || Wounds_IsDown(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || Faith_IsServiceRunning() || Faith_IsRiteRunning() || !IsValidActor(Faith_GetIdlePriestActor()))
    {
        return false;
    }

	new Float:x, Float:y, Float:z, Float:a;
	Faith_GetPriestSpot(0,x,y,z,a);
    return GetPlayerVirtualWorld(playerid) == 0 && GetPlayerInterior(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,FAITH_ALTAR_RANGE,x,y,z);
}

static Faith_WeddingLines(playerid)
{
	new me[CHARACTER_NAME_MAX + 1], full[FAITH_WEDDING_NAME_LEN], spouse[FAMILY_NAME_LEN], groom[FAMILY_NAME_LEN], bride[FAMILY_NAME_LEN], line[FAITH_RITE_TEXT_LEN], bool:isGroom = Character_GetSex(playerid) == 0, groomSays = isGroom ? FAITH_SAY_PLAYER : FAITH_SAY_OTHER, brideSays = isGroom ? FAITH_SAY_OTHER : FAITH_SAY_PLAYER;
	Faith_GivenName(playerid,me);
	Character_GetName(playerid,full);
	strcopy(spouse,s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE]);
	strcopy(groom,isGroom ? me : spouse);
	strcopy(bride,isGroom ? spouse : me);

	format(line,sizeof(line),"comes down to the altar step to join %s and %s in marriage.",full,spouse);
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,line);
	format(line,sizeof(line),"%s, wilt thou have this woman to thy wedded wife, and her to love and to honour,",groom);
	Faith_RiteAdd(FAITH_SAY_PRIEST,line);
	Faith_RiteAdd(FAITH_SAY_PRIEST,"keep and serve in health and in sickness, and all other forsake for her, and hold thee only to her to thy life's end?");
	Faith_RiteAdd(groomSays,"I will.","",isGroom ? ("The priest asks if you will have her. Press ~y~Y~w~ to answer: ~y~I will~w~.") : (""));
	format(line,sizeof(line),"%s, wilt thou have this man to thy wedded husband, to obey him and serve him,",bride);
	Faith_RiteAdd(FAITH_SAY_PRIEST,line);
	Faith_RiteAdd(FAITH_SAY_PRIEST,"love, honour and keep him in health and in sickness, and all other forsake for him, and hold thee only to him to thy life's end?");
	Faith_RiteAdd(brideSays,"I will.","",isGroom ? ("") : ("The priest asks if you will have him. Press ~y~Y~w~ to answer: ~y~I will~w~."));
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,"joins their right hands.");

	for (new part = 0;part < 2;part++)
	{
		new says = part == 0 ? groomSays : brideSays, bool:isMine = says == FAITH_SAY_PLAYER;
		format(line,sizeof(line),"I, %s, take thee %s to my wedded %s, to have and to hold from this day forward,",part == 0 ? groom : bride,part == 0 ? bride : groom,part == 0 ? ("wife") : ("husband"));
		Faith_RiteAdd(says,line,"",isMine ? ("Hand in hand, press ~y~Y~w~ to speak your vows.") : (""));
		Faith_RiteAdd(says,"for better for worse, for richer for poorer, in sickness and in health,");
		Faith_RiteAdd(says,"till death us depart, if holy Church it will ordain; and thereto I plight thee my troth.");
	}

	format(line,sizeof(line),"blesses the ring and gives it to %s.",groom);
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,line);
	Faith_RiteAdd(groomSays,"With this ring I thee wed, and this gold and silver I thee give,","",isGroom ? ("Press ~y~Y~w~ to give the ring with the old words.") : (""));
	Faith_RiteAdd(groomSays,"and with my body I thee worship, and with all my worldly chattels I thee endow.");
	format(line,sizeof(line),"watches %s set the ring on %s's hand.",groom,bride);
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,line);
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Ego conjungo vos in matrimonium, in nomine Patris, et Filii, et Spiritus Sancti. Amen.","I join you together in marriage, in the name of the Father, and of the Son, and of the Holy Ghost. Amen.");
	Faith_RiteAdd(FAITH_SAY_PRIEST,"Those whom God hath joined together, let no man put asunder.");
	Faith_RiteAdd(FAITH_SAY_PRIEST_ME,"raises his hand over the couple in blessing.");
}

stock bool:Faith_StartWedding(playerid,lineMs = FAITH_RITE_LINE_MS)
{
	if (!Faith_AreBannsRead(playerid) || !Family_IsLoaded(playerid) || Family_HasSpouse(playerid))
	{
		return false;
	}

	new church = 0, Float:x, Float:y, Float:z, Float:a;
	Faith_GetPriestSpot(church,x,y,z,a);

	if (!Faith_RiteBegin(FAITH_RITE_WEDDING,playerid,church,x,y,z,a,"Your wedding",true,lineMs))
	{
		return false;
	}

	new Float:dx = floatsin(-a,degrees), Float:dy = floatcos(-a,degrees), Float:px = x + dx * 1.3, Float:py = y + dy * 1.3, Float:sideX = -dy * 0.5, Float:sideY = dx * 0.5, spouseSex = Character_GetSex(playerid) == 1 ? 0 : 1;
	SetPlayerPos(playerid,px + sideX,py + sideY,z);
	SetPlayerFacingAngle(playerid,a + 180.0);
	Faith_RiteOther(Skins_GetStarter(spouseSex,random(max(Skins_CountStarter(spouseSex),1))),px - sideX,py - sideY,z,a + 180.0,s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE]);
	Faith_WeddingLines(playerid);
	Faith_RiteStart();
	return true;
}

stock Faith_OnWeddingDone(playerid,church,const priest[])
{
	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	new spouse[FAMILY_NAME_LEN], full[FAITH_WEDDING_NAME_LEN];
	strcopy(spouse,s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE]);
	Character_GetName(playerid,full);
	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = false;
	s_FaithAsked[playerid][E_FAITH_ASKED_READ] = 0;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_banns WHERE character_id = %d",Character_GetId(playerid)));
	Family_GrantSpouse(playerid,spouse,s_FaithAsked[playerid][E_FAITH_ASKED_AGE]);

	foreach (new i : Player)
	{
		if (i != playerid && Faith_IsInChurch(i,church))
		{
			Gui_Notify(i,sprintf("%s and %s are wed.",full,spouse));
		}
	}

	Log_Info("faith","%s wed %s at the altar (%s)",full,spouse,priest);
	Crier_Announce(CRIER_KIND_FAITH,"A wedding at the monastery church",sprintf("%s and %s were joined in marriage before God by %s. May their house be blessed with children.",full,spouse,priest));
	pawn_call_public("Faith_OnWedding","ds",playerid,spouse);
}

forward Faith_OnWedding(playerid,const spouse[]);

public Faith_OnWedding(playerid,const spouse[])
{
	return 1;
}

static FaithWedding_AskName(playerid,token,dest[],size = sizeof(dest))
{
	new response[DIALOG_RESPONSE], body[320], error[128];
	error[0] = EOS;
	dest[0] = EOS;

	for (;;)
	{
		format(body,sizeof(body),GUI_TEXT "Whom do you wish to marry? The priest writes their given name into the banns.\n\n" GUI_MUTED "Letters only, the first one a capital. The match is a %s of a village family.",Character_GetSex(playerid) == 1 ? ("son") : ("daughter"));

		if (error[0] != EOS)
		{
			format(body,sizeof(body),"%s\n\n" GUI_BAD "%s",body,error);
		}

		await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,"The banns",body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
		{
			return;
		}

		if (!Character_ValidateName(response[DIALOG_RESPONSE_INPUTTEXT]))
		{
			format(error,sizeof(error),"That is not a name a priest would write down. Use %d to %d letters and start with a capital.",CHARACTER_NAME_MIN,CHARACTER_NAME_MAX);
			continue;
		}

		strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);
		return;
	}
}

static FaithWedding_AskAge(playerid)
{
	static const ages[] = {18, 20, 22, 25, 30, 35, 40};
	new Float:x, Float:y, Float:width, label[16];
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Their age");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,200.0,float(sizeof(ages)) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Their age",x,y,width);

	for (new i = 0;i < sizeof(ages);i++)
	{
		format(label,sizeof(label),"%d years old",ages[i]);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,label,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(sizeof(ages)) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick >= 0 && pick < sizeof(ages) ? ages[pick] : 0;
}

static bool:FaithWedding_Choice(playerid,const title[],const text[],const button[])
{
	new Float:x, Float:y, Float:contentWidth, Float:textHeight = Gui_TextHeight(text,300.0);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,textHeight + KIT_ROW + 10.0,title,x,y,contentWidth);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,contentWidth);
	Kit_AddButton(playerid,x,y + textHeight + 8.0,contentWidth * 0.45,button,1,KIT_COLOUR_ACCENT);
	Kit_AddButton(playerid,x + contentWidth * 0.55,y + textHeight + 8.0,contentWidth * 0.45,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick == 1;
}

stock FaithWedding_OpenAltar(playerid)
{
    new token = Account_GetToken(playerid);
	yield 1;

    if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
    {
        return;
    }
    if (!Faith_CanUseAltar(playerid))
    {
        return;
    }

	new text[400], wrapped[480], spouse[FAMILY_NAME_LEN];

	if (Family_HasSpouse(playerid))
	{
		Family_GetSpouseName(playerid,spouse);
		format(text,sizeof(text),"You're already wed to ~y~%s~w~. The Church marries you once, till death you depart.",spouse);
		Util_WrapText(text,wrapped,sizeof(wrapped),60,"~n~");
		Gui_ShowMessage(playerid,"Marriage",wrapped,GUI_BUTTON_BACK,300.0);
		return;
	}

	if (!Faith_HasBanns(playerid))
	{
		Util_WrapText("The priest marries couples of the parish here at the altar.~n~~n~First he reads your ~y~banns~w~ at three masses, so that anyone who knows a reason you can't marry may say so. Once they're read, come back here to be wed.",wrapped,sizeof(wrapped),60,"~n~");

		if (!FaithWedding_Choice(playerid,"Marriage",wrapped,"Ask for banns") || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		FaithWedding_AskName(playerid,token,spouse);

		if (spouse[0] == EOS || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		new age = FaithWedding_AskAge(playerid);

		if (age <= 0 || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			return;
		}

		if (Faith_AskBanns(playerid,spouse,age))
		{
			Gui_Notify(playerid,sprintf("The priest writes your banns with %s. They're read at the next three masses; after that, come back to the altar to be wed.",spouse));
		}

		return;
	}

	strcopy(spouse,s_FaithAsked[playerid][E_FAITH_ASKED_SPOUSE]);

	if (!Faith_AreBannsRead(playerid))
	{
		new seconds = Faith_SecondsToNextService();
		format(text,sizeof(text),"Your banns with ~y~%s~w~ have been read ~y~%d~w~ of %d times. The next mass is in %dh %02dm.~n~~n~Withdraw them if you've changed your mind.",spouse,Faith_GetBannsReads(playerid),FAITH_BANNS_READINGS,seconds / 3600,(seconds % 3600) / 60);
		Util_WrapText(text,wrapped,sizeof(wrapped),60,"~n~");

		if (FaithWedding_Choice(playerid,"The banns",wrapped,"Withdraw") && IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
		{
			Faith_WithdrawBanns(playerid);
			Gui_Notify(playerid,"The priest strikes your banns from the book.");
		}

		return;
	}

	if (Faith_IsServiceRunning() || Faith_SecondsToNextService() < FAITH_WEDDING_MASS_GAP)
	{
		Gui_ShowMessage(playerid,"Marriage","Mass is about to begin. Come back after it, and the priest will wed you.",GUI_BUTTON_BACK,300.0);
		return;
	}

	format(text,sizeof(text),"Your banns have been read three times and nobody spoke against the marriage.~n~~n~The priest can wed you and ~y~%s~w~ now. You answer and speak your vows with ~y~Y~w~.",spouse);
	Util_WrapText(text,wrapped,sizeof(wrapped),60,"~n~");

	if (FaithWedding_Choice(playerid,"Marriage",wrapped,"Be wed") && IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && !Faith_StartWedding(playerid))
	{
		Gui_Notify(playerid,"The priest can't wed you right now. Try again in a moment.");
	}
}

forward Faith_AltarMarriageAsk(playerid,index,data);

public Faith_AltarMarriageAsk(playerid,index,data)
{
    #pragma unused index, data

    if (IsPlayerConnected(playerid))
    {
        FaithWedding_OpenAltar(playerid);
    }
    return 1;
}

forward Faith_AltarMassAsk(playerid,index,data);

public Faith_AltarMassAsk(playerid,index,data)
{
    #pragma unused index, data

    if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid))
    {
        return 1;
    }

    if (!Faith_CanUseAltar(playerid) || !Clergy_CanLead(playerid))
    {
        return 1;
    }

    if (Faith_SecondsToNextService() < FAITH_WEDDING_MASS_GAP)
    {
        Gui_Notify(playerid,"Not now: the next mass is about to begin. Stand at the altar when it starts and you'll lead it.");
    }
    else if (!Faith_StartService(0,FAITH_LINE_MS,playerid))
    {
        Gui_Notify(playerid,"The mass can't begin right now. Try again in a moment.");
    }
    return 1;
}

forward Faith_BannsLoadDeferred(playerid,token);

public Faith_BannsLoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Faith_LoadBannsState(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_FaithAsked[playerid][E_FAITH_ASKED_LOADED] = false;
	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	s_FaithAsked[playerid][E_FAITH_ASKED_LOADED] = false;
	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = false;
	SetTimerEx("Faith_BannsLoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	s_FaithAsked[playerid][E_FAITH_ASKED_LOADED] = false;
	s_FaithAsked[playerid][E_FAITH_ASKED_PENDING] = false;
}

hook Actors_OnMenuBuild(playerid,index)
{
	if (index == -1 || index != Actors_FindByKey(FAITH_ANSELM_KEY) || !Faith_CanUseAltar(playerid))
	{
		return;
	}

	if (Clergy_CanLead(playerid))
	{
		Actors_MenuAdd(playerid,"Say mass now","Faith_AltarMassAsk",0,KIT_COLOUR_ACCENT);
	}

	Actors_MenuAdd(playerid,"Marriage and banns","Faith_AltarMarriageAsk");
}
