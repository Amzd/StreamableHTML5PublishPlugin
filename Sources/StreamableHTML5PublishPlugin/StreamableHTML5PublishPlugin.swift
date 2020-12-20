//
//  StreamableHTML5PublishPlugin.swift
//
//
//  Created by Casper Zandbergen on 04/12/2019.
//

import Foundation
#if canImport(FoundationNetworking)
// This works in Github Actions
import FoundationNetworking
#endif
import Publish
import Ink
import Codextended
import Files
import OutputForPublishPlugins

/// Example:
/// ```streamable
/// video: 4vbhuo
/// poster: /files/IMG_5190.JPG
/// options: controls muted autoplay loop
/// ```

public let oneDay: TimeInterval = 86400

public extension Plugin {
    static func streamableToHTML5Video(useCacheUntilExpiresWithin seconds: TimeInterval = oneDay) -> Self {
        Plugin(name: "Streamable to MP4") { context in
            guard context.allItems(sortedBy: \.date).isEmpty else {
                return output("Streamable to MP4 (`installPlugin(.streamableToHTML5Video())`) should be added BEFORE `addMarkdownFiles()`", .error)
            }
            cacheFile = try context.cacheFile(named: "Streamable API Results")
            cached = (try? cacheFile!.read().decoded()) ?? [:]
            context.markdownParser.addModifier(.streamableCodeBlocks(context: context, useCacheUntilExpiresWithin: seconds))
            context.markdownParser.addModifier(.streamableImg(context: context, useCacheUntilExpiresWithin: seconds))
            
            didRunStreamableToMP4Plugin = true
        }
    }
    
    static func streamableDuration() -> Self {
        Plugin(name: "Streamable duration") { context in
            guard !context.allItems(sortedBy: \.date).isEmpty else {
                return output("Streamable duration (`installPlugin(.streamableDuration())`) should be added AFTER `addMarkdownFiles()`", .error)
            }
            guard didRunStreamableToMP4Plugin else {
                return output("Plugin Streamable to MP4 did not run. Add `.installPlugin(.streamableToHTML5Video())` to your publishing steps.", .error)
            }
            
            context.sections.forEach { section in
                section.items.forEach { item in
                    var videoIds = item.body.html
                        .components(separatedBy: "streamable.com/video/mp4/").dropFirst()
                        .filter { $0.contains(".mp4") }
                        .compactMap { $0.components(separatedBy: ".mp4").first }
                    videoIds = Array(Set(videoIds))
                    
                    videoIds.forEach { id in
                        guard let cache = cached[id] else {
                            return output("\(item.path): A streamable video with id \(id) was found that was not added using the Streamable to MP4 plugin. This is not added to the items total video duration.", .warning)
                        }
                        data[item, default: StreamableVideosMetadata()].totalDuration += cache.files.mp4.duration
                    }
                }
            }
            
            try cacheFile?.write(cached.encoded())
            didRunStreamableDurationPlugin = true
        }
    }
}

extension Modifier {
    static func streamableCodeBlocks<Site: Website>(context: PublishingContext<Site>, useCacheUntilExpiresWithin seconds: TimeInterval) -> Modifier {
        Modifier(target: .codeBlocks) { html, markdown in
            if markdown.hasPrefix("```streamable\n") {
                let withoutTicks = markdown
                    .drop(while: { !$0.isNewline }).dropFirst().reversed()
                    .drop(while: { !$0.isNewline }).reversed()
                let lines: [String] = withoutTicks.split(separator: "\n").map(String.init(_:))
                
                let video = lines.first(where: { $0.hasPrefix("video: ") })?.dropFirst(7)
                let poster = (lines.first(where: { $0.hasPrefix("poster: ") })?.dropFirst(8)).map(String.init(_:))
                let options = (lines.first(where: { $0.hasPrefix("options: ") })?.dropFirst(9)).map(String.init(_:)) ?? ""
                
                guard let videoID = video.map(String.init(_:)) else {
                    output("Missing video ID in code block", .error)
                    return html
                }
                
                return html5Video(
                    videoId: videoID,
                    poster: poster,
                    options: options,
                    useCacheUntilExpiresWithin: seconds
                ) ?? html
            }
            return html
        }
    }
    
