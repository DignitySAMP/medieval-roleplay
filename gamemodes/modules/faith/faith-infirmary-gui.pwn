#define INFIRMARY_GUI_WIDTH (260.0)
#define INFIRMARY_GUI_CHARS (52)
#define INFIRMARY_GUI_TEXT_LEN (320)

static const s_InfirmaryGuiLabels[INFIRMARY_TEND_COUNT][24] = {
	"Examine",
	"Give a remedy",
	"Stitch a wound",
	"Set a bone",
	"Lance a festering wound",
	"Give the last rites"
};

stock InfirmaryGui_Explain(action,status,dest[],size = sizeof(dest))
{
	switch (status)
	{
		case INFIRMARY_CANON:
		{
			strcopy(dest,"The Church forbids its monks and clergy to cut or burn. A lay brother or sister does this work.",size);
		}
		case INFIRMARY_NOT_ALLOWED:
		{
			if (action == INFIRMARY_TEND_RITES)
			{
				strcopy(dest,"Only a priest gives the last rites.",size);
			}
			else if (action == INFIRMARY_TEND_EXAMINE || action == INFIRMARY_TEND_REMEDY)
			{
				strcopy(dest,"Only a brother or sister of the Church examines the sick and gives remedies.",size);
			}
			else
			{
				strcopy(dest,"Only a lay brother or sister of the Church does the cutting work.",size);
			}
		}
		case INFIRMARY_NO_NEED:
		{
			switch (action)
			{
				case INFIRMARY_TEND_REMEDY:
				{
					strcopy(dest,"There's no named illness left to treat today. Examine them first. Each illness takes one remedy a day.",size);
				}
				case INFIRMARY_TEND_STITCH:
				{
					strcopy(dest,"They have no open wound to stitch.",size);
				}
				case INFIRMARY_TEND_SET:
				{
					strcopy(dest,"They have no broken bone to set.",size);
				}
				case INFIRMARY_TEND_LANCE:
				{
					strcopy(dest,"They have no festering wound to lance.",size);
				}
				default:
				{
					strcopy(dest,"They aren't close enough to death to need the last rites.",size);
				}
			}
		}
		case INFIRMARY_NO_TOOL:
		{
			strcopy(dest,action == INFIRMARY_TEND_STITCH ? ("You need a needle in your bag.") : ("You need a lancet in your bag."),size);
		}
		case INFIRMARY_NO_SUPPLY:
		{
			switch (action)
			{
				case INFIRMARY_TEND_REMEDY:
				{
					strcopy(dest,"You need a remedy in your bag: a poultice, a salve, a tincture or a rare remedy.",size);
				}
				case INFIRMARY_TEND_STITCH:
				{
					strcopy(dest,"You need a thread spool in your bag.",size);
				}
				case INFIRMARY_TEND_SET:
				{
					strcopy(dest,"You need a splint in your bag.",size);
				}
				default:
				{
					strcopy(dest,"You need water or strong drink in your bag to wash the wound out.",size);
				}
			}
		}
		case INFIRMARY_TOO_FAR:
		{
			strcopy(dest,"They're too far away, or they've left the infirmary.",size);
		}
		case INFIRMARY_BUSY:
		{
			strcopy(dest,"The priest can't come while mass or another rite is on.",size);
		}
		default:
		{
			dest[0] = EOS;
		}
	}
}

static InfirmaryGui_Summary(healerid,patientid,dest[],size = sizeof(dest))
{
	new line[160], wounds = Wounds_Count(patientid), named[96], unnamed = 0;

	if (wounds == 0)
	{
		strcopy(line,"No wounds.");
	}
	else
	{
		format(line,sizeof(line),"~y~%d~w~ %s%s.",wounds,wounds == 1 ? ("wound") : ("wounds"),Wounds_IsBleeding(patientid) ? (", ~r~bleeding~w~") : (""));
	}

	for (new i = 0;i < Ailment_GetCount(patientid);i++)
	{
		new ailment = Ailment_GetAt(patientid,i), name[AILMENT_NAME_LEN];

		if (!Ailment_IsDiagnosed(patientid,ailment))
		{
			unnamed++;
			continue;
		}

		Ailment_GetName(ailment,name);
		format(named,sizeof(named),"%s%s~y~%s~w~",named,named[0] != EOS ? (", ") : (""),name);
	}

	if (named[0] != EOS)
	{
		format(line,sizeof(line),"%s Illness: %s.",line,named);
	}

	if (unnamed > 0)
	{
		format(line,sizeof(line),"%s %s ~r~not yet named~w~. Examine them to find out what it is.",line,named[0] != EOS ? ("Something else is") : ("Something ails them,"));
	}
	else if (named[0] == EOS)
	{
		strcat(line," No illness.");
	}

	#pragma unused healerid
	Util_WrapText(line,dest,size,INFIRMARY_GUI_CHARS,"~n~");
}

static InfirmaryGui_Tend(playerid,patientid)
{
	yield 1;

	for (;;)
	{
		if (!Session_IsPlaying(playerid) || !IsPlayerConnected(patientid) || Infirmary_Check(playerid,patientid,INFIRMARY_TEND_EXAMINE) == INFIRMARY_TOO_FAR)
		{
			return;
		}

		new epoch = Gui_BeginFlow(playerid), name[NAMETAG_LEN], title[40], text[INFIRMARY_GUI_TEXT_LEN], reason[24], Float:x, Float:y, Float:width;
		Nametag_GetKnownName(playerid,patientid,name);
		format(title,sizeof(title),"Tend %s",name);
		InfirmaryGui_Summary(playerid,patientid,text);

		new Float:textHeight = Gui_TextHeight(text,INFIRMARY_GUI_WIDTH);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,INFIRMARY_GUI_WIDTH,textHeight + 4.0 + float(INFIRMARY_TEND_COUNT) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new action = 0;action < INFIRMARY_TEND_COUNT;action++)
		{
			new status = Infirmary_Check(playerid,patientid,action);
			Infirmary_Reason(action,status,reason);

			if (status == INFIRMARY_OK)
			{
				strcopy(reason,"Ready");
			}

			Kit_AddChoice(playerid,x,y + textHeight + 4.0 + float(action) * KIT_ROW,width,s_InfirmaryGuiLabels[action],action,status == INFIRMARY_OK ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,reason,status == INFIRMARY_OK ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,0.42);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + textHeight + 4.0 + float(INFIRMARY_TEND_COUNT) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= INFIRMARY_TEND_COUNT)
		{
			return;
		}

		new status = Infirmary_Tend(playerid,patientid,pick);

		if (status != INFIRMARY_OK)
		{
			new explain[144];
			InfirmaryGui_Explain(pick,status,explain);
			Gui_Notify(playerid,explain);
		}

		if (pick == INFIRMARY_TEND_RITES && status == INFIRMARY_OK)
		{
			return;
		}
	}
}

forward InfirmaryGui_TendDeferred(playerid,patientid,token);

public InfirmaryGui_TendDeferred(playerid,patientid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid))
	{
		InfirmaryGui_Tend(playerid,patientid);
	}

	return 1;
}
