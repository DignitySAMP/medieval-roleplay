#define ATTACH_FIT_MAX (128)
#define ATTACH_SEEN_MAX (128)
#define ATTACH_DEV_SLOT (ATTACH_SLOT_BREATH)
#define ATTACH_DEV_PARENT_SLOT (ATTACH_SLOT_INSECTS)

enum E_ATTACH_FIT
{
	bool:E_ATTACH_FIT_USED,
	E_ATTACH_FIT_MODEL,
	E_ATTACH_FIT_BONE,
	Float:E_ATTACH_FIT_POSE[9],
}

static s_AttachFits[ATTACH_FIT_MAX][E_ATTACH_FIT];
static s_AttachSeen[ATTACH_SEEN_MAX][E_ATTACH_FIT];
static bool:s_AttachSlotFitDisabled[MAX_PLAYERS][ATTACH_MAX_SLOTS];

static Attach_FindFit(model,bone)
{
	for (new i = 0;i < ATTACH_FIT_MAX;i++)
	{
		if (s_AttachFits[i][E_ATTACH_FIT_USED] && s_AttachFits[i][E_ATTACH_FIT_MODEL] == model && s_AttachFits[i][E_ATTACH_FIT_BONE] == bone)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Attach_SetSlotFitEnabled(playerid,slot,bool:isEnabled)
{
    if (!Util_IsValidPlayer(playerid) || slot < 0 || slot >= ATTACH_MAX_SLOTS)
    {
        return false;
    }

    s_AttachSlotFitDisabled[playerid][slot] = !isEnabled;
    return true;
}

stock bool:Attach_GetFit(model,bone,Float:offset[3],Float:rotation[3],Float:scale[3])
{
	new fit = Attach_FindFit(model,bone);

	if (fit == -1)
	{
		return false;
	}

	for (new i = 0;i < 3;i++)
	{
		offset[i] = s_AttachFits[fit][E_ATTACH_FIT_POSE][i];
		rotation[i] = s_AttachFits[fit][E_ATTACH_FIT_POSE][3 + i];
		scale[i] = s_AttachFits[fit][E_ATTACH_FIT_POSE][6 + i];
	}

	return true;
}

stock bool:Attach_SetFit(model,bone,const Float:pose[9])
{
	new fit = Attach_FindFit(model,bone);

	for (new i = 0;fit == -1 && i < ATTACH_FIT_MAX;i++)
	{
		if (!s_AttachFits[i][E_ATTACH_FIT_USED])
		{
			fit = i;
		}
	}

	if (fit == -1)
	{
		Log_Error("attach","fit table full at %d",ATTACH_FIT_MAX);
		return false;
	}

	s_AttachFits[fit][E_ATTACH_FIT_USED] = true;
	s_AttachFits[fit][E_ATTACH_FIT_MODEL] = model;
	s_AttachFits[fit][E_ATTACH_FIT_BONE] = bone;

	for (new i = 0;i < 9;i++)
	{
		s_AttachFits[fit][E_ATTACH_FIT_POSE][i] = pose[i];
	}

	return true;
}

stock bool:Attach_ClearFit(model,bone)
{
	new fit = Attach_FindFit(model,bone);

	if (fit == -1)
	{
		return false;
	}

	s_AttachFits[fit][E_ATTACH_FIT_USED] = false;
	return true;
}

stock Attach_CountFits()
{
	new count = 0;

	for (new i = 0;i < ATTACH_FIT_MAX;i++)
	{
		if (s_AttachFits[i][E_ATTACH_FIT_USED])
		{
			count++;
		}
	}

	return count;
}

stock bool:Attach_GetSeen(model,&bone,Float:pose[9])
{
	for (new i = 0;i < ATTACH_SEEN_MAX;i++)
	{
		if (s_AttachSeen[i][E_ATTACH_FIT_USED] && s_AttachSeen[i][E_ATTACH_FIT_MODEL] == model && (bone == -1 || s_AttachSeen[i][E_ATTACH_FIT_BONE] == bone))
		{
			bone = s_AttachSeen[i][E_ATTACH_FIT_BONE];

			for (new p = 0;p < 9;p++)
			{
				pose[p] = s_AttachSeen[i][E_ATTACH_FIT_POSE][p];
			}

			return true;
		}
	}

	return false;
}

stock Attach_FormatSeen(dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	for (new i = 0;i < ATTACH_SEEN_MAX;i++)
	{
		if (s_AttachSeen[i][E_ATTACH_FIT_USED])
		{
			format(dest,size,"%s%s%d/%d",dest,dest[0] == EOS ? ("") : (" "),s_AttachSeen[i][E_ATTACH_FIT_MODEL],s_AttachSeen[i][E_ATTACH_FIT_BONE]);
		}
	}
}

static Attach_NoteSeen(model,bone,const Float:pose[9])
{
	new free = -1;

	for (new i = 0;i < ATTACH_SEEN_MAX;i++)
	{
		if (!s_AttachSeen[i][E_ATTACH_FIT_USED])
		{
			if (free == -1)
			{
				free = i;
			}

			continue;
		}

		if (s_AttachSeen[i][E_ATTACH_FIT_MODEL] == model && s_AttachSeen[i][E_ATTACH_FIT_BONE] == bone)
		{
			return;
		}
	}

	if (free == -1)
	{
		return;
	}

	s_AttachSeen[free][E_ATTACH_FIT_USED] = true;
	s_AttachSeen[free][E_ATTACH_FIT_MODEL] = model;
	s_AttachSeen[free][E_ATTACH_FIT_BONE] = bone;

	for (new p = 0;p < 9;p++)
	{
		s_AttachSeen[free][E_ATTACH_FIT_POSE][p] = pose[p];
	}
}

stock Attach_RefreshAll(model,bone)
{
	foreach (new playerid : Player)
	{
		Attach_Restore(playerid);
	}

	pawn_call_public("Attach_OnFitChanged","dd",model,bone);
}

stock Attach_SaveFit(model,bone)
{
	new Float:offset[3], Float:rotation[3], Float:scale[3];

	if (!Attach_GetFit(model,bone,offset,rotation,scale))
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM attach_fits WHERE model = %d AND bone = %d",model,bone));
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO attach_fits (model, bone, ox, oy, oz, rx, ry, rz, sx, sy, sz) VALUES (%d, %d, %f, %f, %f, %f, %f, %f, %f, %f, %f)",model,bone,offset[0],offset[1],offset[2],rotation[0],rotation[1],rotation[2],scale[0],scale[1],scale[2]));
}

forward bool:Attach_FilterFit(&result,&playerid,&index,&modelid,&bone,&Float:offsetX,&Float:offsetY,&Float:offsetZ,&Float:rotationX,&Float:rotationY,&Float:rotationZ,&Float:scaleX,&Float:scaleY,&Float:scaleZ,&colourOne,&colourTwo);

public bool:Attach_FilterFit(&result,&playerid,&index,&modelid,&bone,&Float:offsetX,&Float:offsetY,&Float:offsetZ,&Float:rotationX,&Float:rotationY,&Float:rotationZ,&Float:scaleX,&Float:scaleY,&Float:scaleZ,&colourOne,&colourTwo)
{
	#pragma unused result, colourOne, colourTwo

    if (playerid >= 0 && playerid < MAX_PLAYERS && index >= 0 && index < ATTACH_MAX_SLOTS && s_AttachSlotFitDisabled[playerid][index])
    {
        return false;
    }

	new Float:pose[9];
	pose[0] = offsetX;
	pose[1] = offsetY;
	pose[2] = offsetZ;
	pose[3] = rotationX;
	pose[4] = rotationY;
	pose[5] = rotationZ;
	pose[6] = scaleX;
	pose[7] = scaleY;
	pose[8] = scaleZ;
	Attach_NoteSeen(modelid,bone,pose);

	new fit = Attach_FindFit(modelid,bone);

	if (fit != -1)
	{
		offsetX = s_AttachFits[fit][E_ATTACH_FIT_POSE][0];
		offsetY = s_AttachFits[fit][E_ATTACH_FIT_POSE][1];
		offsetZ = s_AttachFits[fit][E_ATTACH_FIT_POSE][2];
		rotationX = s_AttachFits[fit][E_ATTACH_FIT_POSE][3];
		rotationY = s_AttachFits[fit][E_ATTACH_FIT_POSE][4];
		rotationZ = s_AttachFits[fit][E_ATTACH_FIT_POSE][5];
		scaleX = s_AttachFits[fit][E_ATTACH_FIT_POSE][6];
		scaleY = s_AttachFits[fit][E_ATTACH_FIT_POSE][7];
		scaleZ = s_AttachFits[fit][E_ATTACH_FIT_POSE][8];
	}

	return false;
}

forward Attach_OnFitChanged(model,bone);

public Attach_OnFitChanged(model,bone)
{
	return 1;
}

forward Attach_LoadOnBoot();

public Attach_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT model, bone, ox, oy, oz, rx, ry, rz, sx, sy, sz FROM attach_fits"));

	new rows = cache_num_rows();

	for (new r = 0;r < rows;r++)
	{
		new model, bone, Float:pose[9];
		cache_get_value_name_int(r,"model",model);
		cache_get_value_name_int(r,"bone",bone);
		cache_get_value_name_float(r,"ox",pose[0]);
		cache_get_value_name_float(r,"oy",pose[1]);
		cache_get_value_name_float(r,"oz",pose[2]);
		cache_get_value_name_float(r,"rx",pose[3]);
		cache_get_value_name_float(r,"ry",pose[4]);
		cache_get_value_name_float(r,"rz",pose[5]);
		cache_get_value_name_float(r,"sx",pose[6]);
		cache_get_value_name_float(r,"sy",pose[7]);
		cache_get_value_name_float(r,"sz",pose[8]);
		Attach_SetFit(model,bone,pose);
	}

	Log_Info("attach","%d attachment fit(s) loaded",rows);
	Boot_LoaderDone();
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
    for (new slot = 0;slot < ATTACH_MAX_SLOTS;slot++)
    {
        s_AttachSlotFitDisabled[playerid][slot] = false;
    }
}
