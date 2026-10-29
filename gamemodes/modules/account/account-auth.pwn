#define ACCOUNT_DOWNLOAD_TIMEOUT_MS (30000)
#define ACCOUNT_WHITELIST_APPROVED (1)

static bool:s_AccountDownloaded[MAX_PLAYERS];
static bool:s_AccountSceneUp[MAX_PLAYERS];
static bool:s_AccountBegun[MAX_PLAYERS];
static s_AccountQuizWait[MAX_PLAYERS];

forward Account_KickPlayer(playerid);

public Account_KickPlayer(playerid)
{
	Kick(playerid);
	return 1;
}

Account_KickDelayed(playerid)
{
	SetTimerEx("Account_KickPlayer",500,false,"d",playerid);
}

Account_WriteAuthLog(playerid,const eventType[])
{
	new name[ACCOUNT_USERNAME_MAX + 1];
	Account_GetName(playerid,name);
	mysql_pquery_s(g_Mysql,str_format("INSERT INTO account_auth_log (account_id, username, event_type, ip) VALUES (%d, '%e', '%e', '%e')",Account_GetId(playerid),name,eventType,Util_GetPlayerIp(playerid)));
}

static Account_Lookup(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid), name[ACCOUNT_USERNAME_MAX + 1];
	Account_GetName(playerid,name);

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, password_hash, admin_level FROM accounts WHERE name = '%e' LIMIT 1",name));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (mysql_errno(g_Mysql) != 0)
	{
		Gui_Notify(playerid,"The server couldn't load your account. Reconnect in a minute.");
		Account_KickDelayed(playerid);
		return;
	}

	s_AccountQuizWait[playerid] = 0;

	if (cache_num_rows() > 0)
	{
		new accountid, hash[BCRYPT_HASH_LENGTH], adminLevel;
		cache_get_value_name_int(0,"id",accountid);
		cache_get_value_name(0,"password_hash",hash);
		cache_get_value_name_int(0,"admin_level",adminLevel);
		Account_SetLookup(playerid,accountid,hash,adminLevel);
		Account_SetAuthState(playerid,E_ACCOUNT_AUTH_DIALOG);
		Session_SetState(playerid,SESSION_AUTH_LOGIN);
		AccountGui_Welcome(playerid,false);
		return;
	}

	new wait = await Account_QuizWaitFor(name,Util_GetPlayerIp(playerid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	s_AccountQuizWait[playerid] = wait;
	Account_SetAuthState(playerid,E_ACCOUNT_AUTH_DIALOG);
	Session_SetState(playerid,SESSION_AUTH_REGISTER);
	AccountGui_Welcome(playerid,true);
}

Account_GetQuizWait(playerid)
{
	return s_AccountQuizWait[playerid];
}

Account_SubmitLogin(playerid,const password[])
{
	new hash[BCRYPT_HASH_LENGTH];
	Account_GetLookupHash(playerid,hash);
	Account_SetAuthState(playerid,E_ACCOUNT_AUTH_VERIFYING);
	bcrypt_verify(playerid,"Account_OnPasswordVerified",password,hash);
}

forward Account_OnPasswordVerified(playerid,bool:success);

public Account_OnPasswordVerified(playerid,bool:success)
{
	if (!IsPlayerConnected(playerid) || Account_GetAuthState(playerid) != E_ACCOUNT_AUTH_VERIFYING)
	{
		return 1;
	}

	if (!success)
	{
		Account_WriteAuthLog(playerid,"login_fail_password");

		if (Account_BumpAttempts(playerid) >= ACCOUNT_MAX_LOGIN_ATTEMPTS)
		{
			Gui_Notify(playerid,"Too many wrong passwords. Reconnect and try again.");
			Account_KickDelayed(playerid);
			return 1;
		}

		Account_SetAuthState(playerid,E_ACCOUNT_AUTH_DIALOG);
		AccountGui_ShowLogin(playerid);
		return 1;
	}

	mysql_pquery_s(g_Mysql,str_format("UPDATE accounts SET last_login_at = NOW(), last_ip = '%e' WHERE id = %d",Util_GetPlayerIp(playerid),Account_GetId(playerid)));
	Account_WriteAuthLog(playerid,"login_ok");
	Account_Complete(playerid);
	return 1;
}

Account_SubmitRegister(playerid,const password[])
{
	Account_SetAuthState(playerid,E_ACCOUNT_AUTH_VERIFYING);
	bcrypt_hash(playerid,"Account_OnPasswordHashed",password,ACCOUNT_BCRYPT_COST);
}

forward Account_OnPasswordHashed(playerid,hashid);

public Account_OnPasswordHashed(playerid,hashid)
{
	#pragma unused hashid

	if (!IsPlayerConnected(playerid) || Account_GetAuthState(playerid) != E_ACCOUNT_AUTH_VERIFYING)
	{
		return 1;
	}

	new hash[BCRYPT_HASH_LENGTH];
	bcrypt_get_hash(hash,sizeof(hash));
	Account_SetLookup(playerid,0,hash,ADMIN_LEVEL_NONE);
	Account_SetAuthState(playerid,E_ACCOUNT_AUTH_DIALOG);
	AccountGui_StartQuiz(playerid);
	return 1;
}

bool:Account_RecordQuizPass(playerid,score)
{
	new token = Account_GetToken(playerid), name[ACCOUNT_USERNAME_MAX + 1], ip[17], hash[BCRYPT_HASH_LENGTH];
	Account_GetName(playerid,name);
	strcopy(ip,Util_GetPlayerIp(playerid));
	Account_GetLookupHash(playerid,hash);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO accounts (name, password_hash, last_ip, last_login_at, whitelist) VALUES ('%e', '%e', '%e', NOW(), %d)",name,hash,ip,ACCOUNT_WHITELIST_APPROVED));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return false;
	}

	if (mysql_errno(g_Mysql) != 0)
	{
		Account_WriteAuthLog(playerid,"register_fail");
		return false;
	}

	Account_SetLookup(playerid,cache_insert_id(),hash,ADMIN_LEVEL_NONE);
	Account_WriteAuthLog(playerid,"register");
	await Account_QuizLog(Account_GetId(playerid),name,ip,score,true);
	return IsPlayerConnected(playerid) && Account_GetToken(playerid) == token;
}

