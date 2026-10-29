#define ACCOUNT_GUI_WARNING_TITLE "Read before closing"
#define ACCOUNT_GUI_WELCOME_TITLE "Welcome to Medieval Roleplay"
#define ACCOUNT_GUI_SUMMARY_COLOUR (0xD8CCB2FF)
#define ACCOUNT_GUI_QUIZ_TITLE "The roleplay quiz"
#define ACCOUNT_GUI_PASS_TITLE "You passed"
#define ACCOUNT_GUI_FAIL_TITLE "Not this time"
#define ACCOUNT_GUI_WAIT_TITLE "Come back later"
#define ACCOUNT_GUI_BANNED_TITLE "Banned"
#define ACCOUNT_GUI_REGISTER_TITLE "Registration"
#define ACCOUNT_GUI_CONFIRM_TITLE "Confirm your password"
#define ACCOUNT_GUI_QUIZ_WIDTH (400.0)
#define ACCOUNT_GUI_MESSAGE_WIDTH (340.0)
#define ACCOUNT_GUI_TOP (138.0)
#define ACCOUNT_GUI_LETTER_GAP (12.0)

static const s_AccountLauncherWarning[] = "~r~You're not using the open.mp launcher.~w~~n~~n~Other clients, the standard SA-MP client too, have exploits that can~n~harm your PC. Other players can also read your game data.~n~~n~Get the latest launcher from open.mp. It has many security updates~n~and fixes game bugs that other launchers still have.~n~~n~Staff may disconnect you if your client behaves strangely.";

static const s_AccountWelcome[] = "~w~Medieval Roleplay is set in a fictional kingdom~n~in the 1200s. Everyone here plays a person of that time.~n~~n~~y~Your roleplay has to be historical.~w~ Speak and act~n~the way people did back then. Modern words, ideas~n~and jokes stay out of character.~n~~n~If you're new, the tutorial shows you the basics~n~after you register.";

static bool:AccountGui_IsCurrent(playerid,epoch)
{
	return Gui_IsFlowCurrent(playerid,epoch) && Account_GetAuthState(playerid) == E_ACCOUNT_AUTH_DIALOG;
}

AccountGui_Welcome(playerid,bool:isNew)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid);

	if (!IsPlayerUsingOmp(playerid))
	{
		Gui_ShowMessage(playerid,ACCOUNT_GUI_WARNING_TITLE,s_AccountLauncherWarning,GUI_BUTTON_OKAY,380.0);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		SendClientMessage(playerid,ACCOUNT_GUI_SUMMARY_COLOUR,"Install the open.mp launcher from open.mp to stay protected.");
	}

	Gui_ShowMessage(playerid,ACCOUNT_GUI_WELCOME_TITLE,s_AccountWelcome,"Okay!",340.0);

	if (!AccountGui_IsCurrent(playerid,epoch))
	{
		return;
	}

	MessageSplit_SendClientMessage(playerid,ACCOUNT_GUI_SUMMARY_COLOUR,"Medieval Roleplay is set in a fictional kingdom in the 1200s. Roleplay here has to be historical. Modern words and ideas stay out of character.");

	if (!isNew)
	{
		AccountGui_ShowLogin(playerid);
		return;
	}

	if (Account_GetQuizWait(playerid) != 0)
	{
		AccountGui_ShowCooldown(playerid);
		return;
	}

	AccountGui_ShowRegister(playerid);
}

AccountGui_ShowLogin(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), response[DIALOG_RESPONSE], name[ACCOUNT_USERNAME_MAX + 1], body[256];
	Account_GetName(playerid,name);

	for (;;)
	{
		format(body,sizeof(body),GUI_TEXT "Welcome back to Medieval Roleplay, " GUI_ACCENT "%s" GUI_TEXT ".\n\nEnter your password to continue.",name);

		if (Account_GetAttempts(playerid) > 0)
		{
			format(body,sizeof(body),"%s\n\n" GUI_BAD "That password was wrong. Tries left: %d.",body,ACCOUNT_MAX_LOGIN_ATTEMPTS - Account_GetAttempts(playerid));
		}

		await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_PASSWORD,"Login",body,"Enter",GUI_BUTTON_LEAVE);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		if (!response[DIALOG_RESPONSE_RESPONSE])
		{
			if (!Gui_ConfirmLeave(playerid))
			{
				if (!AccountGui_IsCurrent(playerid,epoch))
				{
					return;
				}

				continue;
			}

			if (!AccountGui_IsCurrent(playerid,epoch))
			{
				return;
			}

			Gui_Notify(playerid,"You need to log in to play.");
			Account_KickDelayed(playerid);
			return;
		}

		if (isnull(response[DIALOG_RESPONSE_INPUTTEXT]))
		{
			continue;
		}

		Account_SubmitLogin(playerid,response[DIALOG_RESPONSE_INPUTTEXT]);
		return;
	}
}

