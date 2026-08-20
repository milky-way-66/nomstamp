import Foundation

/// The four letters both phones show at the table.
///
/// It answers *which of the four Minhs in this room*, it defends against a machine in the middle,
/// and — the reason it is preferred to one reader scanning the other's screen — it is
/// **symmetric**. Neither reader has to work out whether they are the one showing or the one
/// scanning, which is where flows of this kind usually fail in practice (ADR-009, TC-8-06).
public enum VerificationWord {
    /// Letters chosen to be unambiguous when read aloud across a table, and when read by someone
    /// who is not confident in English: no I/O/L against 1/0, no Q, no vowel-heavy confusions.
    static let alphabet = Array("ABCDEFGHJKMNPRSTUVWXYZ")
    public static let length = 4

    /// Sorting the keys is what makes the result identical on both devices without either of them
    /// having to agree on who is who.
    public static func derive(_ a: FriendKey, _ b: FriendKey, using digest: any DigestPort) -> String {
        let ordered = a < b ? [a, b] : [b, a]
        let payload = Data(ordered.flatMap(\.bytes))
        let hex = digest.digest(payload)
        var word = ""
        var value = 0
        for (index, character) in hex.unicodeScalars.enumerated() {
            value = (value &* 31 &+ Int(character.value)) % 1_000_003
            if index % max(1, hex.count / length) == 0 && word.count < length {
                word.append(alphabet[abs(value) % alphabet.count])
            }
        }
        while word.count < length {
            value = (value &* 31 &+ 7) % 1_000_003
            word.append(alphabet[abs(value) % alphabet.count])
        }
        return word
    }
}
