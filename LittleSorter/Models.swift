import SwiftUI

// MARK: - Core content model

struct SortItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let symbol: String
    let color: Color
    let targetZoneID: String
    let imageName: String?

    init(id: UUID = UUID(),
         name: String,
         symbol: String,
         color: Color,
         targetZoneID: String,
         imageName: String? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
        self.targetZoneID = targetZoneID
        self.imageName = imageName
    }
}

/// The little celebration that fires when an item is dropped in the right zone.
enum DropEffect: Equatable {
    case splash, feathers, leaves, dust, petals, clouds, sand, sparkle
}

struct DropZone: Identifiable, Equatable {
    let id: String
    let symbol: String
    let color: Color
    let label: String
    var imageName: String? = nil       // illustrated zone art (falls back to `symbol`)
    var effect: DropEffect = .sparkle  // correct-drop celebration
}

struct Level: Identifiable, Equatable {
    let id: Int
    let title: String
    let symbol: String                 // fallback thumbnail symbol
    let background: Color              // fallback background color
    let zones: [DropZone]
    let items: [SortItem]
    let isFree: Bool
    var thumbnailImage: String? = nil  // picker card art
    var backgroundImage: String? = nil // in-level background art
}

// MARK: - Starter content (6 levels, first two free)
//
// Every level sorts on ONE clean, toddler-obvious axis; items are unique per level
// (except a few genuinely-correct reuses: car/bus/truck, boat/sailboat, frog).
// Level *titles* are unchanged so music ("<title>_music") and scene/background art
// ("<title>_scene/_bg") keep resolving. Zones carry illustrated art + a drop effect.

extension Level {

    static let all: [Level] = [farm, ocean, town, jungle, vehicles, garden]

    static var hasLockedLevels: Bool { all.contains { !$0.isFree } }

    // 1 — Farm (FREE) — sort by where each farm animal lives
    static let farm = Level(
        id: 1, title: "Farm", symbol: "carrot.fill",
        background: Color(red: 0.78, green: 0.90, blue: 0.70),
        zones: [
            DropZone(id: "barn", symbol: "house.fill", color: .brown,  label: "Barn", imageName: "zone_barn", effect: .dust),
            DropZone(id: "coop", symbol: "bird.fill",  color: .orange, label: "Coop", imageName: "zone_coop", effect: .feathers),
            DropZone(id: "pond", symbol: "drop.fill",  color: .blue,   label: "Pond", imageName: "zone_pond", effect: .splash)
        ],
        items: [
            SortItem(name: "Cow",     symbol: "pawprint.fill", color: .black,  targetZoneID: "barn", imageName: "cow"),
            SortItem(name: "Horse",   symbol: "pawprint.fill", color: .brown,  targetZoneID: "barn", imageName: "horse"),
            SortItem(name: "Chicken", symbol: "bird.fill",     color: .orange, targetZoneID: "coop", imageName: "chicken"),
            SortItem(name: "Chick",   symbol: "bird.fill",     color: .yellow, targetZoneID: "coop", imageName: "chick"),
            SortItem(name: "Duck",    symbol: "bird.fill",     color: .yellow, targetZoneID: "pond", imageName: "duck"),
            SortItem(name: "Frog",    symbol: "pawprint.fill", color: .green,  targetZoneID: "pond", imageName: "frog")
        ],
        isFree: true,
        thumbnailImage: "farm_scene", backgroundImage: "farm_bg"
    )

