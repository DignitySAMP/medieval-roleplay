#define ACCOUNT_QUIZ_DRAW (8)
#define ACCOUNT_QUIZ_PASS (5)
#define ACCOUNT_QUIZ_OPTIONS (3)
#define ACCOUNT_QUIZ_COOLDOWN_MIN (30)
#define ACCOUNT_QUIZ_CAP_FAILS (3)
#define ACCOUNT_QUIZ_CAP_HOURS (12)
#define ACCOUNT_QUIZ_BANNED (-1)
#define ACCOUNT_QUIZ_APPEAL "discord.gg/X52XVYHz5s"
#define ACCOUNT_QUIZ_TEXT_LEN (144)
#define ACCOUNT_QUIZ_OPTION_LEN (96)

enum E_ACCOUNT_QUIZ
{
	E_ACCOUNT_QUIZ_TEXT[ACCOUNT_QUIZ_TEXT_LEN],
	E_ACCOUNT_QUIZ_OPTION_A[ACCOUNT_QUIZ_OPTION_LEN],
	E_ACCOUNT_QUIZ_OPTION_B[ACCOUNT_QUIZ_OPTION_LEN],
	E_ACCOUNT_QUIZ_OPTION_C[ACCOUNT_QUIZ_OPTION_LEN],
	E_ACCOUNT_QUIZ_ANSWER,
}

