import Foundation
import SwiftUI

public enum DownloadOrigin: Hashable, Sendable {
    case chrome
    case safari
    case arc
    case slack
    case discord
    case chatgpt
    case gmail
    case googleDrive
    case whatsapp
    case github
    case figma
    case canva
    case x
    case notion
    case pinterest
    case mail
    case telegram
    case airdrop
    case custom(appName: String, domain: String?)
    case unknown

    public var displayName: String {
        switch self {
        case .chrome:                  return "Chrome"
        case .safari:                  return "Safari"
        case .arc:                     return "Arc"
        case .slack:                   return "Slack"
        case .discord:                 return "Discord"
        case .chatgpt:                 return "ChatGPT"
        case .gmail:                   return "Gmail"
        case .googleDrive:             return "Google Drive"
        case .whatsapp:                return "WhatsApp"
        case .github:                  return "GitHub"
        case .figma:                   return "Figma"
        case .canva:                   return "Canva"
        case .x:                       return "X"
        case .notion:                  return "Notion"
        case .pinterest:               return "Pinterest"
        case .mail:                    return "Apple Mail"
        case .telegram:                return "Telegram"
        case .airdrop:                 return "AirDrop"
        case .custom(let appName, _):  return appName
        case .unknown:                 return "Local"
        }
    }

    public var iconSystemName: String {
        switch self {
        case .chrome:      return "globe"
        case .safari:      return "safari"
        case .arc:         return "network"
        case .slack:       return "bubble.left.and.bubble.right"
        case .discord:     return "gamecontroller"
        case .chatgpt:     return "sparkles"
        case .gmail:       return "envelope.badge.fill"
        case .googleDrive: return "externaldrive.fill"
        case .whatsapp:    return "message.fill"
        case .github:      return "chevron.left.forwardslash.chevron.right"
        case .figma:       return "pencil.and.ruler.fill"
        case .canva:       return "paintpalette.fill"
        case .x:           return "at"
        case .notion:      return "note.text"
        case .pinterest:   return "pin.fill"
        case .mail:        return "envelope"
        case .telegram:    return "paperplane.fill"
        case .airdrop:     return "antenna.radiowaves.left.and.right"
        case .custom:      return "arrow.down.app"
        case .unknown:     return "internaldrive"
        }
    }

    public var tintColor: Color {
        switch self {
        case .chrome:      return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .safari:      return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .arc:         return Color(red: 0.95, green: 0.35, blue: 0.45)
        case .slack:       return Color(red: 0.40, green: 0.15, blue: 0.45)
        case .discord:     return Color(red: 0.45, green: 0.40, blue: 0.95)
        case .chatgpt:     return Color(red: 0.20, green: 0.65, blue: 0.55)
        case .gmail:       return Color(red: 0.90, green: 0.25, blue: 0.25)
        case .googleDrive: return Color(red: 0.95, green: 0.75, blue: 0.15)
        case .whatsapp:    return Color(red: 0.15, green: 0.75, blue: 0.40)
        case .github:      return Color(red: 0.45, green: 0.35, blue: 0.75)
        case .figma:       return Color(red: 0.95, green: 0.45, blue: 0.35)
        case .canva:       return Color(red: 0.15, green: 0.70, blue: 0.85)
        case .x:           return Color(red: 0.20, green: 0.20, blue: 0.25)
        case .notion:      return Color(red: 0.35, green: 0.35, blue: 0.40)
        case .pinterest:   return Color(red: 0.85, green: 0.20, blue: 0.25)
        case .mail:        return Color(red: 0.30, green: 0.60, blue: 0.95)
        case .telegram:    return Color(red: 0.20, green: 0.60, blue: 0.90)
        case .airdrop:     return Color(red: 0.20, green: 0.70, blue: 0.45)
        case .custom:      return Color(red: 0.45, green: 0.55, blue: 0.70)
        case .unknown:     return Color.secondary.opacity(0.6)
        }
    }

