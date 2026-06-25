//
//  DeveloperDiskImageService.swift
//  StikDebug
//

import Foundation

final class DeveloperDiskImageService {
    static let shared = DeveloperDiskImageService()

    private let fileManager: FileManager
    private let session: URLSession

    init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
    }

    func downloadMissingFiles() async throws {
        for item in Self.downloadItems {
            let destinationURL = URL.documentsDirectory.appendingPathComponent(item.relativePath)
            guard !fileManager.fileExists(atPath: destinationURL.path) else {
                continue
            }
            if try copyBundledFileIfAvailable(for: item, to: destinationURL) {
                continue
            }
            try await downloadFile(from: item.urlString, to: destinationURL)
        }
    }

    @discardableResult
    private func copyBundledFileIfAvailable(for item: DDIDownloadItem, to destinationURL: URL) throws -> Bool {
        guard let bundleResourceURL = Bundle.main.resourceURL else {
            return false
        }

        let bundledURL = bundleResourceURL.appendingPathComponent(item.relativePath)
        guard fileManager.fileExists(atPath: bundledURL.path) else {
            return false
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: bundledURL, to: destinationURL)
        return true
    }

    func downloadFile(from urlString: String, to destinationURL: URL) async throws {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https" else {
            throw DDIDownloadError.invalidURL(urlString)
        }

        let (temporaryURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DDIDownloadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DDIDownloadError.badStatus(httpResponse.statusCode)
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    func redownload(progressHandler: ((Double, String) -> Void)? = nil) async throws {
        let totalStages = Double(Self.downloadItems.count + 1)
        var completedStages = 0.0

        progressHandler?(0.0, "Removing existing DDI files...".localized)
        for item in Self.downloadItems {
            let fileURL = URL.documentsDirectory.appendingPathComponent(item.relativePath)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }

        completedStages += 1.0
        progressHandler?(completedStages / totalStages, "Starting downloads...".localized)

        for item in Self.downloadItems {
            progressHandler?(completedStages / totalStages, String(format: "Downloading %@...".localized, item.name.localized))
            let destinationURL = URL.documentsDirectory.appendingPathComponent(item.relativePath)
            let didCopyBundledFile = try copyBundledFileIfAvailable(for: item, to: destinationURL)
            if !didCopyBundledFile {
                try await downloadFile(from: item.urlString, to: destinationURL)
            }
            completedStages += 1.0
            progressHandler?(completedStages / totalStages, String(format: "%@ ready".localized, item.name.localized))
        }

        progressHandler?(1.0, "DDI download complete.".localized)
    }

    private static let downloadItems: [DDIDownloadItem] = [
        .init(
            name: "Build Manifest",
            relativePath: "DDI/BuildManifest.plist",
            urlString: "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/BuildManifest.plist"
        ),
        .init(
            name: "Image",
            relativePath: "DDI/Image.dmg",
            urlString: "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/Image.dmg"
        ),
        .init(
            name: "TrustCache",
            relativePath: "DDI/Image.dmg.trustcache",
            urlString: "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/Image.dmg.trustcache"
        )
    ]
}

private struct DDIDownloadItem {
    let name: String
    let relativePath: String
    let urlString: String
}

enum DDIDownloadError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let string):
            return String(format: "Invalid download URL: %@".localized, string)
        case .invalidResponse:
            return "The DDI server returned an invalid response.".localized
        case .badStatus(let statusCode):
            return String(format: "The DDI server returned HTTP %d.".localized, statusCode)
        }
    }
}

func redownloadDDI(progressHandler: ((Double, String) -> Void)? = nil) async throws {
    try await DeveloperDiskImageService.shared.redownload(progressHandler: progressHandler)
}
