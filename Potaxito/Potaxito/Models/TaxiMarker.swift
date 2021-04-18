//
//  TaxiMarker.swift
//  Potaxito
//
//  Created by Nicolette Hay on 15/3/21.
//

import Foundation
import GoogleMaps

final class TaxiMarker : GMSMarker, Identifiable {
    
    let id : Int
    
    init(xCoord: Float, yCoord: Float, myMap: GMSMapView, id: Int) {
        self.id = id
        super.init()
        position = CLLocationCoordinate2D(latitude: CLLocationDegrees(yCoord), longitude: CLLocationDegrees(xCoord))
        map = myMap
        icon = UIImage(named: "Potato Icon")
    }
}
