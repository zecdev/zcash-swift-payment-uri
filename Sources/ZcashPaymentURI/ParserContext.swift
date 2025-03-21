//
//  ParserContext.swift
//  zcash-swift-payment-uri
//
//  Created by pacu on 20/03/2025.
//

import Foundation

/// Network-dependant parsing context
/// This enum groups logic that varies depending on the corresponding
/// network.
///
/// Example: Human-Readable parts of string-encoded addresses vary depending
/// on whether they correspond to mainnet, testnet or regtest environments.
///
/// - Note: when extending this parser use this enum to describe variants of the
/// a behavior that is network-dependent
public enum ParserContext {
    case mainnet
    case testnet
    case regtest
}

extension ParserContext {
    var sproutPrefix: String {
        switch self {
            
        case .mainnet:
            "zc"
        case .testnet, .regtest:
            "zt"
        }
    }
    
    var saplingPrefix: String {
        switch self {
        case .mainnet:
            "zs"
        case .testnet:
            "ztestsapling"
        case .regtest:
            "zregtestsapling"
        }
    }
    
    var unifiedPrefix: String {
        switch self {
            
        case .mainnet:
            "u"
        case .testnet:
            "utest"
        case .regtest:
            "uregtest"
        }
    }
    
    var p2shPrefix: String {
        switch self {
        case .mainnet:
            "t3"
        case .testnet:
            // TODO: Check whether there is a testnet prefix
            "t2"
        case .regtest:
            // TODO: Check whether there is a regtest prefix
            "t3"
        }
    }
    
    var p2pkhPrefix: String {
        switch self {
        case .mainnet:
            "t1"
        case .testnet:
            // TODO: Check whether there is a testnet prefix
            "tm"
        case .regtest:
            // TODO: Check whether there is a regtest prefix
            "tm"
        }
    }
    
    var texPrefix: String {
        switch self {
        case .mainnet:
            "tex"
        case .testnet:
            "textest"
        case .regtest:
            "texregtest"
        }
    }
}

extension ParserContext: AddressValidator {
    public func isValid(address: String) -> Bool {
        // sprout addresses are not allowed on ZIP-320
        guard !self.isSprout(address: address) else { return false }
        
        return self.isTransparent(address: address) ||
        self.isShielded(address: address)
    }
    
    public func isTransparent(address: String) -> Bool {
        address.hasPrefix(self.p2pkhPrefix) ||
        address.hasPrefix(self.p2shPrefix) ||
        address.hasPrefix(self.texPrefix)
    }
    
    public func isSprout(address: String) -> Bool {
        address.hasPrefix(self.sproutPrefix)
    }
    
    public func isShielded(address: String) -> Bool {
        address.hasPrefix(self.saplingPrefix) ||
        address.hasPrefix(self.unifiedPrefix)
    }
}
