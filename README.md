[![Swift](https://github.com/pacu/zcash-swift-payment-uri/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/pacu/zcash-swift-payment-uri/actions/workflows/swift.yml)

# zcash-swift-payment-uri
Prototype of Zcash Payment URIs defined on ZIP-321 for Swift

## What are Zcash Payment URIs?

Quote from [ZIP-321](https://zips.z.cash/zip-0321)
> [..] a standard format for payment request URIs. Wallets that recognize this format enable users to construct transactions simply by clicking links on webpages or scanning QR codes.

Payment URIs let users express their payment intents in the form of "_standardized_" URIs that
can be parsed by several applications across the ecosystem 


**Example**
`zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok`

## Project Roadmap

### 1. ZIP-321 construction 

- Provide an API that lets users build a Payment Request URI from its bare-bone components. ✅
- There's a comprehensive set of tests that exercises the logic above according with what is defined on [ZIP-321](https://zips.z.cash/zip-0321) ✅
- (Optional) Mechanism for callers to provide logic for validating of Zcash addresses ✅

### 2. ZIP-321 parsing
- Given a valid ZIP-321 Payment Request, initializer a swift struct that represents the given URI.
- The result of the point above would have to be equivalent as if the given URI was generated programmatically with the same inputs using the API of `1.` of the roadmap
- The parser API uses `2.` of the roadmap to validate the provided ZIP-321 Request
- The parser checks the integrity of the provided URI as defined on [ZIP-321](https://zips.z.cash/zip-0321)
- There's a comprehensive set of Unit Tests that exercise the point above.

### 3. ZIP-321 built-in validation
- Built-in mechanism to validate the provided input. This will entail leveraging some sort of FFI calls to [`zcash_address` crate](https://crates.io/crates/zcash_address/0.1.0)

## Getting Started

### Requesting a payment to a Zcash address
Payments requests that do not specify any other information than recipient address.

`zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez`

````Swift
let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet)!

ZIP321.request(recipient)
````

### Requesting a payment specifying amount and other parameters.
Desired Payment URI
`zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase`

````Swift
 let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet)!

let payment = Payment(
    recipientAddress: recipient,
    amount: try Amount(value: 1),
    memo: try MemoBytes(utf8String: "This is a simple memo."),
    label: nil,
    message: "Thank you for your purchase",
    otherParams: nil
)

let paymentURI = ZIP321.request(payment, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
````

### Requesting Payments to multiple recipients
Desired Payment URI:
`zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok`

This payment Request is using `paramlabel`s with empty `paramindex` and number indices. This Request String generation API allows callers to specify their format of choice for parameters and indices. 

````Swift


let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

let recipient0 = RecipientAddress(value: address0, context: .testnet)!

let payment0 = Payment(
    recipientAddress: recipient0,
    amount: try Amount(value: 123.456),
    memo: nil,
    label: nil,
    message: nil,
    otherParams: nil
)

let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

let recipient1 = RecipientAddress(value: address1, context: .testnet)!

let payment1 = Payment(
    recipientAddress: recipient1,
    amount: try Amount(value: 0.789),
    memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
    label: nil,
    message: nil,
    otherParams: nil
)

let paymentRequest = PaymentRequest(payments: [payment0, payment1])

let paymentURIString = ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false))
````

### Parsing a Zcash payment URI

**Usage**:

Given a possible Zcash Payment URI

````Swift
let possibleURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

let paymentRequest = try ZIP321.request(from: possibleURI, context: .testnet)
````

This will return either an error with information about the parsing failure, or in this case
````Swift
ParserResult.request(
    PaymentRequest(payments: [
        Payment(
            recipientAddress: recipient,
            amount: try Amount(value: 1),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: nil
        )
    ]
    )
)
````

#### Support for legacy Zcash payment URI `zcash:[address]`

The parser supports legacy URI of transparent ZEC wallets that resemble to 
Bitcoin URIs.

````Swift
let uri = ZIP321.request("zcash:tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU", context: .testnet)
````

returns a 
````Swift
ParserResult.legacy(recipient)
````

where the recipient address contains the address.
# License 
This project is under MIT License. See [LICENSE.md](LICENSE.md) for more details.
