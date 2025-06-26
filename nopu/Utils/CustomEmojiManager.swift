import Foundation
import SwiftUI

/// Manager for handling NIP-30 Custom Emoji
class CustomEmojiManager {
    static let shared = CustomEmojiManager()
    
    private init() {}
    
    /// Parse emoji tags from event tags array
    /// Returns a dictionary mapping shortcode to image URL
    func parseEmojiTags(from tags: [[String]]) -> [String: String] {
        var emojiMap: [String: String] = [:]
        
        for tag in tags {
            // NIP-30: ["emoji", <shortcode>, <image-url>]
            if tag.count >= 3 && tag[0] == "emoji" {
                let shortcode = tag[1]
                let imageUrl = tag[2]
                
                // Validate shortcode (alphanumeric and underscores only)
                if isValidShortcode(shortcode) && isValidImageUrl(imageUrl) {
                    emojiMap[shortcode] = imageUrl
                }
            }
        }
        
        return emojiMap
    }
    
    /// Process content for plain text display (notifications)
    /// Replaces :shortcode: with 🖼️ indicator for text-only contexts
    func processContentForPlainText(_ content: String, emojiMap: [String: String]) -> String {
        var processedContent = content
        
        // Find all :shortcode: patterns and replace with emoji indicators
        for (shortcode, _) in emojiMap {
            let pattern = ":\(shortcode):"
            if processedContent.contains(pattern) {
                // For plain text notifications, show just the image indicator
                let replacement = "🖼️"
                processedContent = processedContent.replacingOccurrences(of: pattern, with: replacement)
            }
        }
        
        return processedContent
    }
    
    /// Process content to replace :shortcode: with emoji representations
    /// For backwards compatibility, defaults to plain text processing
    func processContent(_ content: String, emojiMap: [String: String]) -> String {
        return processContentForPlainText(content, emojiMap: emojiMap)
    }
    
    /// Format like/reaction content with custom emoji support
    func formatReactionContent(_ content: String, emojiMap: [String: String]) -> String {
        var formattedContent = content
        
        // Handle standard reactions
        if content == "+" {
            formattedContent = "👍"
        } else if content == "-" {
            formattedContent = "👎"
        } else {
            // Process custom emoji in the content
            formattedContent = processContentForPlainText(content, emojiMap: emojiMap)
        }
        
        return formattedContent
    }
    
    /// Get structured emoji data for SwiftUI rendering
    /// Returns array of text segments and emoji info
    func parseContentForSwiftUI(_ content: String, emojiMap: [String: String]) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        let currentText = content
        
        // Find all emoji patterns and their positions
        var emojiMatches: [(range: Range<String.Index>, shortcode: String, imageUrl: String)] = []
        
        for (shortcode, imageUrl) in emojiMap {
            let pattern = ":\(shortcode):"
            var searchStartIndex = currentText.startIndex
            
            while searchStartIndex < currentText.endIndex,
                  let range = currentText.range(of: pattern, range: searchStartIndex..<currentText.endIndex) {
                emojiMatches.append((range: range, shortcode: shortcode, imageUrl: imageUrl))
                searchStartIndex = range.upperBound
            }
        }
        
        // Sort matches by position
        emojiMatches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build segments
        var currentIndex = currentText.startIndex
        
        for match in emojiMatches {
            // Add text before emoji
            if currentIndex < match.range.lowerBound {
                let textSegment = String(currentText[currentIndex..<match.range.lowerBound])
                if !textSegment.isEmpty {
                    segments.append(.text(textSegment))
                }
            }
            
            // Add emoji segment
            segments.append(.emoji(shortcode: match.shortcode, imageUrl: match.imageUrl))
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining text
        if currentIndex < currentText.endIndex {
            let remainingText = String(currentText[currentIndex..<currentText.endIndex])
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }
        
        // If no emoji found, return the original content as text
        if segments.isEmpty {
            segments.append(.text(content))
        }
        
        return segments
    }
    
    /// Extract emoji information for potential image loading
    /// Returns array of (shortcode, imageUrl) tuples found in content
    func extractEmojisFromContent(_ content: String, emojiMap: [String: String]) -> [(shortcode: String, imageUrl: String)] {
        var foundEmojis: [(shortcode: String, imageUrl: String)] = []
        
        for (shortcode, imageUrl) in emojiMap {
            let pattern = ":\(shortcode):"
            if content.contains(pattern) {
                foundEmojis.append((shortcode: shortcode, imageUrl: imageUrl))
            }
        }
        
        return foundEmojis
    }
    
    // MARK: - Private Helpers
    
    private func isValidShortcode(_ shortcode: String) -> Bool {
        // NIP-30: shortcode must be alphanumeric characters and underscores only
        let pattern = "^[a-zA-Z0-9_]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: shortcode.utf16.count)
        return regex?.firstMatch(in: shortcode, options: [], range: range) != nil
    }
    
    private func isValidImageUrl(_ url: String) -> Bool {
        // Basic URL validation
        guard let nsurl = URL(string: url) else { return false }
        return nsurl.scheme == "http" || nsurl.scheme == "https"
    }
}

// MARK: - Content Segment Types

enum ContentSegment {
    case text(String)
    case emoji(shortcode: String, imageUrl: String)
}

// MARK: - SwiftUI Integration

extension CustomEmojiManager {
    /// Create a SwiftUI view for displaying custom emoji
    @ViewBuilder
    func emojiView(shortcode: String, imageUrl: String, fallbackText: String? = nil) -> some View {
        AsyncImage(url: URL(string: imageUrl)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Text(fallbackText ?? "🖼️")
                .foregroundColor(.secondary)
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Rich Text View for SwiftUI

struct RichTextView: View {
    let content: String
    let emojiMap: [String: String]
    
    var body: some View {
        let segments = CustomEmojiManager.shared.parseContentForSwiftUI(content, emojiMap: emojiMap)
        
        // Use Text with inline images for better compatibility
        if segments.count == 1, case .text(let text) = segments[0] {
            // Simple text, no emojis
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        } else {
            // Has emojis, use HStack for simple inline display
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    switch segment {
                    case .text(let text):
                        Text(text)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    case .emoji(let shortcode, let imageUrl):
                        CustomEmojiManager.shared.emojiView(
                            shortcode: shortcode,
                            imageUrl: imageUrl
                        )
                    }
                }
            }
        }
    }
}