    static func streamableImg<Site: Website>(context: PublishingContext<Site>, useCacheUntilExpiresWithin seconds: TimeInterval) -> Modifier {
        Modifier(target: .images) { html, markdown in
            let json = String(markdown.drop(while: { $0 != "{"}).dropLast())
            
            if let video: StreamableVideo = try? json.data(using: .utf8)?.decoded() {
                return html5Video(
                    videoId: video.id,
                    poster: video.poster,
                    options: video.options,
                    useCacheUntilExpiresWithin: seconds
                ) ?? html
            }
            return html
        }
    }
    
    private static func html5Video(videoId: String, poster: String?, options: String, useCacheUntilExpiresWithin seconds: TimeInterval) -> String? {
        let videoUrl: URL
        
        if let oldCache = cached[videoId],
           oldCache.expires > Date().addingTimeInterval(seconds).timeIntervalSince1970 {
            videoUrl = oldCache.files.mp4.url
        } else {
            let result = URLSession.shared.synchronousDataTask(with: URL(string: "https://api.streamable.com/videos/" + videoId)!)
            guard let data = result.data else {
                output("Streamable API error: \(result.error!)", .error)
                return nil
            }
            guard let apiResult: StreamableAPIResult = try? data.decoded() else {
                output("Streamable API result did not decode", .error)
                return nil
            }
            videoUrl = apiResult.files.mp4.url
            
            cached[videoId] = apiResult
        }
        
        return """
            <video id="streamable-video-player-\(videoId)" class="streamable-video-player" \(poster.map { "poster=\"\($0)\"" } ?? "") \(options)>
                <source src="\(videoUrl)" type="video/\(videoUrl.pathExtension.lowercased())">
            </video>
        """
    }
    
    struct StreamableVideo: Codable {
        var id: String
        var options: String
        var poster: String?
        
        init(from decoder: Decoder) throws {
            id = try decoder.decode("video")
            options = try decoder.decodeIfPresent("options") ?? ""
            poster = try decoder.decodeIfPresent("poster")
        }
    }
}

extension URLSession {
    func synchronousDataTask(with url: URL) -> (data: Data?, response: URLResponse?, error: Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.dataTask(with: url) {
            data = $0
            response = $1
            error = $2

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .now() + .seconds(10))

        return (data, response, error)
    }
}

struct StreamableAPIResult: Codable {
    var files: Files
    struct Files: Codable {
        var mp4: MP4
        struct MP4: Codable {
            var url: URL
            var duration: TimeInterval
        }
    }
    
    var expires: TimeInterval
    
    init(from decoder: Decoder) throws {
        files = try decoder.decode("files")
        
        if let timeInterval: TimeInterval = try? decoder.decode("expires") {
            expires = timeInterval
        } else {
            guard
                let components = URLComponents(url: files.mp4.url, resolvingAgainstBaseURL: true),
                let value = components.queryItems?.first(where: { $0.name == "Expires" })?.value,
                let timeInterval = Double(value)
            else {
                throw NSError(domain: "Failed to get expires component from URL", code: 1, userInfo: nil)
            }
            expires = timeInterval
        }
    }
    
    
}

private var cacheFile: File?
private var cached = [String: StreamableAPIResult]()
private var data = [AnyHashable: StreamableVideosMetadata]()
private var didRunStreamableToMP4Plugin = false
private var didRunStreamableDurationPlugin = false

public struct StreamableVideosMetadata: Equatable {
    public var totalDuration: TimeInterval = 0
}

public extension Item {
    var streamableVideos: StreamableVideosMetadata {
        if !didRunStreamableDurationPlugin {
            output("Plugin Streamable duration did not run. Add `.installPlugin(.streamableDuration())` BEFORE generateHTML(withTheme:)", .error)
        }
        return data[self, default: StreamableVideosMetadata()]
    }
}
