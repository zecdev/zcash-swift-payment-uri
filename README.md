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

- Provide an API that lets users build a Payment Request URI from its bare-bone components.
- There's a comprehensive set of tests that exercises the logic above according with what is defined on [ZIP-321](https://zips.z.cash/zip-0321) 
- (Optional) Mechanism for callers to provide logic for validating of Zcash addresses

### 2. ZIP-321 built-in validation
- Built-in mechanism to validate the provided input. This will entail leveraging some sort of FFI calls to [`zcash_address` crate](https://crates.io/crates/zcash_address/0.1.0)

### 3. ZIP-321 parsing
- Given a valid ZIP-321 Payment Request, initializer a swift struct that represents the given URI.
- The result of the point above would have to be equivalent as if the given URI was generated programmatically with the same inputs using the API of `1.` of the roadmap
- The parser API uses `2.` of the roadmap to validate the provided ZIP-321 Request
- The parser checks the integrity of the provided URI as defined on [ZIP-321](https://zips.z.cash/zip-0321)
- There's a comprehensive set of Unit Tests that exercise the point above.


# License 
This project is under MIT License. See [LICENSE.md](LICENSE.md) for more details.
