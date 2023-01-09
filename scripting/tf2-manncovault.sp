/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[TF2] MannCo Vault"
#define PLUGIN_DESCRIPTION "Collect custom built weapons from the MannCo Vault!"
#define PLUGIN_VERSION "1.0.1"

#define DIR_PERMS 511

#define MAX_MANUFACTURERS 16

/*****************************/
//Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#include <json>
#include <tf_econ_data>
#include <tf2items>

/*****************************/
//ConVars

/*****************************/
//Globals

Database g_Database;
KeyValues g_ItemSchema;

enum TF2Quality {
	TF2Quality_Normal = 0, // 0
	TF2Quality_Rarity1,
	TF2Quality_Genuine = 1,
	TF2Quality_Rarity2,
	TF2Quality_Vintage,
	TF2Quality_Rarity3,
	TF2Quality_Rarity4,
	TF2Quality_Unusual = 5,
	TF2Quality_Unique,
	TF2Quality_Community,
	TF2Quality_Developer,
	TF2Quality_Selfmade,
	TF2Quality_Customized, // 10
	TF2Quality_Strange,
	TF2Quality_Completed,
	TF2Quality_Haunted,
	TF2Quality_ToborA
};

enum Grade {
	Any,
	Low,
	Medium,
	High
}

enum struct Manufacturer {
	char name[64];
	Grade grade;

	void Add(const char[] name, Grade grade) {
		strcopy(this.name, sizeof(Manufacturer::name), name);
		this.grade = grade;
	}

	void Clear() {
		this.name[0] = '\0';
		this.grade = Low;
	}
}

Manufacturer g_Manufacturer[MAX_MANUFACTURERS + 1];
int g_TotalManufacturers;

JSON_Object g_WeaponData[4096 + 1];

/*****************************/
//Plugin Info
public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public void OnPluginStart() {
	Database.Connect(OnSQLConnect, "default");

	RegConsoleCmd("sm_vault", Command_Weapons, "View your current vaulted weapons.");
	RegConsoleCmd("sm_weapons", Command_Weapons, "View your current vaulted weapons.");
	RegConsoleCmd("sm_weaponinfo", Command_WeaponInfo, "Views your weapons info.");
	RegAdminCmd("sm_mcv", Command_MCV, ADMFLAG_GENERIC, "Opens the MannCo Vault menu.");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/manncovault/");

	if (!DirExists(sPath)) {
		CreateDirectory(sPath, DIR_PERMS);
	}

	g_ItemSchema = GetItemSchema();
	if (g_ItemSchema == null) {
		ThrowError("[TF2] MannCo Vault: Failed to load item schema!");
	}

	// M_PoopyJoesWarehouse,			//Low Grade
	// M_ArchMedis,						//Healing Weapons
	// M_MonoCule,						//Rocket Launchers
	// M_BonkInc,						//Whacky Weapons
	// M_MerasMuitions,					//Medium Grade
	// M_MannCoFieldsDivision,			//High Grade
	// M_PumpkinInc,					//Melee Weapons
	// M_MissPaulingsPersonalStache		//Rare Weapons
	g_Manufacturer[g_TotalManufacturers++].Add("Poopy Joe's Warehouse", Low);
	g_Manufacturer[g_TotalManufacturers++].Add("Arch Medis", Any);
	g_Manufacturer[g_TotalManufacturers++].Add("Mono Cule", Any);
	g_Manufacturer[g_TotalManufacturers++].Add("Bonk Inc.", Any);
	g_Manufacturer[g_TotalManufacturers++].Add("MerasMunitions", Medium);
	g_Manufacturer[g_TotalManufacturers++].Add("MannCo. Fields Division", Medium);
	g_Manufacturer[g_TotalManufacturers++].Add("Pumpkin Inc.", High);
	g_Manufacturer[g_TotalManufacturers++].Add("Miss Pauling's Personal Stache", High);

	// g_ItemSchema.GotoFirstSubKey();
	// char sName[64];
	// do {
	// 	g_ItemSchema.GetSectionName(sName, sizeof(sName));
	// 	//PrintToServer("Name: %s", sName);
	// } while (g_ItemSchema.GotoNextKey());
	// delete g_ItemSchema;
}

public void OnConfigsExecuted() {

}

public void OnSQLConnect(Database db, const char[] error, any data) {
	if (db == null) {
		ThrowError("[TF2] MannCo Vault: Failed to connect to database: %s", error);
	}

	g_Database = db;
	LogMessage("[TF2] MannCo Vault: Connected to database!");
}

