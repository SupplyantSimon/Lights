import SwiftUI
import AppKit
import HotKey
import Speech
import AVFoundation
import Accelerate

// MARK: - Audio Analyzer for Music Mode
class AudioAnalyzer: ObservableObject {
    @Published var isListening = false
    @Published var bassLevel: Float = 0
    @Published var midLevel: Float = 0
    @Published var trebleLevel: Float = 0
    @Published var beatDetected = false
    
    private var audioEngine: AVAudioEngine?
    private var fftSetup: vDSP_DFT_Setup?
    private let sampleRate: Double = 44100
    private let fftSize = 1024
    
    var onBeat: (() -> Void)?
    var onFrequencyUpdate: ((_ bass: Float, _ mid: Float, _ treble: Float) -> Void)?
    
    func startListening() {
        guard !isListening else { return }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        print("🎵 Input format: \(format)")
        print("🎵 Input available: \(inputNode.isInputFormatBusSupported(0, format: format))")
        
        // Setup FFT
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let samples = buffer.frameLength
            if samples > 0 {
                print("🎵 Got \(samples) audio samples")
                self.processAudioBuffer(buffer)
            }
        }
        
        do {
            try audioEngine.start()
            isListening = true
            print("🎵 Music mode active - listening to audio")
            
        } catch {
            print("❌ Audio setup error: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        if let setup = fftSetup {
            vDSP_DFT_DestroySetupD(setup)
        }
        isListening = false
        print("🎵 Music mode stopped")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Convert to array
        var samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        // Apply Hanning window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(min(frameLength, fftSize)))
        
        // Simplified frequency analysis using time-domain energy bands
        var magnitudes = [Float](repeating: 0, count: min(frameLength, fftSize))
        for i in 0..<magnitudes.count {
            magnitudes[i] = abs(samples[i])
        }
        
        // Simplified frequency analysis (bass, mid, treble)
        let bassRange = 0..<10      // ~0-430Hz
        let midRange = 10..<100     // ~430-4300Hz  
        let trebleRange = 100..<200 // ~4300-8600Hz
        
        var bass: Float = 0
        var mid: Float = 0
        var treble: Float = 0
        
        // Calculate magnitudes
        for i in bassRange where i < samples.count {
            bass += abs(samples[i])
        }
        for i in midRange where i < samples.count {
            mid += abs(samples[i])
        }
        for i in trebleRange where i < samples.count {
            treble += abs(samples[i])
        }
        
        // Normalize
        bass = min(bass / Float(bassRange.count) * 10, 1.0)
        mid = min(mid / Float(midRange.count) * 5, 1.0)
        treble = min(treble / Float(trebleRange.count) * 3, 1.0)
        
        DispatchQueue.main.async { [weak self] in
            self?.bassLevel = bass
            self?.midLevel = mid
            self?.trebleLevel = treble
            
            // Beat detection (bass threshold)
            if bass > 0.5 && !(self?.beatDetected ?? false) {
                self?.beatDetected = true
                self?.onBeat?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.beatDetected = false
                }
            }
            
            self?.onFrequencyUpdate?(bass, mid, treble)
        }
    }
}

// MARK: - Configuration
class AppConfig: Codable, ObservableObject {
    let bridgeIP: String
    let apiKey: String
    let tuya: TuyaConfig
    let hotkeys: HotkeyConfig
    let colors: [ColorPreset]
    let lights: [String]
    
    init(bridgeIP: String, apiKey: String, tuya: TuyaConfig, hotkeys: HotkeyConfig, colors: [ColorPreset], lights: [String]) {
        self.lights = lights
        self.bridgeIP = bridgeIP
        self.apiKey = apiKey
        self.tuya = tuya
        self.hotkeys = hotkeys
        self.colors = colors
    }
}

struct TuyaConfig: Codable {
    let username: String
    let region: String
    let platform: String
}

struct HotkeyConfig: Codable {
    let allOn: String
    let allOff: String
    let partyMode: String
    let movieMode: String
    let monkeyToggle: String
    let bigboyToggle: String
    let colorCycle: String
    let musicMode: String
}

