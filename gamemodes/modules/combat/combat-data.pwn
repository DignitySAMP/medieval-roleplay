#define INVALID_WEAPON_INDEX (-1)
#define INVALID_SHIELD_INDEX (-1)
#define COMBAT_NAME_LEN (24)
#define COMBAT_PATH_LEN (48)
#define WEAPON_ARROW_MODEL (-27999)
#define WEAPON_RANGED_BASE_DAMAGE (5.0)
#define MODEL_WEAPON_CROSSBOW_SPANNED (-7011)
#define MODEL_WEAPON_CROSSBOW_SLACK (-7012)
#define MODEL_WEAPON_CROSSBOW_LOADED (-7013)
#define MODEL_WEAPON_CROSSBOW_CRANK (-7014)
#define MODEL_WEAPON_CROSSBOW_BOLT (-7015)
#define MODEL_WEAPON_BOLT_QUIVER (-7016)
#define MODEL_WEAPON_SLING_EMPTY (-7017)
#define MODEL_WEAPON_SLING_LOADED (-7018)
#define MODEL_WEAPON_SLING_STONE (-7019)
#define MODEL_WEAPON_STONE_POUCH (-7020)

forward Float:Combat_CapToStrikeDown(targetid,Float:damage);

enum E_WEAPON_TYPE
{
	WEAPON_TYPE_LONGSWORD,
	WEAPON_TYPE_SHORTSWORD,
	WEAPON_TYPE_BLUNT,
	WEAPON_TYPE_DAGGER,
	WEAPON_TYPE_AXE,
	WEAPON_TYPE_GREATAXE,
	WEAPON_TYPE_SPEAR,
	WEAPON_TYPE_BOW,
	WEAPON_TYPE_CROSSBOW,
	WEAPON_TYPE_SLING,
}

enum E_WEAPON_ROW
{
	E_WEAPON_MODEL,
	E_WEAPON_NAME[COMBAT_NAME_LEN],
	E_WEAPON_DFF[COMBAT_PATH_LEN],
	E_WEAPON_TYPE:E_WEAPON_KIND,
	Float:E_WEAPON_DAMAGE,
	Float:E_WEAPON_REACH,
	bool:E_WEAPON_THROWABLE,
}

enum
{
	WEAPON_AXE_HATCHET = 0, WEAPON_AXE_IRON_HAMMER, WEAPON_AXE_RUSTY_PICK, WEAPON_AXE_STEEL_PICK,
	WEAPON_BLUNT_MORNINGSTAR, WEAPON_BLUNT_PEAR, WEAPON_BLUNT_POLEHAMMER, WEAPON_BLUNT_SLEDGEHAMMER, WEAPON_BLUNT_SPIKED_CLUB, WEAPON_BLUNT_SPIKED_MACE, WEAPON_BLUNT_WINGED_MACE,
	WEAPON_GREATAXE_BARDICHE, WEAPON_GREATAXE_GREATAX, WEAPON_GREATAXE_BATTLE, WEAPON_GREATAXE_FIGHTING, WEAPON_GREATAXE_DOUBLEHEAD, WEAPON_GREATAXE_IRON, WEAPON_GREATAXE_POLEAX, WEAPON_GREATAXE_VOULGE, WEAPON_GREATAXE_WARAX,
	WEAPON_KNIFE_CLEAVER, WEAPON_KNIFE_CLUB, WEAPON_KNIFE_DAGGER, WEAPON_KNIFE_KHYBER, WEAPON_KNIFE_PEASANT,
	WEAPON_LONGSWORD_B_BASTARD, WEAPON_LONGSWORD_BASTARD,
	WEAPON_SHORTSWORD_B_LONGSWORD, WEAPON_SHORTSWORD_BROADSWORD, WEAPON_SHORTSWORD_FALCHION, WEAPON_SHORTSWORD_LONGSWORD, WEAPON_SHORTSWORD_SCIMITAR, WEAPON_SHORTSWORD_SHASHQA, WEAPON_SHORTSWORD_SICKLE, WEAPON_SHORTSWORD_VIKING,
	WEAPON_SPEAR, WEAPON_SPEAR_DOUBLEHEADED, WEAPON_SPEAR_FORK, WEAPON_SPEAR_FORK_MILITARY, WEAPON_SPEAR_GLAIVE, WEAPON_SPEAR_HEAVYLANCE, WEAPON_SPEAR_WOODENSTAFF, WEAPON_SPEAR_IRONSTAFF, WEAPON_SPEAR_JOUST, WEAPON_SPEAR_PIKE, WEAPON_SPEAR_PITCHFORK, WEAPON_SPEAR_SCYTHE, WEAPON_SPEAR_TRIDENT,
	WEAPON_BOW_RUS, WEAPON_CROSSBOW, WEAPON_SLING,
	WEAPON_COUNT,
}

