![Medieval Roleplay](images/banner.jpg)

# Medieval Roleplay

This is the gamemode of Medieval Roleplay, an open.mp server set in a fictional kingdom in the 1200s. It was written from scratch for open.mp with about 200,000 lines of Pawn over 2608 commits between 17 August and 12 October 2026, a custom map with around 3,800 custom models and four open.mp components written or patched for it. Those dates only cover the open.mp rewrite, Medieval Roleplay itself has been around since 2018. It has a lot of systems you won't find on a regular SA-MP roleplay server. Some of them are finished and some of them were still half way there.

Trailer: https://www.youtube.com/watch?v=56eelPx1J4M

First look at the gameplay: https://www.youtube.com/watch?v=qp4mTQ01Amg

<p><img src="images/castle.webp" width="49%"> <img src="images/night-street.webp" width="49%"></p>
<p><img src="images/village.jpg" width="49%"> <img src="images/castle.jpg" width="49%"></p>

# Summary

This is released as is. No support will be given on how to run it. If you know your way around open.mp and sampctl you'll figure it out. This gamemode is heavily dependant on PawnPlus and uses custom components to handle the load. I don't recommend delving into it if you are a novice scripter.

A few things you should know before you start it:

 - It was in its private test stage when I shut it down, so every player counts as a manager. See modules/account/account-teststage.pwn.
 - The roleplay quiz still links the old Discord invite which no longer works.
 - Villagers' dialogue lines were supposed to use Claude Haiku for dynamic speech generation. That's off by default and staff only, and the service isn't part of this release but there will be code remaining.

The code is BSD 3-Clause. View third party code in legacy/ and plugins/ for per-component licenses.

# Features

> [!IMPORTANT]
> The features below do not do this gamemode justice. Please view [full-overview](full-overview.md) to see a 1111 line and 36838 word document detailing every single feature in this gamemode (over 10 years of work).

Accounts and characters
 - Register and log in with bcrypt passwords, behind a private night scene over the castle
 - Roleplay quiz for new accounts: 8 questions out of 42, 5 needed, repeated failures ban the IP
 - Two character slots per account, with a graveyard of dead and retired characters
 - Character creator: sex, look, name, age 16 to 60, five attributes, two traits out of sixteen, an origin and a starting life
 - 86 cultures in 22 groups, each group with its own language. Players who don't know a language read scrambled words
 - Strangers show as "A stranger" until they introduce themselves with H, and every player keeps their own list of names
 - Tutorial island that teaches walking, the bag, fighting and riding before you reach the realm

<p><img src="images/creator.webp" width="49%"> <img src="images/languages.webp" width="49%"></p>
<p><img src="images/creator.jpg" width="49%"> <img src="images/languages.jpg" width="49%"></p>
<p><img src="images/tutorial.jpg" width="49%"> <img src="images/bag.jpg" width="49%"></p>

Life and death
 - A life clock set by age. Every death takes one off, and when it runs out the next death is final
 - Characters age with the calendar, can retire, marry, have up to four children and pick an heir
 - The dead are buried with their name, dates and cause, in the churchyard or the crypt, followed by a funeral
 - Character panel (Space + Alt) with your sheet, health, skills, buffs, family and ledger

<p><img src="images/charpanel.webp" width="49%"> <img src="images/character-sheet.jpg" width="49%"></p>

Survival
 - Hunger, thirst, stamina, warmth, fatigue, dirt and weight, all saved and all shown on the HUD
 - Warmth follows the season, the hour, the altitude, your clothes and nearby fires
 - Fatigue grows by day and faster at night, beds and rest bring it down, being away counts as a night's sleep
 - Dirt makes flies follow you, traders charge more and families won't seat you. Wash at troughs, rivers and wells
 - Six body parts, four wound kinds in three grades. Wounds bleed, fester and need bandaging, cleaning, splints or stitches
 - Twenty ailments with stages, from chills and flux to plague and pox, some leaving permanent marks
 - Sixteen traits that change hunger, cold, combat and work

