//
//  PropertyGenerators.swift
//  zcash-swift-payment-uri
//
//  Deterministic generators for the property-style round-trip tests in
//  `PropertyTests.swift`. Mirrors (in spirit) the proptest strategies in
//  librustzcash `components/zip321/src/lib.rs` `pub mod testing`
//  (`arb_valid_memo`, `arb_zip321_payment`, `arb_zip321_request`), but built on
//  a tiny inline seeded PRNG so every run is byte-for-byte deterministic
//  across platforms — no `Date`/system-random seeding anywhere.
//

@testable import ZcashPaymentURI

/// A minimal SplitMix64 PRNG. Deterministic, fast, and portable: the same
/// seed always produces the same stream on every platform.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension SplitMix64 {
    /// A uniform value in the closed range `range` (slight modulo bias is
    /// immaterial for property-test generation).
    mutating func nextUInt64(in range: ClosedRange<UInt64>) -> UInt64 {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + (next() % (span + 1))
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        Int(nextUInt64(in: UInt64(range.lowerBound)...UInt64(range.upperBound)))
    }

    /// Returns `true` with roughly the given probability (`0...1`).
    mutating func nextBool(probability: Double = 0.5) -> Bool {
        let scaled = UInt64((probability.clamped01()) * 1_000_000)
        return nextUInt64(in: 0...999_999) < scaled
    }

    /// Picks a uniformly random element of a non-empty array.
    mutating func choice<T>(_ array: [T]) -> T {
        array[nextInt(in: 0...(array.count - 1))]
    }
}

private extension Double {
    func clamped01() -> Double { Swift.min(Swift.max(self, 0), 1) }
}

/// The fixed pool of KNOWN-VALID (checksum-verified) addresses per network,
/// one of each recipient kind ZIP-321 allows: transparent P2PKH, transparent
/// P2SH, Sapling, Unified, TEX. Lifted verbatim from the literals already
/// exercised by `AddressValidationTests.validMatrix` (see that file's header
/// for provenance of each address). They are fed through the same test-only
/// `ReferenceAddressValidator` the rest of the suite injects, so generated
/// recipients carry REAL descriptors rather than hand-written ones.
enum AddressPool {
    static let mainnet: [String] = [
        "t1Hsc1LR8yKnbbe3twRp88p6vFfC5t7DLbs",
        "t3JZcvsuaXE6ygokL4XUiZSTrQBUoPYFnXJ",
        "zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya",
        "u1l8xunezsvhq8fgzfl7404m450nwnd76zshscn6nfys7vyz2ywyh4cc5daaq0c7q2su5lqfh23sp7fkf3kt27ve5948mzpfdvckzaect2jtte308mkwlycj2u0eac077wu70vqcetkxf",
        "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"
    ]

    static let testnet: [String] = [
        "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
        "t26YoyZ1iPgiMEWL4zGUm74eVWfhyDMXzY2",
        "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
        "utest10c5kutapazdnf8ztl3pu43nkfsjx89fy3uuff8tsmxm6s86j37pe7uz94z5jhkl49pqe8yz75rlsaygexk6jpaxwx0esjr8wm5ut7d5s",
        "textest1qyqszqgpqyqszqgpqyqszqgpqyqszqgpfcjgfy"
    ]

    /// Transparent kinds reuse the testnet version bytes on regtest.
    static let regtest: [String] = [
        "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
        "t26YoyZ1iPgiMEWL4zGUm74eVWfhyDMXzY2",
        "zregtestsapling1qqqqqqqqqqqqqqqqqqcguyvaw2vjk4sdyeg0lc970u659lvhqq7t0np6hlup5lusxle7505hlz3",
        "uregtest15xk7vj4grjkay6mnfl93dhsflc2yeunhxwdh38rul0rq3dfhzzxgm5szjuvtqdha4t4p2q02ks0jgzrhjkrav70z9xlvq0plpcjkd5z3",
        "texregtest1s2rt77ggv6q989lr49rkgzmh5slsksa990zqpk"
    ]

    static func addresses(for network: Network) -> [String] {
        switch network {
        case .mainnet: return mainnet
        case .testnet: return testnet
        case .regtest: return regtest
        }
    }
}

enum Gen {
    static let allNetworks: [Network] = [.mainnet, .testnet, .regtest]