public Action Command_MCV(int client, int args) {
	OpenMenu(client);
	return Plugin_Handled;
}

void OpenMenu(int client) {
	Menu menu = new Menu(OpenMenuHandler);
	menu.SetTitle("MannCo Vault");

	menu.AddItem("generate_e", "Generate Weapon Equipped");
	menu.AddItem("generate_d", "Generate Weapon Drop");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if (StrEqual(info, "generate_e")) {
				OpenGenerateEquipWeapon(param1);
			} else if (StrEqual(info, "generate_d")) {
				OpenGenerateDropWeapon(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	return 0;
}

void OpenGenerateEquipWeapon(int client) {
	Menu menu = new Menu(OpenGenerateEquipMenuHandler);
	menu.SetTitle("MannCo Vault - Generate Weapon Equip");

	menu.AddItem("generate_primary", "Generate a primary weapon.");
	menu.AddItem("generate_secondary", "Generate a secondary weapon.");
	menu.AddItem("generate_melee", "Generate a melee weapon.");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenGenerateEquipMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			TFClassType class = TF2_GetPlayerClass(param1);
			int slot;

			if (StrEqual(info, "generate_primary")) {
				slot = TFWeaponSlot_Primary;
			} else if (StrEqual(info, "generate_secondary")) {
				slot = TFWeaponSlot_Secondary;
			} else if (StrEqual(info, "generate_melee")) {
				slot = TFWeaponSlot_Melee;
			}

			GenerateEquipWeapon(class, slot, param1);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void OpenGenerateDropWeapon(int client) {
	Menu menu = new Menu(OpenGenerateDropMenuHandler);
	menu.SetTitle("MannCo Vault - Generate Weapon Drop");

	menu.AddItem("generate_primary", "Generate a primary weapon.");
	menu.AddItem("generate_secondary", "Generate a secondary weapon.");
	menu.AddItem("generate_melee", "Generate a melee weapon.");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenGenerateDropMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			TFClassType class = TF2_GetPlayerClass(param1);
			int slot;

			float vOrigin[3];
			GetClientEyePosition(param1, vOrigin);

			float vAngles[3];
			GetClientEyeAngles(param1, vAngles);

			// float velocity[3];
			// velocity[0] = GetRandomFloat(-100.0, 100.0);
			// velocity[1] = GetRandomFloat(-100.0, 100.0);
			// velocity[2] = GetRandomFloat(100.0, 200.0);

			if (StrEqual(info, "generate_primary")) {
				slot = TFWeaponSlot_Primary;
			} else if (StrEqual(info, "generate_secondary")) {
				slot = TFWeaponSlot_Secondary;
			} else if (StrEqual(info, "generate_melee")) {
				slot = TFWeaponSlot_Melee;
			}

			GenerateDroppedWeapon(class, slot, vOrigin, vAngles);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

int GenerateEquipWeapon(TFClassType class, int slot, int client) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return -1;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return -1;
	}

	JSON_Object weapon = GenerateWeapon(class, slot);

	char name[64];
	weapon.GetString("name", name, sizeof(name));

	int index = weapon.GetInt("index");

	char classname[64];
	weapon.GetString("classname", classname, sizeof(classname));

	TF2_RemoveWeaponSlot(client, slot);

	int entity = TF2_GiveItem(client, classname, index);
	g_WeaponData[entity] = weapon;

	StoreWeapon(client, entity);

	return entity;
}

int GenerateDroppedWeapon(TFClassType class, int slot, float origin[3], float angles[3]) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return -1;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return -1;
	}

	JSON_Object weapon = GenerateWeapon(class, slot);
	int index = weapon.GetInt("index");

	int entity = TF2_CreateDroppedWeapon(origin, angles, index);
	g_WeaponData[entity] = weapon;

	return entity;
}

JSON_Object GenerateWeapon(TFClassType class, int slot) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return null;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return null;
	}

	JSON_Object weapon = new JSON_Object();

	int index = GetRandomIndex(class, slot);

	char classname[64];
	TF2Econ_GetItemClassName(index, classname, sizeof(classname));

	char name[64];
	GenerateWeaponName(name, sizeof(name));

	int manufacturer = GetRandomInt(0, g_TotalManufacturers - 1);

	weapon.SetString("name", name);
	weapon.SetInt("manufacturer", manufacturer);
	weapon.SetInt("index", index);
	weapon.SetString("classname", classname);

	return weapon;
}

