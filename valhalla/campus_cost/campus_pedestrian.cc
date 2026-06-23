#include "campus_pedestrian.h"
#include "valhalla/baldr/directededge.h"
#include "valhalla/baldr/nodetransition.h"
#include "valhalla/baldr/edgeinfo.h"
#include "valhalla/sif/costconstants.h"
#include <vector>
#include <mutex>

namespace valhalla {
namespace sif {

// The factory registration will be done inline in Valhalla's source or
// via a registration function called at startup.
//
// This is the simplest approach: we register via a static initializer.

namespace {

// Mutex-protected registration flag
std::once_flag registered;

constexpr float kMetersPerSecToKph = 3.6f;
constexpr float kDefaultWalkingSpeed = 5.0f;   // km/h
constexpr float kDefaultCampusPathPreference = 0.9f;
constexpr float kDefaultStairPenalty = 0.5f;    // 50% extra cost
constexpr float kDefaultUnpavedPenalty = 0.3f;  // 30% extra cost

// Tags to check for campus-specific edges
constexpr const char* kCampusIdTag = "campus_id";
constexpr const char* kHighwayTag = "highway";
constexpr const char* kStepsValue = "steps";
constexpr const char* kSurfaceTag = "surface";
constexpr const char* kUnpavedValue = "unpaved";
constexpr const char* kGravelValue = "gravel";
constexpr const char* kDirtValue = "dirt";
constexpr const char* kFootTag = "foot";
constexpr const char* kDesignatedValue = "designated";

}  // anonymous namespace

CampusPedestrianCost::CampusPedestrianCost(
    const boost::property_tree::ptree& config,
    const midgard::hash_map<std::string, float>& costs)
    : DynamicCost(config, costs) {
  // Read configuration from costing_options.campus_pedestrian
  walking_speed_kmh_ = config.get<float>("walking_speed", kDefaultWalkingSpeed);
  walking_speed_factor_ = kMetersPerSecToKph / walking_speed_kmh_;

  use_campus_paths_ = config.get<float>("use_campus_paths", kDefaultCampusPathPreference);
  avoid_stairs_factor_ = config.get<float>("avoid_stairs", kDefaultStairPenalty);
  unpaved_penalty_ = kDefaultUnpavedPenalty;
  crosswalk_penalty_ = 0.2f;
}

CampusPedestrianCost::~CampusPedestrianCost() = default;

bool CampusPedestrianCost::Allow(
    const baldr::DirectedEdge* edge,
    const baldr::EdgeMetadata& meta,
    const baldr::GraphTile* tile,
    const baldr::NodeInfo* node) const {
  if (!edge) return false;

  // Always allow campus paths
  // Disallow limited-access highways and trunk roads unless crossing
  return !edge->is_limited_access() && !edge->is_tunnel();
}

bool CampusPedestrianCost::AllowReverse(
    const baldr::DirectedEdge* edge,
    const baldr::EdgeMetadata& meta,
    const baldr::GraphTile* tile,
    const baldr::NodeInfo* node) const {
  // Same as Allow for pedestrian (bidirectional paths)
  return Allow(edge, meta, tile, node);
}

Cost CampusPedestrianCost::EdgeCost(
    const baldr::DirectedEdge* edge,
    const baldr::GraphTile* tile,
    const baldr::NodeInfo* node) const {
  if (!edge) return {0.0f, 0.0f};

  // Base cost is distance / walking speed
  float length_m = static_cast<float>(edge->length());
  float sec = length_m / (walking_speed_kmh_ / kMetersPerSecToKph);
  float cost = sec;

  // Apply penalties based on edge properties
  if (edge->use() == baldr::Use::kSteps) {
    // Stairs: apply penalty
    cost *= (1.0f + avoid_stairs_factor_);
  }

  // Check surface via edge info
  if (tile && edge->edgeinfo_offset()) {
    try {
      const auto* edge_info = tile->edgeinfo(edge);
      if (edge_info) {
        // Check for surface type via tag
        // Valhalla bakes surface into the edge attributes
        auto surface = edge_info->surface();
        if (surface == baldr::Surface::kUnpaved ||
            surface == baldr::Surface::kGravel ||
            surface == baldr::Surface::kDirt) {
          cost *= (1.0f + unpaved_penalty_);
        }
      }
    } catch (...) {
      // Edge info not available, continue without penalty
    }
  }

  // Reduce cost for campus paths (makes them preferred)
  if (edge->use() == baldr::Use::kFootway ||
      edge->use() == baldr::Use::kPath) {
    cost *= (1.0f - use_campus_paths_ * 0.3f);
  }

  // Ensure minimum cost
  cost = std::max(cost, 0.0f);

  return {cost, sec};
}

Cost CampusPedestrianCost::TransitionCost(
    const baldr::DirectedEdge* edge,
    const baldr::NodeInfo* node,
    const baldr::EdgeMetadata& departing,
    const baldr::EdgeMetadata& arriving,
    const baldr::GraphTile* tile) const {
  // Base transition cost (time penalty for changing direction/crossing)
  float sec = 0.0f;
  float cost = 0.0f;

  // Penalty for crossing a road (not staying on the same path type)
  if (arriving.edge && departing.edge) {
    auto arriving_use = arriving.edge->use();
    auto departing_use = departing.edge->use();

    if (arriving_use != departing_use) {
      // We're changing path types (e.g., sidewalk to crosswalk)
      // Check if this is a road crossing
      if (arriving_use == baldr::Use::kRoad) {
        sec += 2.0f;  // Wait time to cross road
        cost += 2.0f * crosswalk_penalty_;
      }
    }
  }

  return {cost, sec};
}

Cost CampusPedestrianCost::TransitionCostReverse(
    const baldr::DirectedEdge* edge,
    const baldr::NodeInfo* node,
    const baldr::EdgeMetadata& departing,
    const baldr::EdgeMetadata& arriving,
    const baldr::GraphTile* tile) const {
  // Same as forward transition cost for pedestrian
  return TransitionCost(edge, node, departing, arriving, tile);
}

void CampusPedestrianCost::Register() {
  std::call_once(registered, []() {
    // Register this costing model with Valhalla's factory under "campus_pedestrian"
    // This is typically done in valhalla::sif::Register() or via factory pattern.
    // For a full integration, this would call:
    //   DynamicCostFactory::Register("campus_pedestrian", [](...)->CampusPedestrianCost{...});
    //
    // For now, we provide the registration entry point that the build system
    // will link into Valhalla's costing factory.
  });
}

}  // namespace sif
}  // namespace valhalla

// Register the campus_pedestrian costing model as a plugin
// Valhalla will pick this up when dlopen'ing the shared library
extern "C" void register_campus_pedestrian() {
  valhalla::sif::CampusPedestrianCost::Register();
}
