//
//  PieChartView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/20/21.
//

import SwiftUI
import Combine
//import Charts
//
//struct GenericPieChartView: View {
//    @ObservedObject var viewModel = PieChartViewModel()
//    var body: some View {
//        WrappedPieChartView(viewModel: viewModel)
//    }
//}
//
//struct GenericPieChartView_Previews: PreviewProvider {
//    private static var sampleModel: PieChartViewModel {
//        let model = PieChartViewModel()
//        model.detail["Brian"] = 124.98
//        model.detail["Melanie"] = 50.87
//        model.detail["Graham"] = 34.67
//        model.detail["Nikki"] = 23.89
//        model.detail["Dennis"] = 43.56
//        model.detail["Gayle"] = 67.89
//        model.detail["Bill"] = 87.54
//        model.detail["Graham1"] = 34.67
//        model.detail["Nikki1"] = 23.89
//        model.detail["Dennis1"] = 43.56
//        model.detail["Gayle1"] = 67.89
//        model.detail["Bill1"] = 87.54
//        return model
//    }
//    
//    static var previews: some View {
//        GenericPieChartView(viewModel: Self.sampleModel)
//            .preferredColorScheme(.dark)
//            
//    }
//}
//
//struct WrappedPieChartView: UIViewRepresentable {
//    @ObservedObject var viewModel: PieChartViewModel
//    var delegate = PieDelegate()
//    
//    func makeUIView(context: UIViewRepresentableContext<WrappedPieChartView>) -> PieChartView {
//        let view = PieChartView()
//        view.holeColor = NSUIColor.clear
//        
//        setDataCount(chartView: view)
//        return view
//    }
//    
//    func updateUIView(_ uiView: PieChartView, context: Context) {
//        setDataCount(chartView: uiView)
////        uiView.animate(xAxisDuration: 0.75, yAxisDuration: 0.75)
//        
//    }
//    
//    func setDataCount(chartView: PieChartView) {
//        var entries: [PieChartDataEntry] = []
//        
//        for item in viewModel.detail {
//            let tempEntry: PieChartDataEntry = PieChartDataEntry(value: item.value, label: item.key)
//            entries.append(tempEntry)
//        }
//        
//        
//        let l = chartView.legend
//        l.horizontalAlignment = .right
//        l.verticalAlignment = .top
//        l.orientation = .vertical
//        
//        
//        l.xEntrySpace = 8
//        l.yEntrySpace = 4
//        l.yOffset = 8
//        l.xOffset = 16
//           
//        
//        let set = PieChartDataSet(entries: entries, label: "")
//        set.sliceSpace = 3
//        
//        let colors: [NSUIColor] = [
//            NSUIColor(red: 217/255.0, green: 80/255.0, blue: 138/255.0, alpha: 1.0),
//            NSUIColor(red: 254/255.0, green: 149/255.0, blue: 7/255.0, alpha: 1.0),
//            NSUIColor(red: 254/255.0, green: 247/255.0, blue: 120/255.0, alpha: 1.0),
//            NSUIColor(red: 106/255.0, green: 167/255.0, blue: 134/255.0, alpha: 1.0),
//            NSUIColor(red: 53/255.0, green: 194/255.0, blue: 209/255.0, alpha: 1.0),
//            NSUIColor(red: 52/255.0, green: 100/255.0, blue: 235/255.0, alpha: 1.0),
//            NSUIColor(red: 235/255.0, green: 52/255.0, blue: 52/255.0, alpha: 1.0)
//        ]
//        set.colors = colors
//        
//        let data = PieChartData(dataSet: set)
//        
//        let pFormatter = NumberFormatter()
//        pFormatter.numberStyle = .currency
//        pFormatter.maximumFractionDigits = 2
//        pFormatter.multiplier = 1
//    
//        data.setValueFont(UIFont(name: "HelveticaNeue", size: 10)!)
//        data.setValueTextColor(.black)
//        
//        chartView.data = data
//        chartView.drawEntryLabelsEnabled = false
//        chartView.delegate = self.delegate
//        data.setValueFormatter(DefaultValueFormatter(formatter: pFormatter))
//        
//        chartView.setNeedsDisplay()
//    }
//}
//
//class PieDelegate: ChartViewDelegate {
//    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
//        print(entry)
//    }
//}
//
//class PieChartViewModel: ObservableObject {
//   @Published var detail: [String: Double] = [:]
//}
