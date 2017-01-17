#include  "InstanceTree.h"
#include "InstanceTreeHelpers.h"
#include <thrust/execution_policy.h>


namespace InstanceTree
{
	typedef thrust::device_vector<unsigned int> UIntThrustVector;
	typedef std::shared_ptr<UIntThrustVector> UIntThrustVectorPtr;

	typedef thrust::device_vector<FeatureInstance> FeatureInstanceThrustVector;
	typedef std::shared_ptr<FeatureInstanceThrustVector> FeatureInstanceThrustVectorPtr;
	


	InstanceTree::InstanceTree(
		PlaneSweepTableInstanceResultPtr planeSweepResult
		, IntanceTablesMapCreator::ITMPackPtr instanceTablePack
		, InstanceTypedNeighboursMapCreator::ITNMPackPtr typedInstanceNeighboursPack
	)
		: planeSweepResult(planeSweepResult)
		, instanceTablePack(instanceTablePack)
		, typedInstanceNeighboursPack(typedInstanceNeighboursPack)
	{
		
	}

	InstanceTreeResultPtr InstanceTree::getInstancesResult(CliquesCandidates cliquesCandidates)
	{
		if (cliquesCandidates.empty())
			return nullptr;

		const unsigned int currentCliquesSize = cliquesCandidates[0].size();
		
		// migrate data to GPU
		thrust::device_vector<thrust::device_vector<unsigned short>> cliquesData;
		thrust::device_vector<thrust::device_ptr<const unsigned short>> cliques;
		{
			thrust::host_vector<thrust::device_vector<unsigned short>> hcliquesData;

			for (CliqueCandidate cc : cliquesCandidates)
				hcliquesData.push_back(cc);

			cliquesData = hcliquesData;

			std::vector<thrust::device_ptr<const unsigned short>> hcliques;
			for (thrust::device_vector<unsigned short> tdus : hcliquesData)
				hcliques.push_back(tdus.data());

			cliques = hcliques;
		}

		std::vector<FeatureInstanceThrustVectorPtr> instancesElementsInLevelVectors;
		thrust::device_vector<thrust::device_ptr<FeatureInstance>> instancesElementsInLevel;


		thrust::device_vector<thrust::device_ptr<bool>> masksOnLevels;

		thrust::device_vector<thrust::device_ptr<unsigned int>> groupNumbersOnLevels;

		//TODO check if is needed
		thrust::device_vector<thrust::device_ptr<unsigned int>> itemNumbersOnLevels;
		

		// build first tree level
		thrust::device_vector<unsigned int> pairCounts(cliquesCandidates.size());
		
		dim3 insertGrid;
		findSmallest2D(cliquesCandidates.size(), 256, insertGrid.x, insertGrid.y);

		thrust::device_vector<unsigned int> newEntriesCounts(cliquesCandidates.size());

		InstanceTreeHelpers::fillFirstPairCountFromMap <<< insertGrid, 256 >>>(
			instanceTablePack->map->getBean()
			, thrust::raw_pointer_cast(cliques.data())
			, cliques.size()
			, newEntriesCounts.data()
		);
		
		CUDA_CHECK_RETURN(cudaDeviceSynchronize());

		std::vector<InstanceTreeHelpers::ForGroupsResultPtr> levelResults;

		auto firstTwoLevelsFg = InstanceTreeHelpers::forGroups(newEntriesCounts);

		CUDA_CHECK_RETURN(cudaDeviceSynchronize());
		
		// level 0
		levelResults.push_back(firstTwoLevelsFg);
		instancesElementsInLevelVectors.push_back(std::make_shared<FeatureInstanceThrustVector>(firstTwoLevelsFg->threadCount));
		instancesElementsInLevel.push_back(instancesElementsInLevelVectors.back()->data());
		groupNumbersOnLevels.push_back(firstTwoLevelsFg->groupNumbers.data());
		itemNumbersOnLevels.push_back(firstTwoLevelsFg->itemNumbers.data());

		// level 1
		levelResults.push_back(firstTwoLevelsFg);
		instancesElementsInLevelVectors.push_back(std::make_shared<FeatureInstanceThrustVector>(firstTwoLevelsFg->threadCount));
		instancesElementsInLevel.push_back(instancesElementsInLevelVectors.back()->data());
		groupNumbersOnLevels.push_back(firstTwoLevelsFg->groupNumbers.data());
		itemNumbersOnLevels.push_back(firstTwoLevelsFg->itemNumbers.data());

		// fill first two tree levels with FeatureInstance
		dim3 writeFirstTwoLevelsGrid;
		findSmallest2D(firstTwoLevelsFg->threadCount, 256, writeFirstTwoLevelsGrid.x, writeFirstTwoLevelsGrid.y);

		InstanceTreeHelpers::writeFirstTwoLevels <<< writeFirstTwoLevelsGrid, 256 >>> (
			instanceTablePack->map->getBean()
			, thrust::raw_pointer_cast(cliques.data())
			, firstTwoLevelsFg->groupNumbers.data()
			, firstTwoLevelsFg->itemNumbers.data()
			, planeSweepResult->pairsA.data()
			, planeSweepResult->pairsB.data()
			, firstTwoLevelsFg->threadCount
			, instancesElementsInLevel[0]
			, instancesElementsInLevel[1]
		);
		
		thrust::device_vector<bool> integrityMask(firstTwoLevelsFg->threadCount, true);

		for (unsigned int currentLevel = 2; currentLevel < currentCliquesSize; ++currentLevel)
		{
			unsigned int previousLevelInstancesCount = instancesElementsInLevelVectors.back()->size();

			dim3 getLevelCounts;
			findSmallest2D(previousLevelInstancesCount, 256, getLevelCounts.x, getLevelCounts.y);

			thrust::device_vector<unsigned int> levelCountsResult(previousLevelInstancesCount);

			InstanceTreeHelpers::fillWithNextLevelCountsFromTypedNeighbour <<< getLevelCounts, 256 >>> (
				typedInstanceNeighboursPack->map->getBean()
				, thrust::raw_pointer_cast(cliques.data())
				, thrust::raw_pointer_cast(groupNumbersOnLevels.data())
				, instancesElementsInLevel[currentLevel - 1]
				, previousLevelInstancesCount
				, currentLevel
				, integrityMask.data()
				, levelCountsResult.data()
			);

			CUDA_CHECK_RETURN(cudaDeviceSynchronize());

			auto forGroupsResult = InstanceTreeHelpers::forGroups(levelCountsResult);

			CUDA_CHECK_RETURN(cudaDeviceSynchronize());

			// maintain history
			levelResults.push_back(forGroupsResult);
			instancesElementsInLevelVectors.push_back(std::make_shared<FeatureInstanceThrustVector>(forGroupsResult->threadCount));
			instancesElementsInLevel.push_back(instancesElementsInLevelVectors.back()->data());
			groupNumbersOnLevels.push_back(forGroupsResult->groupNumbers.data());
			itemNumbersOnLevels.push_back(forGroupsResult->itemNumbers.data());

			dim3 insertLevelInstances;
			findSmallest2D(forGroupsResult->threadCount, 256, insertLevelInstances.x, insertLevelInstances.y);

			InstanceTreeHelpers::fillLevelInstancesFromNeighboursList <<< insertLevelInstances, 256 >>> (
				typedInstanceNeighboursPack->map->getBean()
				, cliques.data().get()
				, groupNumbersOnLevels.data().get()
				, forGroupsResult->itemNumbers.data()
				, instancesElementsInLevel[currentLevel - 1]
				, planeSweepResult->pairsB.data()
				, forGroupsResult->threadCount
				, currentLevel
				, instancesElementsInLevel[currentLevel]
			);

			CUDA_CHECK_RETURN(cudaDeviceSynchronize());
			
			dim3 checkCliqueIntegrity = insertLevelInstances;

			unsigned int currentLevelElementsCount = instancesElementsInLevelVectors.back()->size();

			if (integrityMask.size() < currentLevelElementsCount)
				integrityMask = thrust::device_vector<bool>(currentLevelElementsCount);

			InstanceTreeHelpers::markAsPartOfCurrentCliqueInstance <<< checkCliqueIntegrity, 256 >>> (
				typedInstanceNeighboursPack->map->getBean()
				, groupNumbersOnLevels.data().get()
				, instancesElementsInLevel.data().get()
				, instancesElementsInLevel[currentLevel]
				, planeSweepResult->pairsB.data()
				, forGroupsResult->threadCount
				, currentLevel
				, integrityMask.data()
			);

			CUDA_CHECK_RETURN(cudaDeviceSynchronize());
		}

		unsigned int candidatesCount = levelResults.back()->threadCount;

		
		thrust::device_vector<unsigned int> writePositions(candidatesCount);

		InstanceTreeResultPtr result = std::make_shared<InstanceTreeResult>();
		
		unsigned int consistentCount = InstanceTreeHelpers::fillWritePositionsAndReturnCount(
			integrityMask
			, writePositions
			, candidatesCount
		);

		result->instances = thrust::device_vector<FeatureInstance>(consistentCount);

		dim3 reverseGenerateInstancesDim;
		findSmallest2D(candidatesCount, 256, reverseGenerateInstancesDim.x, reverseGenerateInstancesDim.y);

		InstanceTreeHelpers::reverseGenerateCliquesInstances <<< reverseGenerateInstancesDim, 256 >>>(
			groupNumbersOnLevels.data().get()
			, instancesElementsInLevel.data().get()
			, candidatesCount
			, currentCliquesSize
			, integrityMask.data()
			, writePositions.data()
			, result->instances.data()
		);

		CUDA_CHECK_RETURN(cudaDeviceSynchronize());

		return result;
	}
}
// --------------------------------------------------------------------------------------------------
