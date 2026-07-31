This page is copyright ZecDev.org, 2024. It is posted in order to conform to this standard: https://github.com/RD-Crypto-Spec/Responsible-Disclosure/tree/d47a5a3dafa5942c8849a93441745fdd186731e6

# Security Disclosures

## Disclosure Principles

ZecDev's security disclosure process aims to achieve the following goals:
- protecting ZecDev's users and the wider ecosystem
- respecting the work of security researchers
- improving the ongoing health of the Zcash ecosystem

Specifically, we will:
- assume good faith from researchers and ecosystem partners
- operate a no fault process, focusing on the technical issues
- work with security researchers, regardless of how they choose to disclose issues

## Receiving Disclosures

ZecDev.org is committed to working with researchers who submit security vulnerability notifications to us to resolve those issues on an appropriate timeline and perform a coordinated release, giving credit to the reporter if they would like.

Our best contact for security issues is security@zecdev.org.

## Sending Disclosures

In the case where we become aware of security issues affecting other projects that has never affected ZecDev's projects, our intention is to inform those projects of security issues on a best effort basis.

In the case where we fix a security issue in our projects that also affects the following neighboring projects, our intention is to engage in responsible disclosures with them as described in https://github.com/RD-Crypto-Spec/Responsible-Disclosure, subject to the deviations described in the section at the bottom of this document.

## Scope note: address validation is the integrator's responsibility

As of v2.0.0 this library performs **no recipient-address validation at all**. It implements the
[ZIP-321](https://zips.z.cash/zip-0321) URI grammar; it contains no Bech32/Bech32m or Base58Check
decoding, no SHA-256, no human-readable-part or version-byte tables, and no address prefix
classification.

Integrators MUST supply an `AddressValidator` to `ZIP321.parse(_:expecting:validator:)`. It is
REQUIRED, and it is **authoritative**:

- returning `nil` rejects the address and the request fails with `.invalidAddress`;
- returning an `AddressDescriptor` accepts it, and that descriptor is trusted verbatim. Its
  `canReceiveMemos` decides whether a memo may accompany the recipient; its `isTransparent`
  decides whether a zero-valued output to it is permitted.

Nothing in this library re-checks an address afterwards. There is no built-in check to compose
with, no fallback, and no defense-in-depth layering: a URI parser shipping its own address tables
would be a second, weaker source of truth sitting beside the wallet's real one, and the two could
disagree — silently, and in the direction of accepting an address the wallet would not.

Implement the validator by delegating to your Zcash SDK (librustzcash `ZcashAddress`, via the
mobile SDKs' FFI/JNI bindings). That is the only component that can decode Unified Address
receivers, apply your network's consensus rules, and decide which address kinds your wallet is
willing to pay. Reject Sprout recipients there: ZIP-321 forbids them.

The one rule this library applies on top of the validator's verdict is a comparison, not a
validation: an accepted address whose `AddressDescriptor.network` differs from the `expecting:`
network makes the request invalid.

## Deviations from the Standard

The standard describes reporters of vulnerabilities including full details of an issue, in order to reproduce it. This is necessary for instance in the case of an external researcher both demonstrating and proving that there really is a security issue, and that security issue really has the impact that they say it has - allowing the development team to accurately prioritize and resolve the issue.

For the case our assessment determines so, we might decide not to include those details with our reports to partners ahead of coordinated release, so long as we are sure that they are vulnerable.


Below you can find security@zecdev.org PGP pub key.
```
-----BEGIN PGP PUBLIC KEY BLOCK-----

xjMEZvruLhYJKwYBBAHaRw8BAQdAidX5sDkbrVGcRp3RIhhJoXPdsqBM5slk
8H3mgs+EhFXNKXNlY3VyaXR5QHplY2Rldi5vcmcgPHNlY3VyaXR5QHplY2Rl
di5vcmc+wowEEBYKAD4Fgmb67i4ECwkHCAmQ0hYruZ0SM+QDFQgKBBYAAgEC
GQECmwMCHgEWIQRdDkFAkPdo3dHRpRTSFiu5nRIz5AAAcFsBAIpCq9AGvFdc
M9MYKCkstRMrltnhKsdnVs97oegM8HCsAQDTEB3GZn3kJGG1kCa+Wy0C1zZO
FDTB0P3eBBLOr84oAM44BGb67i4SCisGAQQBl1UBBQEBB0C53DLo7aTs/6fC
j4Hvjr7l7993eKZhb6RPqGeWt4xdLwMBCAfCeAQYFgoAKgWCZvruLgmQ0hYr
uZ0SM+QCmwwWIQRdDkFAkPdo3dHRpRTSFiu5nRIz5AAANOYA+QGte85uZHxI
9o29GbPndaoSUo6+3+YS9m1oqzJjmg4tAQD2RvYflmx7vIQirGvfaCwumN3v
DzIvY8Qt3jfH4WJXBw==
=AQmT
-----END PGP PUBLIC KEY BLOCK-----
```

