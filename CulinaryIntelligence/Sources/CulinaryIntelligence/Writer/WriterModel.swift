import Foundation
import Observation

/// The model that writes a recipe before Apple Intelligence sorts it: IBM's Granite 4.0 1B,
/// quantized to Q4_K_M, the build the Plates Kitchen evals ran. It is too large to ship in the
/// app, so it is downloaded once, into Application Support, and kept out of backups.
public nonisolated enum WriterModel {
    static let fileName = "granite-4.0-1b-Q4_K_M.gguf"

    /// Pinned to one revision of the repository, so the file the app runs is the file it was
    /// tested with.
    static let source = URL(
        string: "https://huggingface.co/ibm-granite/granite-4.0-1b-GGUF/resolve/b27c2fe3f211b7f44e80fa620177aea371099aaa/granite-4.0-1b-Q4_K_M.gguf"
    )!

    /// The size of that revision, which is how a finished download is told from a cut one.
    static let byteCount: Int64 = 1_023_645_440

    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Models", directoryHint: .isDirectory)
    }

    static var fileURL: URL { directory.appending(path: fileName) }

    /// True once the whole file is on disk.
    public static var isInstalled: Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attributes?[.size] as? NSNumber)?.int64Value == byteCount
    }
}

/// Fetches the writer model and says how far along it is. The download runs in a background
/// session, so it carries on when the cook leaves the app, and a session made again with the
/// same identifier picks up the transfer already in flight rather than starting a second one.
@Observable
public final class WriterModelDownload {
    public enum State: Equatable {
        case idle
        case downloading
        case finished
        case failed(String)
    }

    public private(set) var state: State
    /// From 0 to 1.
    public private(set) var fraction = 0.0

    public var isReady: Bool { state == .finished }

    /// The one download for the process. A background session identifier can only be in use
    /// once, so everything that asks about the model asks this.
    public static let shared = WriterModelDownload()

    /// The session identifier the app hands to `backgroundTask(.urlSession(_:))`, so a
    /// download that finishes while the app is not running is delivered when it is woken.
    public static let sessionIdentifier = "com.tsubuzaki.Plates.WriterModel"

    @ObservationIgnored private var session: URLSession?
    @ObservationIgnored private let delegate = DownloadDelegate()

    private init() {
        state = WriterModel.isInstalled ? .finished : .idle
        delegate.progress = { [weak self] fraction in
            Task { @MainActor in self?.progressed(fraction) }
        }
        delegate.completion = { [weak self] result in
            Task { @MainActor in self?.completed(result) }
        }
    }

    /// Starts the download, or takes up the one the system is already running. Asking again
    /// while it runs does nothing.
    public func start() {
        guard state != .finished, state != .downloading else { return }
        state = .downloading
        fraction = 0
        let session = self.session ?? makeSession()
        self.session = session
        session.getAllTasks { [weak self] tasks in
            // A transfer the system already holds, running or finished with its outcome still
            // to be delivered, is left to report through the delegate.
            if let task = tasks.first {
                if task.state == .suspended { task.resume() }
                return
            }
            Task { @MainActor in
                guard let self, self.state == .downloading else { return }
                session.downloadTask(with: WriterModel.source).resume()
            }
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private func progressed(_ value: Double) {
        guard state == .downloading else { return }
        fraction = max(fraction, min(value, 1))
    }

    private func completed(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            fraction = 1
            state = .finished
        case let .failure(error):
            state = .failed(error.localizedDescription)
        }
    }
}

/// The session's delegate. URLSession calls it on a queue of its own, and a finished file has to
/// be moved before the call returns, so the move happens here and only the outcome goes back to
/// the main actor.
private nonisolated final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var progress: (@Sendable (Double) -> Void)?
    var completion: (@Sendable (Result<Void, Error>) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : WriterModel.byteCount
        progress?(Double(totalBytesWritten) / Double(expected))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if let response = downloadTask.response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                throw DownloadError.http(response.statusCode)
            }
            let size = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.int64Value
            guard size == WriterModel.byteCount else { throw DownloadError.incomplete }
            let manager = FileManager.default
            try manager.createDirectory(at: WriterModel.directory, withIntermediateDirectories: true)
            if manager.fileExists(atPath: WriterModel.fileURL.path) {
                try manager.removeItem(at: WriterModel.fileURL)
            }
            try manager.moveItem(at: location, to: WriterModel.fileURL)
            var destination = WriterModel.fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try destination.setResourceValues(values)
            completion?(.success(()))
        } catch {
            completion?(.failure(error))
        }
    }

    /// Reports a transfer that ended without a file. One that ended with a file has already
    /// been reported above.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        completion?(.failure(error))
    }
}

private nonisolated enum DownloadError: LocalizedError {
    case http(Int)
    case incomplete

    var errorDescription: String? {
        switch self {
        case let .http(code): String(format: String(culinary: "Download.Error.Server"), String(code))
        case .incomplete: String(culinary: "Download.Error.Incomplete")
        }
    }
}
