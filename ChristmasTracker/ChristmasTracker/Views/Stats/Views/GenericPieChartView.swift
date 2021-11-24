//
//  PieChartView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/20/21.
//

import SwiftUI
import Combine
import Charts

struct GenericPieChartView: View {
    @ObservedObject var viewModel = PieChartViewModel()
    var body: some View {
        WrappedPieChartView(viewModel: viewModel)
    }
}

struct GenericPieChartView_Previews: PreviewProvider {
    private static var sampleModel: PieChartViewModel {
        let model = PieChartViewModel()
        model.detail["Brian"] = 124.98
        model.detail["Melanie"] = 50.87
        model.detail["Graham"] = 34.67
        model.detail["Nikki"] = 23.89
        return model
    }
    
    static var previews: some View {
        GenericPieChartView(viewModel: Self.sampleModel)
            
    }
}

struct WrappedPieChartView: UIViewRepresentable {
    @ObservedObject var viewModel: PieChartViewModel
    
    func makeUIView(context: UIViewRepresentableContext<WrappedPieChartView>) -> PieChartView {
        let view = PieChartView()
        view.holeColor = NSUIColor.clear
        
        setDataCount(chartView: view)
        return view
    }
    
    func updateUIView(_ uiView: PieChartView, context: Context) {
        setDataCount(chartView: uiView)
        uiView.animate(xAxisDuration: 0.75, yAxisDuration: 0.75)
        
    }
    
    func setDataCount(chartView: PieChartView) {
        var entries: [PieChartDataEntry] = []
        
        for item in viewModel.detail {
            let tempEntry: PieChartDataEntry = PieChartDataEntry(value: item.value, label: item.key)
            entries.append(tempEntry)
        }
        
        
        let l = chartView.legend
        l.horizontalAlignment = .right
        l.verticalAlignment = .top
        l.orientation = .vertical
        l.xEntrySpace = 8
        l.yEntrySpace = 4
        l.yOffset = 8
        l.xOffset = 16
           
        
        let set = PieChartDataSet(entries: entries, label: "")
        set.sliceSpace = 3
        set.colors = ChartColorTemplates.joyful()
        
        let data = PieChartData(dataSet: set)
        
        let pFormatter = NumberFormatter()
        pFormatter.numberStyle = .currency
        pFormatter.maximumFractionDigits = 2
        pFormatter.multiplier = 1
    
        data.setValueFont(UIFont(name: "HelveticaNeue", size: 10)!)
        data.setValueTextColor(.black)
        
        chartView.data = data
        chartView.drawEntryLabelsEnabled = false
        data.setValueFormatter(DefaultValueFormatter(formatter: pFormatter))
        
        chartView.setNeedsDisplay()
    }
}

class PieChartViewModel: ObservableObject {
   @Published var detail: [String: Double] = [:]
}