static const s_Weapons[WEAPON_COUNT][E_WEAPON_ROW] = {
	{-27003, "Hatchet", "axe/axe_hatchet.dff", WEAPON_TYPE_AXE, 7.5, 1.5, true},
	{-27005, "Iron Hammer", "axe/axe_iron_hammer.dff", WEAPON_TYPE_AXE, 6.5, 1.5, true},
	{-27007, "Rusty Pick", "axe/axe_rusty_pick.dff", WEAPON_TYPE_AXE, 7.0, 1.5, true},
	{-27008, "Steel Pick", "axe/axe_steel_pick.dff", WEAPON_TYPE_AXE, 7.5, 1.5, true},
	{-27011, "Morningstar", "blunt/blunt_morningstar.dff", WEAPON_TYPE_BLUNT, 9.0, 1.5, false},
	{-27012, "Pear", "blunt/blunt_pear.dff", WEAPON_TYPE_BLUNT, 7.0, 1.5, false},
	{-27013, "Polehammer", "blunt/blunt_polehammer_maul.dff", WEAPON_TYPE_BLUNT, 8.0, 1.5, false},
	{-27014, "Sledgehammer", "blunt/blunt_sledgehammer.dff", WEAPON_TYPE_BLUNT, 7.0, 1.5, false},
	{-27015, "Spiked Club", "blunt/blunt_spiked_club.dff", WEAPON_TYPE_BLUNT, 9.0, 1.5, false},
	{-27016, "Spiked Mace", "blunt/blunt_spiked_mace.dff", WEAPON_TYPE_BLUNT, 9.0, 1.5, false},
	{-27017, "Winged Mace", "blunt/blunt_mace_winged.dff", WEAPON_TYPE_BLUNT, 10.0, 1.5, false},
	{-27018, "Bardiche", "greataxe/axe_bardiche.dff", WEAPON_TYPE_GREATAXE, 12.5, 1.5, false},
	{-27019, "Greatax", "greataxe/axe_greatax.dff", WEAPON_TYPE_GREATAXE, 13.5, 1.5, false},
	{-27000, "Battle Axe", "axe/axe_battle.dff", WEAPON_TYPE_GREATAXE, 13.0, 1.5, false},
	{-27002, "Fighting Axe", "axe/axe_fightingaxe.dff", WEAPON_TYPE_GREATAXE, 12.0, 1.5, false},
	{-27001, "Double Headed", "axe/axe_doublehead.dff", WEAPON_TYPE_GREATAXE, 14.0, 1.5, false},
	{-27004, "Iron Axe", "axe/axe_iron.dff", WEAPON_TYPE_GREATAXE, 11.5, 1.5, false},
	{-27006, "Pole Axe", "axe/axe_poleax.dff", WEAPON_TYPE_GREATAXE, 13.5, 1.5, false},
	{-27009, "Voulge", "axe/axe_voulge.dff", WEAPON_TYPE_GREATAXE, 12.5, 1.5, false},
	{-27010, "War Axe", "axe/axe_warax.dff", WEAPON_TYPE_GREATAXE, 13.0, 1.5, false},
	{-27020, "Cleaver", "knive/cleaver.dff", WEAPON_TYPE_DAGGER, 3.5, 1.5, true},
	{-27021, "Club", "knive/club.dff", WEAPON_TYPE_DAGGER, 3.0, 1.5, true},
	{-27022, "Dagger", "knive/dagger.dff", WEAPON_TYPE_DAGGER, 4.0, 1.5, true},
	{-27023, "Khyber Knife", "knive/khyber_knife.dff", WEAPON_TYPE_DAGGER, 4.5, 1.5, true},
	{-27024, "Peasant Knife", "knive/knife_peasant.dff", WEAPON_TYPE_DAGGER, 3.25, 1.5, true},
	{-27025, "Hand-and-a-Half Sword", "longsword/b_bastardsword.dff", WEAPON_TYPE_LONGSWORD, 12.5, 1.5, false},
	{-27026, "Bastard Sword", "longsword/bastardsword.dff", WEAPON_TYPE_LONGSWORD, 12.5, 1.5, false},
	{-27027, "Long Sword", "longsword/b_longsword.dff", WEAPON_TYPE_SHORTSWORD, 7.5, 1.5, false},
	{-27028, "Broadsword", "shortsword/broadsword.dff", WEAPON_TYPE_SHORTSWORD, 6.5, 1.5, false},
	{-27029, "Falchion", "shortsword/falchion.dff", WEAPON_TYPE_SHORTSWORD, 4.5, 1.5, false},
	{-27030, "Longsword", "shortsword/longsword.dff", WEAPON_TYPE_SHORTSWORD, 6.0, 1.5, false},
	{-27031, "Scimitar", "shortsword/scimitar.dff", WEAPON_TYPE_SHORTSWORD, 6.0, 1.5, false},
	{-27032, "Shashqa", "shortsword/shashqa.dff", WEAPON_TYPE_SHORTSWORD, 5.75, 1.5, false},
	{-27033, "Sickle", "shortsword/sickle.dff", WEAPON_TYPE_SHORTSWORD, 4.5, 1.5, false},
	{-27034, "Viking Sword", "shortsword/vikingsword.dff", WEAPON_TYPE_SHORTSWORD, 6.0, 1.5, false},
	{-27035, "Spear", "spear/spear.dff", WEAPON_TYPE_SPEAR, 7.0, 1.5, true},
	{-27036, "Double Spear", "spear/spear_doubleheaded.dff", WEAPON_TYPE_SPEAR, 7.0, 1.5, false},
	{-27037, "Fork", "spear/spear_fork.dff", WEAPON_TYPE_SPEAR, 7.0, 1.5, false},
	{-27038, "Military Fork", "spear/spear_fork_military.dff", WEAPON_TYPE_SPEAR, 7.5, 1.5, false},
	{-27039, "Glaive", "spear/spear_glaive.dff", WEAPON_TYPE_SPEAR, 7.5, 1.5, false},
	{-27040, "Heavy Lance", "spear/spear_heavylance.dff", WEAPON_TYPE_SPEAR, 5.0, 1.5, false},
	{-27041, "Wooden Staff", "spear/spear_woodenstaff.dff", WEAPON_TYPE_SPEAR, 3.0, 1.5, false},
	{-27042, "Iron Staff", "spear/spear_ironstaff.dff", WEAPON_TYPE_SPEAR, 4.0, 1.5, false},
	{-27043, "Joust of Peace", "spear/spear_joust_of_peace.dff", WEAPON_TYPE_SPEAR, 5.0, 1.5, false},
	{-27044, "Pike", "spear/spear_pike.dff", WEAPON_TYPE_SPEAR, 5.5, 1.5, false},
	{-27045, "Pitchfork", "spear/spear_pitchfork.dff", WEAPON_TYPE_SPEAR, 6.0, 1.5, false},
	{-27046, "Scythe", "spear/spear_scythe.dff", WEAPON_TYPE_SPEAR, 6.0, 1.5, false},
	{-27047, "Trident", "spear/spear_trident.dff", WEAPON_TYPE_SPEAR, 6.5, 1.5, false},
	{-27048, "Rus Bow", "bow/rus_bow.dff", WEAPON_TYPE_BOW, 5.0, 1.5, false},
	{-7012, "Crossbow", "crossbow/crossbow_slack.dff", WEAPON_TYPE_CROSSBOW, 8.0, 1.5, false},
	{-7017, "Sling", "sling/sling_empty.dff", WEAPON_TYPE_SLING, 2.5, 1.5, false}
};