static bool:AccountGui_AskLeave(playerid,epoch)
{
	new bool:isLeaving = Gui_ConfirmLeave(playerid);

	if (!AccountGui_IsCurrent(playerid,epoch))
	{
		return true;
	}

	if (!isLeaving)
	{
		return false;
	}

	Gui_Notify(playerid,"You need to pass the roleplay quiz to play.");
	Account_KickDelayed(playerid);
	return true;
}

static AccountGui_OpenPanel(playerid,const title[],Float:width,Float:contentHeight,&Float:x,&Float:y,&Float:contentWidth)
{
	new Float:height = contentHeight + KIT_PANEL_EXTRA, Float:top = 224.0 - height / 2.0;

	if (top < ACCOUNT_GUI_TOP)
	{
		top = ACCOUNT_GUI_TOP;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_AddPanel(playerid,320.0 - width / 2.0,top,width,height,title,x,y,contentWidth);
}

static Task:AccountGui_Message(playerid,const title[],const text[],const button[],colour)
{
	new Float:x, Float:y, Float:width, Float:textHeight = Gui_TextHeight(text,ACCOUNT_GUI_MESSAGE_WIDTH);
	AccountGui_OpenPanel(playerid,title,ACCOUNT_GUI_MESSAGE_WIDTH,textHeight + KIT_ROW + 10.0,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + textHeight + 8.0,90.0,button,1,colour);
	return Kit_Present(playerid);
}

static Task:AccountGui_Question(playerid,index)
{
	new title[KIT_TITLE_LEN], text[ACCOUNT_QUIZ_TEXT_LEN], option[ACCOUNT_QUIZ_OPTION_LEN], Float:x, Float:y, Float:width;
	new Float:textWidth = ACCOUNT_GUI_QUIZ_WIDTH * (1.0 - KIT_BOX_INSET_X * 2.0), Float:optionWidth = textWidth - ACCOUNT_GUI_LETTER_GAP;
	new Float:questionHeight, Float:contentHeight;
	format(title,sizeof(title),"Question %d of %d",index + 1,ACCOUNT_QUIZ_DRAW);
	Account_QuizGetText(playerid,index,text);
	questionHeight = float(Gui_CountLines(text,textWidth)) * GUI_MESSAGE_LINE;
	contentHeight = questionHeight + 8.0 + GUI_MESSAGE_LINE + 4.0;

	for (new slot = 0;slot < ACCOUNT_QUIZ_OPTIONS;slot++)
	{
		Account_QuizGetOption(playerid,index,slot,option);
		contentHeight += float(Gui_CountLines(option,optionWidth)) * GUI_MESSAGE_LINE + 5.0;
	}

	AccountGui_OpenPanel(playerid,title,ACCOUNT_GUI_QUIZ_WIDTH,contentHeight,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	y += questionHeight + 8.0;

	for (new slot = 0;slot < ACCOUNT_QUIZ_OPTIONS;slot++)
	{
		new value = Account_QuizGetOption(playerid,index,slot,option), Float:rowHeight = float(Gui_CountLines(option,optionWidth)) * GUI_MESSAGE_LINE + 2.0, letter[4];
		format(letter,sizeof(letter),"%c.",'a' + slot);
		Kit_AddHit(playerid,x - 3.0,y - 1.0,width + 6.0,rowHeight,value);
		Kit_AddText(playerid,x,y,letter,KIT_COLOUR_ACCENT,KIT_TEXT_ROW);
		Kit_AddText(playerid,x + ACCOUNT_GUI_LETTER_GAP,y,option,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width - ACCOUNT_GUI_LETTER_GAP);
		y += rowHeight + 3.0;
	}

	Kit_AddText(playerid,x,y + 2.0,"Click the answer you think is right.",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
	return Kit_Present(playerid);
}

AccountGui_ShowRegister(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), response[DIALOG_RESPONSE], name[ACCOUNT_USERNAME_MAX + 1], body[384], error[96], password[ACCOUNT_PASSWORD_MAX + 1];
	Account_GetName(playerid,name);
	error[0] = EOS;

	for (;;)
	{
		format(body,sizeof(body),GUI_TEXT "Welcome to Medieval Roleplay, " GUI_ACCENT "%s" GUI_TEXT ".\n\nChoose a password to guard your account.\nIt must be %d to %d characters long.\n\nAfter this you take a short quiz about roleplay here.",name,ACCOUNT_PASSWORD_MIN,ACCOUNT_PASSWORD_MAX);

		if (error[0] != EOS)
		{
			format(body,sizeof(body),"%s\n\n" GUI_BAD "%s",body,error);
		}

		await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_PASSWORD,ACCOUNT_GUI_REGISTER_TITLE,body,GUI_BUTTON_CONTINUE,GUI_BUTTON_LEAVE);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		if (!response[DIALOG_RESPONSE_RESPONSE])
		{
			if (AccountGui_AskLeave(playerid,epoch))
			{
				return;
			}

			continue;
		}

		new length = strlen(response[DIALOG_RESPONSE_INPUTTEXT]);

		if (length < ACCOUNT_PASSWORD_MIN || length > ACCOUNT_PASSWORD_MAX)
		{
			format(error,sizeof(error),"That password is %s. Use %d to %d characters.",(length < ACCOUNT_PASSWORD_MIN) ? ("too short") : ("too long"),ACCOUNT_PASSWORD_MIN,ACCOUNT_PASSWORD_MAX);
			continue;
		}

		strcopy(password,response[DIALOG_RESPONSE_INPUTTEXT]);
		await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_PASSWORD,ACCOUNT_GUI_CONFIRM_TITLE,GUI_TEXT "Type the same password again, so you know you have it right.","Enter",GUI_BUTTON_BACK);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		if (!response[DIALOG_RESPONSE_RESPONSE])
		{
			error[0] = EOS;
			continue;
		}

		if (isnull(response[DIALOG_RESPONSE_INPUTTEXT]) || strcmp(password,response[DIALOG_RESPONSE_INPUTTEXT],false) != 0)
		{
			strcopy(error,"The two passwords didn't match. Choose one again.");
			continue;
		}

		Account_SubmitRegister(playerid,password);
		return;
	}
}

