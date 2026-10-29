#define WORK_CRATE_MODEL (1224)
#define WORK_DEV_RANGE (5.0)
#define WORK_DEV_LIST_MAX (16)
#define WORK_SHOT_STEP_DIST (0.1)
#define WORK_SHOT_STEP (0.1)

enum
{
	WORK_DEV_PLACE,
	WORK_DEV_MOVE,
	WORK_DEV_STAND,
	WORK_DEV_SHOTS,
	WORK_DEV_SUPPLY,
	WORK_DEV_DELETE,
	WORK_DEV_LIST,
	WORK_DEV_REFILL,
	WORK_DEV_BUILD_SUPPLY,
	WORK_DEV_POINTS,
	WORK_DEV_CAMERA,
	WORK_DEV_WILD_RESET,
	WORK_DEV_COOLDOWNS,
}

static Work_DevPickKind(playerid,epoch,bool:isNode)
{
	new kinds[64], count = 0, name[WORK_KIND_NAME_LEN], detail[16], Float:x, Float:y, Float:width;

	for (new kind = 0;kind < Work_GetKindCount() && count < sizeof(kinds);kind++)
	{
		if (Work_IsNodeKind(kind) == isNode)
		{
			kinds[count++] = kind;
		}
	}

	new title[24];
	strcopy(title,isNode ? ("Place a node") : ("Place a station"));
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,230.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new recipes = Work_CountRecipesForKind(kinds[i]);
		Work_GetKindName(kinds[i],name);
		format(detail,sizeof(detail),"%d recipe%s",recipes,recipes == 1 ? ("") : ("s"));
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,recipes > 0 ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,detail,KIT_COLOUR_MUTED,0.60);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= count)
	{
		return -1;
	}

	return kinds[pick];
}

