#define TUTORIAL_GUI_DONE_MS (10000)
#define TUTORIAL_BRIEF_WIDTH (360.0)
#define TUTORIAL_BRIEF_DELAY_MS (400)
#define TUTORIAL_BRIEF_CONTINUE (1)
#define TUTORIAL_BRIEF_READ_SECONDS (5)
#define TUTORIAL_STEP_CHARS (38)

enum E_TUTORIAL_BRIEF
{
	E_TUTORIAL_BRIEF_TITLE[32],
	E_TUTORIAL_BRIEF_ROWS,
	E_TUTORIAL_BRIEF_BODY[800],
}

static const s_TutorialText[E_TUTORIAL_STEP][160] = {
	"",
	"Walk to the weapon rack. The red marker shows the way.",
	"You've picked up a club. Press N to open your bag.",
	"This is everything you own. Click the club, then click Carry it.",
	"Press Y to draw your club.",
	"Swing once in every direction. Hold forward, back, left or right and left click. Right click blocks.",
	"Press Y again to put it away.",
	"The club stays on the island. With empty hands, press Y to raise your fists.",
	"Shove (left click), then throw a hook (hold left or right and left click) and a kick (hold back and left click).",
	"Now dodge. Hold Sprint (Space) and press back to step away, then hold it and press left or right to roll aside.",
	"Nobody here knows your name yet. Press H to introduce yourself to the people around you.",
	"Walk to the fire pit by the tents. Follow the red marker.",
	"Time for a fire of your own. Press N to open your bag, then click Crafting.",
	"The Campfire is already picked for you. Click Build it. You already have its materials.",
	"Drag the arrows to move the fire, then click the save icon. Press ESC to cancel.",
	"Stand at your campfire and press Y. Click Work here, then Roast fish to cook the fish in your bag.",
	"Press Sprint + Walk (Space + left Alt) to look at your character, or click Character in your bag.",
	"Your donkey is at the stables, by the red marker. Stand next to it and press F to get on.",
	"Ride up the hill to the red marker. The tutorial ends when you reach it.",
	"That's the end of the tutorial. You've been given a water skin. Drink from it in your bag (N) when you're thirsty."
};

