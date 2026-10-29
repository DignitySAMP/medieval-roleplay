#define MODEL_UI_KIT (-29997)
#define MODEL_UI_ICONS (-7001)
#define KIT_UNITS_X(%0) ((%0) / 3.0)
#define KIT_UNITS_Y(%0) ((%0) * 448.0 / 1080.0)
#define KIT_PIXELS_X(%0) ((%0) * 3.0)
#define KIT_MAX_ELEMENTS (160)
#define KIT_BACK (-1)
#define KIT_ARMED (-2)
#define KIT_CANCEL_GRACE_MS (700)
#define KIT_NONE (cellmin)

enum
{
	KIT_LAYER_SCREEN,
	KIT_LAYER_NOTICE,
	KIT_LAYER_HUD,
	KIT_LAYERS,
}

enum
{
	KIT_ANCHOR_CENTRE,
	KIT_ANCHOR_BOTTOM_RIGHT,
	KIT_ANCHOR_TOP,
	KIT_ANCHOR_BOTTOM,
}

#define KIT_SPRITE_HEADER_LEFT "mdl-29997:hdr_l"
#define KIT_SPRITE_HEADER_MID "mdl-29997:hdr_mid"
#define KIT_SPRITE_HEADER_RIGHT "mdl-29997:hdr_r"
#define KIT_SPRITE_BOX "mdl-29997:ui_box"
#define KIT_SPRITE_LOGO "mdl-29997:logo"
#define KIT_SPRITE_LOGO_FIRE "mdl-29997:logo_fire"
#define KIT_SPRITE_PLATE "mdl-7001:ic_plate"
#define KIT_SPRITE_RING "mdl-7001:ic_ring"

#define KIT_HEADER_END_SHARE (0.281)
#define KIT_HEADER_HEIGHT (22.0)
#define KIT_BOX_INSET_X (0.14)
#define KIT_BOX_INSET_Y (0.12)

#define KIT_LOGO_WIDTH (240.0)
#define KIT_LOGO_HEIGHT (KIT_UNITS_Y(KIT_PIXELS_X(KIT_LOGO_WIDTH) / 4.0))
#define KIT_LOGO_Y (58.0)

#define KIT_PANEL_ALPHA (125)
#define KIT_PANEL_TINT (0xFFFFFF00 | KIT_PANEL_ALPHA)
#define KIT_COLOUR_TILE (0x00000088)
#define KIT_COLOUR_TILE_SELECTED (0xB89A7255)
#define KIT_COLOUR_TILE_WORN (0x8DAA5B55)
#define KIT_COLOUR_IN_HAND (0xD9A441FF)
#define KIT_COLOUR_PLATE (0x574B3DFF)
#define KIT_COLOUR_PLATE_EMPTY (0x3A3129FF)
#define KIT_COLOUR_PLATE_SELECTED (0xA88A62FF)
#define KIT_COLOUR_PLATE_WORN (0x71894AFF)
#define KIT_COLOUR_BAR_TROUGH (0x00000099)
#define KIT_COLOUR_HIT (0xFFFFFF01)
#define KIT_COLOUR_HOVER (0xB89A7250)
#define KIT_COLOUR_BUTTON (0x00000077)
#define KIT_TITLE_LEN (32)
#define KIT_PANEL_EXTRA (70.0)
#define KIT_ROW (10.0)
#define KIT_BOTTOM_EDGE (390.0)
#define KIT_TEXT_ROW (0.85)
#define KIT_COLOUR_TEXT (0xD8CCB2FF)
#define KIT_TEXT_TINT "~y~~h~~h~"
#define KIT_TEXT_TINT_MAX (1000)
#define KIT_COLOUR_ACCENT (0xB89A72FF)
#define KIT_COLOUR_MUTED (0x7D705AFF)
#define KIT_COLOUR_GOOD (0x8DAA5BFF)
#define KIT_COLOUR_PENDING (0xD4B44EFF)
#define KIT_COLOUR_BAD (0xB5543CFF)
#define KIT_COLOUR_PIP_EMPTY (0x3A332AFF)

#define KIT_TEXT_BODY (1.0)
#define KIT_TEXT_TITLE (1.2)
#define KIT_TITLE_WIDTH_RATIO (0.231)
#define KIT_TEXT_WIDTH_RATIO (0.19)
#define KIT_LINE_HEIGHT (11.0)

static PlayerText:s_KitElements[MAX_PLAYERS][KIT_LAYERS][KIT_MAX_ELEMENTS];
static s_KitValues[MAX_PLAYERS][KIT_MAX_ELEMENTS];
static s_KitCount[MAX_PLAYERS][KIT_LAYERS];
static s_KitLayer[MAX_PLAYERS];
static s_KitTitle[MAX_PLAYERS][KIT_TITLE_LEN];
static Task:s_KitTask[MAX_PLAYERS] = {INVALID_TASK, ...};
static bool:s_KitSelecting[MAX_PLAYERS];
static bool:s_KitLabelsHidden[MAX_PLAYERS];
static bool:s_KitLabelsHeld[MAX_PLAYERS];
static bool:s_KitCoversHud[MAX_PLAYERS];
static s_KitIgnoreCancelUntil[MAX_PLAYERS];
static PlayerText:s_KitLogo[MAX_PLAYERS] = {INVALID_PLAYER_TEXT_DRAW, ...};