void GenerateWeaponName(char[] buffer, int size) {
	strcopy(buffer, size, "The");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/manncovault/names.txt");

	File file = OpenFile(sPath, "r");

	if (file == null) {
		ThrowError("[TF2] MannCo Vault: Failed to parse file: %s", sPath);
	}

	ArrayList words = new ArrayList(ByteCountToCells(64));
	char name[64];

	while (!file.EndOfFile() && file.ReadLine(name, sizeof(name))) {
		if (strlen(name) == 0) {
			continue;
		}

		words.PushString(name);
	}

	for (int i = 0; i < GetRandomInt(1, 2); i++) {
		words.GetString(GetRandomInt(0, words.Length - 1), name, sizeof(name));
		Format(buffer, size, "%s %s", buffer, name);
	}

	delete words;
	file.Close();
}

int GetRandomIndex(TFClassType class, int slot) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return -1;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return -1;
	}

	ArrayList items = new ArrayList();

	char sClass[64];
	TF2_GetClassName(class, sClass, sizeof(sClass));
	
	char sSlotString[64];
	if (slot == TFWeaponSlot_Primary) {
		sSlotString = "primary";
	} else if (slot == TFWeaponSlot_Secondary) {
		sSlotString = "secondary";
	} else if (slot == TFWeaponSlot_Melee) {
		sSlotString = "melee";
	}

	for (int i = 0; i < 10000; i++) {
		if (TF2Econ_GetItemLoadoutSlot(i, class) == slot) {
			items.Push(i);
		}
	}

	int length = items.Length;

	if (length < 1) {
		delete items;
		return -1;
	}

	int random = items.Get(GetRandomInt(0, length - 1));
	delete items;

	return random;
}

int TF2_CreateDroppedWeapon(float origin[3], float angles[3] = NULL_VECTOR, int index) {
	int entity = CreateEntityByName("tf_dropped_weapon");

	if (!IsValidEntity(entity)) {
		LogError("[TF2] Failed to create dropped weapon entity");
		return -1;
	}

	char model[PLATFORM_MAX_PATH];
	GetModelFromIndex(index, model, sizeof(model));

	DispatchKeyValueVector(entity, "origin", origin);
	DispatchKeyValueVector(entity, "angles", angles);
	DispatchKeyValue(entity, "model", model);
	DispatchSpawn(entity);

	SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", 1);
	SetEntProp(entity, Prop_Send, "m_iEntityQuality", 6);
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", 2048);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", 0);

	return entity;
}

void GetModelFromIndex(int index, char[] buffer, int size) {
	char sIndex[16];
	IntToString(index, sIndex, sizeof(sIndex));

	g_ItemSchema.Rewind();
	g_ItemSchema.JumpToKey("items");
	g_ItemSchema.JumpToKey(sIndex);
	g_ItemSchema.GetString("model_player", buffer, size);

	if (strlen(buffer) == 0) {
		char sPrefab[64];
		g_ItemSchema.GetString("prefab", sPrefab, sizeof(sPrefab));
		g_ItemSchema.Rewind();
		g_ItemSchema.JumpToKey("prefabs");
		g_ItemSchema.JumpToKey(sPrefab);
		g_ItemSchema.GetString("model_player", buffer, size);
	}
}

stock TF2Quality GetQualityFromIndex(int index) {
	char sIndex[16]; char quality[64];
	IntToString(index, sIndex, sizeof(sIndex));

	g_ItemSchema.Rewind();
	g_ItemSchema.JumpToKey("items");
	g_ItemSchema.JumpToKey(sIndex);
	g_ItemSchema.GetString("item_quality", quality, sizeof(quality));

	if (strlen(quality) == 0) {
		char sPrefab[64];
		g_ItemSchema.GetString("prefab", sPrefab, sizeof(sPrefab));
		g_ItemSchema.Rewind();
		g_ItemSchema.JumpToKey("prefabs");
		g_ItemSchema.JumpToKey(sPrefab);
		g_ItemSchema.GetString("item_quality", quality, sizeof(quality));
	}

	if (strlen(quality) == 0) {
		return TF2Quality_Normal;
	}

	return TF2_GetQualityFromName(quality);
}

