#define CLERGY_ADMIT_RANGE (5.0)
#define CLERGY_ROSTER_ROWS (14)
#define CLERGY_TITLE_LEN (16)

enum E_CLERGY_RANK
{
	CLERGY_NONE,
	CLERGY_NOVICE,
	CLERGY_LAY,
	CLERGY_BROTHER,
	CLERGY_DEACON,
	CLERGY_PRIEST,
	CLERGY_PRIOR,
	CLERGY_ABBOT,
	CLERGY_RANK_COUNT,
}

enum E_CLERGY_ROW
{
	E_CLERGY_ROW_MAN[CLERGY_TITLE_LEN],
	E_CLERGY_ROW_WOMAN[CLERGY_TITLE_LEN],
	E_CLERGY_ROW_KEY[CLERGY_TITLE_LEN],
	E_CLERGY_ROW_ALT[CLERGY_TITLE_LEN],
	bool:E_CLERGY_ROW_MEN_ONLY,
}

static const s_ClergyRanks[E_CLERGY_RANK][E_CLERGY_ROW] = {
	{"", "", "none", "none", false},
	{"Novice", "Novice", "novice", "novice", false},
	{"Lay brother", "Lay sister", "lay", "lay", false},
	{"Brother", "Sister", "brother", "sister", false},
	{"Deacon", "", "deacon", "deacon", true},
	{"Priest", "", "priest", "priest", true},
	{"Prior", "Prioress", "prior", "prioress", false},
	{"Abbot", "Abbess", "abbot", "abbess", false},
	{"", "", "", "", false}
};

static E_CLERGY_RANK:s_ClergyRank[MAX_PLAYERS];
static bool:s_ClergyLoaded[MAX_PLAYERS];

stock E_CLERGY_RANK:Clergy_GetRank(playerid)
{
	return Util_IsValidPlayer(playerid) && s_ClergyLoaded[playerid] ? s_ClergyRank[playerid] : CLERGY_NONE;
}

stock bool:Clergy_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_ClergyLoaded[playerid];
}

stock Clergy_RankTitle(E_CLERGY_RANK:rank,sex,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (rank <= CLERGY_NONE || rank >= CLERGY_RANK_COUNT)
	{
		return;
	}

	if (sex == 1)
	{
		strcopy(dest,s_ClergyRanks[rank][E_CLERGY_ROW_WOMAN],size);
	}
	else
	{
		strcopy(dest,s_ClergyRanks[rank][E_CLERGY_ROW_MAN],size);
	}
}

stock E_CLERGY_RANK:Clergy_ParseRank(const text[])
{
	for (new E_CLERGY_RANK:rank = CLERGY_NONE;rank < CLERGY_RANK_COUNT;rank++)
	{
		if (!strcmp(text,s_ClergyRanks[rank][E_CLERGY_ROW_KEY],true) || !strcmp(text,s_ClergyRanks[rank][E_CLERGY_ROW_ALT],true))
		{
			return rank;
		}
	}

	return CLERGY_RANK_COUNT;
}

stock bool:Clergy_RankAllowed(E_CLERGY_RANK:rank,sex)
{
	return rank >= CLERGY_NONE && rank < CLERGY_RANK_COUNT && (!s_ClergyRanks[rank][E_CLERGY_ROW_MEN_ONLY] || sex == 0);
}

stock bool:Clergy_CanLead(playerid)
{
	new E_CLERGY_RANK:rank = Clergy_GetRank(playerid);
	return (rank == CLERGY_PRIEST || rank == CLERGY_PRIOR || rank == CLERGY_ABBOT) && Character_GetSex(playerid) == 0;
}

stock bool:Clergy_CanBaptise(playerid)
{
	return Clergy_GetRank(playerid) >= CLERGY_DEACON && Character_GetSex(playerid) == 0;
}

stock bool:Clergy_CanAdmit(playerid)
{
	return Clergy_GetRank(playerid) >= CLERGY_PRIOR;
}

