#define WORK_TICK_MS (50)
#define WORK_STAGE_LIMIT_MS (12000)
#define WORK_SEQUENCE_MAX (8)
#define WORK_RHYTHM_HITS (6)
#define WORK_HOLD_NEED_TICKS (100)
#define WORK_BAR_GLYPHS (30)
#define WORK_PANEL_WIDTH (280.0)
#define WORK_CHALLENGE_TEXT (1.3)
#define WORK_WAIT_DEFAULT_MS (8000)
#define WORK_HOLD_BAND_MIN (15.0)
#define WORK_HOLD_BAND_MAX (85.0)
#define MODEL_UI_GLYPHS (-7021)
#define WORK_GLYPH_STEP (74.0)
#define WORK_GLYPH_GAP (10.0)
#define WORK_GLYPH_PIXELS (64.0)
#define WORK_GLYPH_WIDE_PIXELS (128.0)
#define WORK_GLYPH_FLASH_MS (300)
#define WORK_GLYPH_MISS_MS (600)
#define WORK_RHYTHM_MISS_MS (250)
#define WORK_RHYTHM_BEAT_BASE_MS (800)
#define WORK_RHYTHM_WINDOW_BASE_MS (210)
#define WORK_GLYPH_HIDDEN (0x00000000)

enum E_WORK_CHALLENGE
{
	E_WORK_CHALLENGE_KIND,
	E_WORK_CHALLENGE_EASE,
	E_WORK_CHALLENGE_STARTED,
	E_WORK_CHALLENGE_MISTAKES,
	E_WORK_CHALLENGE_PROGRESS,
	E_WORK_CHALLENGE_NEED,
	E_WORK_CHALLENGE_SEQUENCE[WORK_SEQUENCE_MAX],
	Float:E_WORK_CHALLENGE_VALUE,
	Float:E_WORK_CHALLENGE_SPEED,
	Float:E_WORK_CHALLENGE_BAND,
	Float:E_WORK_CHALLENGE_BAND_HALF,
	Float:E_WORK_CHALLENGE_SWEET_HALF,
	Float:E_WORK_CHALLENGE_DRIFT,
	E_WORK_CHALLENGE_LIMIT_MS,
	bool:E_WORK_CHALLENGE_ENTERED,
	E_WORK_CHALLENGE_OUT_TICKS,
	E_WORK_CHALLENGE_BEAT_MS,
	E_WORK_CHALLENGE_WINDOW_MS,
	E_WORK_CHALLENGE_SCORE,
}

static s_WorkChallenge[MAX_PLAYERS][E_WORK_CHALLENGE];
static s_WorkNextStrength[MAX_PLAYERS];
static s_WorkNextWaitMs[MAX_PLAYERS];
static s_WorkNextLimitMs[MAX_PLAYERS];
static s_WorkBandScale[MAX_PLAYERS] = {100, ...};
static PlayerText:s_WorkPanelStage[MAX_PLAYERS] = {INVALID_PLAYER_TEXT_DRAW, ...};
static PlayerText:s_WorkPanelChallenge[MAX_PLAYERS] = {INVALID_PLAYER_TEXT_DRAW, ...};
static PlayerText:s_WorkPanelHint[MAX_PLAYERS] = {INVALID_PLAYER_TEXT_DRAW, ...};

static const s_WorkSeqGlyphs[4][6] = {"y", "h", "c", "space"};
static PlayerText:s_WorkPanelGlyphs[MAX_PLAYERS][WORK_SEQUENCE_MAX + 1];
static s_WorkGlyphShown[MAX_PLAYERS][WORK_SEQUENCE_MAX + 1][24];
static s_WorkGlyphSeenMistakes[MAX_PLAYERS];
static s_WorkGlyphSeenProgress[MAX_PLAYERS];
static s_WorkGlyphMissUntil[MAX_PLAYERS];
static s_WorkGlyphDoneUntil[MAX_PLAYERS];
static s_WorkGlyphMissAt[MAX_PLAYERS] = {-1, ...};
static const KEY:s_WorkSeqKeys[4] = {KEY_YES, KEY_CTRL_BACK, KEY_CROUCH, KEY_SPRINT};

stock Work_ScoreFromMistakes(mistakes)
{
	if (mistakes <= 0)
	{
		return 3;
	}

	return mistakes <= 2 ? 2 : 1;
}

stock Work_TimeoutScore(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_LIMIT_MS] == WORK_STAGE_LIMIT_MS && s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS] > 0 ? 1 : 0;
}

