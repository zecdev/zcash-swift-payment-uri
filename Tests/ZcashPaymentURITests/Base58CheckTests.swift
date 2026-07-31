//
//  Base58CheckTests.swift
//  zcash-swift-payment-uri
//
//  Base58Check decode/verify tests for transparent Zcash addresses, plus
//  edge cases (leading-zero bytes, invalid alphabet characters, short input).
//

import Testing

@Suite("Base58Check")
struct Base58CheckTests {
    // Transparent address version bytes, from librustzcash
    // zcash_protocol/src/constants/{mainnet,testnet}.rs.
    private let mainnetP2PKH: [UInt8] = [0x1c, 0xb8]
    private let testnetP2PKH: [UInt8] = [0x1d, 0x25]

    @Test func testnetP2PKHDecodes() throws {
        // From spec/lib.rs; also the source of the corpus's corrupted variant.
        let addr = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        let payload = try #require(Base58Check.decode(addr))
        #expect(Array(payload[0..<2]) == testnetP2PKH)
        #expect(Base58Check.verify(addr, expectedVersionBytes: [testnetP2PKH]))
    }

    @Test func mainnetP2PKHDecodes() throws {
        // Mainnet t1 address from zcash-test-vectors (zip_0320.json).
        let addr = "t1V9mnyk5Z5cTNMCkLbaDwSskgJZucTLdgW"
        let payload = try #require(Base58Check.decode(addr))
        #expect(Array(payload[0..<2]) == mainnetP2PKH)
        #expect(Base58Check.verify(addr, expectedVersionBytes: [mainnetP2PKH]))
    }

    @Test func corruptedTestnetAddressFails() {
        // Corpus invalid variant: last char changed ('U' -> '1'), checksum breaks.
        let corrupted = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovp1"
        #expect(Base58Check.decode(corrupted) == nil)
        #expect(!Base58Check.verify(corrupted, expectedVersionBytes: [testnetP2PKH]))
    }

    @Test func verifyRejectsWrongVersionBytes() {
        // A valid testnet address must not verify against mainnet prefixes.
        let addr = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        #expect(!Base58Check.verify(addr, expectedVersionBytes: [mainnetP2PKH]))
        // ...but does verify when the correct prefix is among several.
        #expect(Base58Check.verify(addr, expectedVersionBytes: [mainnetP2PKH, testnetP2PKH]))
    }

    @Test func leadingOnePreservesLeadingZeroBytes() throws {
        // '1'-prefixed vector encoding payload 0x00 01 02 03 04 (checksum valid).
        let vector = "1An6UhWF92g"
        let payload = try #require(Base58Check.decode(vector))
        #expect(payload == [0x00, 0x01, 0x02, 0x03, 0x04])
    }

    @Test func invalidAlphabetCharactersRejected() {
        // 0, O, I, l are not in the base58 alphabet.
        for bad in ["tmEZ0hbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                    "tmEZOhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                    "tmEZIhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                    "tmEZlhbWHTpdKMw5it8YDspUXSMGQyFwovpU"] {
            #expect(Base58Check.decode(bad) == nil)
        }
    }

    @Test func tooShortRejected() {
        // Fewer than 4 decoded bytes cannot carry a checksum.
        #expect(Base58Check.decode("") == nil)
        #expect(Base58Check.decode("z") == nil)   // decodes to a single byte
        #expect(Base58Check.decode("111") == nil) // three zero bytes, no checksum
    }
}