static bool:Work_DevGizmo(playerid,epoch,model,const label[],&Float:x,&Float:y,&Float:z,&Float:a,bool:isCheckedSupport)
{
	Kit_Close(playerid);

	new STREAMER_TAG_OBJECT:crate = CreateDynamicObject(model,x,y,z,0.0,0.0,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (label[0] != EOS)
	{
		SetDynamicObjectMaterialText(crate,0,label,_:OBJECT_MATERIAL_SIZE_256x128,"Arial",28,1,0xFFFFFFFF,0xFF3A332A,1);
	}

	for (;;)
	{
		new bool:isSaved = bool:await Placement_Edit(playerid,crate);

		if (!Gui_IsFlowCurrent(playerid,epoch) || !isSaved)
		{
			DestroyDynamicObject(crate);
			return false;
		}

		new Float:rx, Float:ry;
		Placement_GetPose(playerid,x,y,z,rx,ry,a);

		new E_PLACEMENT_RESULT:result = Placement_Check(model,x,y,z,rx,ry,a,PLACEMENT_CHECK_TILT);

		if (result == PLACEMENT_OK && isCheckedSupport && !Placement_SnapToSurface(model,x,y,z,a))
		{
			result = PLACEMENT_FLOATING;
		}

		if (result == PLACEMENT_OK)
		{
			DestroyDynamicObject(crate);
			return true;
		}

		new reason[24], message[64];
		Placement_GetReason(result,reason);
		format(message,sizeof(message),"You can't place it there. It's %s. Try again or press ESC.",reason);
		Gui_Notify(playerid,message);
		SetDynamicObjectPos(crate,x,y,z);
		SetDynamicObjectRot(crate,0.0,0.0,a);
	}
}

static Work_DevFrontOf(playerid,Float:distance,&Float:x,&Float:y,&Float:z,&Float:a)
{
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x -= distance * floatsin(a,degrees);
	y += distance * floatcos(a,degrees);

	new Float:surfaceZ;
	z = Placement_FindSurface(x,y,z + 1.0,4.0,surfaceZ) ? surfaceZ - Placement_GetBaseOffset(WORK_CRATE_MODEL) : z - 1.0;
}

static Work_DevPlaceStation(playerid,epoch)
{
	new kind = Work_DevPickKind(playerid,epoch,false);

	if (kind == -1)
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a, name[WORK_KIND_NAME_LEN];
	Work_DevFrontOf(playerid,1.5,x,y,z,a);
	Work_GetKindName(kind,name);

	if (!Work_DevGizmo(playerid,epoch,WORK_CRATE_MODEL,name,x,y,z,a,true))
	{
		return;
	}

	z += Placement_GetBaseOffset(WORK_CRATE_MODEL);

	new stationid = await Work_CreateStation(kind,x,y,z,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	Gui_Notify(playerid,stationid == -1 ? ("The station couldn't be saved.") : ("Station placed. If the worker's spot is off, stand where they should stand and use Worker stands here."));
}

static Work_DevPlaceNode(playerid,epoch)
{
	new kind = Work_DevPickKind(playerid,epoch,true);

	if (kind == -1)
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a, model = Work_GetNodeModel(kind,1,1);
	Work_DevFrontOf(playerid,2.0,x,y,z,a);

	if (model != WORK_NO_MODEL && !Work_DevGizmo(playerid,epoch,model,"",x,y,z,a,false))
	{
		return;
	}

	new nodeid = await Work_CreateNode(kind,x,y,z,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	Gui_Notify(playerid,nodeid == -1 ? ("The node couldn't be saved.") : ("Node placed."));
}

static Work_DevTuneShots(playerid,epoch,stationid)
{
	static const labels[4][] = {"Distance", "Height", "Aim", "Side"};
	new Float:x, Float:y, Float:width, value[16];

	for (;;)
	{
		if (!Work_IsValidStation(stationid))
		{
			return;
		}

		Work_PreviewStationShot(playerid,stationid);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Shots");
		Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,200.0,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,"Shots",x,y,width);

		for (new field = 0;field < 4;field++)
		{
			format(value,sizeof(value),"%.2f",Work_GetStationShot(stationid,field));
			Kit_AddText(playerid,x,y + float(field) * KIT_ROW,labels[field],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.40);
			Kit_AddText(playerid,x + width * 0.40,y + float(field) * KIT_ROW,value,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.25);
			Kit_AddButton(playerid,x + width * 0.66,y + float(field) * KIT_ROW,width * 0.15,"-",field * 2);
			Kit_AddButton(playerid,x + width * 0.84,y + float(field) * KIT_ROW,width * 0.15,"+",field * 2 + 1);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 4.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= 8)
		{
			SetCameraBehindPlayer(playerid);
			return;
		}

		new field = pick / 2;
		Work_AdjustStationShot(stationid,field,(pick % 2 == 0 ? -1.0 : 1.0) * (field == WORK_SHOT_DIST ? WORK_SHOT_STEP_DIST : WORK_SHOT_STEP));
	}
}

static Work_DevSupply(playerid,epoch,kind)
{
	new recipes[WORK_MENU_MAX], count = Work_GetRecipesForKind(kind,recipes), name[RECIPE_NAME_LEN], Float:x, Float:y, Float:width;

	if (count == 0)
	{
		Gui_Notify(playerid,"No recipe uses this kind yet.");
		return;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Give me what it needs");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,230.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Give me what it needs",x,y,width);

	for (new i = 0;i < count;i++)
	{
		Recipe_GetName(recipes[i],name);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= count)
	{
		return;
	}

	new recipe = recipes[pick], tool = Recipe_GetTool(recipe);

	if (tool != RECIPE_NO_TOOL && !Work_HasTool(playerid,recipe))
	{
		Inventory_Give(playerid,Item_GetDefKind(tool),tool);
	}

	for (new i = 0;i < RECIPE_MAX_INPUTS;i++)
	{
		new E_ITEM_KIND:inKind, param, amount, minStars;

		if (Recipe_GetInput(recipe,i,inKind,param,amount,minStars))
		{
			Inventory_Give(playerid,inKind,param,amount,max(minStars,ITEM_STARS_MIN));
		}
	}

	Vitals_SetStamina(playerid,Vitals_GetStaminaCap(playerid));
	Gui_Notify(playerid,"Supplied. Your bag has what that recipe needs.");
}

static Work_DevGoto(playerid,epoch,bool:isNode)
{
	new Float:px, Float:py, Float:pz, ids[WORK_DEV_LIST_MAX], Float:dists[WORK_DEV_LIST_MAX], count = 0, total = isNode ? WORK_MAX_NODES : WORK_MAX_STATIONS;
	GetPlayerPos(playerid,px,py,pz);

	for (new i = 0;i < total;i++)
	{
		new Float:x, Float:y, Float:z;

		if (isNode)
		{
			if (!Work_IsValidNode(i))
			{
				continue;
			}

			x = g_WorkNodes[i][E_WORK_NODE_POS][0];
			y = g_WorkNodes[i][E_WORK_NODE_POS][1];
			z = g_WorkNodes[i][E_WORK_NODE_POS][2];
		}
		else
		{
			if (!Work_IsValidStation(i))
			{
				continue;
			}

			x = g_WorkStations[i][E_WORK_STATION_STAND][0];
			y = g_WorkStations[i][E_WORK_STATION_STAND][1];
			z = g_WorkStations[i][E_WORK_STATION_STAND][2];
		}

		new Float:d = Util_GetDistance3D(px,py,pz,x,y,z), k = count < WORK_DEV_LIST_MAX ? count++ : WORK_DEV_LIST_MAX - 1;

		if (k == WORK_DEV_LIST_MAX - 1 && count == WORK_DEV_LIST_MAX && dists[k] <= d)
		{
			continue;
		}

		while (k > 0 && dists[k - 1] > d)
		{
			dists[k] = dists[k - 1];
			ids[k] = ids[k - 1];
			k--;
		}

		dists[k] = d;
		ids[k] = i;
	}

	if (count == 0)
	{
		Gui_Notify(playerid,isNode ? ("There are no nodes yet.") : ("There are no stations yet."));
		return;
	}

	new title[24], name[WORK_KIND_NAME_LEN], detail[16], Float:x, Float:y, Float:width;
	strcopy(title,isNode ? ("Go to a node") : ("Go to a station"));
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,230.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		Work_GetKindName(isNode ? g_WorkNodes[ids[i]][E_WORK_NODE_KIND] : g_WorkStations[ids[i]][E_WORK_STATION_KIND],name);
		format(detail,sizeof(detail),"%.0fm",dists[i]);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,KIT_COLOUR_TEXT,detail,KIT_COLOUR_MUTED,0.70);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= count)
	{
		return;
	}

	new id = ids[pick];
	Kit_Close(playerid);

	if (isNode)
	{
		Util_SafeTeleport(playerid,g_WorkNodes[id][E_WORK_NODE_POS][0] + 1.5,g_WorkNodes[id][E_WORK_NODE_POS][1],g_WorkNodes[id][E_WORK_NODE_POS][2] + 1.0,0.0,g_WorkNodes[id][E_WORK_NODE_WORLD],g_WorkNodes[id][E_WORK_NODE_INTERIOR]);
	}
	else
	{
		Util_SafeTeleport(playerid,g_WorkStations[id][E_WORK_STATION_STAND][0],g_WorkStations[id][E_WORK_STATION_STAND][1],g_WorkStations[id][E_WORK_STATION_STAND][2],g_WorkStations[id][E_WORK_STATION_STAND][3],g_WorkStations[id][E_WORK_STATION_WORLD],g_WorkStations[id][E_WORK_STATION_INTERIOR]);
	}
}