stock Work_RhythmBeatMs(ease)
{
	return WORK_RHYTHM_BEAT_BASE_MS + ease * 25;
}

stock Work_RhythmWindowMs(ease)
{
	return WORK_RHYTHM_WINDOW_BASE_MS + ease * 15;
}

stock Work_SetChallengeTuning(playerid,strength,waitMs,limitMs = 0)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WorkNextStrength[playerid] = Util_ClampInt(strength,0,100);
		s_WorkNextWaitMs[playerid] = max(waitMs,0);
		s_WorkNextLimitMs[playerid] = max(limitMs,0);
	}
}

stock Work_SetBandScale(playerid,percent)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WorkBandScale[playerid] = Util_ClampInt(percent,50,150);
	}
}

stock Work_GetBandScale(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_WorkBandScale[playerid] : 100;
}

stock Work_BeginChallenge(playerid,kind,ease)
{
	new strength = s_WorkNextStrength[playerid], waitMs = s_WorkNextWaitMs[playerid], limitMs = s_WorkNextLimitMs[playerid];
	s_WorkNextStrength[playerid] = 0;
	s_WorkNextWaitMs[playerid] = 0;
	s_WorkNextLimitMs[playerid] = 0;

	if (kind == CHALLENGE_WALK)
	{
		kind = CHALLENGE_HOLD;
	}

	s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND] = kind;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_EASE] = ease;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_STARTED] = GetTickCount();
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES] = 0;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS] = 0;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE] = 0.0;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_ENTERED] = false;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_OUT_TICKS] = 0;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = -1;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_DRIFT] = 0.0;
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_LIMIT_MS] = limitMs > 0 ? limitMs : WORK_STAGE_LIMIT_MS;

	switch (kind)
	{
		case CHALLENGE_WAIT:
		{
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED] = waitMs > 0 ? waitMs : WORK_WAIT_DEFAULT_MS;
		}
		case CHALLENGE_SEQUENCE:
		{
			new length = Util_ClampInt(7 - ease / 2,3,WORK_SEQUENCE_MAX);
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED] = length;

			for (new i = 0;i < length;i++)
			{
				s_WorkChallenge[playerid][E_WORK_CHALLENGE_SEQUENCE][i] = random(4);
			}
		}
		case CHALLENGE_RHYTHM:
		{
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED] = WORK_RHYTHM_HITS;
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_BEAT_MS] = Work_RhythmBeatMs(ease);
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_WINDOW_MS] = Work_RhythmWindowMs(ease);
		}
		case CHALLENGE_HOLD:
		{
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED] = WORK_HOLD_NEED_TICKS;
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND] = float(40 + random(31));
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF] = Util_Clamp((11.0 + float(ease) * 1.5 - float(strength) * 0.06) * float(s_WorkBandScale[playerid]) / 100.0,4.0,100.0);
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_DRIFT] = float(strength) * 0.012 * (random(2) ? 1.0 : -1.0);
		}
		default:
		{
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND] = CHALLENGE_TIMING;
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED] = 1;
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_SPEED] = Util_Clamp(2.6 - float(ease) * 0.1,1.2,2.6);
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND] = float(25 + random(51));
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF] = (10.0 + float(ease)) * float(s_WorkBandScale[playerid]) / 100.0;
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_SWEET_HALF] = (3.0 + float(ease) * 0.4) * float(s_WorkBandScale[playerid]) / 100.0;
		}
	}
}

stock KEY:Work_GetSequenceKey(playerid,index)
{
	return s_WorkSeqKeys[s_WorkChallenge[playerid][E_WORK_CHALLENGE_SEQUENCE][index]];
}

stock Work_GetChallengeNeed(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED];
}

stock Work_GetChallengeScore(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE];
}

stock Float:Work_GetChallengeBand(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND];
}

stock Float:Work_GetChallengeBandHalf(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF];
}

stock Work_GetChallengeKind(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND];
}

stock Work_GetChallengeProgress(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS];
}

stock Work_GetChallengeMistakes(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES];
}

stock Work_GetChallengeElapsed(playerid)
{
	return GetTickCount() - s_WorkChallenge[playerid][E_WORK_CHALLENGE_STARTED];
}

stock Work_GetChallengeBeat(playerid)
{
	return s_WorkChallenge[playerid][E_WORK_CHALLENGE_BEAT_MS];
}

