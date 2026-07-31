//
//  Bech32Tests.swift
//  zcash-swift-payment-uri
//
//  BIP-173 (Bech32) and BIP-350 (Bech32m) known-answer vectors, plus real
//  Zcash Sapling / Unified / regtest addresses and their corpus-corrupted
//  variants (which must fail checksum verification).
//

import Testing

@Suite("Bech32")
struct Bech32Tests {
    // MARK: BIP-173 valid Bech32

    @Test(arguments: [
        "A12UEL5L",
        "a12uel5l",
        "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs",
        "abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw",
        "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w",
        "?1ezyfcl"
    ])
    func validBech32(_ s: String) throws {
        let decoded = try #require(Bech32.decode(s))
        #expect(decoded.variant == .bech32)
    }

    // MARK: BIP-350 valid Bech32m

    @Test(arguments: [
        "A1LQFN3A",
        "a1lqfn3a",
        "abcdef1l7aum6echk45nj3s0wdvt2fg8x9yrzpqzd3ryx",
        "split1checkupstagehandshakeupstreamerranterredcaperredlc445v",
        "?1v759aa"
    ])
    func validBech32m(_ s: String) throws {
        let decoded = try #require(Bech32.decode(s))
        #expect(decoded.variant == .bech32m)
    }

    // MARK: Invalid encodings must decode to nil

    @Test(arguments: [
        "A1G7SGD8",   // invalid checksum
        "x1b4n0q5v",  // invalid data character 'b'
        "li1dgmt3",   // too short (data part < 6)
        "1pzry9x0s0muk", // empty HRP
        "pzry9x0s0muk",  // no separator
        "10a06t8",       // too short / empty HRP after last '1'
        "1qzzfhee",      // empty HRP
        // Mixed upper/lower case is rejected before lowercasing.
        "ztestsapling10YY2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
    ])
    func invalidEncodings(_ s: String) {
        #expect(Bech32.decode(s) == nil)
    }

    @Test func mixedCaseRejectedBeforeLowercasing() {
        // Valid lowercase and valid uppercase decode; a mix of both does not.
        #expect(Bech32.decode("a12uel5l") != nil)
        #expect(Bech32.decode("A12UEL5L") != nil)
        #expect(Bech32.decode("a12UEL5L") == nil)
    }

    @Test func nonPrintableAsciiRejected() {
        #expect(Bech32.decode(" 1nwldj5") == nil)   // space (0x20) in HRP
        #expect(Bech32.decode("\u{7f}1axkwrx") == nil) // DEL (0x7f)
    }

    @Test func exceedingLengthLimitRejected() {
        // A syntactically char-valid string longer than the 1023-char limit.
        let tooLong = "a1" + String(repeating: "q", count: 1023)
        #expect(tooLong.count > Bech32.maxLength)
        #expect(Bech32.decode(tooLong) == nil)
    }

    // MARK: Real Zcash addresses from the vector corpus

    @Test func saplingTestnetAddress() throws {
        let addr = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        let decoded = try #require(Bech32.decode(addr))
        #expect(decoded.variant == .bech32)
        #expect(decoded.hrp == "ztestsapling")
        #expect(Bech32.verify(addr, expectedHrp: "ztestsapling", variant: .bech32))
    }

    @Test func unifiedMainnetAddress() throws {
        // Mainnet UA, zcash-test-vectors unified_address.json.
        let addr = "u1l8xunezsvhq8fgzfl7404m450nwnd76zshscn6nfys7vyz2ywyh4cc5daaq0c7q2su5lqfh23sp7fkf3kt27ve5948mzpfdvckzaect2jtte308mkwlycj2u0eac077wu70vqcetkxf"
        let decoded = try #require(Bech32.decode(addr))
        #expect(decoded.variant == .bech32m)
        #expect(decoded.hrp == "u")
        #expect(Bech32.verify(addr, expectedHrp: "u", variant: .bech32m))
    }

    @Test func saplingRegtestAddress() throws {
        let addr = "zregtestsapling1qqqqqqqqqqqqqqqqqqcguyvaw2vjk4sdyeg0lc970u659lvhqq7t0np6hlup5lusxle7505hlz3"
        let decoded = try #require(Bech32.decode(addr))
        #expect(decoded.variant == .bech32)
        #expect(decoded.hrp == "zregtestsapling")
    }

    // MARK: Corpus corrupted variants must FAIL

    @Test func corruptedSaplingFails() {
        // Last char changed within the charset ('z' -> 'q'): checksum breaks.
        let corrupted = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2keq"
        #expect(Bech32.decode(corrupted) == nil)
    }

    @Test func corruptedUnifiedFails() {
        // Last char changed within the charset ('f' -> 'q'): checksum breaks.
        let corrupted = "u1l8xunezsvhq8fgzfl7404m450nwnd76zshscn6nfys7vyz2ywyh4cc5daaq0c7q2su5lqfh23sp7fkf3kt27ve5948mzpfdvckzaect2jtte308mkwlycj2u0eac077wu70vqcetkxq"
        #expect(Bech32.decode(corrupted) == nil)
    }

    // MARK: verify() convenience

    @Test func verifyRejectsWrongHrpOrVariant() {
        let sapling = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        #expect(Bech32.verify(sapling, expectedHrp: "ztestsapling", variant: .bech32))
        #expect(!Bech32.verify(sapling, expectedHrp: "zs", variant: .bech32))       // wrong HRP
        #expect(!Bech32.verify(sapling, expectedHrp: "ztestsapling", variant: .bech32m)) // wrong variant
    }
}
