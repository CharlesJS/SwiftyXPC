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
            }.padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