struct ColorPreset: Codable, Identifiable {
    let id = UUID()
    let name: String
    let hue: Int
    let sat: Int
}

// MARK: - Config Loader
class ConfigLoader {
    static func load() -> AppConfig {
        let possiblePaths = [
            Bundle.main.url(forResource: "config", withExtension: "json"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".simonslights/config.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("config.json")
        ]
        
        for path in possiblePaths.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: path),
               let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
                print("✅ Loaded config from: \(path.path)")
                return config
            }
        }
        
        print("⚠️ Using default config")
        return AppConfig(
            bridgeIP: "192.168.50.228",
            apiKey: "",
            tuya: TuyaConfig(username: "", region: "eu", platform: "smart_life"),
            hotkeys: HotkeyConfig(allOn: "f13", allOff: "f14", partyMode: "f15", movieMode: "f16", 
                                  monkeyToggle: "f17", bigboyToggle: "f18", colorCycle: "f19", musicMode: "f20"),
            colors: [
                ColorPreset(name: "White", hue: 0, sat: 0),
                ColorPreset(name: "Red", hue: 0, sat: 254),
                ColorPreset(name: "Green", hue: 21845, sat: 254),
                ColorPreset(name: "Blue", hue: 43690, sat: 254)
            ],
            lights: ["Unit", "TV Left", "BigBoy"]
        )
    }
}

// MARK: - Hue Light Model
struct HueLight: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var state: LightState
    
    static func == (lhs: HueLight, rhs: HueLight) -> Bool {
        return lhs.id == rhs.id
    }
}

struct LightState: Codable {
    var on: Bool = false
    var bri: Int? = nil
    var hue: Int? = nil
    var sat: Int? = nil
    var ct: Int? = nil
    
    enum CodingKeys: String, CodingKey {
        case on, bri, hue, sat, ct
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        on = (try? container.decode(Bool.self, forKey: .on)) ?? false
        bri = try? container.decode(Int.self, forKey: .bri)
        hue = try? container.decode(Int.self, forKey: .hue)
        sat = try? container.decode(Int.self, forKey: .sat)
        ct = try? container.decode(Int.self, forKey: .ct)
    }
}

struct HueLightData: Codable {
    let name: String
    let state: LightState
}

// MARK: - Monkey Light Service
class MonkeyService: ObservableObject {
    @Published var isOn: Bool = false
    @Published var isLoading: Bool = false
    
    private let config: TuyaConfig
    private let scriptPath: String
    
    init(config: TuyaConfig) {
        self.config = config
        let possiblePaths = [
            Bundle.main.path(forResource: "control_monkey", ofType: "py"),
            NSHomeDirectory() + "/.openclaw/workspace/control_monkey.py",
            NSHomeDirectory() + ".simonslights/control_monkey.py",
            FileManager.default.currentDirectoryPath + "/control_monkey.py"
        ]
        self.scriptPath = possiblePaths.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0)
        } ?? "control_monkey.py"
        
        print("🐵 Monkey script path: \(scriptPath)")
    }
    
    func toggle() {
        isLoading = true
        let targetState = !isOn
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            task.arguments = [self.scriptPath, targetState ? "--on" : "--off"]
            
            var env = ProcessInfo.processInfo.environment
            env["TUYA_USERNAME"] = self.config.username
            env["TUYA_COUNTRY"] = "44"
            env["TUYA_PLATFORM"] = self.config.platform
            task.environment = env
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    self.isOn = targetState
                    self.isLoading = false
                    print("🐵 Monkey: \(output)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("🐵 Monkey error: \(error)")
                }
            }
        }
    }
    
    func fetchStatus() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            task.arguments = [self.scriptPath, "--status"]
            
            var env = ProcessInfo.processInfo.environment
            env["TUYA_USERNAME"] = self.config.username
            env["TUYA_COUNTRY"] = "44"
            env["TUYA_PLATFORM"] = self.config.platform
            task.environment = env
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    self.isOn = output.contains("ON")
                }
            } catch {
                print("🐵 Monkey status error: \(error)")
            }
        }
    }
}