    /// Reserved ZIP-321 query keys that `otherParam` names must never collide
    /// with (matches `Payment.OtherParam.isReservedKey`).
    private static let reservedParamNames: Set<String> = ["address", "amount", "label", "memo", "message"]

    /// A pool of characters/graphemes chosen to exercise every corner of the
    /// `qchar` grammar: plain `unreserved` bytes, every `allowed-delims`
    /// character, bytes that MUST be percent-encoded (space, `%`, `&`, `/`,
    /// control-adjacent punctuation, …), and non-ASCII text (accented Latin,
    /// CJK, emoji — including a multi-scalar ZWJ/skin-tone cluster and a
    /// combining mark) to stress multi-byte UTF-8 percent-encoding.
    private static let unicodePool: [String] = [
        "a", "Z", "5", "-", ".", "_", "~",
        "!", "$", "'", "(", ")", "*", "+", ",", ";",
        ":", "@",
        " ", "\"", "#", "%", "&", "/", "<", "=", ">", "?", "[", "\\", "]", "^", "`", "{", "|", "}",
        "é", "ñ", "中", "星", "🎉", "😀", "👍🏽", "𐍈", "\u{0301}"
    ]

    /// Arbitrary valid memo bytes: 0..512 raw bytes (matches the reference
    /// `arb_valid_memo`).
    static func memoBytes(_ rng: inout SplitMix64) -> MemoBytes {
        let length = rng.nextInt(in: 0...512)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(length)
        for _ in 0..<length {
            bytes.append(UInt8(rng.nextUInt64(in: 0...255)))
        }
        // Never fails: `length <= 512` by construction.
        return try! MemoBytes(bytes: bytes)
    }

    /// Arbitrary `NonNegativeAmount` in `0...maxMoney`, biased to also hit the exact
    /// boundary values (0, 1, `maxMoney`, `maxMoney - 1`) that a purely
    /// uniform draw would rarely land on.
    static func zatoshi(_ rng: inout SplitMix64) -> NonNegativeAmount {
        let value: UInt64
        switch rng.nextInt(in: 0...9) {
        case 0: value = 0
        case 1: value = NonNegativeAmount.maxMoney
        case 2: value = 1
        case 3: value = NonNegativeAmount.maxMoney - 1
        default: value = UInt64(rng.nextUInt64(in: 0...UInt64(NonNegativeAmount.maxMoney)))
        }
        // Never fails: `value` is always in `0...maxMoney` by construction.
        return try! NonNegativeAmount.zatoshi(value).get()
    }

    /// An arbitrary label/message/otherParam-value string: unicode text
    /// (including emoji and characters that require percent-encoding),
    /// possibly empty.
    static func unicodeString(_ rng: inout SplitMix64) -> String {
        let length = rng.nextInt(in: 0...12)
        var result = ""
        for _ in 0..<length {
            result += rng.choice(unicodePool)
        }
        return result
    }

    /// An arbitrary valid `paramname` (`ALPHA *(ALPHA / DIGIT / "+" / "-")`)
    /// that does not collide with a reserved ZIP-321 query key and does not
    /// carry the `req-` prefix.
    static func paramName(_ rng: inout SplitMix64) -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let nameChars = letters + Array("0123456789") + ["+", "-"]

