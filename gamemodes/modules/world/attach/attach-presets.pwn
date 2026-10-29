#define ATTACH_PRESET_NAME_LEN (16)
#define ATTACH_ANIM_LIB_LEN (16)
#define ATTACH_ANIM_NAME_LEN (32)

enum E_ATTACH_PRESET
{
	E_ATTACH_PRESET_NAME[ATTACH_PRESET_NAME_LEN],
	E_ATTACH_PRESET_MODEL,
	E_ATTACH_PRESET_BONE,
	Float:E_ATTACH_PRESET_POSE[9],
}

static const s_AttachPresets[][E_ATTACH_PRESET] = {
	{"torch", MODEL_LIGHT_TORCH_LIT, ATTACH_BONE_LEFT_HAND, {0.087, 0.025, 0.1, -133.5, 0.0, 180.0, 1.0, 1.0, 1.0}},
	{"torchflame", 19632, ATTACH_BONE_LEFT_HAND, {0.05, -0.299, -0.222, 0.0, 0.0, 0.0, 0.01, 0.01, 0.01}},
	{"lantern", MODEL_LIGHT_LANTERN_LIT, ATTACH_BONE_LEFT_THIGH, {0.014, 0.066, -0.136, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0}},
	{"lanternunlit", MODEL_LIGHT_LANTERN_UNLIT, ATTACH_BONE_LEFT_THIGH, {0.014, 0.066, -0.136, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0}},
	{"smokepot", MODEL_TOOLS_NEXT_SMOKE_POT, ATTACH_BONE_RIGHT_HAND, {0.167, 0.02, 0.0, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0}},
	{"bucket", MODEL_CARRY_BUCKET, ATTACH_BONE_LEFT_HAND, {0.131, 0.011, 0.05, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0}},
	{"basket", MODEL_CARRY_BASKET, ATTACH_BONE_LEFT_HAND, {0.142, 0.038, 0.0, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0}},
	{"wovenbasket", MODEL_CARRY_WOVEN_BASKET, ATTACH_BONE_LEFT_HAND, {0.111, 0.038, 0.0, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0}},
	{"creel", MODEL_CARRY_CREEL, ATTACH_BONE_LEFT_HAND, {0.096, 0.025, 0.0, 0.0, -90.0, 17.6, 1.0, 1.0, 1.0}},
	{"backpack", MODEL_CARRY_BACKPACK, ATTACH_BONE_SPINE, {-0.394, -0.152, -0.003, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0}},
	{"satchel", MODEL_CARRY_SATCHEL, ATTACH_BONE_SPINE, {0.029, -0.158, 0.0, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0}},
	{"log", MODEL_CARRY_CARRY_LOG, ATTACH_BONE_SPINE, {0.166, 0.0, -0.17, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0}},
	{"sack", MODEL_CARRY_CARRY_SACK, ATTACH_BONE_SPINE, {0.22, 0.0, -0.151, 81.5, 101.7, -82.1, 1.0, 1.0, 1.0}},
	{"barrel", MODEL_CARRY_CARRY_BARREL, ATTACH_BONE_SPINE, {0.099, 0.25, -0.04, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0}},
	{"stone", MODEL_CARRY_CARRY_STONE, ATTACH_BONE_SPINE, {0.103, 0.3, -0.04, 82.9, 91.9, -87.5, 1.0, 1.0, 1.0}},
	{"coffer", MODEL_CARRY_COFFER, ATTACH_BONE_SPINE, {-0.043, 0.416, -0.04, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0}},
	{"tabard", MODEL_CLOTHING_TABARD, ATTACH_BONE_SPINE, {0.06, -0.184, 0.0, -92.1, -3.6, -93.8, 1.0, 1.0, 1.0}},
	{"breath", 18696, ATTACH_BONE_HEAD, {0.0, 0.1, -0.2, -25.5, 0.0, 0.0, 0.10, 0.3, 0.15}},
	{"lute", MODEL_GEAR_LUTE, ATTACH_BONE_LEFT_HAND, {-0.157, 0.03, -0.06, 41.6, 160.5, -117.7, 1.0, 1.0, 1.0}},
	{"flute", MODEL_GEAR_FLUTE, ATTACH_BONE_RIGHT_HAND, {0.089, 0.076, -0.07, 78.4, 76.2, -0.7, 1.0, 1.0, 1.0}},
	{"lance", -8218, ATTACH_BONE_RIGHT_HAND, {0.096, 0.038, 0.0, 87.0, -4.2, -174.1, 1.0, 1.0, 1.0}},
	{"lancestub", -8219, ATTACH_BONE_RIGHT_HAND, {0.096, 0.038, 0.0, 87.0, -94.2, 172.2, 1.0, 1.0, 1.0}},
	{"drum", MODEL_GEAR_DRUM, ATTACH_BONE_LEFT_HAND, {0.09, 0.03, 0.0, 180.0, 0.0, 0.0, 1.0, 1.0, 1.0}}
};

enum E_ATTACH_ANIM
{
	E_ATTACH_ANIM_LIB[ATTACH_ANIM_LIB_LEN],
	E_ATTACH_ANIM_NAME[ATTACH_ANIM_NAME_LEN],
}

static s_AttachPresetAnims[sizeof(s_AttachPresets)][E_ATTACH_ANIM];

stock Attach_FindPreset(const name[])
{
	for (new i = 0;i < sizeof(s_AttachPresets);i++)
	{
		if (!strcmp(name,s_AttachPresets[i][E_ATTACH_PRESET_NAME],true))
		{
			return i;
		}
	}

	return -1;
}

stock Attach_FindPresetByModel(model)
{
	for (new i = 0;i < sizeof(s_AttachPresets);i++)
	{
		if (s_AttachPresets[i][E_ATTACH_PRESET_MODEL] == model)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Attach_SetPresetAnim(preset,const lib[],const anim[])
{
	if (preset < 0 || preset >= sizeof(s_AttachPresets))
	{
		return false;
	}

	strcopy(s_AttachPresetAnims[preset][E_ATTACH_ANIM_LIB],lib,ATTACH_ANIM_LIB_LEN);
	strcopy(s_AttachPresetAnims[preset][E_ATTACH_ANIM_NAME],anim,ATTACH_ANIM_NAME_LEN);
	return true;
}

stock bool:Attach_GetPresetAnim(preset,lib[],anim[],libSize = sizeof(lib),animSize = sizeof(anim))
{
	if (preset < 0 || preset >= sizeof(s_AttachPresets) || s_AttachPresetAnims[preset][E_ATTACH_ANIM_NAME][0] == EOS)
	{
		lib[0] = EOS;
		anim[0] = EOS;
		return false;
	}

	strcopy(lib,s_AttachPresetAnims[preset][E_ATTACH_ANIM_LIB],libSize);
	strcopy(anim,s_AttachPresetAnims[preset][E_ATTACH_ANIM_NAME],animSize);
	return true;
}

stock Attach_GetPreset(preset,&model,&bone,Float:pose[9])
{
	model = s_AttachPresets[preset][E_ATTACH_PRESET_MODEL];
	bone = s_AttachPresets[preset][E_ATTACH_PRESET_BONE];

	for (new i = 0;i < 9;i++)
	{
		pose[i] = s_AttachPresets[preset][E_ATTACH_PRESET_POSE][i];
	}
}

stock Attach_FormatPresets(dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	for (new i = 0;i < sizeof(s_AttachPresets);i++)
	{
		format(dest,size,"%s%s%s",dest,i == 0 ? ("") : (" "),s_AttachPresets[i][E_ATTACH_PRESET_NAME]);
	}
}
