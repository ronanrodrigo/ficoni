import SwiftUI
import AppKit

// MARK: - Paths / helpers

let appsDir = ("~/Applications/Ficoni" as NSString).expandingTildeInPath
let supportDir = ("~/Library/Application Support/Ficoni" as NSString).expandingTildeInPath
let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
let bundlePrefix = "dev.ronanrodrigo.findericon"

func runTool(_ launch: String, _ args: [String], extraEnv: [String: String] = [:]) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: launch)
    p.arguments = args
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    for (k, v) in extraEnv { env[k] = v }
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func suffix(from name: String) -> String {
    String(String.UnicodeScalarView(name.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
}

// MARK: - Model

struct SidebarIcon: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var target: String
    var symbol: String
    var suffix: String
}

@MainActor
final class Store: ObservableObject {
    @Published var items: [SidebarIcon] = []
    @Published var status: [UUID: String] = [:]
    @Published var busy = false
    @Published var log = ""

    private var configURL: URL { URL(fileURLWithPath: supportDir).appendingPathComponent("config.json") }

    init() {
        try? FileManager.default.createDirectory(atPath: supportDir, withIntermediateDirectories: true)
        load()
        refreshStatus()
    }

    func load() {
        if let d = try? Data(contentsOf: configURL),
           let list = try? JSONDecoder().decode([SidebarIcon].self, from: d), !list.isEmpty {
            items = list
        } else {
            items = scanInstalled()
        }
        save()
    }

    func save() {
        if let d = try? JSONEncoder().encode(items) { try? d.write(to: configURL) }
    }

    /// Reconhece os helper apps que já existem na pasta, lendo o símbolo do Info.plist
    /// e a pasta monitorada de dentro do binário da extensão.
    func scanInstalled() -> [SidebarIcon] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: appsDir) else { return [] }
        var found: [SidebarIcon] = []
        for file in names where file.hasSuffix(".app") {
            let appPath = appsDir + "/" + file
            let name = String(file.dropLast(4))
            let plist = appPath + "/Contents/Info.plist"
            let sym = runTool("/usr/libexec/PlistBuddy",
                              ["-c", "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleSymbolName", plist]).1
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let binary = appPath + "/Contents/PlugIns/SidebarSync.appex/Contents/MacOS/SidebarSync"
            var target = ""
            for raw in runTool("/usr/bin/strings", [binary]).1.split(separator: "\n") {
                let line = String(raw)
                if (line.hasPrefix("/Volumes/") || line.hasPrefix("/Users/")), FileManager.default.fileExists(atPath: line) {
                    target = line
                    break
                }
            }
            found.append(SidebarIcon(name: name, target: target,
                                     symbol: sym.isEmpty ? "folder" : sym,
                                     suffix: suffix(from: name)))
        }
        return found.sorted { $0.name < $1.name }
    }

    func refreshStatus() {
        let out = runTool("/usr/bin/pluginkit", ["-m", "-A", "-D", "-p", "com.apple.FinderSync"]).1
        var map: [UUID: String] = [:]
        for line in out.split(separator: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            for item in items where text.contains("\(bundlePrefix).\(item.suffix).sync") {
                map[item.id] = text.hasPrefix("+") ? "Ativo" : "Desativado"
            }
        }
        for item in items where map[item.id] == nil { map[item.id] = "Não instalado" }
        status = map
    }

    func apply(_ item: SidebarIcon) {
        guard let script = Bundle.main.path(forResource: "build_icon_app", ofType: "sh") else {
            log = "script build_icon_app.sh não encontrado no bundle"
            return
        }
        busy = true
        let (name, target, suffix, symbol) = (item.name, item.target, item.suffix, item.symbol)
        DispatchQueue.global().async {
            let result = runTool("/bin/bash", [script, name, target, suffix, symbol],
                                 extraEnv: ["SYMBOLMODE": "1", "HOME": NSHomeDirectory()])
            DispatchQueue.main.async {
                self.log = result.1
                self.busy = false
                self.refreshStatus()
            }
        }
    }

    func remove(_ item: SidebarIcon) {
        let appPath = appsDir + "/\(item.name).app"
        _ = runTool("/usr/bin/pluginkit", ["-r", appPath + "/Contents/PlugIns/SidebarSync.appex"])
        _ = runTool(lsregister, ["-u", appPath])
        try? FileManager.default.removeItem(atPath: appPath)
        items.removeAll { $0.id == item.id }
        save()
        _ = runTool("/usr/bin/killall", ["Finder"])
        refreshStatus()
    }

    func upsert(_ item: SidebarIcon) {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item } else { items.append(item) }
        save()
        apply(item)
    }

    func refreshFinder() {
        _ = runTool("/usr/bin/killall", ["pkd"])
        _ = runTool("/usr/bin/killall", ["Finder"])
        refreshStatus()
    }
}