stock Work_ResolveChallenge(playerid,score)
{
	s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = Util_ClampInt(score,0,3);
}

stock bool:Work_ChallengeInput(playerid,KEY:keys,KEY:oldKeys)
{
	if (s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] != -1)
	{
		return false;
	}

	new elapsed = GetTickCount() - s_WorkChallenge[playerid][E_WORK_CHALLENGE_STARTED], bool:isAction = (keys & KEY_SPRINT) && !(oldKeys & KEY_SPRINT), bool:isCorrect = false;

	if (s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND] == CHALLENGE_WAIT)
	{
		if (elapsed >= s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED])
		{
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = 3;
		}

		return false;
	}

	if (elapsed >= s_WorkChallenge[playerid][E_WORK_CHALLENGE_LIMIT_MS])
	{
		s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = Work_TimeoutScore(playerid);
		return false;
	}

	switch (s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND])
	{
		case CHALLENGE_SEQUENCE:
		{
			new pressed = -1;

			for (new i = 0;i < sizeof(s_WorkSeqKeys);i++)
			{
				if ((keys & s_WorkSeqKeys[i]) && !(oldKeys & s_WorkSeqKeys[i]))
				{
					pressed = i;
					break;
				}
			}

			if (pressed != -1)
			{
				new at = s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS];

				if (pressed == s_WorkChallenge[playerid][E_WORK_CHALLENGE_SEQUENCE][at])
				{
					isCorrect = true;

					if (++s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS] >= s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED])
					{
						s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = Work_ScoreFromMistakes(s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]);
					}
				}
				else
				{
					s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]++;
				}
			}
		}
		case CHALLENGE_RHYTHM:
		{
			if (isAction)
			{
				new beat = s_WorkChallenge[playerid][E_WORK_CHALLENGE_BEAT_MS], offset = elapsed % beat;

				if (offset > beat / 2)
				{
					offset = beat - offset;
				}

				if (offset <= s_WorkChallenge[playerid][E_WORK_CHALLENGE_WINDOW_MS] && elapsed > beat / 2)
				{
					isCorrect = true;

					if (++s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS] >= s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED])
					{
						s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = Work_ScoreFromMistakes(s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]);
					}
				}
				else
				{
					s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]++;
				}
			}
		}
		case CHALLENGE_HOLD:
		{
			if (s_WorkChallenge[playerid][E_WORK_CHALLENGE_DRIFT] != 0.0)
			{
				new Float:band = s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND] + s_WorkChallenge[playerid][E_WORK_CHALLENGE_DRIFT];

				if (band < WORK_HOLD_BAND_MIN || band > WORK_HOLD_BAND_MAX)
				{
					s_WorkChallenge[playerid][E_WORK_CHALLENGE_DRIFT] = -s_WorkChallenge[playerid][E_WORK_CHALLENGE_DRIFT];
					band = Util_Clamp(band,WORK_HOLD_BAND_MIN,WORK_HOLD_BAND_MAX);
				}

				s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND] = band;
			}

			new Float:value = s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE] + ((keys & KEY_SPRINT) ? 2.5 : -1.8);
			s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE] = Util_Clamp(value,0.0,100.0);

			if (floatabs(s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE] - s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND]) <= s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF])
			{
				s_WorkChallenge[playerid][E_WORK_CHALLENGE_ENTERED] = true;
				isCorrect = (++s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS] % 10) == 0;

				if (s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS] >= s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED])
				{
					s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = Work_ScoreFromMistakes(s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]);
				}
			}
			else if (s_WorkChallenge[playerid][E_WORK_CHALLENGE_ENTERED] && (++s_WorkChallenge[playerid][E_WORK_CHALLENGE_OUT_TICKS] % 10) == 0)
			{
				s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]++;
			}
		}
		default:
		{
			new Float:value = s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE] + s_WorkChallenge[playerid][E_WORK_CHALLENGE_SPEED];

			if (value > 100.0 || value < 0.0)
			{
				s_WorkChallenge[playerid][E_WORK_CHALLENGE_SPEED] = -s_WorkChallenge[playerid][E_WORK_CHALLENGE_SPEED];
				value = Util_Clamp(value,0.0,100.0);
			}

			s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE] = value;

			if (isAction)
			{
				new Float:off = floatabs(value - s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND]);

				if (off <= s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF])
				{
					isCorrect = true;
					new base = off <= s_WorkChallenge[playerid][E_WORK_CHALLENGE_SWEET_HALF] ? 3 : 2;
					s_WorkChallenge[playerid][E_WORK_CHALLENGE_SCORE] = max(1,base - s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]);
				}
				else
				{
					s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES]++;
				}
			}
		}
	}

	return isCorrect;
}