#define KIT_HIGHLIGHT_MAX (4)
#define KIT_ANIM_MAX (32)
#define KIT_COLOUR_GLOW (0xD9A44188)
#define KIT_GLOW_MS (700)
#define KIT_BOUNCE_UP (2.5)
#define KIT_BOUNCE_UP_MS (220)
#define KIT_BOUNCE_DOWN_MS (700)
#define KIT_DROP_FROM (10.0)
#define KIT_DROP_MS (800)
#define KIT_ANIM_EXTERNAL (KIT_LAYERS)
#define KIT_MARKER_TEXT "~y~~d~"
#define KIT_MARKER_SIZE (0.6)
#define KIT_MARKER_GAP (11.0)
#define KIT_COLOUR_MARKER (0xD9A441FF)

enum E_KIT_GLOW
{
	bool:E_KIT_GLOW_ACTIVE,
	PlayerText:E_KIT_GLOW_HIT,
	PlayerText:E_KIT_GLOW_LABEL,
	Float:E_KIT_GLOW_REST_Y,
	E_KIT_GLOW_COLOUR_ANIM,
	E_KIT_GLOW_MOVE_ANIM,
	bool:E_KIT_GLOW_LIT,
	bool:E_KIT_GLOW_UP,
	bool:E_KIT_GLOW_IS_TILE,
}

static s_KitHighlightTitle[MAX_PLAYERS][KIT_HIGHLIGHT_MAX][KIT_TITLE_LEN];
static s_KitHighlightValue[MAX_PLAYERS][KIT_HIGHLIGHT_MAX];
static s_KitHighlightCount[MAX_PLAYERS];
static s_KitGlow[MAX_PLAYERS][KIT_HIGHLIGHT_MAX][E_KIT_GLOW];
static s_KitAnims[MAX_PLAYERS][KIT_LAYERS + 1][KIT_ANIM_MAX];
static s_KitAnimCount[MAX_PLAYERS][KIT_LAYERS + 1];
static bool:s_KitIsTile[MAX_PLAYERS][KIT_MAX_ELEMENTS];
static PlayerText:s_KitMarkers[MAX_PLAYERS][KIT_HIGHLIGHT_MAX];
static const s_KitStarColours[] = {0x8E9196FF, 0xC4643AFF, 0xA5773AFF, 0xD6DCE2FF, 0xE9BE45FF};

static PlayerText:Kit_Track(playerid,PlayerText:td,value = KIT_NONE)
{
	new layer = s_KitLayer[playerid];

	if (td == INVALID_PLAYER_TEXT_DRAW)
	{
		return td;
	}

	if (s_KitCount[playerid][layer] >= KIT_MAX_ELEMENTS)
	{
		PlayerTextDrawDestroy(playerid,td);
		Log_Error("kit","player %d is over %d kit elements on layer %d",playerid,KIT_MAX_ELEMENTS,layer);
		return INVALID_PLAYER_TEXT_DRAW;
	}

	if (layer == KIT_LAYER_SCREEN)
	{
		s_KitValues[playerid][s_KitCount[playerid][layer]] = value;
		s_KitIsTile[playerid][s_KitCount[playerid][layer]] = false;
	}

	s_KitElements[playerid][layer][s_KitCount[playerid][layer]++] = td;
	return td;
}

static PlayerText:Kit_CreateSprite(playerid,Float:x,Float:y,Float:width,Float:height,const sprite[],colour = -1)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,sprite);
	PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_SPRITE_DRAW);
	PlayerTextDrawTextSize(playerid,td,width,height);
	PlayerTextDrawColour(playerid,td,colour);
	return td;
}

static Kit_TrackAnim(playerid,layer,animator)
{
	if (animator >= 0 && s_KitAnimCount[playerid][layer] < KIT_ANIM_MAX)
	{
		s_KitAnims[playerid][layer][s_KitAnimCount[playerid][layer]++] = animator;
	}

	return animator;
}

static Kit_UntrackAnim(playerid,animator)
{
	for (new layer = 0;layer <= KIT_ANIM_EXTERNAL;layer++)
	{
		for (new i = 0;i < s_KitAnimCount[playerid][layer];i++)
		{
			if (s_KitAnims[playerid][layer][i] == animator)
			{
				s_KitAnims[playerid][layer][i] = s_KitAnims[playerid][layer][--s_KitAnimCount[playerid][layer]];
				return;
			}
		}
	}
}

static Kit_StopAnims(playerid,layer)
{
	for (new i = 0;i < s_KitAnimCount[playerid][layer];i++)
	{
		PlayerText_StopMove(s_KitAnims[playerid][layer][i]);
	}

	s_KitAnimCount[playerid][layer] = 0;

	if (layer == KIT_LAYER_SCREEN)
	{
		for (new slot = 0;slot < KIT_HIGHLIGHT_MAX;slot++)
		{
			s_KitGlow[playerid][slot][E_KIT_GLOW_ACTIVE] = false;
		}
	}
}

stock Kit_TrackExternalAnim(playerid,animator)
{
	return Util_IsValidPlayer(playerid) ? Kit_TrackAnim(playerid,KIT_ANIM_EXTERNAL,animator) : -1;
}

stock Kit_StopExternalAnims(playerid)
{
	if (Util_IsValidPlayer(playerid))
	{
		Kit_StopAnims(playerid,KIT_ANIM_EXTERNAL);
	}
}

