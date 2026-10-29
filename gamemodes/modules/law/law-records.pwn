#define LAW_NOTICE_WAIT_MS (4000)

enum E_LAW_WANTED
{
	E_LAW_WANTED_BOUNTY,
	E_LAW_WANTED_UNTIL,
	E_LAW_WANTED_CRIME,
}

static s_LawWanted[MAX_PLAYERS][E_LAW_WANTED];
static s_LawLastCrimeAt[MAX_PLAYERS][LAW_CRIME_COUNT];
static s_LawLastVictim[MAX_PLAYERS][LAW_CRIME_COUNT];
static s_LawSoughtWitnesses;

stock Law_GetCrimeName(kind,dest[],size = sizeof(dest))
{
	if (kind < 0 || kind >= LAW_CRIME_COUNT)
	{
		strcopy(dest,"a crime",size);
		return;
	}

	strcopy(dest,g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_NAME],size);
}

stock Law_GetFine(kind)
{
	return kind >= 0 && kind < LAW_CRIME_COUNT ? g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_FINE] * Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_FINE_SCALE) / 100 : 0;
}

stock bool:Law_IsWanted(playerid)
{
	return Util_IsValidPlayer(playerid) && s_LawWanted[playerid][E_LAW_WANTED_UNTIL] > gettime();
}

stock Law_GetBounty(playerid)
{
	return Law_IsWanted(playerid) ? s_LawWanted[playerid][E_LAW_WANTED_BOUNTY] : 0;
}

stock Law_GetWantedCrime(playerid)
{
	return Law_IsWanted(playerid) ? s_LawWanted[playerid][E_LAW_WANTED_CRIME] : -1;
}

stock Law_GetWantedUntil(playerid)
{
	return Law_IsWanted(playerid) ? s_LawWanted[playerid][E_LAW_WANTED_UNTIL] : 0;
}

stock Law_DescribeLook(playerid,dest[],size = sizeof(dest))
{
	new age = Lineage_IsLoaded(playerid) ? Lineage_GetAge(playerid) : Character_GetAge(playerid), bool:isWoman = Character_GetSex(playerid) == 1, look[SKIN_LOOK_LEN], skin = GetPlayerCustomSkin(playerid);

	if (!Skins_GetLook(skin,look))
	{
		Skins_GetLook(Character_GetSkin(playerid),look);
	}

	if (age < 25)
	{
		format(dest,size,"a young %s",isWoman ? ("woman") : ("man"));
	}
	else if (age < 50)
	{
		format(dest,size,"a %s",isWoman ? ("woman") : ("man"));
	}
	else
	{
		format(dest,size,"an old %s",isWoman ? ("woman") : ("man"));
	}

	if (look[0] != EOS)
	{
		strcat(dest," ",size);
		strcat(dest,look,size);
	}
}

stock Law_Describe(playerid,dest[],size = sizeof(dest))
{
	Law_DescribeLook(playerid,dest,size);

	if (Light_HasLight(playerid))
	{
		strcat(dest,", carrying a light",size);
	}
}

stock Law_GetKnownOrLook(viewerid,targetid,dest[],size = sizeof(dest),bool:capital = false)
{
	Nametag_GetKnownName(viewerid,targetid,dest,size);

	if (strcmp(dest,NAMETAG_STRANGER) != 0 || !Util_IsValidPlayer(targetid))
	{
		return;
	}

	new look[LAW_DESCRIPTION_LEN];
	Law_DescribeLook(targetid,look);

	if (capital)
	{
		look[0] = toupper(look[0]);
	}

	format(dest,size,"~y~%s~w~",look);
}

stock Float:Law_WitnessRange(Float:x,Float:y,Float:z,world)
{
	if (!Calendar_IsNight())
	{
		return LAW_WITNESS_DAY;
	}

	return Light_IsLitNear(x,y,z,world) ? LAW_WITNESS_DAY : LAW_WITNESS_DARK;
}

stock bool:Law_CanSee(witnessid,targetid,Float:range)
{
	if (witnessid == targetid || !Session_IsPlaying(witnessid) || GetPlayerVirtualWorld(witnessid) != GetPlayerVirtualWorld(targetid))
	{
		return false;
	}

	new Float:wx, Float:wy, Float:wz, Float:tx, Float:ty, Float:tz, Float:hx, Float:hy, Float:hz;
	GetPlayerPos(witnessid,wx,wy,wz);
	GetPlayerPos(targetid,tx,ty,tz);

	if (Util_GetDistance3D(wx,wy,wz,tx,ty,tz) > range)
	{
		return false;
	}

	if (GetPlayerInterior(witnessid) != 0 || GetPlayerVirtualWorld(witnessid) != 0)
	{
		return true;
	}

	return CA_RayCastLine(wx,wy,wz + LAW_EYE_Z,tx,ty,tz + LAW_EYE_Z,hx,hy,hz) == 0;
}

