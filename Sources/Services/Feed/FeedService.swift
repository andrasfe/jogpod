//
//  FeedService.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation

// MARK: - Feed Service Protocol

/// Protocol defining the interface for RSS/Atom feed parsing services.
///
/// This abstraction allows for different implementations (native XMLParser,
/// FeedKit, or other libraries) while maintaining a consistent API.
public protocol FeedServiceProtocol: Sendable {

    /// Fetches and parses a feed from the given URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the RSS/Atom feed.
    ///   - options: Parsing options to control what data is extracted.
    /// - Returns: A ParsedFeed containing the feed info and items.
    /// - Throws: FeedParsingError if fetching or parsing fails.
    func fetchFeed(from url: URL, options: FeedParseOptions) async throws -> ParsedFeed

    /// Fetches and parses a feed from a URL string.
    ///
    /// - Parameters:
    ///   - urlString: The URL string of the RSS/Atom feed.
    ///   - options: Parsing options.
    /// - Returns: A ParsedFeed containing the feed info and items.
    /// - Throws: FeedParsingError if the URL is invalid or parsing fails.
    func fetchFeed(from urlString: String, options: FeedParseOptions) async throws -> ParsedFeed

    /// Parses feed data that has already been downloaded.
    ///
    /// - Parameters:
    ///   - data: The raw feed data.
    ///   - sourceURL: The original URL (for reference).
    ///   - options: Parsing options.
    /// - Returns: A ParsedFeed containing the feed info and items.
    /// - Throws: FeedParsingError if parsing fails.
    func parseFeed(data: Data, sourceURL: URL, options: FeedParseOptions) async throws -> ParsedFeed
}

// MARK: - Default Options Extension

extension FeedServiceProtocol {

    /// Fetches a feed with default options.
    public func fetchFeed(from url: URL) async throws -> ParsedFeed {
        try await fetchFeed(from: url, options: .default)
    }

    /// Fetches a feed from a URL string with default options.
    public func fetchFeed(from urlString: String) async throws -> ParsedFeed {
        try await fetchFeed(from: urlString, options: .default)
    }

    /// Parses feed data with default options.
    public func parseFeed(data: Data, sourceURL: URL) async throws -> ParsedFeed {
        try await parseFeed(data: data, sourceURL: sourceURL, options: .default)
    }
}

// MARK: - Feed Service Implementation

