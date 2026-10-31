import AVFoundation
import Foundation
import Observation
import os
import Voz
import Who

let logger = Logger(subsystem: "com.whorealtime.app", category: "session")

/// App state machine: models → idle → recording → finishing → saved/failed.
@Observable
public final class SessionModel {
    public init() {}

    enum Mode: String, CaseIterable, Identifiable {
        case call = "On this Mac"
        case room = "In a room"
        var id: String { rawValue }
    }

    /// A failed phase carries what to say, not a raw error string: the card
    /// needs a headline, and `permissions` tells it to point at System Settings.
    struct Failure: Equatable {
        let title: String
        let message: String
        var permissions = false
    }

    enum Phase: Equatable {
        case missingModels
        case models(fraction: Double)
        case idle
        case recording
        case finishing
        case saved(URL)
        case failed(Failure)
    }

    private(set) var phase: Phase = .missingModels
    var mode: Mode = .call
    private(set) var apps: [AudioApp] = []
    var selectedApp: AudioApp?

    private(set) var elapsed: TimeInterval = 0
    private(set) var lines: [Line] = []
    private(set) var tailText: String = ""
    private(set) var speakerCount = 0
    var speakerNames: [Int: String] = [:]

    // Live surface the views read: meters, "audio is flowing" flags, and the
    // per-model download rows.
    private(set) var micLevel: Double = 0
    private(set) var callLevel: Double = 0
    private(set) var micLive = false
    private(set) var callLive = false
    private(set) var vozFraction: Double = 0
    private(set) var whoFraction: Double = 0
    private(set) var launching = false

    // Everything live above; plumbing below.
    @ObservationIgnored private var voz: Voz?
    @ObservationIgnored private var who: Who?
    @ObservationIgnored private var recorder: SessionRecorder?
    @ObservationIgnored private var mic: MicTap?
    @ObservationIgnored private var call: CallTap?
    @ObservationIgnored private var live: LiveTranscriber?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var diarizeTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var allWords: [Word] = []
    @ObservationIgnored private var snapshotCount = 0
    @ObservationIgnored private var turns: [Turn] = []
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var savedDocURL: URL?
    @ObservationIgnored private var pendingTail: String = ""
    @ObservationIgnored private var micMeter: LevelMeter?
    @ObservationIgnored private var callMeter: LevelMeter?
    @ObservationIgnored private var uiTickTask: Task<Void, Never>?
    @ObservationIgnored private var appPollTask: Task<Void, Never>?

    // MARK: - Models

    /// Both flavors share one model cache, so the ~550 MB download happens
    /// once per Mac — `.cachesDirectory` is per bundle ID, and Application
    /// Support isn't subject to system cache purges.
    @ObservationIgnored private static let modelCacheRoot: String = {
        let root = NSHomeDirectory() + "/Library/Application Support/WhoRealtime/Models"
        try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }()

    public func bootstrapIfNeeded() {
        guard case .missingModels = phase else { return }
        phase = .models(fraction: 0)
        Task { await downloadModels() }
    }

    func retryAfterFailure() {
        // Capture failures retry straight into the picker; only a model
        // failure needs the download path again.
        if voz != nil, who != nil {
            phase = .idle
            return
        }
        phase = .missingModels
        whoFraction = 0
        vozFraction = 0
        bootstrapIfNeeded()
    }

    // Voz ~337MB on disk, Who ~81MB: byte-weight roughly 80/20 (constants on
    // the download card); the fractions are published state above.
    private func downloadModels() async {
        do {
            let cacheRoot = Self.modelCacheRoot
            let who = Who(directory: nil, cacheRoot: cacheRoot)
            if !Who.isDownloaded(cacheRoot: cacheRoot) {
                try await who.download { [weak self] fraction in
                    Task { @MainActor [weak self] in self?.reportProgress(who: fraction) }
                }
            }
            if !Voz.isDownloaded(cacheRoot: cacheRoot) {
                try await Voz.download(cacheRoot: cacheRoot) { [weak self] progress in
                    Task { @MainActor [weak self] in self?.reportProgress(voz: progress.fraction) }
                }
            }
            voz = try await Voz(cacheRoot: cacheRoot)
            self.who = who
            reloadApps()
            phase = .idle
            startAppPolling()
        } catch {
            phase = .failed(Failure(title: "Model setup failed", message: error.localizedDescription))
        }
    }

    private func reportProgress(who: Double? = nil, voz: Double? = nil) {
        if let voz { vozFraction = voz }
        if let who { whoFraction = who }
        phase = .models(fraction: min(0.999, 0.8 * vozFraction + 0.2 * whoFraction))
    }

    // MARK: - App picker