static Kit_DestroyMarkers(playerid)
{
	for (new slot = 0;slot < KIT_HIGHLIGHT_MAX;slot++)
	{
		if (s_KitMarkers[playerid][slot] != INVALID_PLAYER_TEXT_DRAW)
		{
			PlayerTextDrawDestroy(playerid,s_KitMarkers[playerid][slot]);
			s_KitMarkers[playerid][slot] = INVALID_PLAYER_TEXT_DRAW;
		}
	}
}

static PlayerText:Kit_AddMarker(playerid,slot,PlayerText:tile)
{
	new Float:x, Float:y, Float:width, Float:height;
	PlayerTextDrawGetPos(playerid,tile,x,y);
	PlayerTextDrawGetTextSize(playerid,tile,width,height);

	new PlayerText:marker = CreatePlayerTextDraw(playerid,x + width / 2.0,y + KIT_MARKER_GAP,KIT_MARKER_TEXT);
	PlayerTextDrawFont(playerid,marker,TEXT_DRAW_FONT_1);
	PlayerTextDrawLetterSize(playerid,marker,KIT_MARKER_SIZE * KIT_TEXT_WIDTH_RATIO,KIT_MARKER_SIZE);
	PlayerTextDrawColour(playerid,marker,KIT_COLOUR_MARKER);
	PlayerTextDrawSetShadow(playerid,marker,0);
	PlayerTextDrawSetOutline(playerid,marker,1);
	PlayerTextDrawBackgroundColour(playerid,marker,0x000000AA);
	PlayerTextDrawAlignment(playerid,marker,TEXT_DRAW_ALIGN_CENTER);
	PlayerTextDrawShow(playerid,marker);
	s_KitMarkers[playerid][slot] = marker;
	return marker;
}

static Kit_GlowStep(playerid,slot)
{
	if (s_KitGlow[playerid][slot][E_KIT_GLOW_IS_TILE])
	{
		s_KitGlow[playerid][slot][E_KIT_GLOW_COLOUR_ANIM] = -1;
		return;
	}

	new PlayerText:hit = s_KitGlow[playerid][slot][E_KIT_GLOW_HIT], bool:isLit = !s_KitGlow[playerid][slot][E_KIT_GLOW_LIT];
	s_KitGlow[playerid][slot][E_KIT_GLOW_LIT] = isLit;

	s_KitGlow[playerid][slot][E_KIT_GLOW_COLOUR_ANIM] = Kit_TrackAnim(playerid,KIT_LAYER_SCREEN,PlayerText_InterpolateColor(playerid,hit,isLit ? KIT_COLOUR_GLOW : KIT_COLOUR_HIT,KIT_GLOW_MS,EASE_IN_OUT_SINE));
}

static Kit_BounceStep(playerid,slot)
{
	new PlayerText:label = s_KitGlow[playerid][slot][E_KIT_GLOW_LABEL], Float:restY = s_KitGlow[playerid][slot][E_KIT_GLOW_REST_Y];

	if (label == INVALID_PLAYER_TEXT_DRAW)
	{
		return;
	}

	s_KitGlow[playerid][slot][E_KIT_GLOW_UP] = !s_KitGlow[playerid][slot][E_KIT_GLOW_UP];
	s_KitGlow[playerid][slot][E_KIT_GLOW_MOVE_ANIM] = Kit_TrackAnim(playerid,KIT_LAYER_SCREEN,s_KitGlow[playerid][slot][E_KIT_GLOW_UP] ? PlayerText_MoveToY(playerid,label,restY - KIT_BOUNCE_UP,KIT_BOUNCE_UP_MS,EASE_OUT_QUAD) : PlayerText_MoveToY(playerid,label,restY,KIT_BOUNCE_DOWN_MS,EASE_OUT_BOUNCE));
}

static Kit_StartHighlights(playerid)
{
	new glows = 0;
	Kit_DestroyMarkers(playerid);

	for (new i = 0;i < s_KitCount[playerid][KIT_LAYER_SCREEN] && glows < KIT_HIGHLIGHT_MAX;i++)
	{
		if (s_KitValues[playerid][i] == KIT_NONE)
		{
			continue;
		}

		for (new h = 0;h < s_KitHighlightCount[playerid];h++)
		{
			if (s_KitHighlightValue[playerid][h] != s_KitValues[playerid][i] || strcmp(s_KitHighlightTitle[playerid][h],s_KitTitle[playerid]))
			{
				continue;
			}

			new bool:isTile = s_KitIsTile[playerid][i], PlayerText:hit = s_KitElements[playerid][KIT_LAYER_SCREEN][i], Float:x, Float:y;
			new PlayerText:label = isTile ? Kit_AddMarker(playerid,glows,hit) : (i + 1 < s_KitCount[playerid][KIT_LAYER_SCREEN] ? s_KitElements[playerid][KIT_LAYER_SCREEN][i + 1] : INVALID_PLAYER_TEXT_DRAW);
			s_KitGlow[playerid][glows][E_KIT_GLOW_ACTIVE] = true;
			s_KitGlow[playerid][glows][E_KIT_GLOW_HIT] = hit;
			s_KitGlow[playerid][glows][E_KIT_GLOW_LABEL] = label;
			s_KitGlow[playerid][glows][E_KIT_GLOW_IS_TILE] = isTile;
			s_KitGlow[playerid][glows][E_KIT_GLOW_LIT] = false;
			s_KitGlow[playerid][glows][E_KIT_GLOW_UP] = false;

			if (label != INVALID_PLAYER_TEXT_DRAW)
			{
				PlayerTextDrawGetPos(playerid,label,x,y);
				s_KitGlow[playerid][glows][E_KIT_GLOW_REST_Y] = y;
			}

			Kit_GlowStep(playerid,glows);
			Kit_BounceStep(playerid,glows);
			glows++;
			break;
		}
	}
}