static Work_FormatBar(dest[],size,Float:value,Float:band,Float:bandHalf,Float:sweetHalf)
{
	dest[0] = EOS;
	new marker = floatround(value * float(WORK_BAR_GLYPHS - 1) / 100.0);

	for (new i = 0;i < WORK_BAR_GLYPHS;i++)
	{
		new Float:at = float(i) * 100.0 / float(WORK_BAR_GLYPHS - 1), Float:off = floatabs(at - band);

		if (i == marker)
		{
			strcat(dest,"~r~I",size);
		}
		else if (off <= sweetHalf)
		{
			strcat(dest,"~y~I",size);
		}
		else if (off <= bandHalf)
		{
			strcat(dest,"~g~I",size);
		}
		else
		{
			strcat(dest,"~w~I",size);
		}
	}
}

stock Work_FormatChallenge(playerid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	switch (s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND])
	{
		case CHALLENGE_WAIT:
		{
			strcopy(dest,"~w~...",size);
		}
		case CHALLENGE_SEQUENCE:
		{
			strcopy(dest,"_",size);
		}
		case CHALLENGE_RHYTHM:
		{
			format(dest,size,"~w~%d/%d",s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS],s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED]);
		}
		case CHALLENGE_HOLD:
		{
			Work_FormatBar(dest,size,s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE],s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND],s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF],-1.0);
		}
		default:
		{
			Work_FormatBar(dest,size,s_WorkChallenge[playerid][E_WORK_CHALLENGE_VALUE],s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND],s_WorkChallenge[playerid][E_WORK_CHALLENGE_BAND_HALF],s_WorkChallenge[playerid][E_WORK_CHALLENGE_SWEET_HALF]);
		}
	}
}

stock Work_GetChallengeHint(kind,dest[],size = sizeof(dest))
{
	switch (kind)
	{
		case CHALLENGE_SEQUENCE: strcopy(dest,"Press the keys in the order shown.  Hold ~y~N~w~ to walk away",size);
		case CHALLENGE_RHYTHM: strcopy(dest,"Press ~y~SPACE~w~ each time it lights up.  Hold ~y~N~w~ to walk away",size);
		case CHALLENGE_HOLD, CHALLENGE_WALK: strcopy(dest,"Hold ~y~SPACE~w~ to keep the red mark in the green.  Hold ~y~N~w~ to walk away",size);
		case CHALLENGE_WAIT: strcopy(dest,"Wait.  Hold ~y~N~w~ to walk away",size);
		default: strcopy(dest,"Press ~y~SPACE~w~ as the red mark passes the green.  Hold ~y~N~w~ to walk away",size);
	}
}