        while true {
            let length = rng.nextInt(in: 1...8)
            var chars: [Character] = [rng.choice(letters)]
            for _ in 1..<length {
                chars.append(rng.choice(nameChars))
            }
            let name = String(chars)
            if name.hasPrefix("req-") || reservedParamNames.contains(name) {
                continue
            }
            return name
        }
    }

    /// An arbitrary valid `Payment` to one of `AddressPool`'s known-valid
    /// recipients on `network`.
    ///
    /// The recipient's ``AddressDescriptor`` comes from the test-only
    /// `ReferenceAddressValidator` — the same authority the parser is given —
    /// so the payment's memo/zero-amount legality is decided by exactly the
    /// descriptor the round trip will later reproduce.
    ///
    /// - Note: the `amount` is OPTIONAL here. The reference
    /// `arb_zip321_payment` attaches one unconditionally, and so did this
    /// generator, to sidestep the single-payment/empty-query "bare address"
    /// collapse: a lone payment with no parameters renders `zcash:<addr>`,
    /// which used to parse back as `.singleAddress(_:)` rather than
    /// `.request(_:)`, making the round-trip law ambiguous. With
    /// `ParsedRequest` gone, both spellings parse to the SAME
    /// `PaymentRequest`, so the amount-less shape is now generated — and the
    /// law is asserted over it.
    static func payment(_ rng: inout SplitMix64, network: Network) -> Payment {
        let recipient = recipient(&rng, network: network)

        var amount: NonNegativeAmount? = rng.nextBool(probability: 0.85) ? zatoshi(&rng) : nil
        if recipient.isTransparent, amount?.value == 0 {
            // Zero-valued transparent outputs are disallowed by consensus.
            amount = try! NonNegativeAmount.zatoshi(1).get()
        }

        let memo: MemoBytes? = (recipient.canReceiveMemos && rng.nextBool(probability: 0.5))
            ? memoBytes(&rng)
            : nil

        let label: String? = rng.nextBool(probability: 0.4) ? unicodeString(&rng) : nil
        let message: String? = rng.nextBool(probability: 0.4) ? unicodeString(&rng) : nil

        var otherParams: [OtherParam] = []
        var usedNames: Set<String> = []
        let otherCount = rng.nextInt(in: 0...3)
        for _ in 0..<otherCount {
            var name = paramName(&rng)
            while usedNames.contains(name) {
                name = paramName(&rng)
            }
            usedNames.insert(name)
            let value: String? = rng.nextBool(probability: 0.5) ? unicodeString(&rng) : nil
            // Never fails: `name` is always a valid, non-reserved paramname.
            otherParams.append(try! OtherParam(name: name, value: value))
        }

        switch Payment.create(
            recipientAddress: recipient,
            amount: amount,
            memo: memo,
            label: label,
            message: message,
            otherParams: otherParams
        ) {
        case .success(let payment):
            return payment
        case .failure(let error):
            fatalError("Gen.payment produced a structurally invalid Payment: \(error)")
        }
    }

    /// An arbitrary `PaymentRequest` of 0...20 payments at sparse, unique
    /// `paramindex` values in `0...9999` (mirroring the reference
    /// `arb_zip321_request`'s `btree_map(0usize..10000, …, 1..10)`, extended
    /// down to 0 payments to also exercise the empty request).
    static func indexedPaymentRequest(_ rng: inout SplitMix64, network: Network) -> PaymentRequest {
        let count = rng.nextInt(in: 0...20)
        var usedIndices: Set<UInt> = []
        var indexed: [(index: UInt, payment: Payment)] = []

        for _ in 0..<count {
            var index: UInt
            repeat {
                index = UInt(rng.nextInt(in: 0...9999))
            } while usedIndices.contains(index)
            usedIndices.insert(index)
            indexed.append((index: index, payment: payment(&rng, network: network)))
        }

        // Never fails: indices are unique by construction and `<= 9999`.
        return try! PaymentRequest(indexedPayments: indexed)
    }

    /// A DELIBERATELY INVALID other-param list: `count` distinct names with one
    /// of them repeated. Constructing a `Payment` from this must fail.
    static func duplicatedOtherParams(_ rng: inout SplitMix64) -> (params: [OtherParam], repeated: String) {
        var names: [String] = []
        var used: Set<String> = []
        let count = rng.nextInt(in: 1...4)

        for _ in 0..<count {
            var name = paramName(&rng)
            while used.contains(name) {
                name = paramName(&rng)
            }
            used.insert(name)
            names.append(name)
        }

        // Re-insert one of the names at an arbitrary position after its first
        // occurrence, so the duplicate is not always adjacent or trailing.
        let repeatedIndex = rng.nextInt(in: 0...(names.count - 1))
        let repeated = names[repeatedIndex]
        let insertAt = rng.nextInt(in: (repeatedIndex + 1)...names.count)
        names.insert(repeated, at: insertAt)

        let params = names.map { name in
            let value: String? = rng.nextBool(probability: 0.5) ? unicodeString(&rng) : nil
            // Never fails: `name` is always a valid, non-reserved paramname.
            return try! OtherParam(name: name, value: value)
        }

        return (params, repeated)
    }

    /// An arbitrary known-valid recipient on `network`, resolved through the
    /// reference validator.
    static func recipient(_ rng: inout SplitMix64, network: Network) -> RecipientAddress {
        let addressString = rng.choice(AddressPool.addresses(for: network))
        // Never fails: the pool holds only checksum-valid addresses.
        return RecipientAddress(value: addressString, validator: ReferenceAddressValidator.of(network))!
    }
}
