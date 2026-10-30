import Foundation

/// External links shown in the app. The privacy policy is `site/privacy.html`,
/// deployed by Vercel from this repo (guideline 5.1.1(i): the same URL goes
/// into App Store Connect).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://bp-app-site.vercel.app/privacy.html")!
    static let support = URL(string: "mailto:woodoo2013@gmail.com?subject=BP%20Log")!
}
