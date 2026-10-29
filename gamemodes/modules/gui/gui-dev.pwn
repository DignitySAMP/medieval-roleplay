CMD<ADMIN_LEVEL_TRIAL>:fx(cmdid, playerid, params[])
{
	new name[8], alpha = 255;

	if (sscanf(params,"s[8]I(255)",name,alpha))
	{
		Command_Usage(playerid,cmdid,"<blood|cold|heat|off> [alpha 0-255, default 255]");
		return 1;
	}

	if (!strcmp(name,"off",true))
	{
		ScreenFx_SetOverride(playerid,false);
		SendClientMessage(playerid,0xFFFFFFFF,"Test effects off, gameplay drives them again.");
		return 1;
	}

	new E_SCREENFX:effect = ScreenFx_GetByName(name);

	if (effect == SCREENFX_COUNT)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Effects: blood, cold, heat, or off.");
		return 1;
	}

	if (!ScreenFx_IsOverride(playerid))
	{
		ScreenFx_SetOverride(playerid,true);
	}

	ScreenFx_Set(playerid,effect,alpha);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Screen effect %s at alpha %d. /fx off hands the effects back to gameplay.",name,alpha));
	return 1;
}

static GuiDev_ShowPanel(playerid)
{
	new Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"A test panel");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,120.0,"A test panel",x,y,width);
	Kit_AddText(playerid,x,y,"Body text at the row size, left aligned, wrapping at the panel's inner edge so a long line never runs off the box.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddChoice(playerid,x,y + 30.0,width,"A row you can click",0,KIT_COLOUR_TEXT,"it lights up");
	Kit_AddBar(playerid,x,y + 44.0,width,7.0,3,5,0xB5543CFF);
	Kit_AddPips(playerid,x,y + 56.0,2,5,0x6D8FB3FF);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 72.0,80.0,GUI_BUTTON_CLOSE,KIT_BACK);
	Kit_Present(playerid);
}

CMD<ADMIN_LEVEL_TRIAL>:uidemo(cmdid, playerid, params[])
{
	new layout[12], variant[8];

	if (sscanf(params,"s[12]S()[8]",layout,variant))
	{
		Command_Usage(playerid,cmdid,"<login|panel|off> [fire]");
		return 1;
	}

	Kit_Close(playerid);
	Kit_HideLogo(playerid);

	if (!strcmp(layout,"off",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"UI demo off.");
		return 1;
	}

	if (!strcmp(layout,"login",true))
	{
		Kit_ShowLogo(playerid,!strcmp(variant,"fire",true));
	}
	else if (!strcmp(layout,"panel",true))
	{
		GuiDev_ShowPanel(playerid);
	}
	else
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Layouts: login [fire], panel, off. The bag (N) and the creator are the real screens.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("UI demo: %s. /uidemo off clears it.",layout));
	return 1;
}