    // 2 — Ocean (FREE) — sort by location in the ocean/beach scene
    static let ocean = Level(
        id: 2, title: "Ocean", symbol: "water.waves",
        background: Color(red: 0.70, green: 0.86, blue: 0.94),
        zones: [
            DropZone(id: "inwater", symbol: "fish.fill",           color: .teal,   label: "In the Water", imageName: "zone_underwater", effect: .splash),
            DropZone(id: "onwater", symbol: "sailboat.fill",       color: .blue,   label: "On the Water", imageName: "zone_surface",    effect: .splash),
            DropZone(id: "beach",   symbol: "beach.umbrella.fill", color: .yellow, label: "On the Beach", imageName: "zone_beach",      effect: .sand)
        ],
        items: [
            SortItem(name: "Fish",       symbol: "fish.fill",           color: .orange, targetZoneID: "inwater", imageName: "fish"),
            SortItem(name: "Starfish",   symbol: "star.fill",           color: .pink,   targetZoneID: "inwater", imageName: "starfish"),
            SortItem(name: "Boat",       symbol: "sailboat.fill",       color: .blue,   targetZoneID: "onwater", imageName: "boat"),
            SortItem(name: "Sailboat",   symbol: "sailboat.fill",       color: .red,    targetZoneID: "onwater", imageName: "sailboat"),
            SortItem(name: "Shell",      symbol: "fossil.shell.fill",   color: .brown,  targetZoneID: "beach",   imageName: "shell"),
            SortItem(name: "Sandcastle", symbol: "beach.umbrella.fill", color: .yellow, targetZoneID: "beach",   imageName: "sandcastle")
        ],
        isFree: true,
        thumbnailImage: "ocean_scene", backgroundImage: "ocean_bg"
    )

    // 3 — Town (LOCKED) — sort by where each thing belongs
    static let town = Level(
        id: 3, title: "Town", symbol: "building.2.fill",
        background: Color(red: 0.85, green: 0.88, blue: 0.95),
        zones: [
            DropZone(id: "road",       symbol: "car.fill",         color: .gray,   label: "Road",       imageName: "zone_road",       effect: .dust),
            DropZone(id: "home",       symbol: "house.fill",       color: .orange, label: "Home",       imageName: "zone_home",       effect: .sparkle),
            DropZone(id: "playground", symbol: "sportscourt.fill", color: .green,  label: "Playground", imageName: "zone_playground", effect: .sparkle)
        ],
        items: [
            SortItem(name: "Car",   symbol: "car.fill",         color: .red,    targetZoneID: "road",       imageName: "car"),
            SortItem(name: "Bus",   symbol: "bus.fill",         color: .yellow, targetZoneID: "road",       imageName: "bus"),
            SortItem(name: "Truck", symbol: "box.truck.fill",   color: .brown,  targetZoneID: "road",       imageName: "truck"),
            SortItem(name: "Bed",   symbol: "bed.double.fill",  color: .purple, targetZoneID: "home",       imageName: "bed"),
            SortItem(name: "Sofa",  symbol: "sofa.fill",        color: .brown,  targetZoneID: "home",       imageName: "sofa"),
            SortItem(name: "Slide", symbol: "sportscourt.fill", color: .red,    targetZoneID: "playground", imageName: "slide"),
            SortItem(name: "Swing", symbol: "sportscourt.fill", color: .blue,   targetZoneID: "playground", imageName: "swing")
        ],
        isFree: false,
        thumbnailImage: "town_scene", backgroundImage: "town_bg"
    )

    // 4 — Jungle (LOCKED) — sort by habitat layer (true jungle animals)
    static let jungle = Level(
        id: 4, title: "Jungle", symbol: "leaf.fill",
        background: Color(red: 0.55, green: 0.78, blue: 0.55),
        zones: [
            DropZone(id: "trees",  symbol: "leaf.fill",     color: .green, label: "Trees",  imageName: "zone_trees",  effect: .leaves),
            DropZone(id: "ground", symbol: "pawprint.fill", color: .brown, label: "Ground", imageName: "zone_ground", effect: .dust),
            DropZone(id: "river",  symbol: "drop.fill",     color: .blue,  label: "River",  imageName: "zone_river",  effect: .splash)
        ],
        items: [
            SortItem(name: "Monkey",    symbol: "pawprint.fill", color: .brown,  targetZoneID: "trees",  imageName: "monkey"),
            SortItem(name: "Toucan",    symbol: "bird.fill",     color: .orange, targetZoneID: "trees",  imageName: "toucan"),
            SortItem(name: "Tiger",     symbol: "pawprint.fill", color: .orange, targetZoneID: "ground", imageName: "tiger"),
            SortItem(name: "Snake",     symbol: "lizard.fill",   color: .green,  targetZoneID: "ground", imageName: "snake"),
            SortItem(name: "Crocodile", symbol: "lizard.fill",   color: .green,  targetZoneID: "river",  imageName: "crocodile"),
            SortItem(name: "Frog",      symbol: "pawprint.fill", color: .green,  targetZoneID: "river",  imageName: "frog")
        ],
        isFree: false,
        thumbnailImage: "jungle_scene", backgroundImage: "jungle_bg"
    )