enum E_RANGED_MODEL_ROW
{
	E_RANGED_MODEL_ID,
	E_RANGED_MODEL_DFF[COMBAT_PATH_LEN],
}

static const s_RangedModels[][E_RANGED_MODEL_ROW] = {
	{-7011, "crossbow/crossbow_spanned.dff"},
	{-7013, "crossbow/crossbow_loaded.dff"},
	{-7014, "crossbow/crossbow_crank.dff"},
	{-7015, "crossbow/crossbow_bolt.dff"},
	{-7016, "crossbow/bolt_quiver.dff"},
	{-7018, "sling/sling_loaded.dff"},
	{-7019, "sling/sling_stone.dff"},
	{-7020, "sling/stone_pouch.dff"}
};

enum E_SCABBARD_ROW
{
	E_SCABBARD_MODEL,
	E_SCABBARD_DFF[COMBAT_PATH_LEN],
	bool:E_SCABBARD_FULL,
	E_SCABBARD_WEAPON,
}

static const s_Scabbards[][E_SCABBARD_ROW] = {
	{-27500, "knive/dagger_e_scabbard.dff", false, WEAPON_KNIFE_DAGGER},
	{-27501, "knive/dagger_f_scabbard.dff", true, WEAPON_KNIFE_DAGGER},
	{-27502, "longsword/b_bastardsword_e_scabbard.dff", false, WEAPON_LONGSWORD_B_BASTARD},
	{-27503, "longsword/b_bastardsword_f_scabbard.dff", true, WEAPON_LONGSWORD_B_BASTARD},
	{-27504, "longsword/b_longsword_e_scabbard.dff", false, WEAPON_SHORTSWORD_B_LONGSWORD},
	{-27505, "longsword/b_longsword_f_scabbard.dff", true, WEAPON_SHORTSWORD_B_LONGSWORD},
	{-27506, "longsword/bastardsword_e_scabbard.dff", false, WEAPON_LONGSWORD_BASTARD},
	{-27507, "longsword/bastardsword_f_scabbard.dff", true, WEAPON_LONGSWORD_BASTARD},
	{-27508, "shortsword/broadsword_e_scabbard.dff", false, WEAPON_SHORTSWORD_BROADSWORD},
	{-27509, "shortsword/broadsword_f_scabbard.dff", true, WEAPON_SHORTSWORD_BROADSWORD},
	{-27510, "shortsword/longsword_e_scabbard.dff", false, WEAPON_SHORTSWORD_LONGSWORD},
	{-27511, "shortsword/longsword_f_scabbard.dff", true, WEAPON_SHORTSWORD_LONGSWORD},
	{-27512, "shortsword/scimitar_e_scabbard.dff", false, WEAPON_SHORTSWORD_SCIMITAR},
	{-27513, "shortsword/scimitar_f_scabbard.dff", true, WEAPON_SHORTSWORD_SCIMITAR},
	{-27514, "shortsword/shashqa_e_scabbard.dff", false, WEAPON_SHORTSWORD_SHASHQA},
	{-27515, "shortsword/shashqa_f_scabbard.dff", true, WEAPON_SHORTSWORD_SHASHQA},
	{-27516, "shortsword/vikingsword_e_scabbard.dff", false, WEAPON_SHORTSWORD_VIKING},
	{-27517, "shortsword/vikingsword_f_scabbard.dff", true, WEAPON_SHORTSWORD_VIKING},
	{-27518, "bow/quiver.dff", false, WEAPON_BOW_RUS}
};