static Work_DevMenu(playerid,bool:isNode)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid);

	for (;;)
	{
		new Float:px, Float:py, Float:pz, world = GetPlayerVirtualWorld(playerid), nearest, name[WORK_KIND_NAME_LEN], title[48], rows = 0, Float:x, Float:y, Float:width;
		GetPlayerPos(playerid,px,py,pz);
		nearest = isNode ? Work_FindNearestNode(px,py,pz,world,WORK_DEV_RANGE) : Work_FindNearestStation(px,py,pz,world,WORK_DEV_RANGE);

		if (nearest != -1 && isNode)
		{
			Work_GetNodeName(INVALID_PLAYER_ID,nearest,name);
		}
		else if (nearest != -1)
		{
			Work_GetKindName(g_WorkStations[nearest][E_WORK_STATION_KIND],name);
		}

		if (isNode)
		{
			format(title,sizeof(title),"Nodes (%d, %d wild, %d coming back)",Work_GetNodeCount(),Work_GetWildNodeCount(),Work_GetWildPending());
		}
		else
		{
			format(title,sizeof(title),"Stations (%d)",Work_GetStationCount());
		}

		new bool:isAdmin = Account_IsAtLeast(playerid,ADMIN_LEVEL_ADMIN), count = (nearest == -1 ? 2 : (isNode ? 6 : (isAdmin ? 9 : 6))) + 2;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,isNode ? ("Place a node here") : ("Place a station here"),WORK_DEV_PLACE);
		Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Go to one",WORK_DEV_LIST);

		if (isNode)
		{
			Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Scatter the wild nodes again",WORK_DEV_WILD_RESET);
			Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Clear my node cooldowns",WORK_DEV_COOLDOWNS);
		}
		else
		{
			Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Give me build materials",WORK_DEV_BUILD_SUPPLY);
			Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Give me 10 talent points",WORK_DEV_POINTS);
		}

		if (nearest != -1)
		{
			new detail[32];

			if (isNode)
			{
				format(detail,sizeof(detail),"%d of %d left",g_WorkNodes[nearest][E_WORK_NODE_STOCK],g_WorkNodes[nearest][E_WORK_NODE_MAX_STOCK]);
			}

			Kit_AddText(playerid,x,y + float(rows++) * KIT_ROW + 2.0,name,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.5);
			Kit_AddText(playerid,x + width * 0.5,y + float(rows - 1) * KIT_ROW + 2.0,detail,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.5);

			if (isNode)
			{
				Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Refill it",WORK_DEV_REFILL);
			}
			else
			{
				Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Move it",WORK_DEV_MOVE);
				if (isAdmin)
				{
					new label[64];
					format(label,sizeof(label),"Worker stands here, at every %s",name);
					Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,label,WORK_DEV_STAND);
					format(label,sizeof(label),"Film from my camera, at every %s",name);
					Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,label,WORK_DEV_CAMERA);
					format(label,sizeof(label),"Fine-tune the view of every %s",name);
					Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,label,WORK_DEV_SHOTS);
				}
			}

			Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Give me what it needs",WORK_DEV_SUPPLY);
			Kit_AddChoice(playerid,x,y + float(rows++) * KIT_ROW,width,"Delete it",WORK_DEV_DELETE,KIT_COLOUR_BAD);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case WORK_DEV_PLACE:
			{
				if (isNode)
				{
					Work_DevPlaceNode(playerid,epoch);
				}
				else
				{
					Work_DevPlaceStation(playerid,epoch);
				}

				return;
			}
			case WORK_DEV_LIST:
			{
				Work_DevGoto(playerid,epoch,isNode);
				return;
			}
			case WORK_DEV_MOVE:
			{
				new Float:sx = g_WorkStations[nearest][E_WORK_STATION_POS][0], Float:sy = g_WorkStations[nearest][E_WORK_STATION_POS][1], Float:sz = g_WorkStations[nearest][E_WORK_STATION_POS][2] - Placement_GetBaseOffset(WORK_CRATE_MODEL), Float:sa = g_WorkStations[nearest][E_WORK_STATION_POS][3];

				if (Work_DevGizmo(playerid,epoch,WORK_CRATE_MODEL,name,sx,sy,sz,sa,true) && Work_IsValidStation(nearest))
				{
					sz += Placement_GetBaseOffset(WORK_CRATE_MODEL);
					Work_MoveStation(nearest,sx,sy,sz,sa);
					Gui_Notify(playerid,"Station moved. The worker's spot was reset in front of it.");
				}

				return;
			}
			case WORK_DEV_STAND:
			{
				if (!isAdmin)
				{
					continue;
				}

				new Float:a;
				GetPlayerFacingAngle(playerid,a);
				Work_SetStationStand(nearest,px,py,pz,a);
				Gui_Notify(playerid,sprintf("Saved for every %s, now and later. The worker stands where you stand and faces where you face.",name));
			}
			case WORK_DEV_CAMERA:
			{
				if (!isAdmin)
				{
					continue;
				}

				new Float:cx, Float:cy, Float:cz, Float:fx, Float:fy, Float:fz;
				GetPlayerCameraPos(playerid,cx,cy,cz);
				GetPlayerCameraFrontVector(playerid,fx,fy,fz);

				if (Work_SetShotFromCamera(nearest,cx,cy,cz,fx,fy,fz))
				{
					Gui_Notify(playerid,sprintf("Saved for every %s, now and later. Work is filmed from where your camera is. The stages still swing around it a little.",name));
				}
				else
				{
					Gui_Notify(playerid,"Stand on the worker's side of the station and look at it, then try again.");
				}
			}
			case WORK_DEV_SHOTS:
			{
				if (!isAdmin)
				{
					continue;
				}

				Work_DevTuneShots(playerid,epoch,nearest);
			}
			case WORK_DEV_SUPPLY:
			{
				Work_DevSupply(playerid,epoch,isNode ? g_WorkNodes[nearest][E_WORK_NODE_KIND] : g_WorkStations[nearest][E_WORK_STATION_KIND]);
			}
			case WORK_DEV_WILD_RESET:
			{
				Work_ClearWildNodes();
				new spawned = await Work_FillWildNodes();
				Gui_Notify(playerid,sprintf("The wild nodes were scattered again: %d placed.",spawned));

				if (!Gui_IsFlowCurrent(playerid,epoch))
				{
					return;
				}
			}
			case WORK_DEV_COOLDOWNS:
			{
				Work_ClearNodeCooldowns(playerid);
				Gui_Notify(playerid,"Your node cooldowns are cleared.");
			}
			case WORK_DEV_REFILL:
			{
				Work_RefillNode(nearest);
			}
			case WORK_DEV_BUILD_SUPPLY:
			{
				new kind = Work_DevPickKind(playerid,epoch,false);

				if (kind != -1)
				{
					for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
					{
						if (Work_GetBuildMaterial(kind,i,item,amount))
						{
							Inventory_Give(playerid,Item_GetDefKind(item),item,amount);
						}
					}

					Work_ResetBuildCooldown(playerid);
					Gui_Notify(playerid,"Supplied. Your bag has what that station takes to build.");
				}
			}
			case WORK_DEV_POINTS:
			{
				Talent_GivePoints(playerid,10);
				Gui_Notify(playerid,"Ten talent points added. Spend them in your bag (N) > Crafting > Talents.");
			}
			case WORK_DEV_DELETE:
			{
				if (isNode)
				{
					Work_DeleteNode(nearest);
				}
				else if (Work_GetStationOwner(nearest) > 0)
				{
					Work_PackUpStation(nearest,WORK_PACK_STAFF);
				}
				else
				{
					Work_DeleteStation(nearest);
				}

				Gui_Notify(playerid,"Deleted.");
			}
		}

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}
	}
}

CMD<ADMIN_LEVEL_TRIAL>:station(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	if (Work_IsWorking(playerid) || Gui_IsBusy(playerid))
	{
		return 1;
	}

	Work_DevMenu(playerid,false);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:node(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	if (Work_IsWorking(playerid) || Gui_IsBusy(playerid))
	{
		return 1;
	}

	Work_DevMenu(playerid,true);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:workpanel(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	if (Work_IsWorking(playerid))
	{
		return 1;
	}

	if (Work_GetPanelChallenge(playerid) != INVALID_PLAYER_TEXT_DRAW)
	{
		Work_HidePanel(playerid);
		return 1;
	}

	Work_ShowPanel(playerid,"Test panel");
	Work_SetPanelLines(playerid,"1/3  Test stage","~y~Y  ~w~H  C  SPACE","Press the keys in the order shown.  Hold ~y~N~w~ to walk away");
	return 1;
}