static const s_AccountQuizPool[][E_ACCOUNT_QUIZ] = {
	{"What does \"in character\" (IC) mean?", "What your character says and does in the world", "Anything you type in chat", "Talking about the game with your friends", 0},
	{"You need to ask a quick out-of-character question during a scene. What do you do?", "Ask it in character and hope they understand", "Ask it briefly with /b, the local OOC chat", "Stop the scene for a long chat about it", 1},
	{"Your character says \"brb, my food is here\" in the normal chat. What's wrong with that?", "Nothing, everyone understands it", "Food didn't arrive like that in the 1200s, so say \"bread\"", "It's out-of-character talk in the in-character chat, it belongs in /b", 2},
	{"Another character insults yours in a scene and it stings you as a player. What's best?", "Insult the player back in /b", "Keep it in character, and ask staff if it really crosses a line", "Leave the server without a word", 1},
	{"A friend tells you on Discord where another character is hiding. What do you do?", "Go there, it's a free advantage", "Act as if you don't know, because your character doesn't", "Tell everyone in the area", 1},
	{"You meet a stranger whose name your character never heard. What can you call them?", "Their real name, you know it from Discord", "What your character would call them, like \"the tall man\"", "Their account name", 1},
	{"You watch a friend's stream and see where a rival character is. Can your character act on it?", "Yes, it's just information", "Yes, but only at night", "No, your character has no way to know it", 2},
	{"In /b, a player mentions their character carries a full purse. Can your character rob them for it?", "No, your character never heard it", "Yes, they said it themselves", "Yes, if you wait an hour first", 0},
	{"Your first character knows where a stash is hidden. Can your second character go and take it?", "Yes, it's the same account", "No, they're two different people who share nothing", "Yes, if you take only half", 1},
	{"Another player swings a sword at your character. What's fair?", "Say your character dodges and hits back in one line", "Describe how your character reacts and let the other player respond", "Say the sword breaks on your character", 1},
	{"Which of these is powergaming?", "Writing that your character trips over a root", "Writing \"/me ties him up and takes his purse\" in one go", "Asking the other player how their character reacts", 1},
	{"A player stands still and doesn't answer, and their name shows (away). Can you rob them?", "Yes, they should have logged off", "No, they can't react, so there's no roleplay", "Yes, if you write it with /me", 1},
	{"Which /me line forces an outcome on another player?", "/me swings his club at the man's arm.", "/me reaches for the man's purse.", "/me stabs the man and he falls dead.", 2},
	{"Your character strikes a passing stranger for no reason at all. What is that?", "Fine, it's a dangerous world", "Attacking without a roleplay reason, which isn't allowed", "Good roleplay, it starts a story", 1},
	{"You just bought a new sword and want to try it out. What's fine?", "Hit the first player you meet", "Hit someone who is away, so nobody gets upset", "Spar with someone who agreed to it", 2},
	{"When can your character kill another character?", "Whenever you're bored", "When there's a roleplay reason and the other player could react", "Whenever they insult you once", 1},
	{"Your character died for good and you think it was unfair. What can you do?", "Make a new character and take revenge", "Appeal to staff and wait for their answer", "Ignore the rules for a week", 1},
	{"Your character has captured a thief and wants him hanged. What's needed?", "A roleplay reason and a scene the other player can take part in", "Nothing, captives have no say", "A friend to say it's fine on Discord", 0},
	{"Your character was killed and wakes at the chapel. Can they run straight back to the killer for revenge?", "Yes, they remember everything", "Yes, but only with friends", "No, treat it as a fresh start and don't rush back to that fight", 2},
	{"A man holds a knife to your character's throat and wants their purse. What would your character do?", "Fight back, you'll wake up at the chapel anyway", "Be afraid and do what your character would do to stay alive", "Ignore him and keep talking", 1},
	{"Three armed guards surround your unarmed character. What's good roleplay?", "Draw your knife and charge them all", "Log off before they can act", "Play the fear and talk, give in or try to slip away", 2},
	{"How should your character treat a deadly threat?", "Like a real person who fears for their life", "Without a care, death costs little", "Laugh at it and walk on", 0},
	{"You're about to be arrested. Is it fine to go away from your keyboard so you avoid it?", "Yes, nobody can arrest a player who is away", "No, going away to dodge roleplay is against the rules", "Yes, if you say so on Discord first", 1},
	{"You need to leave your keyboard for twenty minutes. What's best?", "Leave your character standing in the market", "Ask someone to watch your character", "Log off, or go to your own room first", 2},
	{"You're losing a fight. Is it fine to disconnect?", "Yes, it saves your character", "No, leaving to escape a fight or an arrest is against the rules", "Yes, if you reconnect quickly", 1},
	{"Your character is tied up by bandits and you really have to go. What's best?", "Just quit, it's only a game", "Say so in /b and ask to end the scene fairly", "Pretend your character escaped and log off", 1},
	{"Which of these can your character say in a tavern?", "\"Send a messenger when the harvest is in.\"", "\"I'll text you when the harvest is in.\"", "\"Let me check the map on my phone.\"", 0},
	{"Which idea doesn't exist for a farmer in the 1200s?", "Paying a tithe to the church", "Voting for a mayor in an election", "Trading a cow for grain", 1},
	{"Your character is asked where they learned to read. What fits the setting?", "\"At school, like everyone.\"", "\"A monk taught me letters as a boy.\"", "\"I watched videos online.\"", 1},
	{"Your character needs to reach a friend in another village. How do they do it?", "Send them a quick message on their phone", "Email them before dinner", "Write a letter, or go there in person", 2},
	{"Which of these names fits a character here?", "Agnes Weber", "xXSlayerXx", "Jayden McRich", 0},
	{"Your character falls ill. What fits the setting?", "Herbs, rest and a prayer", "Pills from the pharmacy", "A trip to the hospital by car", 0},
	{"You want a scene to turn intimate. What comes first?", "Doing it before they can object", "Asking the other player out of character if they're fine with it", "Nothing, roleplay is always allowed", 1},
	{"The other player says they're not comfortable with where a scene is going. What do you do?", "Stop and take the scene somewhere else", "Finish it, it was almost over", "Ask them again in a minute", 0},
	{"You want to play out something cruel, like torture, on another character. What comes first?", "Nothing, it's roleplay", "Asking the other player out of character if they're fine with it", "Doing it fast so it's over sooner", 1},
	{"Which /me line is written well?", "/me pulls his hood up and looks away.", "/me I'm so tired lol", "/me wins the fight.", 0},
	{"What is /do for?", "Talking out of character", "Saying something out loud", "Describing what others can see, like \"The door is barred from inside.\"", 2},
	{"You find a spot where you can walk through a wall into someone's house. What do you do?", "Use it, the house is open", "Report it to staff and leave it alone", "Tell your friends about it", 1},
	{"A member of staff asks you to stop a scene. What do you do?", "Stop, and talk it over with staff afterwards if you disagree", "Keep going, it's your scene", "Argue in the chat until they give up", 0},
	{"Another player breaks the rules against you. What's best?", "Break a rule back so it's even", "Shout about it in the chat", "Keep playing, then report it to staff", 2},
	{"You're in a hurry. Is it fine to gallop your horse through the crowded market?", "Yes, they'll move", "No, play it like a real rider in a crowd", "Yes, if you shout first", 1},
	{"Can your character be hurt while your name shows (away)?", "Yes, always", "No, but going away to escape a scene is still against the rules", "Only by staff", 1}
};

