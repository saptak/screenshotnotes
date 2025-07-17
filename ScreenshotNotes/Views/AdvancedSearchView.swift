
import SwiftUI

struct AdvancedSearchView: View {
    @State private var query: String = ""

    var body: some View {
        NavigationView {
            VStack {
                Text("Advanced Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Enter search query", text: $query)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                // Placeholder for advanced search filters
                Form {
                    Section(header: Text("Filters")) {
                        Text("Date Range: All Time")
                        Text("Content Types: All")
                    }
                }

                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

#if DEBUG
struct AdvancedSearchView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedSearchView()
    }
}
#endif
