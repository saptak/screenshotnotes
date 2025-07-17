
import SwiftUI

struct ExplorationModeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Exploration Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Placeholder for the interactive mind map
                ZStack {
                    Circle().strokeBorder(Color.blue, lineWidth: 4)
                        .frame(width: 200, height: 200)
                    Text("Mind Map Placeholder")
                }
                
                Spacer()
            }
            .navigationTitle("Explore")
        }
    }
}

#if DEBUG
struct ExplorationModeView_Previews: PreviewProvider {
    static var previews: some View {
        ExplorationModeView()
    }
}
#endif