static s_AccountQuizDrawn[MAX_PLAYERS][ACCOUNT_QUIZ_DRAW];
static s_AccountQuizOrder[MAX_PLAYERS][ACCOUNT_QUIZ_DRAW][ACCOUNT_QUIZ_OPTIONS];
static s_AccountQuizGiven[MAX_PLAYERS][ACCOUNT_QUIZ_DRAW];

static Account_QuizOptionText(question,option,dest[],size)
{
	switch (option)
	{
		case 0: strcopy(dest,s_AccountQuizPool[question][E_ACCOUNT_QUIZ_OPTION_A],size);
		case 1: strcopy(dest,s_AccountQuizPool[question][E_ACCOUNT_QUIZ_OPTION_B],size);
		default: strcopy(dest,s_AccountQuizPool[question][E_ACCOUNT_QUIZ_OPTION_C],size);
	}
}

static bool:Account_QuizValidIndex(index)
{
	return index >= 0 && index < ACCOUNT_QUIZ_DRAW;
}

Account_QuizDraw(playerid)
{
	new pool[sizeof(s_AccountQuizPool)], count = sizeof(s_AccountQuizPool);

	for (new i = 0;i < count;i++)
	{
		pool[i] = i;
	}

	for (new i = 0;i < ACCOUNT_QUIZ_DRAW;i++)
	{
		new pick = i + random(count - i), swap = pool[i];
		pool[i] = pool[pick];
		pool[pick] = swap;
		s_AccountQuizDrawn[playerid][i] = pool[i];
		s_AccountQuizGiven[playerid][i] = -1;

		for (new option = 0;option < ACCOUNT_QUIZ_OPTIONS;option++)
		{
			s_AccountQuizOrder[playerid][i][option] = option;
		}

		for (new option = ACCOUNT_QUIZ_OPTIONS - 1;option > 0;option--)
		{
			new other = random(option + 1), held = s_AccountQuizOrder[playerid][i][option];
			s_AccountQuizOrder[playerid][i][option] = s_AccountQuizOrder[playerid][i][other];
			s_AccountQuizOrder[playerid][i][other] = held;
		}
	}
}

Account_QuizGetText(playerid,index,dest[],size = sizeof(dest))
{
	if (!Account_QuizValidIndex(index))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_AccountQuizPool[s_AccountQuizDrawn[playerid][index]][E_ACCOUNT_QUIZ_TEXT],size);
}

Account_QuizGetOption(playerid,index,slot,dest[],size = sizeof(dest))
{
	if (!Account_QuizValidIndex(index) || slot < 0 || slot >= ACCOUNT_QUIZ_OPTIONS)
	{
		dest[0] = EOS;
		return -1;
	}

	new option = s_AccountQuizOrder[playerid][index][slot];
	Account_QuizOptionText(s_AccountQuizDrawn[playerid][index],option,dest,size);
	return option;
}