TF2Quality TF2_GetQualityFromName(const char[] name) {
	if (StrEqual(name, "normal", false)) {
		return TF2Quality_Normal;
	} else if (StrEqual(name, "rarity1", false)) {
		return TF2Quality_Rarity1;
	} else if (StrEqual(name, "genuine", false)) {
		return TF2Quality_Genuine;
	} else if (StrEqual(name, "rarity2", false)) {
		return TF2Quality_Rarity2;
	} else if (StrEqual(name, "vintage", false)) {
		return TF2Quality_Vintage;
	} else if (StrEqual(name, "rarity3", false)) {
		return TF2Quality_Rarity3;
	} else if (StrEqual(name, "rarity4", false)) {
		return TF2Quality_Rarity4;
	} else if (StrEqual(name, "unusual", false)) {
		return TF2Quality_Unusual;
	} else if (StrEqual(name, "unique", false)) {
		return TF2Quality_Unique;
	} else if (StrEqual(name, "community", false)) {
		return TF2Quality_Community;
	} else if (StrEqual(name, "developer", false)) {
		return TF2Quality_Developer;
	} else if (StrEqual(name, "selfmade", false)) {
		return TF2Quality_Selfmade;
	} else if (StrEqual(name, "customized", false)) {
		return TF2Quality_Customized;
	} else if (StrEqual(name, "strange", false)) {
		return TF2Quality_Strange;
	} else if (StrEqual(name, "completed", false)) {
		return TF2Quality_Completed;
	} else if (StrEqual(name, "haunted", false)) {
		return TF2Quality_Haunted;
	} else if (StrEqual(name, "tobora", false)) {
		return TF2Quality_ToborA;
	}
	
	return TF2Quality_Normal;
}

KeyValues GetItemSchema() {
	KeyValues kv = new KeyValues("items_game");
	kv.ImportFromFile("scripts/items/items_game.txt");
	return kv;
}

void TF2_GetClassName(TFClassType class, char[] buffer, int size, bool capitalize = false) {
	switch (class) {
		case TFClass_Unknown: {
			strcopy(buffer, size, "unknown");
		}
		case TFClass_Scout: {
			strcopy(buffer, size, "scout");
		}
		case TFClass_Sniper: {
			strcopy(buffer, size, "sniper");
		}
		case TFClass_Soldier: {
			strcopy(buffer, size, "soldier");
		}
		case TFClass_DemoMan: {
			strcopy(buffer, size, "demoman");
		}
		case TFClass_Medic: {
			strcopy(buffer, size, "medic");
		}
		case TFClass_Heavy: {
			strcopy(buffer, size, "heavy");
		}
		case TFClass_Pyro: {
			strcopy(buffer, size, "pyro");
		}
		case TFClass_Spy: {
			strcopy(buffer, size, "spy");
		}
		case TFClass_Engineer: {
			strcopy(buffer, size, "engineer");
		}
	}

	if (capitalize) {
		buffer[0] = CharToUpper(buffer[0]);
	} else {
		buffer[0] = CharToLower(buffer[0]);
	}
}

stock int TF2_GiveItem(int client, char[] classname, int index, TF2Quality quality = TF2Quality_Normal, int level = 0, const char[] attributes = "") {
	char sClass[64];
	strcopy(sClass, sizeof(sClass), classname);
	
	if (StrContains(sClass, "saxxy", false) != -1) {
		switch (TF2_GetPlayerClass(client)) {
			case TFClass_Scout: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bat");
			}
			case TFClass_Sniper: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_club");
			}
			case TFClass_Soldier: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shovel");
			}
			case TFClass_DemoMan: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bottle");
			}
			case TFClass_Engineer: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_wrench");
			}
			case TFClass_Pyro: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_fireaxe");
			}
			case TFClass_Heavy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_fists");
			}
			case TFClass_Spy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_knife");
			}
			case TFClass_Medic: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bonesaw");
			}
		}
	} else if (StrContains(sClass, "shotgun", false) != -1) {
		switch (TF2_GetPlayerClass(client)) {
			case TFClass_Soldier: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_soldier");
			}
			case TFClass_Pyro: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_pyro");
			}
			case TFClass_Heavy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_hwg");
			}
			case TFClass_Engineer: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_primary");
			}
		}
	}
	
	Handle item = TF2Items_CreateItem(PRESERVE_ATTRIBUTES | FORCE_GENERATION);	//Keep reserve attributes otherwise random issues will occur... including crashes.
	TF2Items_SetClassname(item, sClass);
	TF2Items_SetItemIndex(item, index);
	TF2Items_SetQuality(item, view_as<int>(quality));
	TF2Items_SetLevel(item, level);
	
	char sAttrs[32][32];
	int count = ExplodeString(attributes, " ; ", sAttrs, 32, 32);
	
	if (count > 1) {
		TF2Items_SetNumAttributes(item, count / 2);
		
		int i2;
		for (int i = 0; i < count; i += 2) {
			TF2Items_SetAttribute(item, i2, StringToInt(sAttrs[i]), StringToFloat(sAttrs[i + 1]));
			i2++;
		}
	} else {
		TF2Items_SetNumAttributes(item, 0);
	}

	int weapon = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	if (StrEqual(sClass, "tf_weapon_builder", false) || StrEqual(sClass, "tf_weapon_sapper", false)) {
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
	}
	
	if (StrContains(sClass, "tf_weapon_", false) == 0) {
		EquipPlayerWeapon(client, weapon);
	}
	
	return weapon;
}