stock bool:Kit_HasValue(playerid,value)
{
	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_KitCount[playerid][KIT_LAYER_SCREEN];i++)
	{
		if (s_KitValues[playerid][i] == value)
		{
			return true;
		}
	}

	return false;
}

stock Kit_CountGlows(playerid)
{
	new count = 0;

	for (new slot = 0;Util_IsValidPlayer(playerid) && slot < KIT_HIGHLIGHT_MAX;slot++)
	{
		if (s_KitGlow[playerid][slot][E_KIT_GLOW_ACTIVE])
		{
			count++;
		}
	}

	return count;
}

stock PlayerText:Kit_GetHighlightMarker(playerid,slot)
{
    if (!Util_IsValidPlayer(playerid) || slot < 0 || slot >= KIT_HIGHLIGHT_MAX)
    {
        return INVALID_PLAYER_TEXT_DRAW;
    }

    return s_KitMarkers[playerid][slot];
}

stock Kit_ClearHighlights(playerid)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_KitHighlightCount[playerid] = 0;
	}
}

stock Kit_AddHighlight(playerid,const title[],value)
{
	if (!Util_IsValidPlayer(playerid) || s_KitHighlightCount[playerid] >= KIT_HIGHLIGHT_MAX)
	{
		return;
	}

	new h = s_KitHighlightCount[playerid]++;
	strcopy(s_KitHighlightTitle[playerid][h],title,KIT_TITLE_LEN);
	s_KitHighlightValue[playerid][h] = value;

	if (Kit_IsOpen(playerid) && !strcmp(title,s_KitTitle[playerid]))
	{
		Kit_StopAnims(playerid,KIT_LAYER_SCREEN);
		Kit_StartHighlights(playerid);
	}
}

stock Kit_BounceNotice(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	for (new i = 0;i < s_KitCount[playerid][KIT_LAYER_NOTICE];i++)
	{
		new PlayerText:td = s_KitElements[playerid][KIT_LAYER_NOTICE][i], Float:x, Float:y;
		PlayerTextDrawGetPos(playerid,td,x,y);
		PlayerTextDrawSetPos(playerid,td,x,y - KIT_DROP_FROM);
		Kit_TrackAnim(playerid,KIT_LAYER_NOTICE,PlayerText_MoveToY(playerid,td,y,KIT_DROP_MS,EASE_OUT_BOUNCE));
	}
}

static Kit_ClearLayer(playerid,layer)
{
	Kit_StopAnims(playerid,layer);

	if (layer == KIT_LAYER_SCREEN)
	{
		Kit_DestroyMarkers(playerid);
	}

	for (new i = 0;i < s_KitCount[playerid][layer];i++)
	{
		PlayerTextDrawDestroy(playerid,s_KitElements[playerid][layer][i]);
	}

	s_KitCount[playerid][layer] = 0;
}

static Kit_EndSelection(playerid)
{
	if (s_KitSelecting[playerid])
	{
		s_KitSelecting[playerid] = false;
		s_KitIgnoreCancelUntil[playerid] = GetTickCount() + KIT_CANCEL_GRACE_MS;
		CancelSelectTextDraw(playerid);
	}
}

static Kit_DropTask(playerid)
{
	if (task_valid(s_KitTask[playerid]))
	{
		task_delete(s_KitTask[playerid]);
	}

	s_KitTask[playerid] = INVALID_TASK;
}

stock Kit_Begin(playerid,layer = KIT_LAYER_SCREEN,const title[] = "")
{
	Kit_ClearLayer(playerid,layer);
	s_KitLayer[playerid] = layer;

	if (layer == KIT_LAYER_SCREEN)
	{
		strcopy(s_KitTitle[playerid],title,KIT_TITLE_LEN);
		s_KitCoversHud[playerid] = false;
	}
}

stock Kit_CoverHud(playerid)
{
	s_KitCoversHud[playerid] = true;
}

stock PlayerText:Kit_AddSprite(playerid,Float:x,Float:y,Float:width,Float:height,const sprite[],colour = -1)
{
	return Kit_Track(playerid,Kit_CreateSprite(playerid,x,y,width,height,sprite,colour));
}

stock PlayerText:Kit_AddBox(playerid,Float:x,Float:y,Float:width,Float:height,colour)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,"_");
	PlayerTextDrawUseBox(playerid,td,true);
	PlayerTextDrawLetterSize(playerid,td,0.0,height / 10.0);
	PlayerTextDrawTextSize(playerid,td,x + width,0.0);
	PlayerTextDrawBoxColour(playerid,td,colour);
	PlayerTextDrawColour(playerid,td,0);
	PlayerTextDrawBackgroundColour(playerid,td,0);
	PlayerTextDrawSetShadow(playerid,td,0);
	PlayerTextDrawSetOutline(playerid,td,0);
	return Kit_Track(playerid,td);
}

static bool:Kit_HasColourCode(const text[])
{
	for (new i = 0;text[i] != EOS && text[i + 1] != EOS && text[i + 2] != EOS;i++)
	{
		if (text[i] != '~' || text[i + 2] != '~')
		{
			continue;
		}

		switch (tolower(text[i + 1]))
		{
			case 'r', 'g', 'b', 'y', 'p', 'w', 's', 'l', 'h': return true;
		}
	}

	return false;
}

