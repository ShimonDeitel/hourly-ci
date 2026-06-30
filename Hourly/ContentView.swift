import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TrackView()
                .tabItem { Label("Track", systemImage: "timer") }
            ClientsView()
                .tabItem { Label("Clients", systemImage: "person.2") }
            InvoiceView()
                .tabItem { Label("Invoice", systemImage: "doc.text") }
        }
        .tint(.blue)
    }
}

struct TrackView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.createdAt) private var clients: [Client]
    @Query(filter: #Predicate<WorkSession> { $0.end == nil }) private var active: [WorkSession]
    @StateObject private var store = StoreManager.shared
    @State private var selectedClient: Client?
    @State private var showPaywall = false
    @State private var now = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let session = active.first {
                    VStack(spacing: 8) {
                        Text(session.clientName).font(.title2.bold())
                        Text(elapsed(session.start))
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Button(role: .destructive) {
                            session.end = now
                            try? context.save()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                } else {
                    if clients.isEmpty {
                        ContentUnavailableView("Add a client first", systemImage: "person.badge.plus", description: Text("Switch to the Clients tab"))
                    } else {
                        Picker("Client", selection: $selectedClient) {
                            ForEach(clients) { c in Text(c.name).tag(Optional(c)) }
                        }
                        .pickerStyle(.menu)
                        Button {
                            guard let c = selectedClient ?? clients.first else { return }
                            if !store.isPro && clients.count > 1 && c.name != clients.first?.name {
                                showPaywall = true
                                return
                            }
                            let s = WorkSession(clientName: c.name, rate: c.rate, start: Date())
                            context.insert(s)
                            try? context.save()
                        } label: {
                            Label("Start Timer", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }
            .padding()
            .navigationTitle("Hourly")
            .onReceive(timer) { now = $0 }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { if selectedClient == nil { selectedClient = clients.first } }
        }
    }

    func elapsed(_ start: Date) -> String {
        let secs = Int(now.timeIntervalSince(start))
        return String(format: "%02d:%02d:%02d", secs / 3600, (secs % 3600) / 60, secs % 60)
    }
}

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.createdAt) private var clients: [Client]
    @StateObject private var store = StoreManager.shared
    @State private var name = ""
    @State private var rate = ""
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Add Client") {
                    TextField("Name", text: $name)
                    TextField("Hourly rate ($)", text: $rate)
                        .keyboardType(.decimalPad)
                    Button("Add") {
                        guard !name.isEmpty, let r = Double(rate) else { return }
                        if !store.isPro && clients.count >= 1 {
                            showPaywall = true
                            return
                        }
                        context.insert(Client(name: name, rate: r))
                        try? context.save()
                        name = ""; rate = ""
                    }
                }
                Section("Clients") {
                    ForEach(clients) { c in
                        HStack {
                            Text(c.name)
                            Spacer()
                            Text("$\(c.rate, specifier: "%.2f")/hr").foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(clients[i]) }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Clients")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

struct InvoiceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkSession.start, order: .reverse) private var sessions: [WorkSession]
    @StateObject private var store = StoreManager.shared
    @State private var showPaywall = false
    @State private var pdfURL: URL?

    var unbilled: [WorkSession] { sessions.filter { $0.end != nil && !$0.invoiced } }
    var clientNames: [String] { Array(Set(unbilled.map { $0.clientName })) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(clientNames, id: \.self) { client in
                    let clientSessions = unbilled.filter { $0.clientName == client }
                    let total = clientSessions.reduce(0) { $0 + $1.amount }
                    Section(client) {
                        ForEach(clientSessions) { s in
                            HStack {
                                Text(s.start, style: .date)
                                Spacer()
                                Text("\(s.hours, specifier: "%.2f")h · $\(s.amount, specifier: "%.2f")")
                            }
                        }
                        Button("Generate Invoice — $\(total, specifier: "%.2f")") {
                            guard store.isPro else { showPaywall = true; return }
                            pdfURL = InvoiceGenerator.make(client: client, sessions: clientSessions)
                            for s in clientSessions { s.invoiced = true }
                            try? context.save()
                        }
                        .tint(.blue)
                    }
                }
                if unbilled.isEmpty {
                    ContentUnavailableView("No unbilled hours", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("Invoice")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: Binding(get: { pdfURL.map { IdentifiableURL(url: $0) } }, set: { pdfURL = $0?.url })) { item in
                ShareSheet(items: [item.url])
            }
        }
    }
}

struct IdentifiableURL: Identifiable { let url: URL; var id: URL { url } }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill").font(.system(size: 56)).foregroundStyle(.blue)
            Text("Hourly Pro").font(.largeTitle.bold())
            Text("Unlimited clients, unlimited PDF invoices.\n$6.99/month")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Subscribe") {
                Task { await store.purchase(); if store.isPro { dismiss() } }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            Button("Restore Purchases") { Task { await store.restore() } }
                .font(.footnote)
            Button("Not now") { dismiss() }
                .font(.footnote)
        }
        .padding()
    }
}
