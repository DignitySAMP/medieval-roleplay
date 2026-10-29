stock Light_GripToBone(const Float:offset[3],const Float:rotation[3],const Float:local[3],&Float:x,&Float:y,&Float:z)
{
	new Float:px = local[0], Float:py = local[1], Float:pz = local[2], Float:t;

	t = px * floatcos(rotation[2],degrees) - py * floatsin(rotation[2],degrees);
	py = px * floatsin(rotation[2],degrees) + py * floatcos(rotation[2],degrees);
	px = t;
	t = px * floatcos(rotation[1],degrees) + pz * floatsin(rotation[1],degrees);
	pz = -px * floatsin(rotation[1],degrees) + pz * floatcos(rotation[1],degrees);
	px = t;
	t = py * floatcos(rotation[0],degrees) - pz * floatsin(rotation[0],degrees);
	pz = py * floatsin(rotation[0],degrees) + pz * floatcos(rotation[0],degrees);
	py = t;
	x = px + offset[0];
	y = py + offset[1];
	z = pz + offset[2];
}

stock Light_GetHandFlame(&Float:x,&Float:y,&Float:z)
{
	new grip = Light_FindGrip(MODEL_LIGHT_TORCH_LIT), Float:offset[3], Float:rotation[3], Float:scale[3];

	if (!Attach_GetFit(MODEL_LIGHT_TORCH_LIT,g_LightGrips[grip][E_LIGHT_GRIP_BONE],offset,rotation,scale))
	{
		for (new i = 0;i < 3;i++)
		{
			offset[i] = g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][i];
			rotation[i] = g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][i];
		}
	}

	Light_GripToBone(offset,rotation,g_LightTorchHead,x,y,z);
}

#include <pp-hooks>

hook Attach_OnFitChanged(model,bone)
{
	#pragma unused bone

	if (Light_FindGrip(model) == -1)
	{
		return;
	}

	foreach (new playerid : Player)
	{
		Light_ReattachGrips(playerid);
	}
}