/// Modern RSS/Atom feed parsing service using async/await.
///
/// This service replaces the legacy MWFeedParser-based implementation with
/// a native Swift solution using Foundation's XMLParser. It provides:
///
/// - Full RSS 2.0, RSS 1.0 (RDF), and Atom feed support
/// - Async/await API for modern Swift concurrency
/// - Proper error handling with typed errors
/// - Configurable parsing options
/// - Support for iTunes podcast extensions
///
/// ## Usage
///
/// ```swift
/// let service = FeedService()
///
/// // Fetch and parse a feed
/// let feed = try await service.fetchFeed(from: "https://example.com/feed.xml")
///
/// // Access feed info
/// print("Podcast: \(feed.info.title ?? "Unknown")")
///
/// // Iterate over episodes
/// for episode in feed.items {
///     print("- \(episode.title ?? "Untitled")")
/// }
/// ```
///
/// ## Migration from MWFeedParser
///
/// This service provides equivalent functionality to MWFeedParser:
/// - `FeedInfo` corresponds to `MWFeedInfo`
/// - `FeedItem` corresponds to `MWFeedItem`
/// - `FeedEnclosure` corresponds to the enclosure dictionaries
///
/// The key differences are:
/// - Uses async/await instead of delegate callbacks
/// - Returns value types instead of reference types
/// - Provides typed errors instead of NSError
public actor FeedService: FeedServiceProtocol {

    // MARK: - Configuration

    /// Default timeout for network requests in seconds.
    public static let defaultTimeout: TimeInterval = 30

    /// User agent string for feed requests.
    private static let userAgent = "JogPod/2.0"

    // MARK: - Properties

    /// The URL session used for network requests.
    private let session: URLSession

    /// Timeout interval for requests.
    private let timeout: TimeInterval

    // MARK: - Initialization

    /// Creates a new FeedService with the specified configuration.
    ///
    /// - Parameters:
    ///   - session: The URL session to use. Defaults to a configured session.
    ///   - timeout: Request timeout in seconds. Defaults to 30 seconds.
    public init(
        session: URLSession? = nil,
        timeout: TimeInterval = FeedService.defaultTimeout
    ) {
        self.timeout = timeout

        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout * 2
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - FeedServiceProtocol

    public func fetchFeed(
        from url: URL,
        options: FeedParseOptions
    ) async throws -> ParsedFeed {
        // Normalize URL (handle feed:// scheme)
        let normalizedURL = normalizeURL(url)

        // Create request
        var request = URLRequest(url: normalizedURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout

        // Fetch data
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw FeedParsingError.connectionFailed(underlying: error.localizedDescription)
        }

        // Validate response
        try validateResponse(response, data: data)

        // Get text encoding from response
        let encoding = (response as? HTTPURLResponse)?.textEncodingName

        // Parse the feed
        return try await parseData(data, sourceURL: normalizedURL, encoding: encoding, options: options)
    }

    public func fetchFeed(
        from urlString: String,
        options: FeedParseOptions
    ) async throws -> ParsedFeed {
        guard let url = URL(string: urlString) else {
            throw FeedParsingError.invalidURL(urlString)
        }
        return try await fetchFeed(from: url, options: options)
    }

    public func parseFeed(
        data: Data,
        sourceURL: URL,
        options: FeedParseOptions
    ) async throws -> ParsedFeed {
        try await parseData(data, sourceURL: sourceURL, encoding: nil, options: options)
    }

    // MARK: - Private Methods

    /// Normalizes a feed URL, handling the feed:// URI scheme.
    private func normalizeURL(_ url: URL) -> URL {
        guard url.scheme == "feed" else { return url }

        // Convert feed:// to http:// or https://
        // The feed: scheme format is typically feed://host/path or feed:http://host/path
        var urlString = url.absoluteString

        if urlString.hasPrefix("feed://") {
            // feed://host/path -> http://host/path
            urlString = "http://" + urlString.dropFirst("feed://".count)
        } else if urlString.hasPrefix("feed:") {
            // feed:http://... -> http://...
            urlString = String(urlString.dropFirst("feed:".count))
        }

        return URL(string: urlString) ?? url
    }

    /// Maps URLError to FeedParsingError.
    private func mapURLError(_ error: URLError) -> FeedParsingError {
        switch error.code {
        case .timedOut:
            return .timeout(seconds: timeout)
        case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return .connectionFailed(underlying: error.localizedDescription)
        case .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            return .certificateError(underlying: error.localizedDescription)
        case .cancelled:
            return .cancelled
        default:
            return .connectionFailed(underlying: error.localizedDescription)
        }
    }

    /// Validates the HTTP response.
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            if data.isEmpty {
                throw FeedParsingError.noDataReceived
            }
            return
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            throw FeedParsingError.httpError(
                statusCode: statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: statusCode)
            )
        }

        if data.isEmpty {
            throw FeedParsingError.emptyResponse
        }
    }

    /// Parses raw feed data into a ParsedFeed.
    private func parseData(
        _ data: Data,
        sourceURL: URL,
        encoding: String?,
        options: FeedParseOptions
    ) async throws -> ParsedFeed {
        // Convert to UTF-8 if needed
        let utf8Data = try convertToUTF8(data: data, encoding: encoding)

        // Parse with XMLParser
        let parser = FeedXMLParser(options: options)
        let (info, items) = try parser.parse(data: utf8Data)

        return ParsedFeed(
            info: info,
            items: items,
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    /// Converts data to UTF-8, handling various encodings.
    private func convertToUTF8(data: Data, encoding: String?) throws -> Data {
        // Try UTF-8 first
        if let _ = String(data: data, encoding: .utf8) {
            return data
        }

        // Try to detect encoding from response header
        var nsEncoding: String.Encoding?
        if let encoding = encoding {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encoding as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                nsEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
            }
        }

        // Try various encodings
        let encodingsToTry: [String.Encoding] = [
            nsEncoding,
            .utf8,
            .isoLatin1,
            .macOSRoman,
            .windowsCP1252
        ].compactMap { $0 }

        for encoding in encodingsToTry {
            if let string = String(data: data, encoding: encoding),
               let utf8Data = string.data(using: .utf8) {
                return utf8Data
            }
        }

        throw FeedParsingError.encodingError(encoding: encoding)
    }
}

// MARK: - XML Parser

/// Internal XML parser for RSS/Atom feeds.
private final class FeedXMLParser: NSObject, XMLParserDelegate {

    // MARK: - Properties