static const s_TutorialBriefs[TUTORIAL_BRIEF_COUNT][E_TUTORIAL_BRIEF] = {
	{"The crossing", 7, "~w~This island is the tutorial. It covers the basics and takes a few minutes.~n~~n~Your current step is always in the ~y~box under your HUD~w~. A ~y~red marker~w~ shows where to go. At the top of the hill the tutorial ends and you're taken to where your character starts."},
	{"Arms", 7, "~w~You're holding the club now. Press ~y~Y~w~ to draw it and again to put it away.~n~~n~The direction you hold decides the swing. Hold ~y~forward~w~, ~y~back~w~, ~y~left~w~ or ~y~right~w~ and ~y~left click~w~ to swing that way. ~y~Right click~w~ blocks."},
	{"Fists", 12, "~w~The ~y~club~w~ stays on the island. Nobody leaves the tutorial with a weapon.~n~~n~Your ~y~fists~w~ are always with you. With nothing in your hands, press ~y~Y~w~ to raise them. ~y~Left click~w~ to shove, hold ~y~forward~w~ and left click to punch, hold ~y~left or right~w~ to hook, and hold ~y~back~w~ for a kick. ~y~Right click~w~ blocks. Hold ~y~Sprint (Space)~w~ with back or a side to dodge.~n~~n~A ~y~kick~w~ knocks people down. Fists can knock someone out but never kill."},
	{"Names and tongues", 7, "~w~Nobody knows your name until you tell them. Stand near someone and press ~y~H~w~ to introduce yourself. Until you do, they'll just see a stranger.~n~~n~Folk from other lands may speak a language you don't know. If they do, you'll see their words scrambled. Everyone understands ~y~Common~w~."},
	{"Food and warmth", 7, "~w~You need ~y~food~w~, ~y~drink~w~ and ~y~warmth~w~. The ~y~bars in the bottom right~w~ show how you're doing. Winter nights are cold. Wear warm clothes or stay near a fire.~n~~n~During your first hour of playtime, ~y~newcomer's warmth~w~ keeps the cold off. The ~y~bar next to the map~w~ shows how long it has left."},
	{"Making things", 6, "~w~You make things at ~y~stations~w~. Open ~y~Crafting~w~ in your bag to see which ones you can build and what they need.~n~~n~New stations cost ~y~talent points~w~. You earn one for every half hour you play. Stations run on ~y~fuel~w~. If it runs out, the station burns out and you only get half its materials back."},
	{"Work", 4, "~w~Working at a station is done by hand. Press the ~y~keys it shows~w~, in order and on time. Doing it well gives you better goods and raises your ~y~trade~w~ level."},
	{"A meal", 8, "~w~Raw fish has to be cooked before you can eat it. ~y~Cooked food~w~ fills you up the most.~n~~n~Eat from your ~y~bag (N)~w~ when your ~y~food bar~w~ gets low. If it empties, you lose health.~n~~n~Next, look at your ~y~character~w~ with ~y~Sprint + Walk~w~ (Space + left Alt)."},
	{"The road ahead", 6, "~w~The realm has villages, a castle and a monastery. Other players there may need what you can make.~n~~n~Your ~y~donkey~w~ is at the stables. Press ~y~F~w~ next to it to get on or off. Ride it with your movement keys. The tutorial ends at the top of the hill."},
	{"Where to start", 10, "~w~From here on, nobody tells you what to do next. These help while you find your feet.~n~~n~Most ~y~village families~w~ feed a guest for free. Press ~y~Y~w~ on one of them before the noon or evening bell (Sext or Vespers) and ask to eat with them. Pick ~y~Ask if there's work~w~ for an ~y~errand~w~ that pays coin. For your first ~y~2 hours~w~ of playtime, errands pay double.~n~~n~~y~Bohuslav~w~, the trader at Talmberg market, buys what you gather. He also sells rope, parchment and a halter for a horse. For a pfennig he fills your water skin. The ~y~notice boards~w~ at the market and in the church village list paid work and news."},
	{"Historical roleplay", 12, "~w~This is a fictional kingdom in the 1200s. Everyone here plays a person of that time.~n~~n~~y~Speak and act in period.~w~ Leave modern words, ideas and jokes out of character. ~y~Only know what your character knows.~w~ What you learn outside the game stays outside. ~y~Give others room to answer.~w~ Never force an outcome on another player. ~y~Your choices matter.~w~ Faith, standing, house and your name all count.~n~~n~Out-of-character talk goes in ~y~/b~w~. Keep it short. Use ~y~/me~w~ and ~y~/do~w~ to describe what you do and what others see."}
};

static s_TutorialGuiToken[MAX_PLAYERS];
static s_TutorialGuiBriefed[MAX_PLAYERS];
static s_TutorialGuiInfobox[MAX_PLAYERS];

TutorialGui_ShowStep(playerid,E_TUTORIAL_STEP:step)
{
	if (step <= TUTORIAL_NONE || step > TUTORIAL_DONE)
	{
		return;
	}

	s_TutorialGuiInfobox[playerid] = Infobox_Show(playerid,step == TUTORIAL_DONE ? ("You're ready") : ("Getting started"),s_TutorialText[step]);
	Kit_BounceNotice(playerid);

	if (step == TUTORIAL_DONE)
	{
		SetTimerEx("TutorialGui_HideDeferred",TUTORIAL_GUI_DONE_MS,false,"dd",playerid,++s_TutorialGuiToken[playerid]);
	}
	else
	{
		s_TutorialGuiToken[playerid]++;
	}
}

stock TutorialGui_ShowText(playerid,const text[],bool:isBouncing = true)
{
	s_TutorialGuiInfobox[playerid] = Infobox_Show(playerid,"Getting started",text,max(INFOBOX_ROWS,(strlen(text) + TUTORIAL_STEP_CHARS - 1) / TUTORIAL_STEP_CHARS));

	if (isBouncing)
	{
		Kit_BounceNotice(playerid);
	}

	s_TutorialGuiToken[playerid]++;
}

stock bool:TutorialGui_GetBriefing(brief,title[],body[],titleSize = sizeof(title),bodySize = sizeof(body))
{
	if (brief < 0 || brief >= TUTORIAL_BRIEF_COUNT)
	{
		return false;
	}

	strcopy(title,s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_TITLE],titleSize);
	strcopy(body,s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_BODY],bodySize);
	return true;
}