// MARK: - Hue API Service
class HueService: ObservableObject {
    @Published var lights: [HueLight] = []
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var isLoading = false
    
    private let baseURL: String
    private let allowedLightNames: [String]
    
    let rightLightName = "Unit"
    let leftLightName = "TV Left"
    let bigboyLightName = "BigBoy"
    
    init(bridgeIP: String, apiKey: String, allowedLights: [String]) {
        self.baseURL = "http://\(bridgeIP)/api/\(apiKey)"
        self.allowedLightNames = allowedLights
        fetchLights()
    }
    
    var rightLight: HueLight? {
        lights.first { $0.name == rightLightName }
    }
    
    var leftLight: HueLight? {
        lights.first { $0.name == leftLightName }
    }
    
    var bigboyLight: HueLight? {
        lights.first { $0.name == bigboyLightName }
    }
    
    func fetchLights() {
        guard let url = URL(string: "\(baseURL)/lights") else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.lastError = error.localizedDescription
                    self?.isConnected = false
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let decoder = JSONDecoder()
                    let lightsDict = try decoder.decode([String: HueLightData].self, from: data)
                    
                    var uniqueLights: [HueLight] = []
                    var seenNames: Set<String> = []
                    
                    for (id, lightData) in lightsDict {
                        let light = HueLight(id: id, name: lightData.name, state: lightData.state)
                        if !seenNames.contains(light.name) && self?.allowedLightNames.contains(light.name) == true {
                            uniqueLights.append(light)
                            seenNames.insert(light.name)
                        }
                    }
                    
                    self?.lights = uniqueLights.sorted { $0.name < $1.name }
                    self?.isConnected = true
                    self?.lastError = nil
                } catch {
                    self?.lastError = "Failed to parse lights: \(error)"
                }
            }
        }.resume()
    }
    
    func toggleLight(_ light: HueLight) {
        setLightState(id: light.id, on: !light.state.on)
    }
    
    func toggleBigBoy() {
        if let bigboy = bigboyLight {
            toggleLight(bigboy)
        }
    }
    
    func setLightState(id: String, on: Bool? = nil, brightness: Int? = nil, hue: Int? = nil, saturation: Int? = nil) {
        guard let url = URL(string: "\(baseURL)/lights/\(id)/state") else { return }
        
        var body: [String: Any] = [:]
        if let on = on { body["on"] = on }
        if let brightness = brightness { body["bri"] = max(1, min(254, brightness)) }
        if let hue = hue { body["hue"] = max(0, min(65535, hue)) }
        if let saturation = saturation { body["sat"] = max(0, min(254, saturation)) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.fetchLights()
            }
        }.resume()
    }
    
    func setAllLightsColor(hue: Int, saturation: Int, brightness: Int = 254) {
        lights.forEach { light in
            setLightState(id: light.id, on: true, brightness: brightness, hue: hue, saturation: saturation)
        }
    }
    
    func setLightBrightness(id: String, brightness: Int) {
        setLightState(id: id, brightness: brightness)
    }
    
    func partyMode() {
        let colors: [(hue: Int, sat: Int)] = [
            (0, 254), (21845, 254), (43690, 254), (12750, 254), (56000, 254),
        ]
        
        lights.enumerated().forEach { index, light in
            let color = colors[index % colors.count]
            setLightState(id: light.id, on: true, brightness: 254, hue: color.hue, saturation: color.sat)
        }
    }
    
    func allOff() {
        lights.forEach { light in
            setLightState(id: light.id, on: false)
        }
    }
    
    func allOn(brightness: Int = 254) {
        lights.forEach { light in
            setLightState(id: light.id, on: true, brightness: brightness)
        }
    }
    
    func movieMode() {
        lights.forEach { light in
            setLightState(id: light.id, on: true, brightness: 30)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var hueService: HueService!
    var monkeyService: MonkeyService!
    var audioAnalyzer: AudioAnalyzer!
    var config: AppConfig!
    var hotKeys: [HotKey] = []
    var currentColorIndex: Int = 0
    var musicModeColor: Float = 0
    var isMusicMode = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        config = ConfigLoader.load()
        
        hueService = HueService(bridgeIP: config.bridgeIP, apiKey: config.apiKey, allowedLights: config.lights)
        monkeyService = MonkeyService(config: config.tuya)
        audioAnalyzer = AudioAnalyzer()
        
        // Setup audio callbacks
        audioAnalyzer.onBeat = { [weak self] in
            self?.handleMusicBeat()
        }
        audioAnalyzer.onFrequencyUpdate = { [weak self] bass, mid, treble in
            self?.handleFrequencyUpdate(bass: bass, mid: mid, treble: treble)
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Simon's Lights")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(hueService)
                .environmentObject(monkeyService)
                .environmentObject(audioAnalyzer)
                .environmentObject(config)
        )
        
        setupHotkeys()
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.hueService.fetchLights()
            self?.monkeyService.fetchStatus()
        }
        
        monkeyService.fetchStatus()
    }
    
    func handleMusicBeat() {
        guard isMusicMode else { return }
        
        // Pulse brightness on beat
        let brightness = 150 + Int.random(in: 0...104)
        hueService.lights.forEach { light in
            hueService.setLightBrightness(id: light.id, brightness: brightness)
        }
        
        // Visual feedback
        DispatchQueue.main.async {
            self.audioAnalyzer.beatDetected = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.audioAnalyzer.beatDetected = false
            }
        }
    }
    
    func handleFrequencyUpdate(bass: Float, mid: Float, treble: Float) {
        guard isMusicMode else { return }
        
        // Cycle color based on music
        musicModeColor += 0.01 + (bass * 0.05)
        if musicModeColor > 1.0 { musicModeColor -= 1.0 }
        
        let hue = Int(musicModeColor * 65535)
        let saturation = 150 + Int(bass * 104)
        
        // Only update occasionally to avoid flooding
        if Int(musicModeColor * 100) % 5 == 0 {
            hueService.setAllLightsColor(hue: hue, saturation: saturation)
        }
    }
    
    func toggleMusicMode() {
        isMusicMode.toggle()
        if isMusicMode {
            audioAnalyzer.startListening()
            showNotification(title: "🎵 Music Mode", message: "ON - Lights reacting to audio")
        } else {
            audioAnalyzer.stopListening()
            showNotification(title: "🎵 Music Mode", message: "OFF")
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                hueService.fetchLights()
                monkeyService.fetchStatus()
            }
        }
    }
    
    func keyFromString(_ str: String) -> Key? {
        let map: [String: Key] = [
            "a": .a, "b": .b, "c": .c, "d": .d, "e": .e,
            "f": .f, "g": .g, "h": .h, "i": .i, "j": .j,
            "k": .k, "l": .l, "m": .m, "n": .n, "o": .o,
            "p": .p, "q": .q, "r": .r, "s": .s, "t": .t,
            "u": .u, "v": .v, "w": .w, "x": .x, "y": .y, "z": .z,
            "0": .zero, "1": .one, "2": .two, "3": .three, "4": .four,
            "5": .five, "6": .six, "7": .seven, "8": .eight, "9": .nine,
            "left": .leftArrow, "right": .rightArrow, "up": .upArrow, "down": .downArrow,
            "space": .space, "return": .return, "tab": .tab,
            "f1": .f1, "f2": .f2, "f3": .f3, "f4": .f4, "f5": .f5,
            "f6": .f6, "f7": .f7, "f8": .f8, "f9": .f9, "f10": .f10,
            "f11": .f11, "f12": .f12, "f13": .f13, "f14": .f14, "f15": .f15,
            "f16": .f16, "f17": .f17, "f18": .f18, "f19": .f19, "f20": .f20,
        ]
        return map[str.lowercased()]
    }
    
    func setupHotkeys() {
        let hotkeyConfigs: [(key: String, action: () -> Void, description: String)] = [
            (config.hotkeys.allOn, { [weak self] in self?.hueService.allOn() }, "All On"),
            (config.hotkeys.allOff, { [weak self] in self?.hueService.allOff() }, "All Off"),
            (config.hotkeys.partyMode, { [weak self] in self?.hueService.partyMode() }, "Party Mode"),
            (config.hotkeys.movieMode, { [weak self] in self?.hueService.movieMode() }, "Movie Mode"),
            (config.hotkeys.monkeyToggle, { [weak self] in self?.monkeyService.toggle() }, "Monkey Toggle"),
            (config.hotkeys.bigboyToggle, { [weak self] in self?.hueService.toggleBigBoy() }, "BigBoy Toggle"),
            (config.hotkeys.colorCycle, { [weak self] in self?.cycleColor() }, "Color Cycle"),
            (config.hotkeys.musicMode, { [weak self] in self?.toggleMusicMode() }, "Music Mode"),
        ]
        
        for configItem in hotkeyConfigs {
            guard let key = keyFromString(configItem.key) else { 
                print("⚠️ Unknown key: \(configItem.key)")
                continue 
            }
            
            let hotKey = HotKey(key: key, modifiers: [])
            hotKey.keyDownHandler = { [weak self] in
                configItem.action()
                self?.showNotification(title: "Simon's Lights", message: configItem.description)
            }
            hotKeys.append(hotKey)
            print("🎹 Registered hotkey: \(configItem.key) → \(configItem.description)")
        }
        
        print("🎹 Total registered: \(hotKeys.count) hotkeys")
    }
    
    func cycleColor() {
        let colors = config.colors
        guard !colors.isEmpty else { return }
        
        currentColorIndex = (currentColorIndex + 1) % colors.count
        let color = colors[currentColorIndex]
        
        hueService.setAllLightsColor(hue: color.hue, saturation: color.sat)
        showNotification(title: "Color: \(color.name)", message: "Applied to all lights")
    }
    
    func showNotification(title: String, message: String) {
        print("🔔 \(title): \(message)")
    }
}

