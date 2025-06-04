import Foundation
import SwiftData
import SwiftUI

// MARK: - Search Index Entry

struct SearchIndexEntry {
    let transcriptionId: UUID
    let searchableText: String
    let timestamp: Date
    let duration: TimeInterval
    let hasVersions: Bool
    let hasEnhancements: Bool
}

// MARK: - Optimized Search Service

@MainActor
class OptimizedSearchService: ObservableObject {
    static let shared = OptimizedSearchService()

    @Published var searchResults: [Transcription] = []
    @Published var isSearching = false

    private var searchIndex: [SearchIndexEntry] = []
    private var allTranscriptions: [Transcription] = []
    private var searchWorkItem: DispatchWorkItem?

    private init() {}

    // MARK: - Index Management

    func buildSearchIndex(from transcriptions: [Transcription]) {
        allTranscriptions = transcriptions

        searchIndex = transcriptions.map { transcription in
            // Build comprehensive searchable text
            var searchableComponents: [String] = []

            // Main transcription text
            searchableComponents.append(transcription.text)

            // All version texts
            for version in transcription.transcriptionVersions {
                searchableComponents.append(version.text)
            }

            // All enhancement texts
            for enhancement in transcription.enhancementVersions {
                searchableComponents.append(enhancement.enhancedText)
                searchableComponents.append(enhancement.enhancementMethod)
            }

            // Date components for date-based searches
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            searchableComponents.append(dateFormatter.string(from: transcription.timestamp))

            let searchableText = searchableComponents.joined(separator: " ").lowercased()

            return SearchIndexEntry(
                transcriptionId: transcription.id,
                searchableText: searchableText,
                timestamp: transcription.timestamp,
                duration: transcription.duration,
                hasVersions: !transcription.transcriptionVersions.isEmpty,
                hasEnhancements: !transcription.enhancementVersions.isEmpty
            )
        }
    }

    // MARK: - Optimized Search

    func search(_ query: String) {
        // Cancel previous search
        searchWorkItem?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = allTranscriptions
            isSearching = false
            return
        }

        isSearching = true

        // Debounced search with optimized algorithm
        searchWorkItem = DispatchWorkItem { [weak self] in
            self?.performOptimizedSearch(query)
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + 0.2,
            execute: searchWorkItem!
        )
    }

    private func performOptimizedSearch(_ query: String) {
        let lowercaseQuery = query.lowercased()
        let queryTerms = lowercaseQuery.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Fast filtering using pre-built index
        let matchingIds = searchIndex.compactMap { entry -> (UUID, Int)? in
            let score = calculateSearchScore(entry: entry, queryTerms: queryTerms)
            return score > 0 ? (entry.transcriptionId, score) : nil
        }

        // Sort by relevance score
        let sortedIds =
            matchingIds
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        // Map back to transcriptions
        let results = sortedIds.compactMap { id in
            allTranscriptions.first { $0.id == id }
        }

        DispatchQueue.main.async {
            self.searchResults = results
            self.isSearching = false
        }
    }

    private func calculateSearchScore(entry: SearchIndexEntry, queryTerms: [String]) -> Int {
        var score = 0

        for term in queryTerms {
            if entry.searchableText.contains(term) {
                score += 1

                // Boost score for exact matches at word boundaries
                if entry.searchableText.range(of: "\\b\(term)\\b", options: .regularExpression)
                    != nil
                {
                    score += 2
                }
            }
        }

        // Boost recent transcriptions slightly
        let daysSinceCreation = Date().timeIntervalSince(entry.timestamp) / (24 * 60 * 60)
        if daysSinceCreation < 7 && score > 0 {
            score += 1
        }

        return score
    }

    // MARK: - Filter Helpers

    func filterByHasVersions() -> [Transcription] {
        return allTranscriptions.filter { !$0.transcriptionVersions.isEmpty }
    }

    func filterByHasEnhancements() -> [Transcription] {
        return allTranscriptions.filter { !$0.enhancementVersions.isEmpty }
    }

    func filterByDateRange(from startDate: Date, to endDate: Date) -> [Transcription] {
        return allTranscriptions.filter { transcription in
            transcription.timestamp >= startDate && transcription.timestamp <= endDate
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        searchIndex.removeAll()
        searchResults.removeAll()
        allTranscriptions.removeAll()
    }

    func updateIndex(for transcription: Transcription) {
        // Update specific entry in index
        if let index = searchIndex.firstIndex(where: { $0.transcriptionId == transcription.id }) {
            searchIndex[index] = createIndexEntry(for: transcription)
        } else {
            searchIndex.append(createIndexEntry(for: transcription))
        }

        // Update transcriptions array
        if let index = allTranscriptions.firstIndex(where: { $0.id == transcription.id }) {
            allTranscriptions[index] = transcription
        } else {
            allTranscriptions.append(transcription)
        }
    }

    private func createIndexEntry(for transcription: Transcription) -> SearchIndexEntry {
        var searchableComponents: [String] = []

        searchableComponents.append(transcription.text)

        for version in transcription.transcriptionVersions {
            searchableComponents.append(version.text)
        }

        for enhancement in transcription.enhancementVersions {
            searchableComponents.append(enhancement.enhancedText)
            searchableComponents.append(enhancement.enhancementMethod)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        searchableComponents.append(dateFormatter.string(from: transcription.timestamp))

        let searchableText = searchableComponents.joined(separator: " ").lowercased()

        return SearchIndexEntry(
            transcriptionId: transcription.id,
            searchableText: searchableText,
            timestamp: transcription.timestamp,
            duration: transcription.duration,
            hasVersions: !transcription.transcriptionVersions.isEmpty,
            hasEnhancements: !transcription.enhancementVersions.isEmpty
        )
    }
}

// MARK: - Search Filters

enum SearchFilter: CaseIterable {
    case all
    case hasVersions
    case hasEnhancements
    case recent
    case longDuration

    var title: String {
        switch self {
        case .all: return "All"
        case .hasVersions: return "Has Versions"
        case .hasEnhancements: return "Enhanced"
        case .recent: return "Recent"
        case .longDuration: return "Long Duration"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .hasVersions: return "doc.on.doc"
        case .hasEnhancements: return "sparkles"
        case .recent: return "clock"
        case .longDuration: return "timer"
        }
    }
}

// MARK: - Search Bar Component

struct OptimizedSearchBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: SearchFilter
    @ObservedObject var searchService: OptimizedSearchService

    var body: some View {
        VStack(spacing: 12) {
            // Search input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search transcriptions, versions, and enhancements...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        searchService.search(newValue)
                    }

                if searchService.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let filter: SearchFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)

                Text(filter.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
