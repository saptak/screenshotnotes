
import SwiftUI

struct WorkspaceTimelineView: View {
    let workspace: ContentWorkspace

    var body: some View {
        // Placeholder for a more detailed timeline view
        VStack(alignment: .leading) {
            Text("Timeline")
                .font(.headline)
            ForEach(workspace.screenshots.sorted(by: { $0.timestamp < $1.timestamp })) { screenshot in
                HStack {
                    Text(screenshot.timestamp, style: .date)
                    Text(screenshot.timestamp, style: .time)
                }
                .font(.caption)
            }
        }
        .padding()
    }
}
