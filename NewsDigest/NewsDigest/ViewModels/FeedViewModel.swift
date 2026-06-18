import Foundation
import Observation

/// Состояние ленты дайджестов. Изолирован на главном акторе — все мутации
/// происходят в UI-потоке.
@MainActor
@Observable
final class FeedViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var digests: [Digest] = []
    private(set) var state: LoadState = .idle

    private let repository: DigestRepository
    private var realtimeTask: Task<Void, Never>?

    init(repository: DigestRepository = SupabaseDigestRepository()) {
        self.repository = repository
    }

    /// Первая загрузка ленты.
    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            digests = try await repository.fetchDigests(limit: 50)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Pull-to-refresh: тихая перезагрузка без скелетонов.
    func refresh() async {
        do {
            digests = try await repository.fetchDigests(limit: 50)
            state = .loaded
        } catch {
            // Сохраняем уже показанные данные, не сбрасываем в ошибку,
            // если что-то уже загружено.
            if digests.isEmpty {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// Подписка на новые вставки в реальном времени.
    func startListening() {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let stream = self?.repository.liveInserts() else { return }
            for await digest in stream {
                self?.insert(digest)
            }
        }
    }

    func stopListening() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    /// Вставляет новый дайджест, сохраняя сортировку и не дублируя.
    private func insert(_ digest: Digest) {
        guard !digests.contains(where: { $0.id == digest.id }) else { return }
        digests.append(digest)
        digests.sort { $0.publishedAt > $1.publishedAt }
    }
}