Account_RecordQuizFail(playerid,score)
{
	new token = Account_GetToken(playerid), name[ACCOUNT_USERNAME_MAX + 1], ip[17];
	Account_GetName(playerid,name);
	strcopy(ip,Util_GetPlayerIp(playerid));
	Account_WriteAuthLog(playerid,"quiz_fail");
	await Account_QuizLog(0,name,ip,score,false);
	new wait = await Account_QuizWaitFor(name,ip);

	if (wait == ACCOUNT_QUIZ_BANNED)
	{
		new reason[144];
		format(reason,sizeof(reason),"You failed the roleplay quiz %d times within %d hours. Appeal on our Discord at %s.",ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_CAP_HOURS,ACCOUNT_QUIZ_APPEAL);
		Account_WriteAuthLog(playerid,"quiz_banned");
		pawn_call_public("Account_OnQuizFailedOut","dss",playerid,ip,reason);
		return wait;
	}

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return wait;
	}

	return (wait > 0) ? wait : (ACCOUNT_QUIZ_COOLDOWN_MIN * 60);
}

forward Account_OnQuizFailedOut(playerid,const ip[],const reason[]);

public Account_OnQuizFailedOut(playerid,const ip[],const reason[])
{
	return 1;
}

forward Account_OnQuizReset(staffid,const name[],const ip[]);

public Account_OnQuizReset(staffid,const name[],const ip[])
{
	return 1;
}

Account_FinishQuiz(playerid)
{
	Account_Complete(playerid);
}

static Account_Complete(playerid)
{
	Account_SetAuthState(playerid,E_ACCOUNT_AUTH_DONE);
	Account_ClearLookupHash(playerid);
	PlayerPlaySound(playerid,1052,0.0,0.0,0.0);
	SetTimerEx("Account_FireAuthenticated",0,false,"dd",playerid,Account_GetToken(playerid));
}

forward Account_FireAuthenticated(playerid,token);