stock bool:TutorialGui_IsStepShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TutorialGuiInfobox[playerid] != 0 && Infobox_IsShown(playerid,s_TutorialGuiInfobox[playerid]);
}

TutorialGui_ResetBriefings(playerid)
{
	s_TutorialGuiBriefed[playerid] = 0;
}

stock TutorialGui_WasBriefed(playerid,brief)
{
	return brief >= 0 && brief < TUTORIAL_BRIEF_COUNT && (s_TutorialGuiBriefed[playerid] & (1 << brief)) != 0;
}

bool:TutorialGui_ShowBriefing(playerid,brief)
{
	if (brief < 0 || brief >= TUTORIAL_BRIEF_COUNT || (s_TutorialGuiBriefed[playerid] & (1 << brief)))
	{
		return false;
	}

	s_TutorialGuiBriefed[playerid] |= 1 << brief;

	Infobox_Hide(playerid,s_TutorialGuiInfobox[playerid]);
	SetTimerEx("TutorialGui_BriefingDeferred",TUTORIAL_BRIEF_DELAY_MS,false,"dd",playerid,brief);
	return true;
}

forward TutorialGui_BriefingDeferred(playerid,brief);

public TutorialGui_BriefingDeferred(playerid,brief)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid))
	{
		return;
	}

	if (Work_IsWorking(playerid))
	{
		TutorialGui_ShowStep(playerid,Tutorial_GetStep(playerid));
		return;
	}

	new epoch = Gui_BeginFlow(playerid), wait = TUTORIAL_BRIEF_READ_SECONDS, label[24], Float:x, Float:y, Float:width, Float:bodyHeight = float(s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_ROWS]) * KIT_ROW;

	if (brief == TUTORIAL_BRIEF_NEEDS)
	{
		Hud_SetAttention(playerid,true);
	}

	for (;;)
	{
		Kit_Begin(playerid,KIT_LAYER_SCREEN,s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_TITLE]);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TUTORIAL_BRIEF_WIDTH,bodyHeight + KIT_ROW + 16.0,s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_TITLE],x,y,width);
		Kit_AddText(playerid,x,y,s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_BODY],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		if (wait > 0)
		{
			format(label,sizeof(label),"Continue in %d",wait);
			Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + bodyHeight + 8.0,90.0,label,KIT_NONE,KIT_COLOUR_MUTED);
		}
		else
		{
			Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + bodyHeight + 8.0,90.0,"Continue",TUTORIAL_BRIEF_CONTINUE,KIT_COLOUR_ACCENT);
			Kit_AddHighlight(playerid,s_TutorialBriefs[brief][E_TUTORIAL_BRIEF_TITLE],TUTORIAL_BRIEF_CONTINUE);
		}

		new Task:shown = Kit_Present(playerid);

		if (wait > 0)
		{
			Kit_ArmAfter(playerid,1000);
		}

		new pick = await shown;

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			break;
		}

		if (pick == KIT_ARMED)
		{
			wait--;
			continue;
		}

		if (wait <= 0)
		{
			break;
		}
	}

	if (brief == TUTORIAL_BRIEF_NEEDS)
	{
		Hud_SetAttention(playerid,false);
	}

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	switch (brief)
	{
		case TUTORIAL_BRIEF_NEXT:
		{
			TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_HISTORY);
			return;
		}
		case TUTORIAL_BRIEF_HISTORY:
		{
			Tutorial_EndWelcome(playerid);
			return;
		}
		default: {}
	}

	if (!Tutorial_IsActive(playerid))
	{
		return;
	}

	TutorialGui_ShowStep(playerid,Tutorial_GetStep(playerid));

	switch (brief)
	{
		case TUTORIAL_BRIEF_CRAFTING: SetTimerEx("Craft_OpenDeferred",0,false,"d",playerid);
		case TUTORIAL_BRIEF_WORK: Tutorial_OnWorkBriefed(playerid);
		default: {}
	}
}

forward TutorialGui_HideDeferred(playerid,token);

public TutorialGui_HideDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && s_TutorialGuiToken[playerid] == token)
	{
		Infobox_Hide(playerid,s_TutorialGuiInfobox[playerid]);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_TutorialGuiToken[playerid]++;
	s_TutorialGuiBriefed[playerid] = 0;
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		s_TutorialGuiToken[playerid]++;
		Infobox_Hide(playerid,s_TutorialGuiInfobox[playerid]);
	}
}
