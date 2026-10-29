#define GUI_TEXT "{D8CCB2}"
#define GUI_ACCENT "{B89A72}"
#define GUI_MUTED "{7D705A}"
#define GUI_GOOD "{8DAA5B}"
#define GUI_BAD "{B5543C}"
#define GUI_WARN "{D9A441}"

#define GUI_BUTTON_BACK "Back"
#define GUI_BUTTON_CLOSE "Close"
#define GUI_BUTTON_LEAVE "Leave"
#define GUI_BUTTON_OKAY "Okay"
#define GUI_BUTTON_SELECT "Select"
#define GUI_BUTTON_CONTINUE "Continue"

#define GUI_MESSAGE_LINE (9.5)
#define GUI_TEXT_LETTER_X (0.1615)

#define GUI_PIP "o"
#define GUI_PIPS_LEN (64)

static const s_GuiGlyphWidths[95] = {
	15, 9, 17, 27, 20, 34, 23, 12, 12, 12, 21, 20, 12, 14, 12, 15,
	23, 15, 21, 21, 21, 21, 21, 21, 20, 21, 12, 12, 24, 24, 24, 19,
	10, 22, 19, 19, 22, 16, 19, 24, 22, 11, 16, 21, 15, 28, 24, 27,
	20, 25, 19, 19, 18, 23, 23, 31, 23, 19, 21, 21, 13, 35, 11, 21,
	10, 19, 20, 14, 20, 19, 13, 20, 19, 9, 9, 19, 9, 29, 19, 21,
	19, 19, 15, 15, 14, 18, 19, 27, 20, 20, 17, 21, 17, 20, 15
};

static s_GuiEpoch[MAX_PLAYERS];

stock bool:Gui_IsDialogOpen(playerid)
{
	return Util_IsValidPlayer(playerid) && GetPlayerDialogID(playerid) != INVALID_DIALOG_ID;
}

stock Gui_BeginFlow(playerid)
{
	return ++s_GuiEpoch[playerid];
}

stock bool:Gui_IsFlowCurrent(playerid,epoch)
{
	return IsPlayerConnected(playerid) && s_GuiEpoch[playerid] == epoch;
}

stock Gui_Notify(playerid,const text[])
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid) || text[0] == EOS)
	{
		return;
	}

	Subtitle_Show(playerid,text);
}

stock Gui_FormatPips(dest[],size,filled,total,const colour[])
{
	dest[0] = EOS;
	strcat(dest,colour,size);

	for (new i = 0;i < total;i++)
	{
		if (i == filled)
		{
			strcat(dest,GUI_MUTED,size);
		}

		strcat(dest,GUI_PIP,size);
	}
}

stock bool:Gui_IsBusy(playerid)
{
	return Gui_IsDialogOpen(playerid) || Kit_IsOpen(playerid);
}

static Gui_PlaceWord(Float:width,&lines,&Float:column,&Float:word,&Float:space)
{
	if (word <= 0.0)
	{
		return;
	}

	if (column > 0.0 && column + space + word > width)
	{
		lines++;
		column = 0.0;
	}

	column += (column > 0.0 ? space : 0.0) + word;
	word = 0.0;
	space = 0.0;
}

stock Gui_CountLines(const text[],Float:width = 0.0)
{
	if (width <= 0.0)
	{
		new lines = 1, position = -1;

		while ((position = strfind(text,"~n~",false,position + 1)) != -1)
		{
			lines++;
		}

		return lines;
	}

	new lines = 1, Float:column = 0.0, Float:word = 0.0, Float:space = 0.0;

	for (new i = 0;;i++)
	{
		new bool:lineBreak = text[i] == '~' && text[i + 1] == 'n' && text[i + 2] == '~';

		if (text[i] == EOS || text[i] == ' ' || lineBreak)
		{
			Gui_PlaceWord(width,lines,column,word,space);

			if (text[i] == EOS)
			{
				break;
			}

			if (lineBreak)
			{
				lines++;
				column = 0.0;
				space = 0.0;
			}
			else
			{
				space += float(s_GuiGlyphWidths[0]) * GUI_TEXT_LETTER_X;
			}

			i += lineBreak ? 2 : 0;
			continue;
		}

		if (text[i] == '~' && text[i + 1] != EOS && text[i + 2] == '~')
		{
			i += 2;
			continue;
		}

		word += float(text[i] >= 32 && text[i] <= 126 ? s_GuiGlyphWidths[text[i] - 32] : 20) * GUI_TEXT_LETTER_X;
	}

	return lines;
}

stock Gui_FormatColour(dest[],size,colour)
{
	format(dest,size,"{%06x}",colour >>> 8);
}

forward bool:Gui_KeyContext(playerid);

public bool:Gui_KeyContext(playerid)
{
	return Gui_IsBusy(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_GuiEpoch[playerid]++;
}

hook OnPlayerDisconnect(playerid,reason)
{
	s_GuiEpoch[playerid]++;
}