    private let options: FeedParseOptions
    private var feedInfo = FeedInfo()
    private var items: [FeedItem] = []
    private var currentItem: FeedItem?
    private var currentPath = "/"
    private var currentText = ""
    private var currentAttributes: [String: String] = [:]
    private var feedType: FeedType = .unknown
    private var hasEncounteredItems = false
    private var parseError: FeedParsingError?
    private var shouldStopParsing = false

    // MARK: - Date Formatters

    private static let rfc822Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601Formatter = ISO8601DateFormatter()

    private static let rfc822Formats = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss zzz",
        "dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm zzz",
        "EEE, dd MMM yyyy HH:mm Z"
    ]

    // MARK: - Initialization

    init(options: FeedParseOptions) {
        self.options = options
        super.init()
    }

    // MARK: - Parsing

    func parse(data: Data) throws -> (FeedInfo, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true

        let success = parser.parse()

        if let error = parseError {
            throw error
        }

        if !success, let error = parser.parserError {
            throw FeedParsingError.xmlParsingFailed(underlying: error.localizedDescription)
        }

        return (feedInfo, items)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        guard !shouldStopParsing else { return }

        let qualifiedName = qName ?? elementName
        currentPath = (currentPath as NSString).appendingPathComponent(qualifiedName)
        currentAttributes = attributeDict
        currentText = ""

        // Detect feed type
        if feedType == .unknown {
            detectFeedType(qualifiedName)
            return
        }

        // Check for new item
        if isItemStart(qualifiedName) {
            // Dispatch feed info before processing items
            if !hasEncounteredItems {
                hasEncounteredItems = true
                feedInfo.feedType = feedType

                if options.infoOnly {
                    shouldStopParsing = true
                    parser.abortParsing()
                    return
                }
            }

            currentItem = FeedItem()
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard !shouldStopParsing else { return }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Process element content
        processElement(path: currentPath, text: text, attributes: currentAttributes)

        // Update path
        currentPath = (currentPath as NSString).deletingLastPathComponent

        // Check for item end
        let qualifiedName = qName ?? elementName
        if isItemEnd(qualifiedName) {
            if var item = currentItem {
                // Normalize summary/content
                if item.summary == nil {
                    item.summary = item.content
                    item.content = nil
                }
                if item.date == nil {
                    item.date = item.updated
                }

                items.append(item)
                currentItem = nil

                // Check if we should stop
                if options.firstItemOnly || (options.maxItems != nil && items.count >= options.maxItems!) {
                    shouldStopParsing = true
                    parser.abortParsing()
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !shouldStopParsing else { return }
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard !shouldStopParsing else { return }
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentText += string
        } else if let string = String(data: CDATABlock, encoding: .isoLatin1) {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Only report errors if we didn't intentionally abort
        if !shouldStopParsing {
            self.parseError = .xmlParsingFailed(underlying: parseError.localizedDescription)
        }
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        self.parseError = .feedValidationError(underlying: validationError.localizedDescription)
    }

    // MARK: - Private Methods

    private func detectFeedType(_ element: String) {
        switch element {
        case "rss":
            feedType = .rss
        case "rdf:RDF":
            feedType = .rss1
        case "feed":
            feedType = .atom
        default:
            if element != "?xml" && !element.hasPrefix("?") {
                parseError = .invalidFeedFormat(details: "Root element '\(element)' is not a valid feed type")
            }
        }
    }

    private func isItemStart(_ element: String) -> Bool {
        switch feedType {
        case .rss:
            return currentPath == "/rss/channel/item"
        case .rss1:
            return currentPath == "/rdf:RDF/item"
        case .atom:
            return currentPath == "/feed/entry"
        case .unknown:
            return false
        }
    }

    private func isItemEnd(_ element: String) -> Bool {
        switch feedType {
        case .rss, .rss1:
            return element == "item"
        case .atom:
            return element == "entry"
        case .unknown:
            return false
        }
    }

    private func processElement(path: String, text: String, attributes: [String: String]) {
        // Process item elements
        if currentItem != nil {
            processItemElement(path: path, text: text, attributes: attributes)
            return
        }

        // Process feed info elements
        processFeedInfoElement(path: path, text: text, attributes: attributes)
    }

    private func processFeedInfoElement(path: String, text: String, attributes: [String: String]) {
        switch feedType {
        case .rss:
            processRSSInfoElement(path: path, text: text, attributes: attributes)
        case .rss1:
            processRSS1InfoElement(path: path, text: text, attributes: attributes)
        case .atom:
            processAtomInfoElement(path: path, text: text, attributes: attributes)
        case .unknown:
            break
        }
    }

    private func processRSSInfoElement(path: String, text: String, attributes: [String: String]) {
        switch path {
        case "/rss/channel/title":
            if !text.isEmpty { feedInfo.title = text }
        case "/rss/channel/description":
            if !text.isEmpty { feedInfo.summary = text }
        case "/rss/channel/link":
            if !text.isEmpty { feedInfo.link = text }
        case "/rss/channel/image/url":
            if !text.isEmpty { feedInfo.imageUrl = text }
        case "/rss/channel/itunes:image":
            if let href = attributes["href"] { feedInfo.imageUrl = href }
        default:
            break
        }
    }

    private func processRSS1InfoElement(path: String, text: String, attributes: [String: String]) {
        switch path {
        case "/rdf:RDF/channel/title":
            if !text.isEmpty { feedInfo.title = text }
        case "/rdf:RDF/channel/description":
            if !text.isEmpty { feedInfo.summary = text }
        case "/rdf:RDF/channel/link":
            if !text.isEmpty { feedInfo.link = text }
        case "/rdf:RDF/channel/image/url":
            if !text.isEmpty { feedInfo.imageUrl = text }
        default:
            break
        }
    }

    private func processAtomInfoElement(path: String, text: String, attributes: [String: String]) {
        switch path {
        case "/feed/title":
            if !text.isEmpty { feedInfo.title = text }
        case "/feed/subtitle", "/feed/tagline":
            if !text.isEmpty { feedInfo.summary = text }
        case "/feed/link":
            if attributes["rel"] == "alternate" || attributes["rel"] == nil {
                if let href = attributes["href"] { feedInfo.link = href }
            }
        case "/feed/icon", "/feed/logo":
            if !text.isEmpty { feedInfo.imageUrl = text }
        default:
            break
        }
    }

    private func processItemElement(path: String, text: String, attributes: [String: String]) {
        switch feedType {
        case .rss:
            processRSSItemElement(path: path, text: text, attributes: attributes)
        case .rss1:
            processRSS1ItemElement(path: path, text: text, attributes: attributes)
        case .atom:
            processAtomItemElement(path: path, text: text, attributes: attributes)
        case .unknown:
            break
        }
    }

    private func processRSSItemElement(path: String, text: String, attributes: [String: String]) {
        switch path {
        case "/rss/channel/item/title":
            if !text.isEmpty { currentItem?.title = text }
        case "/rss/channel/item/link":
            if !text.isEmpty { currentItem?.link = text }
        case "/rss/channel/item/guid":
            if !text.isEmpty { currentItem?.identifier = text }
        case "/rss/channel/item/description":
            if !text.isEmpty { currentItem?.summary = text }
        case "/rss/channel/item/content:encoded":
            if !text.isEmpty { currentItem?.content = text }
        case "/rss/channel/item/pubDate":
            currentItem?.date = parseDate(text, hint: .rfc822)
        case "/rss/channel/item/dc:date":
            currentItem?.date = parseDate(text, hint: .rfc3339)
        case "/rss/channel/item/enclosure":
            if let enclosure = createEnclosure(from: attributes, feedType: .rss) {
                currentItem?.enclosures.append(enclosure)
            }
        case "/rss/channel/item/itunes:duration":
            if !text.isEmpty { currentItem?.duration = text }
        default:
            break
        }
    }

    private func processRSS1ItemElement(path: String, text: String, attributes: [String: String]) {
        switch path {
        case "/rdf:RDF/item/title":
            if !text.isEmpty { currentItem?.title = text }
        case "/rdf:RDF/item/link":
            if !text.isEmpty { currentItem?.link = text }
        case "/rdf:RDF/item/dc:identifier":
            if !text.isEmpty { currentItem?.identifier = text }
        case "/rdf:RDF/item/description":
            if !text.isEmpty { currentItem?.summary = text }
        case "/rdf:RDF/item/content:encoded":
            if !text.isEmpty { currentItem?.content = text }
        case "/rdf:RDF/item/dc:date":
            currentItem?.date = parseDate(text, hint: .rfc3339)
        case "/rdf:RDF/item/enc:enclosure":
            if let enclosure = createEnclosure(from: attributes, feedType: .rss1) {
                currentItem?.enclosures.append(enclosure)
            }
        default:
            break
        }
    }

    private func processAtomItemElement(path: String, text: String, attributes: [String: String]) {
        switch path {
        case "/feed/entry/title":
            if !text.isEmpty { currentItem?.title = text }
        case "/feed/entry/id":
            if !text.isEmpty { currentItem?.identifier = text }
        case "/feed/entry/summary":
            if !text.isEmpty { currentItem?.summary = text }
        case "/feed/entry/content":
            if !text.isEmpty { currentItem?.content = text }
        case "/feed/entry/published":
            currentItem?.date = parseDate(text, hint: .rfc3339)
        case "/feed/entry/updated":
            currentItem?.updated = parseDate(text, hint: .rfc3339)
        case "/feed/entry/link":
            processAtomLink(attributes: attributes)
        default:
            break
        }
    }

    private func processAtomLink(attributes: [String: String]) {
        let rel = attributes["rel"] ?? "alternate"

        switch rel {
        case "alternate":
            if let href = attributes["href"] {
                currentItem?.link = href
            }
        case "enclosure":
            if let enclosure = createEnclosure(from: attributes, feedType: .atom) {
                currentItem?.enclosures.append(enclosure)
            }
        default:
            break
        }
    }

    private func createEnclosure(from attributes: [String: String], feedType: FeedType) -> FeedEnclosure? {
        let url: String?
        let type: String?
        let lengthString: String?

        switch feedType {
        case .rss:
            url = attributes["url"]
            type = attributes["type"]
            lengthString = attributes["length"]
        case .rss1:
            url = attributes["rdf:resource"]
            type = attributes["enc:type"]
            lengthString = attributes["enc:length"]
        case .atom:
            url = attributes["href"]
            type = attributes["type"]
            lengthString = attributes["length"]
        case .unknown:
            return nil
        }

        guard let enclosureURL = url else { return nil }

        let length = lengthString.flatMap { Int64($0) }

        return FeedEnclosure(url: enclosureURL, type: type, length: length)
    }

    // MARK: - Date Parsing

    private enum DateFormatHint {
        case rfc822
        case rfc3339
    }

    private func parseDate(_ string: String, hint: DateFormatHint) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch hint {
        case .rfc822:
            return parseRFC822Date(trimmed)
        case .rfc3339:
            return parseRFC3339Date(trimmed)
        }
    }

    private func parseRFC822Date(_ string: String) -> Date? {
        for format in Self.rfc822Formats {
            Self.rfc822Formatter.dateFormat = format
            if let date = Self.rfc822Formatter.date(from: string) {
                return date
            }
        }
        // Fall back to RFC3339 if RFC822 fails
        return parseRFC3339Date(string)
    }

    private func parseRFC3339Date(_ string: String) -> Date? {
        // Try ISO8601 first
        if let date = Self.iso8601Formatter.date(from: string) {
            return date
        }

        // Try common variants
        let variants = [
            string,
            string.replacingOccurrences(of: " ", with: "T"),
            string + "Z"
        ]

        for variant in variants {
            if let date = Self.iso8601Formatter.date(from: variant) {
                return date
            }
        }

        return nil
    }
}

// MARK: - Convenience Extensions

extension FeedService {

    /// Refreshes a feed by fetching the latest content.
    ///
    /// This is a convenience method that fetches a feed and returns
    /// all new items since the last fetch.
    ///
    /// - Parameters:
    ///   - url: The feed URL.
    ///   - lastFetchDate: The date of the last successful fetch.
    /// - Returns: A ParsedFeed with only items newer than lastFetchDate.
    public func refreshFeed(
        from url: URL,
        since lastFetchDate: Date?
    ) async throws -> ParsedFeed {
        let feed = try await fetchFeed(from: url)

        guard let lastFetchDate = lastFetchDate else {
            return feed
        }

        // Filter to only new items
        let newItems = feed.items.filter { item in
            guard let itemDate = item.effectiveDate else { return true }
            return itemDate > lastFetchDate
        }

        return ParsedFeed(
            info: feed.info,
            items: newItems,
            sourceURL: feed.sourceURL,
            fetchedAt: feed.fetchedAt
        )
    }

    /// Fetches the first episode from a feed for quick metadata extraction.
    ///
    /// This is optimized for cases where you only need the most recent
    /// episode, such as checking for updates.
    ///
    /// - Parameter url: The feed URL.
    /// - Returns: A ParsedFeed with only the first item.
    public func fetchFirstEpisode(from url: URL) async throws -> ParsedFeed {
        try await fetchFeed(from: url, options: .firstItemOnly)
    }

    /// Fetches only the feed metadata without parsing episodes.
    ///
    /// - Parameter url: The feed URL.
    /// - Returns: A ParsedFeed with info but no items.
    public func fetchFeedInfo(from url: URL) async throws -> FeedInfo {
        let feed = try await fetchFeed(from: url, options: .infoOnly)
        return feed.info
    }
}
