//
//  ContentView.swift
//  Example App
//
//  Created by Charles Srstka on 5/5/22.
//

import SwiftUI
import SwiftyXPC

struct ContentView: View {
    @State var request = "hello world"
    @State var response = ""
    @State var progress: Double? = nil

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text("Request:").fixedSize().padding()
                    Text("Response:").fixedSize().padding()
                }
                VStack {
                    TextField("Request", text: self.$request).frame(minWidth: 200).padding()
                    Text(self.response).frame(maxWidth: .infinity, alignment: .leading).padding()
                }
            }
            Button("Capitalize") {
                Task {
                    do {
                        self.response = try await MessageSender.shared.capitalize(string: self.request)
                    } catch {
                        self.response = "Error: \(error.localizedDescription)"
                    }
                }
            }
            Button("Start Long-Running-Task") {
                Task {
                    do {
                        self.response = NSLocalizedString("Please Wait…", comment: "Please Wait...")

                        try await MessageSender.shared.startLongRunningTask() {
                            self.progress = $0
                        }

                        self.response = NSLocalizedString("Done!", comment: "Done message")
                    } catch {
                        self.response = "Error: \(error.localizedDescription)"
                    }
                }
            }.padding()

            ProgressView(value: self.progress, total: 1.0)
                .progressViewStyle(.linear)
                .opacity(self.progress != nil ? 1.0 : 0.0)
        }.padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