<p><img src="images/hud.jpg" width="49%"> <img src="images/station.jpg" width="49%"></p>

Chat and emotes
 - /me, /do, /my, /to, /shout, /whisper, /b, /pm and the rest, with ranges and text that fades with distance
 - 404 emote variants over 137 commands in 13 categories, paired emotes and favourites
 - Friends list for every account

The world
 - Custom map with 842 LOD pieces, ColAndreas collision on every map model and a radar drawn from the map
 - Calendar from the year 1200: 12 months of 30 days, 5 real hours per day, moon phases
 - Seasons change the map: 454 trees swap with the season, snow settles in five stages and rivers freeze over
 - Snowfall, storms with lightning, floods, droughts and pestilence, announced by the crier
 - Torches, lanterns, candles, braziers and bonfires that burn their fuel
 - 44 buildings that can burn down, with bucket chains, a church bell and rebuilding by the carpenters
 - Buildings wear down and get repaired from materials players bring
 - Notice boards, the town crier, letters with wax seals and couriers
 - Saturday market and a seasonal fair
 - Graveyard and crypt, /stuck and fall rescue

<p><img src="images/summer.jpg" width="49%"> <img src="images/winter.jpg" width="49%"></p>
<p><img src="images/autumn.jpg" width="49%"> <img src="images/snow-night.jpg" width="49%"></p>
<p><img src="images/winter.webp" width="49%"> <img src="images/tavern-night.jpg" width="49%"></p>
<p><img src="images/map.jpg" width="100%"></p>
<p><img src="images/fortress.webp" width="49%"> <img src="images/crafttown.jpg" width="49%"></p>
<p><img src="images/hamlet.jpg" width="49%"> <img src="images/monastery.jpg" width="49%"></p>

Work and crafting
 - 24 trades, from farming, milling and brewing to smithing, herbalism, physic and scribing, each up to level 10
 - 198 recipes as hands-on scenes: the camera frames the work and you press keys in order, in rhythm or on time
 - Quality from one to five stars, masterpieces at the top level
 - 30 stations you build yourself, unlocked with talent points earned by playing. Fire stations burn fuel
 - 19 kinds of gathering node that regrow, herbs by season with poisonous lookalikes
 - Fishing in rivers, ponds, lakes and the sea with bait, about 35 kinds of fish and ice in winter
 - Hunting with seasonal licences, closed seasons, traps and a wolf bounty
 - Errands from villagers, seasonal duties, player contracts and a ledger

<p><img src="images/chopping.webp" width="49%"> <img src="images/cooking.webp" width="49%"></p>
<p><img src="images/stew.webp" width="49%"> <img src="images/fruit.webp" width="49%"></p>
<p><img src="images/workstation.webp" width="49%"> <img src="images/craftpanel.webp" width="49%"></p>
<p><img src="images/felling.jpg" width="49%"> <img src="images/roasting.jpg" width="49%"></p>
<p><img src="images/gathering.jpg" width="49%"> <img src="images/crafting.jpg" width="49%"></p>

Inventory and currencies
 - Pfennig, groschen and gulden as real coins in the bag
 - Face to face trading where both sides see both bags and both accept
 - NPC traders that buy what you gather and sell a few imports
 - 18 slot bag, 364 items, containers, dropped items and claims for things that don't fit
 - Weight slows you down and bulky loads are carried in your arms
 - Fish go off within the hour unless you cook or salt them

Villagers
 - 41 households with 131 villagers on a daily routine: work, meals, Mass, the spinning circle and market day
 - Sit down and eat with a family, and they remember how you treated them
 - Conversation panel with hundreds of lines, errands and questions about the village
 - Walkers on a node graph and baked navmeshes, through the custom paths and pedestrians components
 - 16 animal species: herds, game, wolves and bears
 - Bandits on the lonely roads at night, and road wardens who keep them away

<p><img src="images/skins.jpg" width="100%"></p>
<p><img src="images/villagers.jpg" width="49%"> <img src="images/horses-night.jpg" width="49%"></p>