// MARK: - Main View
struct ContentView: View {
    @EnvironmentObject var hueService: HueService
    @EnvironmentObject var monkeyService: MonkeyService
    @EnvironmentObject var audioAnalyzer: AudioAnalyzer
    @EnvironmentObject var config: AppConfig
    @State private var currentColorIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: hueService.isConnected ? "lightbulb.fill" : "lightbulb")
                    .font(.title2)
                    .foregroundColor(hueService.isConnected ? .yellow : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simon's Lights")
                        .font(.headline)
                    
                    if let error = hueService.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    } else if hueService.isConnected {
                        Text("Unit (R) | TV Left (L) | BigBoy | Monkey")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Music mode button
                Button(action: { 
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.toggleMusicMode()
                    }
                }) {
                    Image(systemName: audioAnalyzer.isListening ? "music.note" : "music.note.list")
                        .font(.title3)
                        .foregroundColor(audioAnalyzer.isListening ? .pink : .gray)
                        .overlay(
                            Group {
                                if audioAnalyzer.isListening {
                                    Circle()
                                        .stroke(Color.pink, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Music Mode (\(config.hotkeys.musicMode.uppercased()))")
                
                // Monkey indicator
                Button(action: { monkeyService.toggle() }) {
                    Image(systemName: monkeyService.isOn ? "lamp.desk.fill" : "lamp.desk")
                        .font(.title3)
                        .foregroundColor(monkeyService.isOn ? .orange : .gray)
                        .overlay(
                            Group {
                                if monkeyService.isLoading {
                                    ProgressView().scaleEffect(0.5)
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Monkey")
                
                // BigBoy indicator
                Button(action: { hueService.toggleBigBoy() }) {
                    Image(systemName: hueService.bigboyLight?.state.on == true ? "light.ribbon.fill" : "light.ribbon")
                        .font(.title3)
                        .foregroundColor(hueService.bigboyLight?.state.on == true ? .cyan : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("BigBoy")
                
                Button(action: { hueService.fetchLights() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(hueService.isLoading)
            }
            .padding()
            
            // Music mode visualization
            if audioAnalyzer.isListening {
                VStack(spacing: 4) {
                    HStack {
                        Text("🎵 Music Mode Active")
                            .font(.caption)
                            .foregroundColor(.pink)
                        Spacer()
                        // Debug: show raw values
                        Text(String(format: "B:%.2f M:%.2f T:%.2f", audioAnalyzer.bassLevel, audioAnalyzer.midLevel, audioAnalyzer.trebleLevel))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 8) {
                        VStack {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 24, height: max(CGFloat(audioAnalyzer.bassLevel * 50), 4))
                            Text("Bass")
                                .font(.system(size: 8))
                        }
                        VStack {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 24, height: max(CGFloat(audioAnalyzer.midLevel * 50), 4))
                            Text("Mid")
                                .font(.system(size: 8))
                        }
                        VStack {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 24, height: max(CGFloat(audioAnalyzer.trebleLevel * 50), 4))
                            Text("Treble")
                                .font(.system(size: 8))
                        }
                        Spacer()
                    }
                    .frame(height: 60)
                }
                .padding(.horizontal)
                .background(Color.pink.opacity(0.05))
            }
            
            Divider()
            
            // Quick Actions Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                QuickActionButton(
                    icon: "power",
                    label: "All Off",
                    color: .red,
                    description: config.hotkeys.allOff.uppercased()
                ) {
                    hueService.allOff()
                }
                
                QuickActionButton(
                    icon: "lightbulb.fill",
                    label: "All On",
                    color: .yellow,
                    description: config.hotkeys.allOn.uppercased()
                ) {
                    hueService.allOn()
                }
                
                QuickActionButton(
                    icon: "party.popper.fill",
                    label: "Party",
                    color: .purple,
                    description: config.hotkeys.partyMode.uppercased()
                ) {
                    hueService.partyMode()
                }
                
                QuickActionButton(
                    icon: "film.fill",
                    label: "Movie",
                    color: .blue,
                    description: config.hotkeys.movieMode.uppercased()
                ) {
                    hueService.movieMode()
                }
            }
            .padding()
            
            Divider()
            
            // Color Grid
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Colors (\(config.hotkeys.colorCycle.uppercased()) to cycle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                    ForEach(Array(config.colors.enumerated()), id: \.element.id) { index, color in
                        ColorButton(color: color, isActive: currentColorIndex == index) {
                            currentColorIndex = index
                            hueService.setAllLightsColor(hue: color.hue, saturation: color.sat)
                        }
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Lights List
            List(hueService.lights) { light in
                LightRow(light: light) {
                    hueService.toggleLight(light)
                } onBrightnessChange: { newBrightness in
                    hueService.setLightState(id: light.id, on: true, brightness: newBrightness)
                }
            }
            .listStyle(PlainListStyle())
        }
        .frame(width: 340, height: 620)
    }
}

struct ColorButton: View {
    let color: ColorPreset
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Circle()
                    .fill(colorSwiftUI)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(isActive ? Color.white : Color.clear, lineWidth: 2)
                    )
                    .shadow(radius: isActive ? 2 : 0)
                
                Text(color.name)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var colorSwiftUI: Color {
        if color.sat == 0 {
            return Color.white
        }
        return Color(hue: Double(color.hue) / 65535, saturation: Double(color.sat) / 254, brightness: 1.0)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LightRow: View {
    let light: HueLight
    let onToggle: () -> Void
    let onBrightnessChange: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(light.state.on ? Color.yellow : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(light.name)
                        .font(.system(size: 13, weight: .medium))
                    
                    if light.state.on, let bri = light.state.bri {
                        Text("\(bri * 100 / 254)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: .init(
                    get: { light.state.on },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
            }
            
            if light.state.on {
                Slider(
                    value: .init(
                        get: { Double(light.state.bri ?? 0) },
                        set: { onBrightnessChange(Int($0)) }
                    ),
                    in: 1...254,
                    step: 1
                )
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - App Entry Point
@main
struct SimonsLightsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