stock Kit_TintText(const text[],dest[],size = sizeof(dest))
{
	if (!Kit_HasColourCode(text))
	{
		strcopy(dest,text,size);
		return;
	}

	format(dest,size,"%s%s",KIT_TEXT_TINT,text);

	for (new i = strfind(dest,"~"),length = strlen(KIT_TEXT_TINT);i != -1;i = strfind(dest,"~",false,i + 1))
	{
		if (dest[i + 1] != EOS && dest[i + 2] == '~' && (dest[i + 1] == 'w' || dest[i + 1] == 'W' || dest[i + 1] == 's' || dest[i + 1] == 'S'))
		{
			strdel(dest,i,i + 3);
			strins(dest,KIT_TEXT_TINT,i,size);
			i += length - 1;
		}
	}

	if (strlen(dest) >= KIT_TEXT_TINT_MAX)
	{
		strcopy(dest,text,size);
	}
}

stock PlayerText:Kit_AddText(playerid,Float:x,Float:y,const text[],colour = KIT_COLOUR_TEXT,Float:size = KIT_TEXT_BODY,TEXT_DRAW_FONT:font = TEXT_DRAW_FONT_1,bool:isCentred = false,Float:width = 200.0)
{
	new tinted[KIT_TEXT_TINT_MAX + 16];

	if (colour == KIT_COLOUR_TEXT)
	{
		Kit_TintText(text,tinted);
	}
	else
	{
		strcopy(tinted,text);
	}

	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,tinted);
	PlayerTextDrawFont(playerid,td,font);
	PlayerTextDrawLetterSize(playerid,td,size * KIT_TEXT_WIDTH_RATIO,size);
	PlayerTextDrawColour(playerid,td,colour);
	PlayerTextDrawSetShadow(playerid,td,0);
	PlayerTextDrawSetOutline(playerid,td,1);
	PlayerTextDrawBackgroundColour(playerid,td,0x000000AA);
	PlayerTextDrawSetProportional(playerid,td,true);

	if (isCentred)
	{
		PlayerTextDrawAlignment(playerid,td,TEXT_DRAW_ALIGN_CENTER);
		PlayerTextDrawTextSize(playerid,td,0.0,width);
	}
	else
	{
		PlayerTextDrawTextSize(playerid,td,x + width,0.0);
	}

	return Kit_Track(playerid,td);
}

stock PlayerText:Kit_AddHit(playerid,Float:x,Float:y,Float:width,Float:height,value)
{
	new PlayerText:td = Kit_CreateSprite(playerid,x,y,width,height,KIT_SPRITE_HEADER_MID,KIT_COLOUR_HIT);
	PlayerTextDrawSetSelectable(playerid,td,true);
	return Kit_Track(playerid,td,value);
}

stock Kit_AddChoice(playerid,Float:x,Float:y,Float:width,const label[],value,labelColour = KIT_COLOUR_TEXT,const valueText[] = "",valueColour = KIT_COLOUR_ACCENT,Float:valueShare = 0.42)
{
	Kit_AddHit(playerid,x - 3.0,y - 1.0,width + 6.0,KIT_ROW,value);
	Kit_AddText(playerid,x,y,label,labelColour,KIT_TEXT_ROW);

	if (valueText[0] != EOS)
	{
		Kit_AddText(playerid,x + width * valueShare,y,valueText,valueColour,KIT_TEXT_ROW);
	}
}

stock Kit_AddButton(playerid,Float:x,Float:y,Float:width,const label[],value,colour = KIT_COLOUR_TEXT)
{
	Kit_AddBox(playerid,x,y,width,KIT_ROW + 2.0,KIT_COLOUR_BUTTON);
	Kit_AddHit(playerid,x,y - 1.0,width,KIT_ROW + 3.0,value);
	Kit_AddText(playerid,x + width / 2.0,y + 1.5,label,colour,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,true,width);
}

stock Kit_AddPips(playerid,Float:x,Float:y,filled,total,colour,Float:size = 5.0,Float:gap = 4.0)
{
	for (new i = 0;i < total;i++)
	{
		Kit_AddBox(playerid,x + float(i) * (size + gap),y,size,KIT_UNITS_Y(KIT_PIXELS_X(size)),i < filled ? colour : KIT_COLOUR_PIP_EMPTY);
	}
}

stock Kit_AddBar(playerid,Float:x,Float:y,Float:width,Float:height,value,maximum,colour,bool:hasLabel = true)
{
	Kit_AddBox(playerid,x,y,width,height,KIT_COLOUR_BAR_TROUGH);

	if (value > 0 && maximum > 0)
	{
		Kit_AddBox(playerid,x,y,width * float(min(value,maximum)) / float(maximum),height,colour);
	}

	if (hasLabel)
	{
		new label[16];
		format(label,sizeof(label),"%d / %d",value,maximum);
		Kit_AddText(playerid,x + width / 2.0,y + (height - 0.8 * KIT_LINE_HEIGHT) / 2.0,label,KIT_COLOUR_TEXT,0.8,TEXT_DRAW_FONT_1,true,width);
	}
}

