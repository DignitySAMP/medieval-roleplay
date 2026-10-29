#define NEEDS_MEAL_MS (2500)
#define NEEDS_MEAL_SOUND (32200)

static bool:s_NeedsEating[MAX_PLAYERS];
static s_NeedsMealToken[MAX_PLAYERS];

stock bool:Needs_IsEating(playerid)
{
	return Util_IsValidPlayer(playerid) && s_NeedsEating[playerid];
}

static Needs_MealAnimation(E_ITEM_KIND:kind,param,library[],animation[],librarySize = sizeof(library),animationSize = sizeof(animation))
{
	if (kind == ITEM_KIND_DRINK)
	{
		strcopy(library,"VENDING",librarySize);
		strcopy(animation,"VEND_Drink_P",animationSize);
		return;
	}

	strcopy(library,"FOOD",librarySize);

	switch (param)
	{
		case ITEM_ROAST, ITEM_SAUSAGE, ITEM_CURED_MEAT, ITEM_SALTED_FISH, ITEM_SMOKED_FISH, ITEM_FISH_DISH, ITEM_ROAST_FISH: strcopy(animation,"EAT_Chicken",animationSize);
		case ITEM_MEAT_PIE, ITEM_FRUIT_PIE, ITEM_PASTRY, ITEM_FEAST_CAKE, ITEM_TRENCHER: strcopy(animation,"EAT_Pizza",animationSize);
		default: strcopy(animation,"EAT_Burger",animationSize);
	}
}

static Needs_PlayMeal(playerid,E_ITEM_KIND:kind,param)
{
	if (Character_IsBusy(playerid))
	{
		return;
	}

	new library[12], animation[16];
	Needs_MealAnimation(kind,param,library,animation);
	SetPlayerAttachedObject(playerid,ATTACH_SLOT_MEAL,Item_GetModel(kind,param),kind == ITEM_KIND_DRINK ? ATTACH_BONE_LEFT_HAND : ATTACH_BONE_RIGHT_HAND,0.135999,0.043999,-0.031000,177.199951,0.0,0.0,1.0,1.0,1.0);

	if (kind == ITEM_KIND_FOOD)
	{
		PlayerPlaySound(playerid,NEEDS_MEAL_SOUND,0.0,0.0,0.0);
	}

	ApplyAnimation(playerid,library,animation,4.1,false,false,false,false,0,SYNC_ALL);
	s_NeedsEating[playerid] = true;
	SetTimerEx("Needs_MealEnd",NEEDS_MEAL_MS,false,"dd",playerid,++s_NeedsMealToken[playerid]);
}

static Needs_Consume(playerid,E_ITEM_KIND:kind,param,stars,index)
{
	new portions = Item_GetPortions(kind,param), value = floatround(float(Item_GetValue(kind,param)) * Item_StarFactor(stars));
	new portion = value / portions, name[ITEM_NAME_LEN], bool:isDrink = kind == ITEM_KIND_DRINK;

	if (Inventory_GetSlotUsed(playerid,index) + 1 >= portions)
	{
		portion = value - portion * (portions - 1);
	}

	Needs_Feed(playerid,isDrink ? NEED_THIRST : NEED_HUNGER,portion);

	if (param == ITEM_ALE && isDrink)
	{
		Needs_Feed(playerid,NEED_HUNGER,NEEDS_ALE_NUTRITION);
	}

	Item_GetName(kind,param,name);
	name[0] = tolower(name[0]);
	new left = Inventory_UsePortion(playerid,index,portions);
	Needs_PlayMeal(playerid,kind,param);

	if (portions == 1)
	{
		Gui_Notify(playerid,sprintf(isDrink ? ("You drank the %s.") : ("You ate the %s."),name));
	}
	else if (left == 0)
	{
		Gui_Notify(playerid,sprintf("You finished the %s.",name));
	}
	else if (isDrink)
	{
		Gui_Notify(playerid,sprintf("You took a sip from the %s. %d sip%s left.",name,left,left == 1 ? ("") : ("s")));
	}
	else
	{
		Gui_Notify(playerid,sprintf("You took a bite of the %s. %d bite%s left.",name,left,left == 1 ? ("") : ("s")));
	}
}

forward Needs_MealEnd(playerid,token);

public Needs_MealEnd(playerid,token)
{
	if (!IsPlayerConnected(playerid) || token != s_NeedsMealToken[playerid])
	{
		return 1;
	}

	s_NeedsEating[playerid] = false;
	RemovePlayerAttachedObject(playerid,ATTACH_SLOT_MEAL);
	return 1;
}

forward bool:Needs_BusyCheck(playerid);

public bool:Needs_BusyCheck(playerid)
{
	return s_NeedsEating[playerid];
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_NeedsEating[playerid] = false;
	s_NeedsMealToken[playerid]++;
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	if (E_ITEM_KIND:kind != ITEM_KIND_FOOD && E_ITEM_KIND:kind != ITEM_KIND_DRINK)
	{
		return;
	}

	if (s_NeedsEating[playerid])
	{
		Gui_Notify(playerid,"You're still eating. Wait until you've finished.");
		return;
	}

	if (Combat_IsInMode(playerid))
	{
		Gui_Notify(playerid,"You can't eat or drink with your guard up. Press ~y~Y~w~ to lower it first.");
		return;
	}

	Needs_Consume(playerid,E_ITEM_KIND:kind,param,stars,index);
}
