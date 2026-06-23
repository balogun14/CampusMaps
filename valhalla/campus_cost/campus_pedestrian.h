#ifndef CAMPUS_PEDESTRIAN_H_
#define CAMPUS_PEDESTRIAN_H_

#include "valhalla/sif/dynamiccost.h"
#include <memory>

namespace valhalla {
namespace sif {

/**
 * Custom pedestrian costing model optimized for campus routing.
 *
 * This costing model:
 * - Prefers paths tagged with campus_id (custom campus paths)
 * - Penalizes stairs (highway=steps) by 50%
 * - Penalizes unpaved surfaces by 30%
 * - Penalizes crossing major roads without crosswalks
 * - Use custom factors to favor safe, walkable campus paths
 */
class CampusPedestrianCost : public DynamicCost {
 public:
  CampusPedestrianCost(const boost::property_tree::ptree& config,
                       const midgard::hash_map<std::string, float>& costs = {});

  ~CampusPedestrianCost() override;

  // -- DynamicCost interface --

  bool Allow(const baldr::DirectedEdge* edge,
             const baldr::EdgeMetadata& meta,
             const baldr::GraphTile* tile,
             const baldr::NodeInfo* node = nullptr) const override;

  bool AllowReverse(const baldr::DirectedEdge* edge,
                    const baldr::EdgeMetadata& meta,
                    const baldr::GraphTile* tile,
                    const baldr::NodeInfo* node = nullptr) const override;

  Cost EdgeCost(const baldr::DirectedEdge* edge,
                const baldr::GraphTile* tile,
                const baldr::NodeInfo* node = nullptr) const override;

  Cost TransitionCost(const baldr::DirectedEdge* edge,
                      const baldr::NodeInfo* node,
                      const baldr::EdgeMetadata& departing,
                      const baldr::EdgeMetadata& arriving,
                      const baldr::GraphTile* tile) const override;

  Cost TransitionCostReverse(const baldr::DirectedEdge* edge,
                             const baldr::NodeInfo* node,
                             const baldr::EdgeMetadata& departing,
                             const baldr::EdgeMetadata& arriving,
                             const baldr::GraphTile* tile) const override;

  float GetCostFactor() const override { return walking_speed_factor_; }

  uint32_t GetExpansionCost() const override { return 2; }

  // Register this costing model with Valhalla's factory
  static void Register();

 private:
  float walking_speed_factor_;
  float use_campus_paths_;
  float avoid_stairs_factor_;
  float unpaved_penalty_;
  float crosswalk_penalty_;
  float walking_speed_kmh_;
};

}  // namespace sif
}  // namespace valhalla

#endif  // CAMPUS_PEDESTRIAN_H_
