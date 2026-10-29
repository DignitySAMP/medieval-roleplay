stock Float:Gui_TextHeight(const text[],Float:panelWidth)
{
	return float(Gui_CountLines(text,panelWidth * (1.0 - KIT_BOX_INSET_X * 2.0))) * GUI_MESSAGE_LINE;
}

stock Gui_ShowMessage(playerid,const title[],const text[],const button[] = GUI_BUTTON_OKAY,Float:width = 300.0)
{
	new Float:x, Float:y, Float:contentWidth, Float:textHeight = Gui_TextHeight(text,width);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,width,textHeight + KIT_ROW + 10.0,title,x,y,contentWidth);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,contentWidth);
	Kit_AddButton(playerid,x + contentWidth / 2.0 - 40.0,y + textHeight + 8.0,80.0,button,1,KIT_COLOUR_ACCENT);
	await Kit_Present(playerid);
	Kit_Close(playerid);
}

stock bool:Gui_ConfirmLeave(playerid)
{
	new Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Leave the realm");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,GUI_MESSAGE_LINE + KIT_ROW + 12.0,"Leave the realm",x,y,width);
	Kit_AddText(playerid,x,y,"You'll be disconnected from Medieval Roleplay.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x,y + GUI_MESSAGE_LINE + 8.0,width * 0.45,GUI_BUTTON_LEAVE,1,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width * 0.55,y + GUI_MESSAGE_LINE + 8.0,width * 0.45,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick == 1;
}