stock Kit_AddTile(playerid,Float:x,Float:y,Float:size,modelid,amount = 0,bool:isSelected = false,value = KIT_NONE,bool:isWorn = false,const icon[] = "",stars = 0)
{
	new Float:height = KIT_UNITS_Y(KIT_PIXELS_X(size)), PlayerText:td;

	if (icon[0] != EOS)
	{
		td = Kit_CreateSprite(playerid,x,y,size,height,KIT_SPRITE_PLATE,isSelected ? KIT_COLOUR_PLATE_SELECTED : (isWorn ? KIT_COLOUR_PLATE_WORN : KIT_COLOUR_PLATE));
	}
	else
	{
		td = CreatePlayerTextDraw(playerid,x,y,"_");
		PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_MODEL_PREVIEW);
		PlayerTextDrawTextSize(playerid,td,size,height);
		PlayerTextDrawUseBox(playerid,td,true);
		PlayerTextDrawBackgroundColour(playerid,td,isSelected ? KIT_COLOUR_TILE_SELECTED : (isWorn ? KIT_COLOUR_TILE_WORN : KIT_COLOUR_TILE));
		PlayerTextDrawBoxColour(playerid,td,0);
		PlayerTextDrawColour(playerid,td,-1);
		PlayerTextDrawSetPreviewModel(playerid,td,modelid != 0 ? modelid : 19300);
		PlayerTextDrawSetPreviewRot(playerid,td,-15.0,0.0,35.0,modelid != 0 ? 1.0 : 50.0);
	}

	if (value != KIT_NONE)
	{
		PlayerTextDrawSetSelectable(playerid,td,true);
	}

	Kit_Track(playerid,td,value);

	if (s_KitLayer[playerid] == KIT_LAYER_SCREEN && s_KitCount[playerid][KIT_LAYER_SCREEN] > 0)
	{
		s_KitIsTile[playerid][s_KitCount[playerid][KIT_LAYER_SCREEN] - 1] = true;
	}

	if (icon[0] != EOS)
	{
		Kit_AddSprite(playerid,x,y,size,height,icon);

		if (stars >= 1 && stars <= sizeof(s_KitStarColours))
		{
			Kit_AddSprite(playerid,x,y,size,height,KIT_SPRITE_RING,s_KitStarColours[stars - 1]);
		}
	}

	if (isWorn)
	{
		new PlayerText:tag = Kit_AddText(playerid,x + 1.5,y + 1.0,"in hand",KIT_COLOUR_IN_HAND,0.55);
		PlayerTextDrawSetOutline(playerid,tag,0);
		PlayerTextDrawSetShadow(playerid,tag,1);
	}

	if (amount > 1)
	{
		new label[8];
		format(label,sizeof(label),"%d",amount);
		Kit_AddText(playerid,x + size - 6.0,y + height - 9.0,label,KIT_COLOUR_TEXT,0.75);
	}
}

stock Kit_AddHeader(playerid,Float:x,Float:y,Float:width,const title[],Float:height = KIT_HEADER_HEIGHT)
{
	new Float:ends = width * KIT_HEADER_END_SHARE;
	Kit_AddSprite(playerid,x,y,ends,height,KIT_SPRITE_HEADER_LEFT,KIT_PANEL_TINT);
	Kit_AddSprite(playerid,x + ends,y,width - ends * 2.0,height,KIT_SPRITE_HEADER_MID,KIT_PANEL_TINT);
	Kit_AddSprite(playerid,x + width - ends,y,ends,height,KIT_SPRITE_HEADER_RIGHT,KIT_PANEL_TINT);

	if (title[0] != EOS)
	{
		new PlayerText:td = Kit_AddText(playerid,x + width / 2.0,y + (height - KIT_TEXT_TITLE * KIT_LINE_HEIGHT) / 2.0,title,KIT_COLOUR_TEXT,KIT_TEXT_TITLE,TEXT_DRAW_FONT_0,true,width);
		PlayerTextDrawLetterSize(playerid,td,KIT_TEXT_TITLE * KIT_TITLE_WIDTH_RATIO,KIT_TEXT_TITLE);
	}
}

stock Kit_AddPanel(playerid,Float:x,Float:y,Float:width,Float:height,const title[],&Float:contentX,&Float:contentY,&Float:contentWidth)
{
	Kit_AddSprite(playerid,x,y,width,height,KIT_SPRITE_BOX,KIT_PANEL_TINT);
	Kit_AddHeader(playerid,x + width * 0.08,y + height * 0.05,width * 0.84,title);
	contentX = x + width * KIT_BOX_INSET_X;
	contentY = y + height * 0.05 + KIT_HEADER_HEIGHT + 6.0;
	contentWidth = width * (1.0 - KIT_BOX_INSET_X * 2.0);
}

stock Kit_OpenPanel(playerid,anchor,Float:width,Float:contentHeight,const title[],&Float:contentX,&Float:contentY,&Float:contentWidth)
{
	new Float:height = contentHeight + KIT_PANEL_EXTRA, Float:x, Float:y;

	switch (anchor)
	{
		case KIT_ANCHOR_BOTTOM_RIGHT: { x = 640.0 - 6.0 - width; y = 448.0 - 6.0 - height; }
		case KIT_ANCHOR_TOP: { x = 320.0 - width / 2.0; y = 6.0; }
		case KIT_ANCHOR_BOTTOM: { x = 320.0 - width / 2.0; y = KIT_BOTTOM_EDGE - height; }
		default: { x = 320.0 - width / 2.0; y = 224.0 - height / 2.0; }
	}

	Kit_AddPanel(playerid,x,y,width,height,title,contentX,contentY,contentWidth);
}

static Kit_ShowWorldLabels(playerid,bool:show)
{
	if (show == !s_KitLabelsHidden[playerid])
	{
		return;
	}

	s_KitLabelsHidden[playerid] = !show;
	Streamer_SetRadiusMultiplier(STREAMER_TYPE_3D_TEXT_LABEL,show ? 1.0 : 0.0,playerid);
	Streamer_Update(playerid,STREAMER_TYPE_3D_TEXT_LABEL);
}

