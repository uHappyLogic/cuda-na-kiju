#pragma once
// --------------------------------------------------------------------------------------------------


#include "..\PlaneSweep\PlaneSweepTableInstanceResult.h"
#include "..\InstanceTree/IntanceTablesMapCreator.h"
#include "..\InstanceTree/InstanceTypedNeighboursMapCreator.h"
#include "..\Helpers/CliquesCandidatesHelpers.h"
// --------------------------------------------------------------------------------------------------


struct GpuCliques;

namespace InstanceTree
{

	/*
		assuming that candidate cliques are
			ABC
			CDE
		then content of instances is as follows ( \ - only visual separation of clique levels)
			
			std::vector
			 a1 a2 a3 c1 c2 \ b1 b1 b2 d1 d2 \ c2 c1 c2 e1 e2

	*/
	typedef std::vector<thrust::device_vector<FeatureInstance>> CliquesInstances;
	// ----------------------------------------------------------------------------------------------

	struct InstanceTreeResult
	{
		thrust::device_vector<FeatureInstance> instances;
		thrust::device_vector<unsigned int> instancesCliqueId;
	};
	// ----------------------------------------------------------------------------------------------
	
	typedef std::shared_ptr<InstanceTreeResult> InstanceTreeResultPtr;
	// ----------------------------------------------------------------------------------------------

	class InstanceTree
	{
	public:
		InstanceTree(
			PlaneSweepTableInstanceResultPtr planeSweepResult
			, IntanceTablesMapCreator::ITMPackPtr instanceTablePack
			, InstanceTypedNeighboursMapCreator::ITNMPackPtr typedInstanceNeighboursPack
		);

		InstanceTreeResultPtr getInstancesResult(Entities::GpuCliques& cliquesCandidates);

	private:

		PlaneSweepTableInstanceResultPtr planeSweepResult;
		IntanceTablesMapCreator::ITMPackPtr instanceTablePack;
		InstanceTypedNeighboursMapCreator::ITNMPackPtr typedInstanceNeighboursPack;
	};
}
