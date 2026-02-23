import Foundation

/// Mock-Daten für die Deff-Übersicht (4 Spieler, 3 Völker).
enum MockPledges {

    static func forCall(_ call: CallItem) -> [TroopPledge] {
        let now = Date.now
        let cid = call.id

        return [
            // Spieler 1: MarcFrei – Gallier, 2 Dörfer
            TroopPledge(callId: cid, playerName: "MarcFrei", villageName: "Bowser Castle",
                        villageX: -6, villageY: 3,
                        troopKind: "gauls.phalanx", count: 200, pledgedAt: now),
            TroopPledge(callId: cid, playerName: "MarcFrei", villageName: "Bowser Castle",
                        villageX: -6, villageY: 3,
                        troopKind: "gauls.haeduan", count: 30, pledgedAt: now),
            TroopPledge(callId: cid, playerName: "MarcFrei", villageName: "Peach Circuit",
                        villageX: -5, villageY: 1,
                        troopKind: "gauls.phalanx", count: 80, pledgedAt: now),

            // Spieler 2: KingNova – Gallier, 1 Dorf
            TroopPledge(callId: cid, playerName: "KingNova", villageName: "Festung Nord",
                        villageX: 12, villageY: -3,
                        troopKind: "gauls.phalanx", count: 71, pledgedAt: now),
            TroopPledge(callId: cid, playerName: "KingNova", villageName: "Festung Nord",
                        villageX: 12, villageY: -3,
                        troopKind: "gauls.druidrider", count: 45, pledgedAt: now),

            // Spieler 3: ShadowBlade – Germanen, 1 Dorf
            TroopPledge(callId: cid, playerName: "ShadowBlade", villageName: "Germanen HQ",
                        villageX: -20, villageY: 8,
                        troopKind: "teutons.spearfighter", count: 150, pledgedAt: now),
            TroopPledge(callId: cid, playerName: "ShadowBlade", villageName: "Germanen HQ",
                        villageX: -20, villageY: 8,
                        troopKind: "teutons.paladin", count: 20, pledgedAt: now),

            // Spieler 4: RomanaX – Römer, 2 Dörfer
            TroopPledge(callId: cid, playerName: "RomanaX", villageName: "Roma Prima",
                        villageX: 5, villageY: -10,
                        troopKind: "romans.praetorian", count: 120, pledgedAt: now),
            TroopPledge(callId: cid, playerName: "RomanaX", villageName: "Roma Secunda",
                        villageX: 7, villageY: -12,
                        troopKind: "romans.praetorian", count: 60, pledgedAt: now),
            TroopPledge(callId: cid, playerName: "RomanaX", villageName: "Roma Prima",
                        villageX: 5, villageY: -10,
                        troopKind: "romans.equites_caesaris", count: 15, pledgedAt: now),
        ]
    }
}
