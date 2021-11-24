//
//  GenericBarChartView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/20/21.
//

import SwiftUI
import Combine
import Charts

struct GenericBarChartView: View {
    @ObservedObject var viewModel = BarChartViewModel()
    var body: some View {
        WrappedBarChartView(viewModel: viewModel)
    }
    
    
}

struct GenericBarChartView_Previews: PreviewProvider {
    private static var sampleModel: BarChartViewModel {
        let model = BarChartViewModel()
        model.detail["Brian"] = 1
        model.detail["Melanie"] = 4
        model.detail["Graham"] = 2
        model.detail["Nikki"] = 3
        return model
    }
    static var previews: some View {
        GenericBarChartView(viewModel: Self.sampleModel)
    }
}

struct WrappedBarChartView: UIViewRepresentable {
    @ObservedObject var viewModel: BarChartViewModel
    
    func makeUIView(context: UIViewRepresentableContext<WrappedBarChartView>) -> HorizontalBarChartView {
        let view = HorizontalBarChartView()

        setDataCount(chartView: view)
        return view
    }
    
    func updateUIView(_ uiView: HorizontalBarChartView, context: Context) {
        setDataCount(chartView: uiView)
        uiView.animate(yAxisDuration: 0.75)
        
    }
    
    func setDataCount(chartView: BarChartView) {
        
        
        let updatedData = self.setupData(model: self.viewModel)
        
        var entries: [BarChartDataEntry] = []

        for item in updatedData {
            let tempEntry: BarChartDataEntry = BarChartDataEntry(x: item.personId, y: item.purchasedItem)
            entries.append(tempEntry)
        }
        
        chartView.drawValueAboveBarEnabled = false
        
        
        let l = chartView.legend
        l.enabled = false
        l.horizontalAlignment = .center
        l.verticalAlignment = .top
        l.orientation = .vertical
        l.xEntrySpace = 8
        l.yEntrySpace = 4
        l.yOffset = 8
        l.xOffset = 16
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelFont = .systemFont(ofSize: 10)
        xAxis.granularity = 1
        xAxis.drawGridLinesEnabled = false
        xAxis.valueFormatter = GenericAxisValueFormatter(dataSet: updatedData)
        
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelFont = .systemFont(ofSize: 10)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.axisMinimum = 0
        leftAxis.granularity = 1
        
        chartView.rightAxis.labelFont = .systemFont(ofSize: 10)
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.rightAxis.axisMinimum = 0
        chartView.rightAxis.granularity = 1
           
        
        let set = BarChartDataSet(entries: entries, label: "")
        let colors: [NSUIColor] = [NSUIColor(red: 17/255, green: 87/255, blue: 74/255, alpha: 1.0)]
        set.colors = colors
        let data = BarChartData(dataSet: set)
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        
    
        data.setValueFont(UIFont(name: "HelveticaNeue", size: 11)!)
        data.setValueTextColor(.white)
        
        chartView.fitBars = true
        
        chartView.data = data
        data.setValueFormatter(DefaultValueFormatter(formatter: formatter))
        
        chartView.setNeedsDisplay()
    }
    
    private func setupData(model: BarChartViewModel) -> [MappedEntryData] {
        
        var index = 0
        var listOfItems: [MappedEntryData] = []
        for item in model.detail {
            let tempEntry = MappedEntryData(personId: Double(index),
                                            name: item.key,
                                            purchasedItem: item.value)
            listOfItems.append(tempEntry)
            index += 1
        }
        return listOfItems
    }

}

class BarChartViewModel: ObservableObject {
   @Published var detail: [String: Double] = [:]
}

struct MappedEntryData {
   let personId: Double
   let name: String
   let purchasedItem: Double
}