    /// Intelligent detection: prioritize actual download URL domain before falling back to browser agent
    public static func detect(quarantineAgent: String?, whereFromsURLs: [String]) -> DownloadOrigin {
        let agentLower = (quarantineAgent ?? "").lowercased()
        let urlsCombined = whereFromsURLs.joined(separator: " ").lowercased()

        // 1. Direct Web Domain / Service Attribution
        if urlsCombined.contains("chatgpt.com") || urlsCombined.contains("openai.com") {
            return .chatgpt
        }
        if urlsCombined.contains("slack.com") || agentLower.contains("slack") {
            return .slack
        }
        if urlsCombined.contains("discord.com") || urlsCombined.contains("discordapp.com") || urlsCombined.contains("discord.gg") || agentLower.contains("discord") {
            return .discord
        }
        if urlsCombined.contains("mail.google.com") {
            return .gmail
        }
        if urlsCombined.contains("drive.google.com") {
            return .googleDrive
        }
        if urlsCombined.contains("whatsapp.com") || agentLower.contains("whatsapp") {
            return .whatsapp
        }
        if urlsCombined.contains("github.com") {
            return .github
        }
        if urlsCombined.contains("figma.com") {
            return .figma
        }
        if urlsCombined.contains("canva.com") {
            return .canva
        }
        if urlsCombined.contains("notion.so") || urlsCombined.contains("notion.site") {
            return .notion
        }
        if urlsCombined.contains("twitter.com") || urlsCombined.contains("x.com") {
            return .x
        }
        if urlsCombined.contains("pinterest.com") {
            return .pinterest
        }
        if urlsCombined.contains("telegram.org") || urlsCombined.contains("t.me") || agentLower.contains("telegram") {
            return .telegram
        }

        // 2. AirDrop / Native System Sharing
        if agentLower.contains("airdrop") || agentLower.contains("sharingd") {
            return .airdrop
        }
        if agentLower.contains("mail") {
            return .mail
        }

        // 3. Clean Website Domain (if downloaded from a specific website in any browser)
        if let firstURL = whereFromsURLs.first,
           let urlObj = URL(string: firstURL),
           let host = urlObj.host,
           !host.isEmpty,
           host != "localhost" && !host.contains("google.com/search") {
            // Clean host (e.g., "download.zerodha.com" -> "Zerodha")
            let parts = host.split(separator: ".")
            if parts.count >= 2 {
                let domainName = parts[parts.count - 2]
                let formattedName = domainName.prefix(1).uppercased() + domainName.dropFirst()
                return .custom(appName: String(formattedName), domain: host)
            }
        }

        // 4. Browser Client Fallback (only if no specific website was identifiable)
        if agentLower.contains("google chrome") || agentLower.contains("chrome") {
            return .chrome
        }
        if agentLower.contains("safari") {
            return .safari
        }
        if agentLower.contains("arc") {
            return .arc
        }

        if let agent = quarantineAgent, !agent.isEmpty {
            return .custom(appName: agent, domain: nil)
        }

        return .unknown
    }

    public var rawIdentifier: String {
        switch self {
        case .chrome:      return "chrome"
        case .safari:      return "safari"
        case .arc:         return "arc"
        case .slack:       return "slack"
        case .discord:     return "discord"
        case .chatgpt:     return "chatgpt"
        case .gmail:       return "gmail"
        case .googleDrive: return "googleDrive"
        case .whatsapp:    return "whatsapp"
        case .github:      return "github"
        case .figma:       return "figma"
        case .canva:       return "canva"
        case .x:           return "x"
        case .notion:      return "notion"
        case .pinterest:   return "pinterest"
        case .mail:        return "mail"
        case .telegram:    return "telegram"
        case .airdrop:     return "airdrop"
        case .custom(let appName, let domain):
            if let domain = domain {
                return "custom:\(appName)|\(domain)"
            } else {
                return "custom:\(appName)"
            }
        case .unknown:     return "unknown"
        }
    }

    public static func from(rawIdentifier: String) -> DownloadOrigin {
        switch rawIdentifier {
        case "chrome":      return .chrome
        case "safari":      return .safari
        case "arc":         return .arc
        case "slack":       return .slack
        case "discord":     return .discord
        case "chatgpt":     return .chatgpt
        case "gmail":       return .gmail
        case "googleDrive": return .googleDrive
        case "whatsapp":    return .whatsapp
        case "github":      return .github
        case "figma":       return .figma
        case "canva":       return .canva
        case "x":           return .x
        case "notion":      return .notion
        case "pinterest":   return .pinterest
        case "mail":        return .mail
        case "telegram":    return .telegram
        case "airdrop":     return .airdrop
        case "unknown":     return .unknown
        default:
            if rawIdentifier.hasPrefix("custom:") {
                let rest = String(rawIdentifier.dropFirst(7))
                let parts = rest.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                let appName = String(parts.first ?? "")
                let domain = parts.count > 1 && !parts[1].isEmpty ? String(parts[1]) : nil
                return .custom(appName: appName, domain: domain)
            }
            return .unknown
        }
    }
}