stock Task:Kit_Present(playerid)
{
	Kit_ShowWorldLabels(playerid,false);
	pawn_call_public("Kit_OnVisibilityChanged","dd",playerid,true);

	for (new i = 0;i < s_KitCount[playerid][KIT_LAYER_SCREEN];i++)
	{
		PlayerTextDrawShow(playerid,s_KitElements[playerid][KIT_LAYER_SCREEN][i]);
	}

	Kit_DropTask(playerid);
	s_KitTask[playerid] = task_new();
	s_KitIgnoreCancelUntil[playerid] = max(s_KitIgnoreCancelUntil[playerid],GetTickCount() + KIT_CANCEL_GRACE_MS);
	s_KitSelecting[playerid] = true;
	SelectTextDraw(playerid,KIT_COLOUR_HOVER);
	Hud_SetSuspended(playerid,s_KitCoversHud[playerid]);
	Kit_StopAnims(playerid,KIT_LAYER_SCREEN);
	Kit_StartHighlights(playerid);
	return s_KitTask[playerid];
}

stock Kit_ShowNotice(playerid)
{
	for (new i = 0;i < s_KitCount[playerid][KIT_LAYER_NOTICE];i++)
	{
		PlayerTextDrawShow(playerid,s_KitElements[playerid][KIT_LAYER_NOTICE][i]);
	}

	s_KitLayer[playerid] = KIT_LAYER_SCREEN;
}

stock Kit_HideNotice(playerid)
{
	Kit_ClearLayer(playerid,KIT_LAYER_NOTICE);
}

stock Kit_ShowHud(playerid)
{
	for (new i = 0;i < s_KitCount[playerid][KIT_LAYER_HUD];i++)
	{
		PlayerTextDrawShow(playerid,s_KitElements[playerid][KIT_LAYER_HUD][i]);
	}

	s_KitLayer[playerid] = KIT_LAYER_SCREEN;
}

stock Kit_HideHud(playerid)
{
	Kit_ClearLayer(playerid,KIT_LAYER_HUD);
}

stock Kit_Suspend(playerid)
{
	Kit_EndSelection(playerid);
}

stock Kit_Clear(playerid)
{
	Kit_DropTask(playerid);
	Kit_ClearLayer(playerid,KIT_LAYER_SCREEN);
	s_KitTitle[playerid][0] = EOS;
	s_KitCoversHud[playerid] = false;
	Hud_SetSuspended(playerid,false);
	if (!s_KitLabelsHeld[playerid])
	{
		Kit_ShowWorldLabels(playerid,true);
	}
	pawn_call_public("Kit_OnVisibilityChanged","dd",playerid,false);
}

stock Kit_Close(playerid)
{
	if (!s_KitLabelsHeld[playerid])
	{
		Kit_ShowWorldLabels(playerid,true);
	}

	Kit_EndSelection(playerid);
	Kit_DropTask(playerid);
	Kit_ClearLayer(playerid,KIT_LAYER_SCREEN);
	s_KitTitle[playerid][0] = EOS;
	s_KitCoversHud[playerid] = false;
	Hud_SetSuspended(playerid,false);
	pawn_call_public("Kit_OnVisibilityChanged","dd",playerid,false);
}

forward Kit_OnVisibilityChanged(playerid,bool:isVisible);

public Kit_OnVisibilityChanged(playerid,bool:isVisible)
{
    return true;
}

stock bool:Kit_IsOpen(playerid)
{
	return Util_IsValidPlayer(playerid) && task_valid(s_KitTask[playerid]) && !task_completed(s_KitTask[playerid]);
}

stock Kit_SetWorldLabels(playerid,bool:show)
{
	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	s_KitLabelsHeld[playerid] = !show;

	if (!show || !Kit_IsOpen(playerid))
	{
		Kit_ShowWorldLabels(playerid,show);
	}
}

stock bool:Kit_AreWorldLabelsShown(playerid)
{
	return Util_IsValidPlayer(playerid) && !s_KitLabelsHidden[playerid];
}

stock Kit_GetTitle(playerid,dest[],size = sizeof(dest))
{
	strcopy(dest,s_KitTitle[playerid],size);
}

stock Kit_ArmAfter(playerid,ms)
{
	if (Kit_IsOpen(playerid))
	{
		SetTimerEx("Kit_ArmDeferred",ms,false,"dd",playerid,_:s_KitTask[playerid]);
	}
}

forward Kit_OnPicked(playerid,value);

public Kit_OnPicked(playerid,value)
{
	return 1;
}

forward Kit_ArmDeferred(playerid,task);

public Kit_ArmDeferred(playerid,task)
{
	if (IsPlayerConnected(playerid) && Kit_IsOpen(playerid) && _:s_KitTask[playerid] == task)
	{
		Kit_Pick(playerid,KIT_ARMED);
	}

	return 1;
}

stock bool:Kit_Pick(playerid,value)
{
	if (!Kit_IsOpen(playerid))
	{
		return false;
	}

	new Task:task = s_KitTask[playerid];
	s_KitTask[playerid] = INVALID_TASK;

	if (value != KIT_ARMED)
	{
		pawn_call_public("Kit_OnPicked","dd",playerid,value);
	}

	task_set_result(task,value);
	return true;
}

