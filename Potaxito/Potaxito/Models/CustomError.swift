//
//  PotatoError.swift
//  Potaxito
//
//  Created by Bhargav Singapuri on 19/3/21.
//

import Foundation

public enum PotatoError: Error {
    case noTaxiStand
    case wrongURL
    case failedJSONSerialisation
    case failedJSONDeserialisation
    case noData
}

extension PotatoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noTaxiStand:
            return NSLocalizedString("No Taxi Stands found in your area.", comment: "noTaxiStandError")
        case .wrongURL:
            return NSLocalizedString("Incorrect URLProvided.", comment: "wrongURL")
        case .failedJSONSerialisation:
            return NSLocalizedString("Failed to Convert Location to JSON Object.", comment: "failedJSONSerialisation")
        case .noData:
            return NSLocalizedString("Response returned no data.", comment: "noData")
        case .failedJSONDeserialisation:
            return NSLocalizedString("Failed to unpack JSON Object.", comment: "failedJSONSerialisation")
        }
    }
}
