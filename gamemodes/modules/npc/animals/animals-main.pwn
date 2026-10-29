#include <pp-hooks>

hook Models_OnRegister()
{
	Models_AddSkin(ANIMAL_SKIN_RED_STAG,"animals/red_deer_stag.dff","animals/red_deer_stag.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_RED_HIND,"animals/red_deer_hind.dff","animals/red_deer_hind.txd",ANIMAL_BASE_PED);
	Models_AddObject(MODEL_CARCASS_RED_STAG,"animals/carcass_red_stag.dff","animals/red_deer_stag.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_RED_HIND,"animals/carcass_red_hind.dff","animals/red_deer_hind.txd",MAP_BASE_STATIC);
	Models_AddSkin(ANIMAL_SKIN_ROE_BUCK,"animals/roe_buck.dff","animals/roe_buck.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_ROE_DOE,"animals/roe_doe.dff","animals/roe_doe.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_BOAR,"animals/wild_boar.dff","animals/wild_boar.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_SOW,"animals/wild_sow.dff","animals/wild_sow.txd",ANIMAL_BASE_PED);
	Models_AddObject(MODEL_CARCASS_ROE_BUCK,"animals/carcass_roe_buck.dff","animals/roe_buck.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_ROE_DOE,"animals/carcass_roe_doe.dff","animals/roe_doe.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_BOAR,"animals/carcass_boar.dff","animals/wild_boar.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_SOW,"animals/carcass_sow.dff","animals/wild_sow.txd",MAP_BASE_STATIC);
	Models_AddSkin(ANIMAL_SKIN_WOLF,"animals/wolf.dff","animals/wolf.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_SHE_WOLF,"animals/wolf_f.dff","animals/wolf.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_FOX,"animals/fox.dff","animals/fox.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_VIXEN,"animals/fox_f.dff","animals/fox.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_BEAR,"animals/bear.dff","animals/bear.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_SHE_BEAR,"animals/bear_f.dff","animals/bear.txd",ANIMAL_BASE_PED);
	Models_AddObject(MODEL_CARCASS_WOLF,"animals/carcass_wolf.dff","animals/wolf.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_SHE_WOLF,"animals/carcass_wolf_f.dff","animals/wolf.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_FOX,"animals/carcass_fox.dff","animals/fox.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_VIXEN,"animals/carcass_fox_f.dff","animals/fox.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_BEAR,"animals/carcass_bear.dff","animals/bear.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_SHE_BEAR,"animals/carcass_bear_f.dff","animals/bear.txd",MAP_BASE_STATIC);
	Models_AddSkin(ANIMAL_SKIN_HARE,"animals/hare.dff","animals/hare.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_RABBIT,"animals/rabbit.dff","animals/rabbit.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_PHEASANT,"animals/pheasant_cock.dff","animals/pheasant_cock.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_DUCK,"animals/mallard_drake.dff","animals/mallard_drake.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_HERON,"animals/grey_heron.dff","animals/grey_heron.txd",ANIMAL_BASE_PED);
	Models_AddObject(MODEL_CARCASS_HARE,"animals/carcass_hare.dff","animals/hare.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_RABBIT,"animals/carcass_rabbit.dff","animals/rabbit.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_PHEASANT,"animals/carcass_pheasant.dff","animals/pheasant_cock.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_DUCK,"animals/carcass_duck.dff","animals/mallard_drake.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_DUCK_SWIM,"animals/duck_swim.dff","animals/mallard_drake.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_HERON,"animals/carcass_heron.dff","animals/grey_heron.txd",MAP_BASE_STATIC);
	Models_AddSkin(ANIMAL_SKIN_COW,"animals/cow.dff","animals/cow.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_SHEEP,"animals/sheep.dff","animals/sheep.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_GOAT,"animals/goat.dff","animals/goat.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_PIG,"animals/pig.dff","animals/pig.txd",ANIMAL_BASE_PED);
	Models_AddSkin(ANIMAL_SKIN_HEN,"animals/hen.dff","animals/hen.txd",ANIMAL_BASE_PED);
	Models_AddObject(MODEL_CARCASS_COW,"animals/carcass_cow.dff","animals/cow.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_SHEEP,"animals/carcass_sheep.dff","animals/sheep.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_GOAT,"animals/carcass_goat.dff","animals/goat.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_PIG,"animals/carcass_pig.dff","animals/pig.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_CARCASS_HEN,"animals/carcass_hen.dff","animals/hen.txd",MAP_BASE_STATIC);
}

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"Are there wolves?","~w~Yes. Wolves hunt at night, and all day in winter, and they go for someone walking alone in the woods. A bear won't leave its den's ground and turns on anyone who comes close. A wounded boar charges whoever hurt it. Stay in company, carry a spear, and keep to the roads after dark.",true);
	Help_Register(HELP_SECTION_WORK,"How do I get close to game?","~w~Deer, hares and birds bolt when you come near. ~y~Crouch~w~ and they let you come twice as close. You stay crouched when you draw a bow, crossbow or sling, and ~y~C~w~ crouches or stands with one drawn. Deer and boar keep to the woods, hares and pheasants to the meadows and woodland edges, ducks and herons to the water.",true);
	Command_Describe("animals","Staff: list animals, let the wild ones roam, spawn or clear them, kill or hurt the nearest.");
	SetTimer("Animals_ThinkTick",ANIMALS_THINK_MS,true);
	SetTimer("Animals_StreamTick",ANIMALS_STREAM_MS,true);
	Log_Info("animals","%d species, %d places (%d dens); wild animals roam on stand-in bodies until their skins",ANIMAL_SPECIES_COUNT,ANIMALS_PLACES,ANIMALS_SEED_DENS);
}
