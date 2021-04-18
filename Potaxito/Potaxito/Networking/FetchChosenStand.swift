//
//  FetchChosenStand.swift
//  Potaxito
//
//  Created by Bhargav Singapuri on 19/3/21.
//

import SwiftyJSON
import GoogleMaps

struct FetchChosenStand {
    
    func fetch(map: GMSMapView, location: CLLocationCoordinate2D, completion: @escaping (TaxiStandMarker?, Error?) -> ()) {
        do {
            let json : JSON = [
                "xCoord" : location.longitude,
                "yCoord" : location.latitude
            ]
            let url = URL(string: Secrets.FindTaxiStandURL)
            if let url = url {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                let bodyContent = try json.rawData(options: .prettyPrinted)
                request.httpBody = bodyContent
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let task = URLSession.shared.dataTask(with: request) { (data, res, err) in
                    do {
                        if let err = err {
                            completion(nil, err)
                        }
                        if let data = data {
                            let dataJSON = try JSON(data: data)
                            if dataJSON.isEmpty {
                                completion(nil, PotatoError.noTaxiStand)
                            } else {
                                if let standID = dataJSON["standID"].string, let id = Int(standID), let xCoord = dataJSON["data"]["xCoord"].float, let yCoord = dataJSON["data"]["yCoord"].float {
                                    DispatchQueue.main.async {
                                        let taxiStandMarker = TaxiStandMarker(xCoord: xCoord, yCoord: yCoord, myMap: map, id: id)
                                        completion(taxiStandMarker, nil)
                                    }
                                }
                            }
                        } else {
                            completion(nil, PotatoError.noData)
                        }
                    } catch {
                        completion(nil, PotatoError.failedJSONDeserialisation)
                    }
                }
                task.resume()
            } else {
                completion(nil, PotatoError.wrongURL)
            }
        } catch {
            completion(nil, PotatoError.failedJSONSerialisation)
        }
    }
}