stock Work_ShowPanel(playerid,const title[])
{
	Work_ClearPanel(playerid);

	new Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_HUD);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,WORK_PANEL_WIDTH,KIT_ROW * 5.0,title,x,y,width);
	s_WorkPanelStage[playerid] = Kit_AddText(playerid,x,y,"_",KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	s_WorkPanelChallenge[playerid] = Kit_AddText(playerid,x + width / 2.0,y + KIT_ROW * 1.7,"_",KIT_COLOUR_TEXT,WORK_CHALLENGE_TEXT,TEXT_DRAW_FONT_1,true,width);
	s_WorkPanelHint[playerid] = Kit_AddText(playerid,x,y + KIT_ROW * 4.0,"_",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new Float:centre = x + width / 2.0, Float:rowY = y + KIT_ROW * 1.1;

	for (new slot = 0;slot < WORK_SEQUENCE_MAX;slot++)
	{
		s_WorkPanelGlyphs[playerid][slot] = Kit_AddSprite(playerid,centre + KIT_UNITS_X(WORK_GLYPH_STEP) * float(slot),rowY,KIT_UNITS_X(WORK_GLYPH_PIXELS),KIT_UNITS_Y(WORK_GLYPH_PIXELS),"mdl-7021:gk_y_idle",WORK_GLYPH_HIDDEN);
		s_WorkGlyphShown[playerid][slot][0] = EOS;
	}

	s_WorkPanelGlyphs[playerid][WORK_SEQUENCE_MAX] = Kit_AddSprite(playerid,centre - KIT_UNITS_X(WORK_GLYPH_WIDE_PIXELS + 40.0),rowY,KIT_UNITS_X(WORK_GLYPH_WIDE_PIXELS),KIT_UNITS_Y(WORK_GLYPH_PIXELS),"mdl-7021:gk_spacew_idle",WORK_GLYPH_HIDDEN);
	s_WorkGlyphShown[playerid][WORK_SEQUENCE_MAX][0] = EOS;
	s_WorkGlyphSeenMistakes[playerid] = 0;
	s_WorkGlyphSeenProgress[playerid] = 0;
	s_WorkGlyphMissUntil[playerid] = 0;
	s_WorkGlyphDoneUntil[playerid] = 0;
	s_WorkGlyphMissAt[playerid] = -1;
	Kit_ShowHud(playerid);
	Kit_SetWorldLabels(playerid,false);
}

stock Work_HidePanel(playerid)
{
	Work_ClearPanel(playerid);
	Kit_SetWorldLabels(playerid,true);
}

static Work_ClearPanel(playerid)
{
	Kit_HideHud(playerid);
	s_WorkPanelStage[playerid] = INVALID_PLAYER_TEXT_DRAW;
	s_WorkPanelChallenge[playerid] = INVALID_PLAYER_TEXT_DRAW;
	s_WorkPanelHint[playerid] = INVALID_PLAYER_TEXT_DRAW;

	for (new slot = 0;slot <= WORK_SEQUENCE_MAX;slot++)
	{
		s_WorkPanelGlyphs[playerid][slot] = INVALID_PLAYER_TEXT_DRAW;
	}
}

static Work_SetGlyph(playerid,slot,const sprite[],Float:x = -1.0)
{
	new PlayerText:td = s_WorkPanelGlyphs[playerid][slot];

	if (td == INVALID_PLAYER_TEXT_DRAW || !strcmp(s_WorkGlyphShown[playerid][slot],sprite) && s_WorkGlyphShown[playerid][slot][0] != EOS && x < 0.0)
	{
		return;
	}

	if (sprite[0] == EOS)
	{
		if (s_WorkGlyphShown[playerid][slot][0] != EOS)
		{
			PlayerTextDrawColour(playerid,td,WORK_GLYPH_HIDDEN);
			PlayerTextDrawShow(playerid,td);
			s_WorkGlyphShown[playerid][slot][0] = EOS;
		}

		return;
	}

	if (x >= 0.0)
	{
		new Float:y;
		PlayerTextDrawGetPos(playerid,td,y,y);
		PlayerTextDrawSetPos(playerid,td,x,y);
	}

	PlayerTextDrawSetString(playerid,td,sprite);
	PlayerTextDrawColour(playerid,td,-1);
	PlayerTextDrawShow(playerid,td);
	strcopy(s_WorkGlyphShown[playerid][slot],sprite,24);
}

stock Work_HideGlyphs(playerid)
{
	for (new slot = 0;slot <= WORK_SEQUENCE_MAX;slot++)
	{
		Work_SetGlyph(playerid,slot,"");
	}
}

stock bool:Work_IsGlyphMissShown(playerid)
{
	return Util_IsValidPlayer(playerid) && (GetTickCount() < s_WorkGlyphMissUntil[playerid] || (s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND] == CHALLENGE_SEQUENCE && s_WorkGlyphMissAt[playerid] != -1 && s_WorkGlyphMissAt[playerid] == s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS]));
}