stock Law_AddWitnesses(count)
{
	if (count > 0)
	{
		s_LawSoughtWitnesses += count;
	}
}

static Law_SeekWitnesses(offenderid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(offenderid,x,y,z);
	s_LawSoughtWitnesses = 0;
	pawn_call_public("Law_OnSeekWitnesses","dfffd",offenderid,x,y,z,GetPlayerVirtualWorld(offenderid));
	return s_LawSoughtWitnesses;
}

stock Law_Commit(offenderid,kind,victimid = INVALID_PLAYER_ID,extraWitnesses = 0)
{
	if (!Util_IsValidPlayer(offenderid) || !Session_IsPlaying(offenderid) || kind < 0 || kind >= LAW_CRIME_COUNT)
	{
		return -1;
	}

	new now = gettime();

	if (now - s_LawLastCrimeAt[offenderid][kind] < LAW_REPEAT_SECONDS && s_LawLastVictim[offenderid][kind] == victimid)
	{
		return -1;
	}

	s_LawLastCrimeAt[offenderid][kind] = now;
	s_LawLastVictim[offenderid][kind] = victimid;

	new Float:x, Float:y, Float:z, world = GetPlayerVirtualWorld(offenderid), witnesses = extraWitnesses, description[LAW_DESCRIPTION_LEN];
	GetPlayerPos(offenderid,x,y,z);
	Law_Describe(offenderid,description);

	new Float:range = Law_WitnessRange(x,y,z,world), crime[LAW_NAME_LEN];
	Law_GetCrimeName(kind,crime);

	foreach (new i : Player)
	{
		if (i == offenderid || IsPlayerNPC(i) || !Law_CanSee(i,offenderid,range))
		{
			continue;
		}

		new known[LAW_DESCRIPTION_LEN + 8], text[200];
		Law_GetKnownOrLook(i,offenderid,known);
		if (i == victimid)
		{
			format(text,sizeof(text),"You saw who it was: %s.",known);
		}
		else
		{
			format(text,sizeof(text),"You saw %s %s.",known,g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_VERB]);
		}
		Gui_Notify(i,text);
		witnesses++;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO crimes (county_id, kind, offender_character_id, victim_character_id, x, y, z, at, witnessed, reported, description) VALUES (%d, %d, %d, %s, %f, %f, %f, %d, %d, %d, '%e')",LAW_COUNTY,kind,Character_GetId(offenderid),victimid != INVALID_PLAYER_ID ? sprintf("%d",Character_GetId(victimid)) : ("NULL"),x,y,z,now,witnesses,witnesses > 0 && g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_WANTED_DAYS] > 0 ? 1 : 0,description));

	if (witnesses > 0 && g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_WANTED_DAYS] > 0)
	{
		Gui_Notify(offenderid,"Someone saw you. Word will reach the guards.");
		Law_SetWanted(offenderid,kind,description);
	}

	pawn_call_public("Law_OnCrime","ddd",offenderid,kind,witnesses);
	return witnesses;
}

