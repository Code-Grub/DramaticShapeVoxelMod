-- Nature set used to decorate the WORLD FILL beyond a loaded map.
--
-- Keep this routing explicit: a new route can be tuned here without touching
-- the renderer, and towns/ordinary rooms deliberately fall through to nil.

local forest = {
  PALLET_TOWN = true, VIRIDIAN_CITY = true, PEWTER_CITY = true,
  CERULEAN_CITY = true, VERMILION_CITY = true, LAVENDER_TOWN = true,
  CELADON_CITY = true, FUCHSIA_CITY = true, SAFFRON_CITY = true,
  ROUTE_1 = true, ROUTE_2 = true, ROUTE_5 = true, ROUTE_6 = true,
  ROUTE_7 = true, ROUTE_8 = true, ROUTE_22 = true,
  ROUTE_24 = true, ROUTE_25 = true,
}

local field = {
  ROUTE_11 = true, ROUTE_12 = true, ROUTE_13 = true, ROUTE_14 = true,
  ROUTE_15 = true, ROUTE_16 = true, ROUTE_17 = true, ROUTE_18 = true,
  SAFARI_ZONE_CENTER = true, SAFARI_ZONE_EAST = true,
  SAFARI_ZONE_NORTH = true, SAFARI_ZONE_WEST = true,
}

local rocky = {
  ROUTE_3 = true, ROUTE_4 = true, ROUTE_9 = true, ROUTE_10 = true,
  ROUTE_23 = true, INDIGO_PLATEAU = true,
}

-- NATURE is an outside-the-map treatment, not a second layer over authored
-- scenery. These locations either have an indoor/black void or an explicit
-- cyan/black visual identity, so generated cards must not be placed beyond
-- their loaded geometry. The exact IDs also prevent the CAVERN fallback from
-- decorating Seafoam's interior maps with rocks.
local excluded = {
  CINNABAR_ISLAND = true,
  VIRIDIAN_FOREST = true,
  SAFARI_ZONE_CENTER_REST_HOUSE = true,
  SAFARI_ZONE_EAST_REST_HOUSE = true,
  SAFARI_ZONE_NORTH_REST_HOUSE = true,
  SAFARI_ZONE_WEST_REST_HOUSE = true,
  SAFARI_ZONE_SECRET_HOUSE = true,
  SEAFOAM_ISLANDS_1F = true,
  SEAFOAM_ISLANDS_B1F = true,
  SEAFOAM_ISLANDS_B2F = true,
  SEAFOAM_ISLANDS_B3F = true,
  SEAFOAM_ISLANDS_B4F = true,
}

-- These maps use NATURE's black material under the authored geometry. Keeping
-- this separate from `excluded` lets the renderer choose the requested void
-- colour even though no generated billboard is allowed there.
local black = {
  VIRIDIAN_FOREST = true,
  SAFARI_ZONE_CENTER_REST_HOUSE = true,
  SAFARI_ZONE_EAST_REST_HOUSE = true,
  SAFARI_ZONE_NORTH_REST_HOUSE = true,
  SAFARI_ZONE_WEST_REST_HOUSE = true,
  SAFARI_ZONE_SECRET_HOUSE = true,
  SEAFOAM_ISLANDS_1F = true,
  SEAFOAM_ISLANDS_B1F = true,
  SEAFOAM_ISLANDS_B2F = true,
  SEAFOAM_ISLANDS_B3F = true,
  SEAFOAM_ISLANDS_B4F = true,
}

return {
  forest = forest,
  field = field,
  rocky = rocky,
  excluded = excluded,
  black = black,
}
