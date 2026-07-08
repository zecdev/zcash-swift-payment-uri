//
//  QcharCodecTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu on 2026-07-08.
//

import Testing
@testable import ZcashPaymentURI

@Suite("QcharCodec")
struct QcharCodecTests {
    // MARK: encode

    @Test func encodesSpaceAsPercent20() {
        #expect(QcharCodec.encode(" ") == "%20")
        #expect(QcharCodec.encode("Thank you") == "Thank%20you")
    }

    @Test func allowedDelimsAndColonAtPassThroughRaw() {
        // qchar allowed-delims / ":" / "@" appear unescaped.
        #expect(QcharCodec.encode("!$'()*+,;:@") == "!$'()*+,;:@")
        #expect(QcharCodec.encode("sk8:forever@!") == "sk8:forever@!")
    }

    @Test func unreservedPassesThroughRaw() {
        #expect(QcharCodec.encode("aZ09-._~") == "aZ09-._~")
    }

    @Test func encodesTheComplementOfQchar() {
        // Exactly the reference QCHAR_ENCODE set (uppercase hex).
        #expect(QcharCodec.encode("\"") == "%22")
        #expect(QcharCodec.encode("#") == "%23")
        #expect(QcharCodec.encode("%") == "%25")
        #expect(QcharCodec.encode("&") == "%26")
        #expect(QcharCodec.encode("/") == "%2F")
        #expect(QcharCodec.encode("<") == "%3C")
        #expect(QcharCodec.encode("=") == "%3D")
        #expect(QcharCodec.encode(">") == "%3E")
        #expect(QcharCodec.encode("?") == "%3F")
        #expect(QcharCodec.encode("[") == "%5B")
        #expect(QcharCodec.encode("\\") == "%5C")
        #expect(QcharCodec.encode("]") == "%5D")
        #expect(QcharCodec.encode("^") == "%5E")
        #expect(QcharCodec.encode("`") == "%60")
        #expect(QcharCodec.encode("{") == "%7B")
        #expect(QcharCodec.encode("|") == "%7C")
        #expect(QcharCodec.encode("}") == "%7D")
    }

    @Test func encodesControlCharactersAndDEL() {
        #expect(QcharCodec.encode("\u{00}") == "%00")
        #expect(QcharCodec.encode("\u{1F}") == "%1F")
        #expect(QcharCodec.encode("\u{7F}") == "%7F") // DEL
    }

    @Test func encodesNonASCIIAsUTF8Bytes() {
        // é = U+00E9 = UTF-8 C3 A9
        #expect(QcharCodec.encode("é") == "%C3%A9")
        // € = U+20AC = UTF-8 E2 82 AC
        #expect(QcharCodec.encode("€") == "%E2%82%AC")
        // 😀 = U+1F600 = UTF-8 F0 9F 98 80
        #expect(QcharCodec.encode("😀") == "%F0%9F%98%80")
    }

    // MARK: decode

    @Test func decodeIsInverseOfEncodeForUnicodeAndEmoji() throws {
        let samples = [
            "",
            "plain",
            "Thank you for your purchase",
            "Order #321",
            "Your Ben & Jerry's Order",
            "sk8:forever@!",
            "café",
            "€100",
            "gm 😀 zcash",
            "100% sure"
        ]

        for sample in samples {
            let encoded = QcharCodec.encode(sample)
            #expect(QcharCodec.decode(encoded) == sample, "round-trip failed for \(sample)")
        }
    }

    @Test func emptyStringRoundTrips() {
        #expect(QcharCodec.encode("") == "")
        #expect(QcharCodec.decode("") == "")
    }

    @Test func decodesLowercaseAndUppercaseHex() {
        #expect(QcharCodec.decode("%2f") == "/")
        #expect(QcharCodec.decode("%2F") == "/")
        #expect(QcharCodec.decode("%c3%a9") == "é")
    }

    @Test func rejectsInvalidHexEscapes() {
        #expect(QcharCodec.decode("%2") == nil)       // truncated
        #expect(QcharCodec.decode("%") == nil)        // lone percent
        #expect(QcharCodec.decode("%2G") == nil)      // non-hex digit
        #expect(QcharCodec.decode("%GG") == nil)
        #expect(QcharCodec.decode("abc%") == nil)
        #expect(QcharCodec.decode("abc%A") == nil)
    }

    @Test func rejectsRawNonQcharBytes() {
        // A raw space / non-qchar character must be percent-encoded, not present raw.
        #expect(QcharCodec.decode("a b") == nil)
        #expect(QcharCodec.decode("a=b") == nil)
        #expect(QcharCodec.decode("a#b") == nil)
        #expect(QcharCodec.decode("café") == nil)     // raw non-ASCII byte
    }

    @Test func rejectsOverlongAndInvalidUTF8Sequences() {
        // Overlong encoding of "/" (0x2F): C0 AF — must be rejected.
        #expect(QcharCodec.decode("%C0%AF") == nil)
        // Lone continuation byte.
        #expect(QcharCodec.decode("%80") == nil)
        // Truncated 2-byte sequence (missing continuation).
        #expect(QcharCodec.decode("%C3") == nil)
        // Unpaired high surrogate (ED A0 80).
        #expect(QcharCodec.decode("%ED%A0%80") == nil)
    }

    @Test func literalPercentRoundTrips() {
        #expect(QcharCodec.encode("50%") == "50%25")
        #expect(QcharCodec.decode("50%25") == "50%")
    }
}