stock Clergy_Address(playerid,dest[],size = sizeof(dest))
{
	new name[CHARACTER_NAME_MAX * 2 + 2], given[CHARACTER_NAME_MAX + 1], E_CLERGY_RANK:rank = Clergy_GetRank(playerid), bool:isWoman = Character_GetSex(playerid) == 1;
	Character_GetName(playerid,name);
	strcopy(given,name);

	new space = strfind(given," ");

	if (space > 0)
	{
		given[space] = EOS;
	}

	switch (rank)
	{
		case CLERGY_PRIEST: format(dest,size,"Father %s",given);
		case CLERGY_DEACON: format(dest,size,"Deacon %s",given);
		case CLERGY_PRIOR: format(dest,size,isWoman ? ("Prioress %s") : ("Prior %s"),given);
		case CLERGY_ABBOT: format(dest,size,isWoman ? ("Mother %s") : ("Abbot %s"),given);
		case CLERGY_BROTHER, CLERGY_LAY: format(dest,size,isWoman ? ("Sister %s") : ("Brother %s"),given);
		default: strcopy(dest,name,size);
	}
}

stock bool:Clergy_SetRank(playerid,E_CLERGY_RANK:rank,appointedBy = 0)
{
	if (!Clergy_IsLoaded(playerid) || !Clergy_RankAllowed(rank,Character_GetSex(playerid)))
	{
		return false;
	}

	new E_CLERGY_RANK:before = s_ClergyRank[playerid], characterid = Character_GetId(playerid);
	s_ClergyRank[playerid] = rank;

	if (rank == CLERGY_NONE)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM church_members WHERE character_id = %d",characterid));
	}
	else
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO church_members (character_id, church_rank, since_day, appointed_by) VALUES (%d, %d, %d, %d) ON DUPLICATE KEY UPDATE church_rank = VALUES(church_rank), appointed_by = VALUES(appointed_by)",characterid,_:rank,Family_Today(),appointedBy));
	}

	Clergy_Announce(playerid,before,rank);
	pawn_call_public("Clergy_OnRankChanged","ddd",playerid,_:before,_:rank);
	return true;
}

static Clergy_Announce(playerid,E_CLERGY_RANK:before,E_CLERGY_RANK:rank)
{
	new name[CHARACTER_NAME_MAX * 2 + 2], title[CLERGY_TITLE_LEN], article[4], sex = Character_GetSex(playerid);
	Character_GetName(playerid,name);
	Clergy_RankTitle(rank,sex,title);
	strcopy(article,Util_StartsWithVowel(title) ? ("an") : ("a"));

	if (rank == CLERGY_NONE)
	{
		Gui_Notify(playerid,"You leave the Church and go back to the world.");
		return;
	}

	title[0] = tolower(title[0]);

	switch (rank)
	{
		case CLERGY_NOVICE:
		{
			Gui_Notify(playerid,"You take the novice's habit. The monastery is your home now; learn its hours and its work.");
			Crier_Announce(CRIER_KIND_FAITH,"A novice at the monastery",sprintf("%s has taken the novice's habit at the monastery.",name));
		}
		case CLERGY_DEACON, CLERGY_PRIEST:
		{
			Gui_Notify(playerid,sprintf("You are ordained %s %s. %s",article,title,rank == CLERGY_PRIEST ? ("You may say mass, marry and baptise.") : ("You may serve at the altar and baptise.")));
			Crier_Announce(CRIER_KIND_FAITH,"An ordination",sprintf("%s was ordained %s %s by the bishop.",name,article,title));
		}
		case CLERGY_PRIOR, CLERGY_ABBOT:
		{
			Gui_Notify(playerid,sprintf("You are made %s %s of the monastery.",article,title));
			Crier_Announce(CRIER_KIND_FAITH,"The monastery has a new head",sprintf("%s is now the %s of the monastery.",name,title));
		}
		default:
		{
			if (rank > before)
			{
				Gui_Notify(playerid,sprintf("You are received as %s %s.",article,title));
			}
			else
			{
				Gui_Notify(playerid,sprintf("You serve as %s %s now.",article,title));
			}
		}
	}
}

static Clergy_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT church_rank FROM church_members WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new rank = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"church_rank",rank);
	}

	s_ClergyRank[playerid] = E_CLERGY_RANK:clamp(rank,0,_:CLERGY_RANK_COUNT - 1);
	s_ClergyLoaded[playerid] = true;
}