    // 5 — Vehicles (LOCKED) — sort by travel medium
    static let vehicles = Level(
        id: 5, title: "Vehicles", symbol: "car.fill",
        background: Color(red: 0.80, green: 0.85, blue: 0.92),
        zones: [
            DropZone(id: "road",  symbol: "car.fill",   color: .gray, label: "Road",  imageName: "zone_road",    effect: .dust),
            DropZone(id: "water", symbol: "drop.fill",  color: .blue, label: "Water", imageName: "zone_surface", effect: .splash),
            DropZone(id: "air",   symbol: "cloud.fill", color: .cyan, label: "Air",   imageName: "zone_air",     effect: .clouds)
        ],
        items: [
            SortItem(name: "Car",        symbol: "car.fill",       color: .red,    targetZoneID: "road",  imageName: "car"),
            SortItem(name: "Bus",        symbol: "bus.fill",       color: .yellow, targetZoneID: "road",  imageName: "bus"),
            SortItem(name: "Truck",      symbol: "box.truck.fill", color: .brown,  targetZoneID: "road",  imageName: "truck"),
            SortItem(name: "Boat",       symbol: "sailboat.fill",  color: .blue,   targetZoneID: "water", imageName: "boat"),
            SortItem(name: "Sailboat",   symbol: "sailboat.fill",  color: .red,    targetZoneID: "water", imageName: "sailboat"),
            SortItem(name: "Airplane",   symbol: "airplane",       color: .purple, targetZoneID: "air",   imageName: "plane"),
            SortItem(name: "Helicopter", symbol: "airplane",       color: .red,    targetZoneID: "air",   imageName: "helicopter")
        ],
        isFree: false,
        thumbnailImage: "vehicles_scene", backgroundImage: "vehicles_bg"
    )

    // 6 — Garden (LOCKED) — garden bugs, sort by where each bug lives
    static let garden = Level(
        id: 6, title: "Garden", symbol: "ladybug.fill",
        background: Color(red: 0.95, green: 0.85, blue: 0.90),
        zones: [
            DropZone(id: "dirt",    symbol: "mountain.2.fill", color: .brown, label: "Dirt",    imageName: "zone_dirt",    effect: .dust),
            DropZone(id: "leaves",  symbol: "leaf.fill",       color: .green, label: "Leaves",  imageName: "zone_leaves",  effect: .leaves),
            DropZone(id: "flowers", symbol: "camera.macro",    color: .pink,  label: "Flowers", imageName: "zone_flowers", effect: .petals)
        ],
        items: [
            SortItem(name: "Ant",         symbol: "ant.fill",     color: .black,  targetZoneID: "dirt",    imageName: "ant"),
            SortItem(name: "Worm",        symbol: "ant.fill",     color: .pink,   targetZoneID: "dirt",    imageName: "worm"),
            SortItem(name: "Caterpillar", symbol: "ant.fill",     color: .green,  targetZoneID: "leaves",  imageName: "caterpillar"),
            SortItem(name: "Snail",       symbol: "ant.fill",     color: .orange, targetZoneID: "leaves",  imageName: "snail"),
            SortItem(name: "Butterfly",   symbol: "ladybug.fill", color: .purple, targetZoneID: "flowers", imageName: "butterfly"),
            SortItem(name: "Bee",         symbol: "ladybug.fill", color: .yellow, targetZoneID: "flowers", imageName: "bee")
        ],
        isFree: false,
        thumbnailImage: "garden_scene", backgroundImage: "garden_bg"
    )

    #if DEBUG
    static func validateContent() {
        for level in all {
            let names = level.items.map(\.name)
            assert(Set(names).count == names.count,
                   "Level \(level.title): duplicate item names \(names)")
            let zoneIDs = Set(level.zones.map(\.id))
            for item in level.items {
                assert(zoneIDs.contains(item.targetZoneID),
                       "Level \(level.title): item \(item.name) targets missing zone '\(item.targetZoneID)'")
            }
            for zone in level.zones {
                assert(level.items.contains { $0.targetZoneID == zone.id },
                       "Level \(level.title): zone '\(zone.label)' has no items")
            }
        }
    }
    #endif
}