AccountGui_ShowCooldown(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), wait = Account_GetQuizWait(playerid), text[256], summary[144], waitText[24];

	if (wait == ACCOUNT_QUIZ_BANNED)
	{
		Account_WriteAuthLog(playerid,"quiz_banned_return");
		format(text,sizeof(text),"You failed the roleplay quiz %d times within %d hours. You're banned from the server until staff lift it.~n~~n~To appeal, ask on our Discord at ~y~%s~w~.",ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_CAP_HOURS,ACCOUNT_QUIZ_APPEAL);
		format(summary,sizeof(summary),"You're banned for failing the roleplay quiz %d times. To appeal, ask on our Discord at %s.",ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_APPEAL);
		await AccountGui_Message(playerid,ACCOUNT_GUI_BANNED_TITLE,text,GUI_BUTTON_LEAVE,KIT_COLOUR_BAD);
	}
	else
	{
		Account_WriteAuthLog(playerid,"quiz_cooldown");
		Account_QuizDescribeWait(wait,waitText);
		format(text,sizeof(text),"You didn't pass the roleplay quiz a little while ago.~n~~n~You can try again in ~y~%s~w~.",waitText);
		format(summary,sizeof(summary),"You can try the roleplay quiz again in %s.",waitText);
		await AccountGui_Message(playerid,ACCOUNT_GUI_WAIT_TITLE,text,GUI_BUTTON_LEAVE,KIT_COLOUR_TEXT);
	}

	if (!AccountGui_IsCurrent(playerid,epoch))
	{
		return;
	}

	Kit_Close(playerid);
	MessageSplit_SendClientMessage(playerid,ACCOUNT_GUI_SUMMARY_COLOUR,summary);
	Account_KickDelayed(playerid);
}