enum E_SHIELD_TYPE
{
	SHIELD_TYPE_ROUND,
	SHIELD_TYPE_ROUND_SMALL,
	SHIELD_TYPE_HEATER,
	SHIELD_TYPE_SQUARE,
}

enum E_SHIELD_ROW
{
	E_SHIELD_MODEL,
	E_SHIELD_DFF[COMBAT_PATH_LEN],
	E_SHIELD_TYPE:E_SHIELD_KIND,
}

static const s_Shields[][E_SHIELD_ROW] = {
	{-27706, "shields/shield_round.dff", SHIELD_TYPE_ROUND},
	{-27707, "shields/shield_round_2.dff", SHIELD_TYPE_ROUND},
	{-27708, "shields/shield_round_3.dff", SHIELD_TYPE_ROUND},
	{-27709, "shields/shield_round_4.dff", SHIELD_TYPE_ROUND},
	{-27710, "shields/shield_round_5.dff", SHIELD_TYPE_ROUND},
	{-27711, "shields/shield_round_6.dff", SHIELD_TYPE_ROUND},
	{-27712, "shields/shield_round_small.dff", SHIELD_TYPE_ROUND_SMALL},
	{-27713, "shields/shield_round_small_2.dff", SHIELD_TYPE_ROUND_SMALL},
	{-27714, "shields/shield_round_small_3.dff", SHIELD_TYPE_ROUND_SMALL},
	{-27715, "shields/shield_round_small_4.dff", SHIELD_TYPE_ROUND_SMALL},
	{-27716, "shields/shield_round_small_5.dff", SHIELD_TYPE_ROUND_SMALL},
	{-27717, "shields/shield_round_small_6.dff", SHIELD_TYPE_ROUND_SMALL},
	{-27700, "shields/shield_h.dff", SHIELD_TYPE_HEATER},
	{-27701, "shields/shield_h_2.dff", SHIELD_TYPE_HEATER},
	{-27702, "shields/shield_h_3.dff", SHIELD_TYPE_HEATER},
	{-27703, "shields/shield_h_4.dff", SHIELD_TYPE_HEATER},
	{-27704, "shields/shield_h_5.dff", SHIELD_TYPE_HEATER},
	{-27705, "shields/shield_h_6.dff", SHIELD_TYPE_HEATER},
	{-27718, "shields/shield_square.dff", SHIELD_TYPE_SQUARE},
	{-27719, "shields/shield_square_2.dff", SHIELD_TYPE_SQUARE},
	{-27720, "shields/shield_square_3.dff", SHIELD_TYPE_SQUARE},
	{-27721, "shields/shield_square_4.dff", SHIELD_TYPE_SQUARE},
	{-27722, "shields/shield_square_5.dff", SHIELD_TYPE_SQUARE},
	{-27723, "shields/shield_square_6.dff", SHIELD_TYPE_SQUARE}
};

