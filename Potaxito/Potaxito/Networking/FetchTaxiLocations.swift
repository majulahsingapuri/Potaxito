//
//  FetchTaxiLocations.swift
//  Potaxito
//
//  Created by Timothy Tan on 18/2/21.
//

import FirebaseStorage
import SwiftyJSON
import GoogleMaps

struct FetchTaxiLocations {

    func fetch(map: GMSMapView, completion: @escaping ([TaxiMarker]?) -> ()) {

        // Points to the root reference
        let storageRef = Storage.storage().reference().child("TaxiLocations.json")
        
        storageRef.getData(maxSize: 5 * 1024 * 1024) { (data, err) in
            if let err = err {
                print(err.localizedDescription)
                completion(nil)
            }
            var taxiMarkers : [TaxiMarker] = []// array of taxi markers to be returned
            do {
                if let data = data {
                    let taxi = try JSON(data: data)
                    
                    for (taxiID, location) in taxi {
                        if let taxiID = Int(taxiID), let xCoord = location["xCoord"].float, let yCoord = location["yCoord"].float {
                            let marker = TaxiMarker(xCoord: xCoord, yCoord: yCoord, myMap: map, id: taxiID)
                            taxiMarkers.append(marker)
                        }
                    }
                    completion(taxiMarkers)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
    }
}
