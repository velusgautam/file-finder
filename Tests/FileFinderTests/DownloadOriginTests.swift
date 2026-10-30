import Testing
import Foundation
@testable import FileFinderLib

@Suite("Download Origin Detection Tests")
struct DownloadOriginTests {

    @Test("Domain attribution overrides browser quarantine agent")
    func testDomainAttributionOverQuarantine() {
        let chromeAgent = "com.google.Chrome"

        // 1. Google Drive
        let driveOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://drive.google.com/uc?id=12345&export=download"]
        )
        #expect(driveOrigin == .googleDrive)

        // 2. Gmail
        let gmailOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://mail.google.com/mail/u/0?view=att&th=18f8e"]
        )
        #expect(gmailOrigin == .gmail)

        // 3. Slack
        let slackOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://files.slack.com/files-pri/T001-F002/report.pdf"]
        )
        #expect(slackOrigin == .slack)

        // 4. GitHub
        let githubOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://github.com/torvalds/linux/archive/master.zip"]
        )
        #expect(githubOrigin == .github)

        // 5. ChatGPT
        let chatGPTOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://chatgpt.com/backend-api/files/download"]
        )
        #expect(chatGPTOrigin == .chatgpt)

        // 6. Canva
        let canvaOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://www.canva.com/design/export.png"]
        )
        #expect(canvaOrigin == .canva)

        // 7. Notion
        let notionOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://notion.so/workspace/export.zip"]
        )
        #expect(notionOrigin == .notion)

        // 8. Custom Website Domain (e.g. Zerodha)
        let customDomainOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://kite.zerodha.com/reports/statement.xlsx"]
        )
        #expect(customDomainOrigin.displayName == "Zerodha")

        // 8. Discord
        let discordOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://cdn.discordapp.com/attachments/123/456/voice.mp3"]
        )
        #expect(discordOrigin == .discord)

        // 9. WhatsApp
        let whatsappOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://web.whatsapp.com/download/file.pdf"]
        )
        #expect(whatsappOrigin == .whatsapp)

        // 10. Telegram
        let telegramOrigin = DownloadOrigin.detect(
            quarantineAgent: chromeAgent,
            whereFromsURLs: ["https://t.me/c/1234/file.zip"]
        )
        #expect(telegramOrigin == .telegram)
    }

    @Test("Fallback to browser quarantine agent when URL is absent")
    func testQuarantineAgentFallback() {
        let safariOrigin = DownloadOrigin.detect(
            quarantineAgent: "com.apple.Safari",
            whereFromsURLs: []
        )
        #expect(safariOrigin == .safari)

        let chromeOrigin = DownloadOrigin.detect(
            quarantineAgent: "com.google.Chrome",
            whereFromsURLs: []
        )
        #expect(chromeOrigin == .chrome)

        let airdropOrigin = DownloadOrigin.detect(
            quarantineAgent: "com.apple.AirDrop",
            whereFromsURLs: []
        )
        #expect(airdropOrigin == .airdrop)

        let unknownOrigin = DownloadOrigin.detect(
            quarantineAgent: nil,
            whereFromsURLs: []
        )
        #expect(unknownOrigin == .unknown)
    }
}
