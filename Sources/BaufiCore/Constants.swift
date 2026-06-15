// Konstanten: Nebenkosten (Grunderwerbsteuer je Bundesland, Notar/Grundbuch).
// Portiert aus src/lib/constants.js. Farben liegen im App-Target (Theme.swift),
// damit BaufiCore UI-frei bleibt.

import Foundation

/// Grunderwerbsteuersatz in Prozent je Bundesland.
public let GREST: [String: Double] = [
    "Baden-Württemberg": 5.0, "Bayern": 3.5, "Berlin": 6.0, "Brandenburg": 6.5,
    "Bremen": 5.0, "Hamburg": 5.5, "Hessen": 6.0, "Mecklenburg-Vorpommern": 6.0,
    "Niedersachsen": 5.0, "Nordrhein-Westfalen": 6.5, "Rheinland-Pfalz": 5.0,
    "Saarland": 6.5, "Sachsen": 5.5, "Sachsen-Anhalt": 5.0,
    "Schleswig-Holstein": 6.5, "Thüringen": 5.0,
]

/// Stabile Reihenfolge für die Bundesland-Auswahl (Swift-Dictionaries sind unsortiert).
public let BUNDESLAENDER: [String] = [
    "Baden-Württemberg", "Bayern", "Berlin", "Brandenburg",
    "Bremen", "Hamburg", "Hessen", "Mecklenburg-Vorpommern",
    "Niedersachsen", "Nordrhein-Westfalen", "Rheinland-Pfalz",
    "Saarland", "Sachsen", "Sachsen-Anhalt",
    "Schleswig-Holstein", "Thüringen",
]

/// Notar + Grundbuch in Prozent.
public let NOTAR_PROZENT: Double = 2.0