stock bool:Weapon_IsValid(weapon)
{
	return weapon >= 0 && weapon < WEAPON_COUNT;
}

stock Weapon_GetModel(weapon)
{
	return Weapon_IsValid(weapon) ? s_Weapons[weapon][E_WEAPON_MODEL] : 0;
}

stock E_WEAPON_TYPE:Weapon_GetType(weapon)
{
	return Weapon_IsValid(weapon) ? s_Weapons[weapon][E_WEAPON_KIND] : WEAPON_TYPE_DAGGER;
}

stock Float:Weapon_GetDamage(weapon)
{
	return Weapon_IsValid(weapon) ? s_Weapons[weapon][E_WEAPON_DAMAGE] : 0.0;
}

stock bool:Weapon_IsRanged(weapon)
{
	if (!Weapon_IsValid(weapon))
	{
		return false;
	}

	new E_WEAPON_TYPE:type = s_Weapons[weapon][E_WEAPON_KIND];
	return type == WEAPON_TYPE_BOW || type == WEAPON_TYPE_CROSSBOW || type == WEAPON_TYPE_SLING;
}

stock Float:Weapon_GetRangedScale(weapon)
{
	return Weapon_GetDamage(weapon) / WEAPON_RANGED_BASE_DAMAGE;
}

stock Float:Weapon_GetReach(weapon)
{
	return Weapon_IsValid(weapon) ? s_Weapons[weapon][E_WEAPON_REACH] : 0.0;
}

