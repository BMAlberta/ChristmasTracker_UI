//
//  GenericAxisValueFormatter.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/20/21.
//

import Foundation
import Charts

class GenericAxisValueFormatter: NSObject, AxisValueFormatter {
    private var dataSet: [MappedEntryData] = []
    
    init(dataSet: [MappedEntryData]) {
        self.dataSet = dataSet
    }
    
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        guard let valueString = self.dataSet.filter({ $0.personId == value }).first else {
            return ""
        }
        return valueString.name
    }
}