static Clergy_OfferNovice(playerid,priorid)
{
	yield 1;

	new token = Account_GetToken(playerid), priorToken = Account_GetToken(priorid), prior[CHARACTER_NAME_MAX * 2 + 8], text[256], Float:x, Float:y, Float:width;
	Clergy_Address(priorid,prior);
	format(text,sizeof(text),"~y~%s~w~ asks if you will enter the Church as a novice.~n~~n~You'd live by the monastery's hours and learn its work. Holy orders come later, from the bishop.",prior);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Holy orders");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,Gui_TextHeight(text,300.0) + KIT_ROW + 10.0,"Holy orders",x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new Float:buttonY = y + Gui_TextHeight(text,300.0) + 8.0;
	Kit_AddButton(playerid,x,buttonY,width * 0.45,"Take the habit",1,KIT_COLOUR_ACCENT);
	Kit_AddButton(playerid,x + width * 0.55,buttonY,width * 0.45,"Decline",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	new name[CHARACTER_NAME_MAX * 2 + 2];
	Character_GetName(playerid,name);

	if (pick != 1)
	{
		if (IsPlayerConnected(priorid) && Account_GetToken(priorid) == priorToken)
		{
			Gui_Notify(priorid,sprintf("%s declines to enter the Church.",name));
		}

		return;
	}

	if (Clergy_GetRank(playerid) == CLERGY_NONE && Clergy_SetRank(playerid,CLERGY_NOVICE,Character_GetId(priorid)) && IsPlayerConnected(priorid) && Account_GetToken(priorid) == priorToken)
	{
		Gui_Notify(priorid,sprintf("%s takes the novice's habit.",name));
	}
}

forward Clergy_LoadDeferred(playerid,token);

public Clergy_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Clergy_Load(playerid,token);
	}

	return 1;
}

forward Clergy_OfferDeferred(playerid,priorid);

public Clergy_OfferDeferred(playerid,priorid)
{
	if (IsPlayerConnected(playerid) && IsPlayerConnected(priorid) && !Gui_IsBusy(playerid))
	{
		Clergy_OfferNovice(playerid,priorid);
	}

	return 1;
}

stock bool:Clergy_Offer(playerid,priorid)
{
	if (!Util_IsValidPlayer(playerid) || !Util_IsValidPlayer(priorid) || !Clergy_CanAdmit(priorid) || Clergy_GetRank(playerid) != CLERGY_NONE || !Session_IsPlaying(playerid))
	{
		return false;
	}

	SetTimerEx("Clergy_OfferDeferred",0,false,"dd",playerid,priorid);
	return true;
}

stock Clergy_GetTitle(playerid,dest[],size = sizeof(dest))
{
	Clergy_RankTitle(Clergy_GetRank(playerid),Character_GetSex(playerid),dest,size);
}

forward Clergy_OnRankChanged(playerid,from,to);

public Clergy_OnRankChanged(playerid,from,to)
{
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:ordain(cmdid, playerid, params[])
{
	new targetid, rankName[CLERGY_TITLE_LEN];

	if (sscanf(params,"us[16]",targetid,rankName) || !Util_IsValidPlayer(targetid))
	{
		Command_Usage(playerid,cmdid,"<player> <none|novice|lay|brother|sister|deacon|priest|prior|prioress|abbot|abbess>");
		return 1;
	}

	new E_CLERGY_RANK:rank = Clergy_ParseRank(rankName);

	if (rank == CLERGY_RANK_COUNT || !Clergy_SetRank(targetid,rank,Character_GetId(playerid)))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,"That rank doesn't fit: deacons and priests are men, as the Church ordains them.");
		return 1;
	}

	SendClientMessage(playerid,COMMAND_COLOUR_HINT,"Done.");
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_ClergyRank[playerid] = CLERGY_NONE;
	s_ClergyLoaded[playerid] = false;
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	s_ClergyRank[playerid] = CLERGY_NONE;
	s_ClergyLoaded[playerid] = false;
	SetTimerEx("Clergy_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	s_ClergyRank[playerid] = CLERGY_NONE;
	s_ClergyLoaded[playerid] = false;
}