    func reloadApps() {
        apps = AudioApps.producingOutput()
        if selectedApp == nil || apps.first(where: { $0.id == selectedApp?.id }) == nil {
            selectedApp = apps.first
        }
    }

    // Polls the audio process list while idle/failed so the picker fills in
    // by itself as soon as the meeting starts making sound.
    private func startAppPolling() {
        appPollTask?.cancel()
        appPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard let self, !Task.isCancelled else { return }
                self.reloadAppsIfNeeded()
            }
        }
    }

    private func reloadAppsIfNeeded() {
        guard isPollablePhase else { return }
        let fresh = AudioApps.producingOutput()
        guard fresh != apps else { return }
        apps = fresh
        if selectedApp == nil || !apps.contains(where: { $0.id == selectedApp?.id }) {
            selectedApp = apps.first
        }
    }

    private var isPollablePhase: Bool {
        switch phase {
        case .idle, .failed: return true
        default: return false
        }
    }

    // MARK: - Session

    func start() {
        guard case .idle = phase else { return }
        guard let voz, let who else { phase = .missingModels; return }
        guard !launching else { return }
        launching = true
        Task { await beginSession() }
    }

    private func beginSession() async {
        guard let voz, let who else { phase = .missingModels; launching = false; return }
        // A denied mic is silent, not an error, and macOS does not re-prompt
        // after a denial — ask before recording so a session can never run on
        // an empty input with only a small banner to show for it.
        guard await Self.micAccess() else {
            launching = false
            phase = .failed(Failure(
                title: "Microphone access is off",
                message: "Allow Who Realtime under Privacy & Security → Microphone, then try again.",
                permissions: true))
            Sounds.failed()
            return
        }
        // Give the meeting app a few seconds to actually start producing
        // audio (the IsRunningOutput flag flips on as soon as sound flows).
        // Polling keeps the picker live, but a short retry here avoids a
        // failed card when the user taps Listen a moment too early.
        if mode == .call, selectedApp == nil {
            for _ in 0..<10 {
                reloadApps()
                if selectedApp != nil { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        if mode == .call, selectedApp == nil {
            launching = false
            phase = .failed(Failure(
                title: "No app is outputting audio yet",
                message: "Join the meeting with sound on — the list fills automatically as it plays."))
            Sounds.failed()
            return
        }
        if mode == .room {
            selectedApp = nil
        }

        speakerNames = [:]
        lines = []
        tailText = ""
        allWords = []
        snapshotCount = 0
        turns = []
        savedDocURL = nil
        startedAt = Date()
        pendingTail = ""
        micLevel = 0
        callLevel = 0
        micLive = false
        callLive = false

        do {
            let sessionStart = HostClock.seconds()
            let mic = MicTap()
            let call = mode == .call
                ? try CallTap(processObjectIDs: selectedApp!.processObjectIDs.map { NSNumber(value: $0) },
                              name: selectedApp!.name)
                : nil
            let rate = mode == .call ? (call?.sampleRate ?? 48_000) : (mic.sampleRate > 0 ? mic.sampleRate : 48_000)

            let liveSession = voz.liveTranscriber()
            let sessionRecorder = try SessionRecorder(
                wavURL: temporaryWavURL(),
                outputRate: rate,
                live: liveSession)
            recorder = sessionRecorder
            self.call = call
            self.mic = mic
            live = liveSession

            let micMeter = LevelMeter()
            let callMeter = LevelMeter()
            try mic.install(sessionStart: sessionStart) { chunk in
                micMeter.record(chunk.samples)
                sessionRecorder.mixdown.push(chunk)
            }
            try call?.install(sessionStart: sessionStart) { chunk in
                callMeter.record(chunk.samples)
                sessionRecorder.mixdown.push(chunk)
            }
            self.micMeter = micMeter
            self.callMeter = callMeter
            sessionRecorder.start()

            updatesTask = Task { [weak self] in
                for await update in liveSession.updates {
                    self?.ingest(update)
                }
            }
            diarizeTask = Task { [weak self, who] in
                await self?.runDiarizeLoop(who: who)
            }
            clockTask = Task { [weak self] in
                while !Task.isCancelled {
                    self?.elapsed = Date().timeIntervalSince(self?.startedAt ?? Date())
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            uiTickTask = Task { [weak self] in
                while !Task.isCancelled {
                    self?.uiTick()
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            phase = .recording
            launching = false
            Sounds.started()
        } catch {
            teardownCapture()
            launching = false
            phase = .failed(Failure(
                title: "Couldn't start listening",
                message: error.localizedDescription,
                permissions: true))
            Sounds.failed()
        }
    }

    private static func micAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    private func temporaryWavURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WhoRealtime-\(UUID().uuidString).wav")
    }

    func stop() {
        guard case .recording = phase else { return }
        phase = .finishing
        clockTask?.cancel()
        diarizeTask?.cancel()
        uiTickTask?.cancel()
        uiTickTask = nil
        pendingTail = tailText   // freeze the live tail; the final pass replaces it
        teardownCapture()
        recorder?.seal()
        Task { await finish() }
    }

    private func finish() async {
        logger.info("stopping: sealing recorder and running the final pass")
        await live?.finish()
        if let updatesTask { await updatesTask.value }
        do {
            guard let who, let sessionRecorder = recorder else { throw CocoaError(.fileNoSuchFile) }
            let dia = try await who.diarize(contentsOf: sessionRecorder.wavURL)
            applyDiarization(dia)

            let docURL = try MeetingDoc.save(
                title: MeetingDoc.title(for: startedAt ?? Date()),
                lines: lines,
                names: speakerNames,
                wavURL: sessionRecorder.wavURL)
            savedDocURL = docURL
            self.recorder = nil
            mic = nil
            call = nil
            live = nil
            updatesTask = nil
            phase = .saved(docURL)
            micMeter = nil
            callMeter = nil
            micLevel = 0
            callLevel = 0
            Sounds.saved()
            logger.info("doc saved to \(docURL.path, privacy: .public)")
        } catch {
            logger.error("finishing failed: \(error.localizedDescription, privacy: .public)")
            Sounds.failed()
            phase = .failed(Failure(title: "Couldn't build the doc", message: error.localizedDescription))
        }
    }

    func newSession() {
        phase = .idle
        lines = []
        tailText = ""
        allWords = []
        snapshotCount = 0
        turns = []
        speakerNames = [:]
        speakerCount = 0
        elapsed = 0
        startedAt = nil
        savedDocURL = nil
    }

    // MARK: - Live plumbing

    private func ingest(_ update: Voz.LiveUpdate) {
        allWords = update.committedWords + update.tentativeWords
        // Held back for the 20 Hz tick: word bursts land as one smooth append
        // instead of republishing + rescrolling several times a second.
        pendingTail = allWords.dropFirst(snapshotCount).map(\.text).joined(separator: " ")
    }

    private func applyDiarization(_ dia: Diarization) {
        turns = dia.turns
        speakerCount = dia.speakerCount
        lines = Attribution.lines(words: allWords, turns: turns)
        snapshotCount = allWords.count
        pendingTail = ""
        tailText = ""
    }

    /// Smoothed meter state + throttled tail publish; runs only while recording.
    func uiTick() {
        if let micMeter {
            let drained = micMeter.drain()
            if drained.hasSignal { micLive = true }
            micLevel = LevelMeter.display(previous: micLevel, peak: drained.peak)
        }
        if let callMeter {
            let drained = callMeter.drain()
            if drained.hasSignal { callLive = true }
            callLevel = LevelMeter.display(previous: callLevel, peak: drained.peak)
        }
        if pendingTail != tailText { tailText = pendingTail }
    }

    /// First checkpoint early so a short meeting still gets labels; after
    /// that, every 2 minutes. Who diarizes hours in seconds, so reading the
    /// growing file whole is cheaper than windowing it.
    @concurrent
    private func runDiarizeLoop(who: Who) async {
        try? await Task.sleep(for: .seconds(30))
        await diarizeOnce(who: who)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(120))
            guard !Task.isCancelled else { return }
            await diarizeOnce(who: who)
        }
    }

    private func diarizeOnce(who: Who) async {
        guard let url = recorder?.wavURL else { return }
        do {
            let dia = try await who.diarize(contentsOf: url)
            await MainActor.run { self.applyDiarization(dia) }
        } catch {
            logger.info("mid-meeting diarize skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func teardownCapture() {
        mic?.stop()
        call?.stop()
        mic = nil
        call = nil
    }

    // MARK: - Speaker naming

    func setSpeakerName(_ name: String, for speaker: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        speakerNames[speaker] = trimmed.isEmpty ? nil : trimmed
        if let savedDocURL {
            let content = MeetingDoc.markdown(
                title: MeetingDoc.title(for: startedAt ?? Date()),
                lines: lines,
                names: speakerNames)
            try? Data(content.utf8).write(to: savedDocURL)
        }
    }

    func name(for speaker: Int) -> String {
        speakerNames[speaker] ?? "Speaker \(speaker + 1)"
    }

    // MARK: - Command surface (windowed app's Session menu)

    public var isRecording: Bool { phase == .recording || phase == .finishing }
    public var canToggle: Bool { phase == .idle || phase == .recording }

    public func toggleSession() {
        switch phase {
        case .idle: start()
        case .recording: stop()
        default: break
        }
    }
}