public Action Command_Weapons(int client, int args) {
	if (client < 1) {
		return Plugin_Handled;
	}

	OpenWeaponsMenu(client);

	return Plugin_Handled;
}

void OpenWeaponsMenu(int client) {
	char sSteamID[64];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID))) {
		return;
	}

	char sQuery[1024];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id, data FROM `mcv_weapons` WHERE steamid = '%s';", sSteamID);
	g_Database.Query(OnViewVault, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void OnViewVault(Database db, DBResultSet results, const char[] error, any data) {
	int client;
	if ((client = GetClientOfUserId(data)) < 1) {
		return;
	}

	if (results == null) {
		ThrowError("Error while opening player vault: %s", error);
	}

	Menu menu = new Menu(MenuHandler_Weapons);
	menu.SetTitle("Vaulted Weapons");

	int id; char sID[16]; char sData[5192]; JSON_Object obj; char sDisplay[64]; char name[64];
	while (results.FetchRow()) {
		id = results.FetchInt(0);
		results.FetchString(1, sData, sizeof(sData));

		obj = json_decode(sData);

		if (obj == null) {
			continue;
		}

		obj.GetString("name", name, sizeof(name));

		IntToString(id, sID, sizeof(sID));
		FormatEx(sDisplay, sizeof(sDisplay), "%s", name);
		menu.AddItem(sID, sDisplay);

		json_cleanup_and_delete(obj);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Weapons(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

public Action Command_WeaponInfo(int client, int args) {
	if (client < 1) {
		return Plugin_Handled;
	}

	int target = GetClientAimTarget(client, false);

	if (IsValidEntity(target)) {
		OpenWeaponInfoPanel(client, target);
		return Plugin_Handled;
	}

	int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	OpenWeaponInfoPanel(client, active);

	return Plugin_Handled;
}

void OpenWeaponInfoPanel(int client, int weapon) {
	if (!IsValidEntity(weapon)) {
		return;
	}

	if (g_WeaponData[weapon] == null) {
		return;
	}

	Panel panel = new Panel();

	panel.SetTitle("Weapon Info");

	char sText[128];

	char sName[64];
	g_WeaponData[weapon].GetString("name", sName, sizeof(sName));

	FormatEx(sText, sizeof(sText), "Name: %s", sName);
	panel.DrawText(sText);

	int manufacturer = g_WeaponData[weapon].GetInt("manufacturer");

	FormatEx(sText, sizeof(sText), "Manufacturer: %s", g_Manufacturer[manufacturer].name);
	panel.DrawText(sText);

	panel.DrawItem("Exit");

	panel.Send(client, OnWeaponInfoPanel, MENU_TIME_FOREVER);
	delete panel;
}

public int OnWeaponInfoPanel(Menu menu, MenuAction action, int param1, int param2) {
	
}

void StoreWeapon(int client, int weapon) {
	if (g_WeaponData[weapon] == null) {
		return;
	}

	char sSteamID[64];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID))) {
		return;
	}

	char sData[5192];
	g_WeaponData[weapon].Encode(sData, sizeof(sData));

	char sQuery[1024];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `mcv_weapons` (steamid, data) VALUES ('%s', '%s');", sSteamID, sData);
	g_Database.Query(OnStoreWeapon, sQuery, _, DBPrio_Low);
}

public void OnStoreWeapon(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while storing player weapon: %s", error);
	}
}

public void OnEntityDestroyed(int entity) {
	if (entity > MaxClients) {
		if (g_WeaponData[entity] != null) {
			json_cleanup_and_delete(g_WeaponData[entity]);
		}
	}
}