AccountGui_StartQuiz(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), text[384], summary[160], waitText[24];
	Account_QuizDraw(playerid);
	format(text,sizeof(text),"Before you play, answer ~y~%d questions~w~ about roleplay on Medieval Roleplay. Each has one right answer. Get at least ~y~%d~w~ right and your account is made.~n~~n~If you don't pass, you can try again after ~y~%d minutes~w~. If you fail %d times within %d hours, you're banned from the server.",ACCOUNT_QUIZ_DRAW,ACCOUNT_QUIZ_PASS,ACCOUNT_QUIZ_COOLDOWN_MIN,ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_CAP_HOURS);

	for (;;)
	{
		new pick = await AccountGui_Message(playerid,ACCOUNT_GUI_QUIZ_TITLE,text,"Start",KIT_COLOUR_ACCENT);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		if (pick != KIT_BACK)
		{
			break;
		}

		if (AccountGui_AskLeave(playerid,epoch))
		{
			return;
		}
	}

	for (new index = 0;index < ACCOUNT_QUIZ_DRAW;index++)
	{
		for (;;)
		{
			new pick = await AccountGui_Question(playerid,index);

			if (!AccountGui_IsCurrent(playerid,epoch))
			{
				return;
			}

			if (pick == KIT_BACK)
			{
				if (AccountGui_AskLeave(playerid,epoch))
				{
					return;
				}

				continue;
			}

			if (Account_QuizSetAnswer(playerid,index,pick))
			{
				break;
			}
		}
	}

	new score = Account_QuizScore(playerid);

	if (score >= ACCOUNT_QUIZ_PASS)
	{
		new bool:isSaved = Account_RecordQuizPass(playerid,score);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		if (!isSaved)
		{
			Kit_Close(playerid);
			Gui_Notify(playerid,"The scribe dropped his quill. Your account wasn't made, please reconnect and try again.");
			Account_KickDelayed(playerid);
			return;
		}

		format(text,sizeof(text),"You got ~y~%d of %d~w~ right.~n~~n~Your account is ready. Next, you make your character.",score,ACCOUNT_QUIZ_DRAW);
		await AccountGui_Message(playerid,ACCOUNT_GUI_PASS_TITLE,text,GUI_BUTTON_CONTINUE,KIT_COLOUR_GOOD);

		if (!AccountGui_IsCurrent(playerid,epoch))
		{
			return;
		}

		Kit_Close(playerid);
		Account_FinishQuiz(playerid);
		return;
	}

	new wait = Account_RecordQuizFail(playerid,score);

	if (!AccountGui_IsCurrent(playerid,epoch))
	{
		return;
	}

	if (wait == ACCOUNT_QUIZ_BANNED)
	{
		format(text,sizeof(text),"You got ~y~%d of %d~w~ right. You need %d to pass.~n~~n~You failed the roleplay quiz %d times within %d hours. You're banned from the server until staff lift it.~n~~n~To appeal, ask on our Discord at ~y~%s~w~.",score,ACCOUNT_QUIZ_DRAW,ACCOUNT_QUIZ_PASS,ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_CAP_HOURS,ACCOUNT_QUIZ_APPEAL);
		format(summary,sizeof(summary),"You're banned for failing the roleplay quiz %d times. To appeal, ask on our Discord at %s.",ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_APPEAL);
		await AccountGui_Message(playerid,ACCOUNT_GUI_BANNED_TITLE,text,GUI_BUTTON_LEAVE,KIT_COLOUR_BAD);
	}
	else
	{
		Account_QuizDescribeWait(wait,waitText);
		format(text,sizeof(text),"You got ~y~%d of %d~w~ right. You need %d to pass.~n~~n~You can try again in ~y~%s~w~.",score,ACCOUNT_QUIZ_DRAW,ACCOUNT_QUIZ_PASS,waitText);
		format(summary,sizeof(summary),"You didn't pass the roleplay quiz. You can try again in %s.",waitText);
		await AccountGui_Message(playerid,ACCOUNT_GUI_FAIL_TITLE,text,GUI_BUTTON_LEAVE,KIT_COLOUR_TEXT);
	}

	if (!AccountGui_IsCurrent(playerid,epoch))
	{
		return;
	}

	Kit_Close(playerid);
	MessageSplit_SendClientMessage(playerid,ACCOUNT_GUI_SUMMARY_COLOUR,summary);
	Account_KickDelayed(playerid);
}
