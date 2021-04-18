//
//  TaxiStandMarker.swift
//  Potaxito
//
//  Created by Nicolette Hay on 25/2/21.
//

import Foundation
import GoogleMaps

final class TaxiStandMarker : GMSMarker, Identifiable {
    
    let id : Int
    private var state : TaxiStandState {
        didSet {
            icon = UIImage(named: state.rawValue)
        }
    }
    
    init(xCoord: Float, yCoord: Float, myMap: GMSMapView, id: Int) {
        self.state = .normal
        self.id = id
        super.init()
        position = CLLocationCoordinate2D(latitude: CLLocationDegrees(yCoord), longitude: CLLocationDegrees(xCoord))
        map = myMap
        icon = UIImage(named: TaxiStandState.normal.rawValue)
    }
    
    func changeState(state: TaxiStandState) -> Bool {
        if self.state == state {
            return false
        } else {
            self.state = state
            return true
        }
    }
}

enum TaxiStandState : String {
    case normal = "Fryer Icon"
    case chosen = "Fryer Full Icon"
}

