import WidgetKit
import SwiftUI

@main
struct BaselineWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeightWidget()
        WeightLockScreenWidget()
    }
}
