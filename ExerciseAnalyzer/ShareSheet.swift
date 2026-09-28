// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The system share sheet for the clip on screen (#162). ShareLink needs its file before the button is drawn, and a
//  Photos clip has to be copied out first, so the button copies and then this sheet opens.

import SwiftUI
import UIKit

struct SharedClip: Identifiable {
  let url: URL
  var id: URL { url }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  /// The activity the clip went to (nil when dismissed), and whether it completed.
  let onDone: (String?, Bool) -> Void

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    controller.completionWithItemsHandler = { activity, completed, _, _ in onDone(activity?.rawValue, completed) }
    return controller
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