// MARK: - UI

@main
struct ManagerApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup("Ícones da Sidebar") {
            ContentView().environmentObject(store)
        }
        .defaultSize(width: 780, height: 460)
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var editing: SidebarIcon?

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                Spacer()
                Text("Nenhum ícone ainda. Use Adicionar.").foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(store.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 17))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).fontWeight(.medium)
                                Text(item.target.isEmpty ? "—" : item.target)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(store.status[item.id] ?? "…")
                                .font(.caption)
                                .foregroundStyle((store.status[item.id] ?? "") == "Ativo" ? .green : .secondary)
                            Button("Editar") { editing = item }
                            Button("Remover") { store.remove(item) }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Divider()
            HStack(spacing: 10) {
                Button { editing = SidebarIcon(name: "", target: "", symbol: "folder", suffix: "") } label: {
                    Label("Adicionar", systemImage: "plus")
                }
                Button { store.refreshStatus() } label: { Label("Atualizar", systemImage: "arrow.clockwise") }
                Button { store.refreshFinder() } label: { Label("Reiniciar Finder", systemImage: "arrow.triangle.2.circlepath") }
                Spacer()
                if store.busy { ProgressView().controlSize(.small) }
                Button { NSWorkspace.shared.open(URL(fileURLWithPath: appsDir)) } label: {
                    Label("Abrir pasta dos apps", systemImage: "folder")
                }
            }
            .padding(10)
        }
        .frame(minWidth: 680, minHeight: 400)
        .sheet(item: $editing) { item in
            EditView(item: item) { saved in store.upsert(saved) }
        }
    }
}

struct EditView: View {
    @State var item: SidebarIcon
    let onSave: (SidebarIcon) -> Void
    @Environment(\.dismiss) private var dismiss

    private let suggestions = [
        "chevron.left.forwardslash.chevron.right", "arrow.down.circle", "house.lodge",
        "sofa", "chair.lounge", "terminal", "hammer", "externaldrive",
        "folder", "tray.and.arrow.down", "star", "book",
        "music.note", "photo", "film", "gamecontroller",
        "wrench.and.screwdriver", "doc.text", "shippingbox", "cube.box",
        "briefcase", "graduationcap", "cart", "creditcard",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.name.isEmpty ? "Novo ícone" : "Editar \(item.name)").font(.headline)

            HStack(spacing: 10) {
                Text("Nome").frame(width: 70, alignment: .leading)
                TextField("Developer", text: $item.name).frame(width: 260)
            }
            HStack(spacing: 10) {
                Text("Pasta").frame(width: 70, alignment: .leading)
                TextField("/Volumes/…", text: $item.target).frame(width: 300)
                Button("Escolher…") { chooseFolder() }
            }
            HStack(spacing: 10) {
                Text("Símbolo").frame(width: 70, alignment: .leading)
                TextField("house.lodge", text: $item.symbol).frame(width: 260)
                Image(systemName: item.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 12), spacing: 8) {
                ForEach(suggestions, id: \.self) { name in
                    Image(systemName: name)
                        .font(.system(size: 16))
                        .foregroundStyle(item.symbol == name ? Color.accentColor : Color.secondary)
                        .onTapGesture { item.symbol = name }
                        .help(name)
                }
            }

            HStack {
                if !FileManager.default.fileExists(atPath: item.target), !item.target.isEmpty {
                    Label("Pasta não encontrada", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Aplicar e instalar") {
                    item.suffix = suffix(from: item.name)
                    onSave(item)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(item.name.isEmpty || item.target.isEmpty || item.symbol.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 580)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { item.target = url.path }
    }
}
