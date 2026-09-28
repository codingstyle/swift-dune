//
//  MusicSituation.swift
//  SwiftDune
//
//  Which song plays: the original classifies the screen into a situation
//  (loc_0aa96) and looks the song up in the table at seg001:375c; bit 0x80
//  switches at once, otherwise the song waits for the current one to end.
//  Port of madmoose's dune-re music.rs (music_situation_index,
//  SITUATION_SONG_TABLE, song_name); the recordings' fingerprints in the
//  Desert Frost engine's notes agree (palace ARRAKIS, endings WORMSUIT).
//

import Foundation


enum MusicSituation {
    /// Song numbers 1-10 (the table at 0xA4 + index).
    static let songs = ["SEKENCE.HSQ", "WATER.HSQ", "WORMSUIT.HSQ", "WORMINTR.HSQ", "WARSONG.HSQ",
                        "MORNING.HSQ", "SIETCHM.HSQ", "BAGDAD.HSQ", "ARRAKIS.HSQ", "CRYOMUS.HSQ"]

    /// seg001:375c, indexed by the situation.
    private static let table: [UInt8] = [0x82, 0x82, 0x01, 0x82, 0x84, 0x04, 0x85, 0x85, 0x87, 0x88, 0x86, 0x89, 0x83, 0x83]

    struct Screen {
        var talking = false
        var ending = false
        var globe = false
        var map = false
        var vision = false
        /// Flying or the open desert (the screen-mode flags' "not a room").
        var travelling = false
    }

    /// loc_0aa96: the situation index 0...0x0D.
    static func situation(_ screen: Screen, _ world: World) -> Int {
        let phase = world.b(World.phase)
        if screen.talking { return phase == 0x48 ? 0x0A : 0 }
        if screen.ending { return 0x0D }
        if screen.globe { return 1 }
        if screen.map { return 2 }
        if screen.vision { return 4 }
        let room = world.room, placeType = Int(world.placeType)
        if world.b(6) == 0x80 && room != 1 && !screen.travelling {
            if placeType >= 0x20 {
                if placeType != 0x20 { return 0x0C }
                return room == 3 ? 0x0A : 0x0B // the palace; its greenhouse
            }
            if phase >= 0x48 { return 0x0A }
            return placeType >= 7 ? 9 : 8     // sietches
        }
        return screen.travelling ? 6 : 5
    }

    /// The song for the screen and whether it replaces the current one now.
    static func song(_ screen: Screen, _ world: World) -> (name: String, forced: Bool)? {
        let entry = table[situation(screen, world)]
        guard entry != 0 else { return nil }
        let number = Int(entry & 0x3F)
        guard number >= 1 && number <= songs.count else { return nil }
        return (songs[number - 1], entry & 0x80 != 0)
    }
}
