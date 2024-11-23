import SwiftUI

struct ContentView: View {
    @State private var textToPost = ""
    @State private var isShowingClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            TextEditor(text: $textToPost)
                .font(.body).fontDesign(.monospaced)
                .navigationTitle(textToPost.count < 10 ? "douglashill.co" : "\(textToPost.count) characters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") {
                            isShowingClearConfirmation = true
                        }
                        .disabled(textToPost.isEmpty)
                        .confirmationDialog("Clear Draft", isPresented: $isShowingClearConfirmation) { 
                            Button("Clear", role: .destructive) {
                                textToPost = ""
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) { 
                        Button("Post") {
                            print("Post the thing here")
                        }
                    }
                }
        }
    }
}
