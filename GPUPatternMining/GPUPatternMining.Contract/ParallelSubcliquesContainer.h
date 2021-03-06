#pragma once

#include <map>
#include <vector>
#include <atomic>
#include <concurrent_unordered_map.h>
#include <concurrent_vector.h>
#include <ppl.h>

class ParallelSubcliquesContainer
{
private:
	unsigned short cliquesCounter;
	std::map<short, concurrency::concurrent_vector<unsigned short>> typesMap;
public:
	ParallelSubcliquesContainer(unsigned short numberOfTypes);
	void insertClique(std::vector<unsigned short>& clique);
	void insertCliques(std::vector<std::vector<unsigned short>>& cliques);
	bool checkCliqueExistence(std::vector<unsigned short>& clique);

	virtual ~ParallelSubcliquesContainer();
};

