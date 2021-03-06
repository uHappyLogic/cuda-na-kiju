#include "catch.hpp"
#include "../GPUPatternMining.CPU/CPUMiningAlgorithms/CPUMiningAlgorithmParallel.h"
#include "../GPUPatternMining.CPU.Tests/testDataGenerator.h"

TEST_CASE("2ElementCliqueParallel", "ParallelMaximalCliquesFindingTests")
{
	CPUMiningAlgorithmParallel miner;
	TestDataGenerator generator;
	int threshold = 5;
	float prevalence = 0.5;
	auto data = generator.getDataForMaximalCliqueSize2();

	miner.loadData(data, 2, 2);
	miner.filterByDistance(threshold);
	miner.filterByPrevalence(prevalence);
	miner.constructMaximalCliques();

	auto result = miner.getMaximalCliques();

	REQUIRE(result.size() == 1);
	REQUIRE(result[0].size() == 2);
}

TEST_CASE("1ElementCliquesParallel", "ParallelMaximalCliquesFindingTests")
{
	CPUMiningAlgorithmParallel miner;
	TestDataGenerator generator;
	int threshold = 5;
	float prevalence = 0.5;
	auto data = generator.getDataForMaximalCliqueSize1();

	miner.loadData(data, 2, 2);
	miner.filterByDistance(threshold);
	miner.filterByPrevalence(prevalence);
	miner.constructMaximalCliques();

	auto result = miner.getMaximalCliques();

	REQUIRE(result.size() == 2);
	REQUIRE(result[0].size() == 1);
	REQUIRE(result[1].size() == 1);
}

TEST_CASE("4ElementCliqueParallel", "ParallelMaximalCliquesFindingTests")
{
	CPUMiningAlgorithmParallel miner;
	TestDataGenerator generator;
	int threshold = 5;
	float prevalence = 0.5;
	auto data = generator.getDataForMaximalCliqueSize4();

	miner.loadData(data, 4, 4);
	miner.filterByDistance(threshold);
	miner.filterByPrevalence(prevalence);
	miner.constructMaximalCliques();

	auto result = miner.getMaximalCliques();

	REQUIRE(result.size() == 1);
	REQUIRE(result[0].size() == 4);
}

TEST_CASE("2OverlappingCliquesParallel", "ParallelMaximalCliquesFindingTests")
{
	CPUMiningAlgorithmParallel miner;
	TestDataGenerator generator;
	int threshold = 5;
	float prevalence = 0.1;
	auto data = generator.getDataFor2OverlappingCliques();

	miner.loadData(data, 5, 5);
	miner.filterByDistance(threshold);
	miner.filterByPrevalence(prevalence);
	miner.constructMaximalCliques();

	auto result = miner.getMaximalCliques();

	REQUIRE(result.size() == 2);
}

TEST_CASE("DistinctCliquesParallel", "ParallelMaximalCliquesFindingTests")
{
	CPUMiningAlgorithmParallel miner;
	TestDataGenerator generator;
	int threshold = 5;
	float prevalence = 0.1;
	auto data = generator.getDataForDistinctCliques();

	miner.loadData(data, 5, 5);
	miner.filterByDistance(threshold);
	miner.filterByPrevalence(prevalence);
	miner.constructMaximalCliques();

	auto result = miner.getMaximalCliques();

	REQUIRE(result.size() == 2);
}