stock Law_SetWanted(playerid,kind,const description[])
{
	new now = gettime(), until = now + g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_WANTED_DAYS] * LAW_DAY_SECONDS;
	new bounty = min(Law_GetBounty(playerid) + g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_FINE] * LAW_BOUNTY_FACTOR,LAW_BOUNTY_CAP);

	if (Law_IsWanted(playerid) && s_LawWanted[playerid][E_LAW_WANTED_UNTIL] > until)
	{
		until = s_LawWanted[playerid][E_LAW_WANTED_UNTIL];
	}

	if (!Law_IsWanted(playerid) || g_LawCrimeDefs[kind][E_LAW_CRIME_DEF_FINE] >= Law_GetFine(s_LawWanted[playerid][E_LAW_WANTED_CRIME]))
	{
		s_LawWanted[playerid][E_LAW_WANTED_CRIME] = kind;
	}

	s_LawWanted[playerid][E_LAW_WANTED_BOUNTY] = bounty;
	s_LawWanted[playerid][E_LAW_WANTED_UNTIL] = until;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO wanted (character_id, county_id, bounty, crime, description, since, expires_at) VALUES (%d, %d, %d, %d, '%e', %d, %d) ON DUPLICATE KEY UPDATE bounty = VALUES(bounty), crime = VALUES(crime), description = VALUES(description), expires_at = VALUES(expires_at)",Character_GetId(playerid),LAW_COUNTY,bounty,s_LawWanted[playerid][E_LAW_WANTED_CRIME],description,now,until));

	new crime[LAW_NAME_LEN], text[200];
	Law_GetCrimeName(s_LawWanted[playerid][E_LAW_WANTED_CRIME],crime);
	format(text,sizeof(text),"Wanted for %s: %s. The county pays %d pfennig to whoever brings them in.",crime,description,bounty);
	Crier_Announce(LAW_CRIER_KIND,"Wanted",text);

	foreach (new i : Player)
	{
		if (Law_IsGuard(i) && i != playerid)
		{
			if (Subtitle_IsShown(i))
			{
				SetTimerEx("Law_NotifyLater",LAW_NOTICE_WAIT_MS,false,"ds",i,text);
			}
			else
			{
				Gui_Notify(i,text);
			}
		}
	}

	pawn_call_public("Law_OnWanted","dd",playerid,bounty);
}

stock Law_ClearWanted(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_LawWanted[playerid][E_LAW_WANTED_BOUNTY] = 0;
	s_LawWanted[playerid][E_LAW_WANTED_UNTIL] = 0;
	s_LawWanted[playerid][E_LAW_WANTED_CRIME] = -1;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM wanted WHERE character_id = %d AND county_id = %d",Character_GetId(playerid),LAW_COUNTY));
}

stock Law_ResetRecords(playerid)
{
	s_LawWanted[playerid][E_LAW_WANTED_BOUNTY] = 0;
	s_LawWanted[playerid][E_LAW_WANTED_UNTIL] = 0;
	s_LawWanted[playerid][E_LAW_WANTED_CRIME] = -1;

	for (new i = 0;i < LAW_CRIME_COUNT;i++)
	{
		s_LawLastCrimeAt[playerid][i] = 0;
		s_LawLastVictim[playerid][i] = INVALID_PLAYER_ID;
	}
}

forward Task:Law_LoadWanted(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Law_LoadWanted(playerid,characterid)
{

	await mysql_aquery_s(g_Mysql,str_format("SELECT bounty, crime, expires_at FROM wanted WHERE character_id = %d AND county_id = %d AND expires_at > %d",characterid,LAW_COUNTY,gettime()));

	if (!cache_num_rows() || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	cache_get_value_name_int(0,"bounty",s_LawWanted[playerid][E_LAW_WANTED_BOUNTY]);
	cache_get_value_name_int(0,"crime",s_LawWanted[playerid][E_LAW_WANTED_CRIME]);
	cache_get_value_name_int(0,"expires_at",s_LawWanted[playerid][E_LAW_WANTED_UNTIL]);
	return async 1;
}
#pragma warning pop

forward Law_OnCrime(offenderid,kind,witnesses);

public Law_OnCrime(offenderid,kind,witnesses)
{
	return 1;
}

forward Law_NotifyLater(playerid,const text[]);

public Law_NotifyLater(playerid,const text[])
{
	if (Session_IsPlaying(playerid))
	{
		Gui_Notify(playerid,text);
	}

	return 1;
}

forward Law_OnSeekWitnesses(offenderid,Float:x,Float:y,Float:z,world);

public Law_OnSeekWitnesses(offenderid,Float:x,Float:y,Float:z,world)
{
	return 1;
}

forward Law_OnWanted(playerid,bounty);

public Law_OnWanted(playerid,bounty)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Law_ResetRecords(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	Law_ResetRecords(playerid);
	Law_LoadWanted(playerid,characterid);
}

hook Combat_OnFelled(attackerid,targetid)
{
	if (Util_IsValidPlayer(attackerid) && attackerid != targetid && !(Law_IsGuard(attackerid) && Law_IsWanted(targetid)))
	{
		Law_Commit(attackerid,LAW_CRIME_ASSAULT,targetid,Law_SeekWitnesses(attackerid));
	}
}

hook Combat_OnExecuted(playerid,executionerid)
{
	if (Util_IsValidPlayer(executionerid) && executionerid != playerid && !(Law_IsGuard(executionerid) && Law_IsWanted(playerid)))
	{
		Law_Commit(executionerid,LAW_CRIME_MURDER,playerid,Law_SeekWitnesses(executionerid));
	}
}