public Account_FireAuthenticated(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 1;
	}

	new accountid = Account_GetId(playerid);
	Log_Info("account","player %d logged in as account %d",playerid,accountid);
	Session_SetState(playerid,SESSION_CHARACTER_SELECT);
	pawn_call_public("Account_OnAuthenticated","dd",playerid,accountid);
	return 1;
}

stock Account_RefreshAdminLevel(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid), accountid = Account_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT admin_level, loremaster FROM accounts WHERE id = %d",accountid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || cache_num_rows() == 0)
	{
		return;
	}

	new level, loremaster;
	cache_get_value_name_int(0,"admin_level",level);
	cache_get_value_name_int(0,"loremaster",loremaster);
	Account_SetAdminLevel(playerid,level);
	Account_LoadLoremaster(playerid,loremaster != 0);
}

forward Account_OnAuthenticated(playerid,accountid);

public Account_OnAuthenticated(playerid,accountid)
{
	return 1;
}

static Account_Begin(playerid)
{
	if (!IsDatabaseReady() || !Database_IsSchemaReady())
	{
		SetTimerEx("Account_ConnectRetry",ACCOUNT_DB_RETRY_MS,false,"d",playerid);
		return;
	}

	new name[MAX_PLAYER_NAME + 1];
	GetPlayerName(playerid,name,sizeof(name));

	if (!Account_ValidateUsername(name))
	{
		Gui_Notify(playerid,sprintf("Your name has to be %d to %d letters or numbers. Reconnect with a different name.",ACCOUNT_USERNAME_MIN,ACCOUNT_USERNAME_MAX));
		Account_KickDelayed(playerid);
		return;
	}

	Account_SetName(playerid,name);
	Account_SetAuthState(playerid,E_ACCOUNT_AUTH_LOOKUP);
	SetTimerEx("Account_ConnectDeferred",0,false,"dd",playerid,Account_NewToken(playerid));
}

forward Account_SceneThenBegin(playerid,token);

public Account_SceneThenBegin(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 1;
	}

	s_AccountSceneUp[playerid] = true;
	Scene_LoginDeferred(playerid);

	if (s_AccountDownloaded[playerid])
	{
		Account_BeginOnce(playerid);
	}
	else
	{
		SetTimerEx("Account_DownloadTimeout",ACCOUNT_DOWNLOAD_TIMEOUT_MS,false,"dd",playerid,token);
	}

	return 1;
}

static Account_BeginOnce(playerid)
{
	if (s_AccountBegun[playerid])
	{
		return;
	}

	s_AccountBegun[playerid] = true;
	Account_Begin(playerid);
}

forward Account_DownloadTimeout(playerid,token);

public Account_DownloadTimeout(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Account_BeginOnce(playerid);
	}

	return 1;
}

forward Account_ConnectRetry(playerid);

public Account_ConnectRetry(playerid)
{
	if (!IsPlayerConnected(playerid) || IsPlayerNPC(playerid) || Account_GetAuthState(playerid) != E_ACCOUNT_AUTH_IDLE)
	{
		return 1;
	}

	Account_Begin(playerid);
	return 1;
}

forward Account_ConnectDeferred(playerid,token);

public Account_ConnectDeferred(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 1;
	}

	Account_Lookup(playerid);
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Account_Reset(playerid);

	if (IsPlayerNPC(playerid))
	{
		return;
	}

	s_AccountDownloaded[playerid] = false;
	s_AccountSceneUp[playerid] = false;
	s_AccountBegun[playerid] = false;

	SetTimerEx("Account_SceneThenBegin",SCENE_CONNECT_DELAY_MS,false,"dd",playerid,Account_NewToken(playerid));
}

hook OnPlayerDisconnect(playerid,reason)
{
	Account_Reset(playerid);
}

hook OnPlayerFinishedDownloading(playerid,virtualworld)
{
	#pragma unused virtualworld

	if (IsPlayerNPC(playerid))
	{
		return;
	}

	Scene_OnDownloadsFinished(playerid);

	if (!s_AccountDownloaded[playerid])
	{
		s_AccountDownloaded[playerid] = true;

		if (s_AccountSceneUp[playerid])
		{
			Account_BeginOnce(playerid);
		}
	}
}