stock bool:Weapon_IsThrowable(weapon)
{
	return Weapon_IsValid(weapon) && s_Weapons[weapon][E_WEAPON_THROWABLE];
}

stock Weapon_GetName(weapon,dest[],size = sizeof(dest))
{
	if (!Weapon_IsValid(weapon))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Weapons[weapon][E_WEAPON_NAME],size);
}

stock Weapon_FindByModel(modelid)
{
	for (new i = 0; i < WEAPON_COUNT; i++)
	{
		if (s_Weapons[i][E_WEAPON_MODEL] == modelid)
		{
			return i;
		}
	}

	return INVALID_WEAPON_INDEX;
}

stock Weapon_GetScabbardModel(weapon,bool:full)
{
	for (new i = 0; i < sizeof(s_Scabbards); i++)
	{
		if (s_Scabbards[i][E_SCABBARD_WEAPON] == weapon && s_Scabbards[i][E_SCABBARD_FULL] == full)
		{
			return s_Scabbards[i][E_SCABBARD_MODEL];
		}
	}

	if (weapon == WEAPON_BOW_RUS)
	{
		return s_Scabbards[sizeof(s_Scabbards) - 1][E_SCABBARD_MODEL];
	}

	if (weapon == WEAPON_CROSSBOW)
	{
		return MODEL_WEAPON_BOLT_QUIVER;
	}

	if (weapon == WEAPON_SLING)
	{
		return MODEL_WEAPON_STONE_POUCH;
	}

	return 0;
}

stock Shield_GetCount()
{
	return sizeof(s_Shields);
}

stock bool:Shield_IsValid(shield)
{
	return shield >= 0 && shield < sizeof(s_Shields);
}

stock Shield_GetModel(shield)
{
	return Shield_IsValid(shield) ? s_Shields[shield][E_SHIELD_MODEL] : 0;
}

#include <pp-hooks>

hook Models_OnRegister()
{
	new dff[64], txd[COMBAT_PATH_LEN];
	for (new i = 0; i < WEAPON_COUNT; i++)
	{
		format(dff,sizeof(dff),"weapons/%s",s_Weapons[i][E_WEAPON_DFF]);
		if (i == WEAPON_BOW_RUS)
		{
			strcopy(txd,"weapons/bow/rus_bow.txd",sizeof(txd));
		}
		else if (i == WEAPON_CROSSBOW || i == WEAPON_SLING)
		{
			strcopy(txd,"weapons/ranged.txd",sizeof(txd));
		}
		else
		{
			strcopy(txd,"weapons/weapons.txd",sizeof(txd));
		}

		Models_AddObject(s_Weapons[i][E_WEAPON_MODEL],dff,txd,i == WEAPON_CROSSBOW || i == WEAPON_SLING ? MAP_BASE_STATIC : MODEL_OBJECT_BASE);
	}

	for (new i = 0; i < sizeof(s_RangedModels); i++)
	{
		format(dff,sizeof(dff),"weapons/%s",s_RangedModels[i][E_RANGED_MODEL_DFF]);
		Models_AddObject(s_RangedModels[i][E_RANGED_MODEL_ID],dff,"weapons/ranged.txd",MAP_BASE_STATIC);
	}

	Models_AddObject(WEAPON_ARROW_MODEL,"weapons/bow/arrow.dff","weapons/bow/arrow.txd");

	for (new i = 0; i < sizeof(s_Scabbards); i++)
	{
		format(dff,sizeof(dff),"weapons/%s",s_Scabbards[i][E_SCABBARD_DFF]);
		Models_AddObject(s_Scabbards[i][E_SCABBARD_MODEL],dff,"weapons/weapons.txd");
	}

	for (new i = 0; i < sizeof(s_Shields); i++)
	{
		format(dff,sizeof(dff),"weapons/%s",s_Shields[i][E_SHIELD_DFF]);
		Models_AddObject(s_Shields[i][E_SHIELD_MODEL],dff,"weapons/shields.txd");
	}
}