bool:Account_QuizSetAnswer(playerid,index,option)
{
	if (!Account_QuizValidIndex(index) || option < 0 || option >= ACCOUNT_QUIZ_OPTIONS)
	{
		return false;
	}

	s_AccountQuizGiven[playerid][index] = option;
	return true;
}

stock Account_GetQuizAnswer(playerid,index)
{
	if (!Util_IsValidPlayer(playerid) || !Account_QuizValidIndex(index))
	{
		return -1;
	}

	return s_AccountQuizPool[s_AccountQuizDrawn[playerid][index]][E_ACCOUNT_QUIZ_ANSWER];
}

Account_QuizScore(playerid)
{
	new score = 0;

	for (new i = 0;i < ACCOUNT_QUIZ_DRAW;i++)
	{
		if (s_AccountQuizGiven[playerid][i] == Account_GetQuizAnswer(playerid,i))
		{
			score++;
		}
	}

	return score;
}

Account_QuizDescribeWait(seconds,dest[],size = sizeof(dest))
{
	if (seconds >= 3600)
	{
		new hours = (seconds + 3599) / 3600;
		format(dest,size,hours == 1 ? ("%d hour") : ("%d hours"),hours);
		return;
	}

	new minutes = max(1,(seconds + 59) / 60);
	format(dest,size,minutes == 1 ? ("%d minute") : ("%d minutes"),minutes);
}

forward Task:Account_QuizWaitFor(const name[],const ip[]);

#pragma warning push
#pragma warning disable 204
async Task:Account_QuizWaitFor(const name[],const ip[])
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS fails, IFNULL(TIMESTAMPDIFF(SECOND, MAX(created_at), NOW()), 0) AS since FROM account_quiz_attempts WHERE passed = 0 AND cleared = 0 AND (name = '%e' OR ip = '%e') AND created_at > NOW() - INTERVAL %d HOUR",name,ip,ACCOUNT_QUIZ_CAP_HOURS));

	if (mysql_errno(g_Mysql) != 0 || cache_num_rows() == 0)
	{
		return async 0;
	}

	new fails, since;
	cache_get_value_name_int(0,"fails",fails);
	cache_get_value_name_int(0,"since",since);

	if (fails == 0)
	{
		return async 0;
	}

	if (fails >= ACCOUNT_QUIZ_CAP_FAILS)
	{
		return async ACCOUNT_QUIZ_BANNED;
	}

	return async max(0,ACCOUNT_QUIZ_COOLDOWN_MIN * 60 - since);
}
#pragma warning pop

forward Task:Account_QuizLog(accountid,const name[],const ip[],score,bool:passed);

#pragma warning push
#pragma warning disable 204
async Task:Account_QuizLog(accountid,const name[],const ip[],score,bool:passed)
{
	new held[ACCOUNT_USERNAME_MAX + 1], heldIp[17];
	strcopy(held,name);
	strcopy(heldIp,ip);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO account_quiz_attempts (account_id, name, ip, score, asked, passed) VALUES (NULLIF(%d, 0), '%e', '%e', %d, %d, %d)",accountid,name,ip,score,ACCOUNT_QUIZ_DRAW,passed ? 1 : 0));

	if (passed)
	{
		await mysql_aquery_s(g_Mysql,str_format("UPDATE account_quiz_attempts SET cleared = 1 WHERE passed = 0 AND cleared = 0 AND (name = '%e' OR ip = '%e')",held,heldIp));
	}

	return async 1;
}
#pragma warning pop

forward Task:Account_QuizClear(const name[]);

#pragma warning push
#pragma warning disable 204
async Task:Account_QuizClear(const name[])
{
	await mysql_aquery_s(g_Mysql,str_format("UPDATE account_quiz_attempts SET cleared = 1 WHERE passed = 0 AND cleared = 0 AND (name = '%e' OR ip IN (SELECT ip FROM (SELECT DISTINCT ip FROM account_quiz_attempts WHERE name = '%e') AS tried))",name,name));
	return async (mysql_errno(g_Mysql) == 0 ? cache_affected_rows() : -1);
}
#pragma warning pop