stock Work_UpdateGlyphs(playerid)
{
	if (s_WorkPanelStage[playerid] == INVALID_PLAYER_TEXT_DRAW)
	{
		return;
	}

	new kind = s_WorkChallenge[playerid][E_WORK_CHALLENGE_KIND], now = GetTickCount(), mistakes = s_WorkChallenge[playerid][E_WORK_CHALLENGE_MISTAKES], progress = s_WorkChallenge[playerid][E_WORK_CHALLENGE_PROGRESS], sprite[24];

	if (mistakes > s_WorkGlyphSeenMistakes[playerid])
	{
		s_WorkGlyphMissUntil[playerid] = now + (kind == CHALLENGE_RHYTHM ? WORK_RHYTHM_MISS_MS : WORK_GLYPH_MISS_MS);
		s_WorkGlyphMissAt[playerid] = progress;
	}
	else if (mistakes < s_WorkGlyphSeenMistakes[playerid] || (s_WorkGlyphMissAt[playerid] != -1 && progress != s_WorkGlyphMissAt[playerid]))
	{
		s_WorkGlyphMissAt[playerid] = -1;
	}

	if (progress > s_WorkGlyphSeenProgress[playerid])
	{
		s_WorkGlyphDoneUntil[playerid] = now + WORK_GLYPH_FLASH_MS;
	}

	s_WorkGlyphSeenMistakes[playerid] = mistakes;
	s_WorkGlyphSeenProgress[playerid] = progress;
	new bool:isMiss = now < s_WorkGlyphMissUntil[playerid] || (kind == CHALLENGE_SEQUENCE && s_WorkGlyphMissAt[playerid] != -1 && s_WorkGlyphMissAt[playerid] == progress), bool:isDone = now < s_WorkGlyphDoneUntil[playerid];

	if (kind == CHALLENGE_SEQUENCE)
	{
		new need = s_WorkChallenge[playerid][E_WORK_CHALLENGE_NEED], Float:left, Float:y;
		PlayerTextDrawGetPos(playerid,s_WorkPanelChallenge[playerid],left,y);
		left -= KIT_UNITS_X(WORK_GLYPH_STEP * float(need) - WORK_GLYPH_GAP) / 2.0;

		for (new slot = 0;slot < WORK_SEQUENCE_MAX;slot++)
		{
			if (slot >= need)
			{
				Work_SetGlyph(playerid,slot,"");
				continue;
			}

			format(sprite,sizeof(sprite),"mdl-7021:gk_%s_%s",s_WorkSeqGlyphs[s_WorkChallenge[playerid][E_WORK_CHALLENGE_SEQUENCE][slot]],slot < progress ? ("done") : (slot == progress ? (isMiss ? ("miss") : ("next")) : ("idle")));
			Work_SetGlyph(playerid,slot,sprite,s_WorkGlyphShown[playerid][slot][0] == EOS ? left + KIT_UNITS_X(WORK_GLYPH_STEP) * float(slot) : -1.0);
		}

		Work_SetGlyph(playerid,WORK_SEQUENCE_MAX,"");
		return;
	}

	for (new slot = 0;slot < WORK_SEQUENCE_MAX;slot++)
	{
		Work_SetGlyph(playerid,slot,"");
	}

	if (kind != CHALLENGE_RHYTHM)
	{
		Work_SetGlyph(playerid,WORK_SEQUENCE_MAX,"");
		return;
	}

	new elapsed = now - s_WorkChallenge[playerid][E_WORK_CHALLENGE_STARTED], beat = s_WorkChallenge[playerid][E_WORK_CHALLENGE_BEAT_MS], offset = elapsed % beat;

	if (offset > beat / 2)
	{
		offset = beat - offset;
	}

	new bool:isBeat = offset <= s_WorkChallenge[playerid][E_WORK_CHALLENGE_WINDOW_MS] && elapsed > beat / 2;
	format(sprite,sizeof(sprite),"mdl-7021:gk_spacew_%s",isMiss ? ("miss") : (isDone ? ("done") : (isBeat ? ("next") : ("idle"))));
	Work_SetGlyph(playerid,WORK_SEQUENCE_MAX,sprite);
}

stock PlayerText:Work_GetPanelChallenge(playerid)
{
	return s_WorkPanelChallenge[playerid];
}

static Work_SetPanelText(playerid,PlayerText:td,const text[])
{
	new trimmed[256], length;
	strcopy(trimmed,text);
	length = strlen(trimmed);

	while (length > 0 && trimmed[length - 1] == ' ')
	{
		trimmed[--length] = EOS;
	}

	PlayerTextDrawSetString(playerid,td,length > 0 ? trimmed : "_");
}

stock Work_SetPanelLines(playerid,const stage[],const challenge[],const hint[])
{
	if (s_WorkPanelStage[playerid] == INVALID_PLAYER_TEXT_DRAW)
	{
		return;
	}

	if (stage[0] != EOS)
	{
		Work_SetPanelText(playerid,s_WorkPanelStage[playerid],stage);
	}

	if (challenge[0] != EOS)
	{
		Work_SetPanelText(playerid,s_WorkPanelChallenge[playerid],challenge);
	}

	if (hint[0] != EOS)
	{
		Work_SetPanelText(playerid,s_WorkPanelHint[playerid],hint);
	}
}