Horses and roads
 - Horses and donkeys are animated models, not vehicles, with the rider attached
 - Feeding, watering, grooming, shoeing, trust, stables, breeding with hidden traits and taming wild horses
 - Handcarts, horse carts, wagons and a public coach between the villages
 - Faster travel on roads, waystones at the crossroads and a toll bar on the forest road

<p><img src="images/riding.webp" width="49%"> <img src="images/horses.webp" width="49%"></p>
<p><img src="images/riding.jpg" width="49%"> <img src="images/horses.jpg" width="49%"></p>

The church
 - Mass three times a day with the bell, a congregation that kneels and 52 Latin texts with English subtitles
 - Clergy from novice to abbot, baptism at the font, banns and weddings
 - The paternoster beads at the kneelers
 - Infirmary where monks or player healers treat wounds and illness, and last rites

<p><img src="images/mass.jpg" width="32%"> <img src="images/elevation.jpg" width="32%"> <img src="images/mass.webp" width="32%"></p>
<p><img src="images/prayer.webp" width="49%"> <img src="images/prayer.jpg" width="49%"></p>
<p><img src="images/monastery-night.jpg" width="100%"></p>

Houses
 - 41 houses with their own interiors, 108 rooms, beds, seats and chests
 - Rent a room for a season at the county register, share it with one other person
 - Furnish it with your own chairs, chests and barrels

Law and the realm
 - 13 crimes that only count when someone sees them, a wanted roll and bounties
 - Sworn guards, binding with rope, the pillory, the stocks and the gaol
 - Duke, count and steward, with 20 county policies and decrees on the boards
 - Dues collected in the villages and carried to the steward, and that coin can be robbed

Groups
 - Guilds, households, mercenary bands, outlaw bands, orders, the guard and the church
 - Ranks, a treasury, a storehouse, a hall, contracts and masterpiece judging for guilds

Tournaments and games
 - Jousting, sword bouts, wrestling, archery, a log toss and a drinking match, run by a herald, with bets
 - Dice, Lansquenet and tavern regulars who play for coin

Combat
 - Directional melee: swing in the direction you hold, block with right click, dodge to the side
 - Fists that knock out but never kill
 - 51 weapons and 24 shields
 - Bows, crossbows you crank to span, slings and thrown weapons, with their own projectile physics
 - Struck down players are helped up by others

<p><img src="images/spar.webp" width="49%"> <img src="images/brawl.webp" width="49%"></p>
<p><img src="images/spar.jpg" width="49%"> <img src="images/brawl.jpg" width="49%"></p>

Staff and interface
 - Staff panel, reports, inspect, warnings, kicks, bans, OOC jail and maintenance restarts
 - Textdraw UI kit for every panel, with dialogs only for passwords and names
 - /help with search and "did you mean" for mistyped commands

Under the hood
 - Pawn with PawnPlus async, MySQL with migrations that create every table on first boot
 - Custom open.mp components: ColAndreas, paths, pedestrians and a patched Actors component

# Credits

 - DignitySAMP: creator, gamemode, map and models
 - The open.mp team: the server, and the Actors component that `plugins/actors` patches
 - Pottus and contributors: ColAndreas, ported here to an open.mp component
 - TanF12: omp-pathfinder, which the paths component started from
 - connysamp: Pedestrians, which the walker component started from
 - danyk: pedestrian retaliation, surrendering and steering logic, ported to c++
 - Mikko Mononen: Recast and Detour, used for the navmeshes
 - Y-Less (YSI and sscanf), IS4 (PawnPlus), Incognito (streamer), BlueG (MySQL plugin), Zeex (crashdetect), Nexius (MapFix), Southclaws (pawn-json), Sreyas-Sreelal (samp-bcrypt), JaTochNietDan (FileManager), katursis (Pawn.RakNet), YashasSamaga (SmartCMD), oscar-broman (strlib), kristoisberg (colour manipulation and the textdraw streamer), TommyB123 (samp-map-parser), AGraber (pp-mysql), Alexander Chwojewski (easing functions) and Niels Lohmann (nlohmann/json)
