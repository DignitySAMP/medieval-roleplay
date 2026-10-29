#ifndef COLANDREASDATABASEREADER_H_INCLUDED
#define COLANDREASDATABASEREADER_H_INCLUDED

#include <stdint.h>
#include <iostream>
#include <string>
#include <fstream>
#include <cstring>
#include <vector>
#include <map>

using namespace std;

typedef struct {
	float x, y, z;
} Vector;

typedef struct {
	float x, y, z, w;
} Quaternion;

typedef struct {
	Vector Offset;
	float Radius;
} structSphereData;

typedef struct {
	Vector Center;
	Vector Size;
} structBoxData;

typedef struct {
	Vector FaceA;
	Vector FaceB;
	Vector FaceC;
} structFacesData;
typedef struct
{
	uint16_t Modelid;
	int16_t CustomModelid;

	uint16_t SphereCount;
	uint16_t BoxCount;
	uint16_t FaceCount;

	structSphereData* SphereData;
	structBoxData* BoxData;
	structFacesData* FacesData;

} CollisionModelstructure;

typedef struct
{
	uint16_t Modelid;

	Vector Position;
	Quaternion Rotation;
} ItemPlacementstructure;

#define GetBytes(Source, Destination, Index, BytesToCopy) memcpy(&(Destination), (Source + Index), BytesToCopy), Index+=BytesToCopy

bool ReadColandreasDatabaseFile(std::string FileLocation);
extern std::map<uint16_t, CollisionModelstructure> CollisionModels;
extern ItemPlacementstructure* ModelPlacements;
extern std::vector<ItemPlacementstructure*> RemovedGameObjects;
extern uint16_t ModelCount;
extern uint32_t IPLCount;
extern std::map<int32_t, uint16_t> ModelRef;

#endif 