stock Kit_ShowLogo(playerid,bool:isFire = false)
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid))
	{
		return;
	}

	Kit_HideLogo(playerid);
	s_KitLogo[playerid] = Kit_CreateSprite(playerid,320.0 - KIT_LOGO_WIDTH / 2.0,KIT_LOGO_Y,KIT_LOGO_WIDTH,KIT_LOGO_HEIGHT,isFire ? (KIT_SPRITE_LOGO_FIRE) : (KIT_SPRITE_LOGO));
	PlayerTextDrawShow(playerid,s_KitLogo[playerid]);
}

stock Kit_HideLogo(playerid)
{
	if (s_KitLogo[playerid] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid,s_KitLogo[playerid]);
		s_KitLogo[playerid] = INVALID_PLAYER_TEXT_DRAW;
	}
}

#include <pp-hooks>

hook Models_OnRegister()
{
	Models_AddObject(MODEL_UI_KIT,"ui/sprite_model.dff","ui/ui_kit.txd");
	Models_AddObject(MODEL_UI_ICONS,"ui/sprite_model.dff","ui/icons_core.txd");
}

hook OnPlayerConnect(playerid)
{
	s_KitLabelsHidden[playerid] = false;
	s_KitLabelsHeld[playerid] = false;
	for (new layer = 0;layer < KIT_LAYERS;layer++)
	{
		s_KitCount[playerid][layer] = 0;
	}

	s_KitLayer[playerid] = KIT_LAYER_SCREEN;
	s_KitTitle[playerid][0] = EOS;
	s_KitTask[playerid] = INVALID_TASK;
	s_KitCoversHud[playerid] = false;
	s_KitHighlightCount[playerid] = 0;

	for (new slot = 0;slot < KIT_HIGHLIGHT_MAX;slot++)
	{
		s_KitMarkers[playerid][slot] = INVALID_PLAYER_TEXT_DRAW;
	}

	for (new layer = 0;layer <= KIT_ANIM_EXTERNAL;layer++)
	{
		s_KitAnimCount[playerid][layer] = 0;
	}

	for (new slot = 0;slot < KIT_HIGHLIGHT_MAX;slot++)
	{
		s_KitGlow[playerid][slot][E_KIT_GLOW_ACTIVE] = false;
	}
	s_KitSelecting[playerid] = false;
	s_KitIgnoreCancelUntil[playerid] = 0;
	s_KitLogo[playerid] = INVALID_PLAYER_TEXT_DRAW;
}

hook ResetPlayerVariables(playerid)
{
    s_KitLabelsHeld[playerid] = false;
    Kit_Close(playerid);
}

hook OnPlayerUpdate(playerid)
{
	if (s_KitLabelsHidden[playerid] && !s_KitLabelsHeld[playerid] && !Kit_IsOpen(playerid))
	{
		Kit_ShowWorldLabels(playerid,true);
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	for (new layer = 0;layer <= KIT_ANIM_EXTERNAL;layer++)
	{
		Kit_StopAnims(playerid,layer);
	}

	Kit_DropTask(playerid);
}

forward Animator_OnFinish(playerid,animator,type);

public Animator_OnFinish(playerid,animator,type)
{
	#pragma unused type

	if (!Util_IsValidPlayer(playerid))
	{
		return 1;
	}

	Kit_UntrackAnim(playerid,animator);

	for (new slot = 0;slot < KIT_HIGHLIGHT_MAX;slot++)
	{
		if (!s_KitGlow[playerid][slot][E_KIT_GLOW_ACTIVE])
		{
			continue;
		}

		if (s_KitGlow[playerid][slot][E_KIT_GLOW_COLOUR_ANIM] == animator)
		{
			Kit_GlowStep(playerid,slot);
			return 1;
		}

		if (s_KitGlow[playerid][slot][E_KIT_GLOW_MOVE_ANIM] == animator)
		{
			Kit_BounceStep(playerid,slot);
			return 1;
		}
	}

	return 1;
}

hook OnPlayerSpawn(playerid)
{
	if (Kit_IsOpen(playerid))
	{
		s_KitIgnoreCancelUntil[playerid] = GetTickCount() + KIT_CANCEL_GRACE_MS;
		s_KitSelecting[playerid] = true;
		SelectTextDraw(playerid,KIT_COLOUR_HOVER);
	}
}

hook OnPlayerClickPlayerTextDraw(playerid,PlayerText:playertextid)
{
	if (!Kit_IsOpen(playerid))
	{
		return;
	}

	for (new i = 0;i < s_KitCount[playerid][KIT_LAYER_SCREEN];i++)
	{
		if (s_KitElements[playerid][KIT_LAYER_SCREEN][i] == playertextid && s_KitValues[playerid][i] != KIT_NONE)
		{
			PlayerPlaySound(playerid,1083,0.0,0.0,0.0);
			Kit_Pick(playerid,s_KitValues[playerid][i]);
			return;
		}
	}
}

hook OnPlayerClickTextDraw(playerid,Text:clickedid)
{
	if (clickedid != Text:INVALID_TEXT_DRAW)
	{
		return;
	}

	if (GetTickCount() < s_KitIgnoreCancelUntil[playerid])
	{
		if (Kit_IsOpen(playerid))
		{
			s_KitSelecting[playerid] = true;
			SelectTextDraw(playerid,KIT_COLOUR_HOVER);
		}

		return;
	}

	s_KitSelecting[playerid] = false;
	Kit_Pick(playerid,KIT_BACK);
}
