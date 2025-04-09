;; Title: BitVault - Bitcoin-Collateralized Stablecoin Protocol (Stacks Layer 2)
;; Summary: Decentralized, non-custodial stablecoin system leveraging Bitcoin as collateral with automated risk management
;; Description:
;; BitVault is a secure DeFi primitive enabling BTC holders to mint USD-pegged stablecoins while maintaining full custody
;; of their assets. Built on Stacks Layer 2 for Bitcoin-native compliance, the protocol features:
;; - Over-collateralization (150% minimum ratio) with dynamic price feeds
;; - Decentralized liquidation mechanism (120% threshold)
;; - Time-decayed oracle protection against stale data
;; - Anti-manipulation safeguards with deposit/price ceilings
;; - Transparent position health monitoring and liquidation history
;;
;; Users can deposit BTC collateral, mint/respay stablecoins, and manage positions through rigorously audited smart contracts
;; with multiple safety checks. Administrative functions maintain protocol integrity through decentralized governance
;; parameters while ensuring compliance with Bitcoin's security model.

;; Error codes for better error handling and debugging
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1001))
(define-constant ERR-BELOW-MINIMUM (err u1002))
(define-constant ERR-INVALID-AMOUNT (err u1003))
(define-constant ERR-POSITION-NOT-FOUND (err u1004))
(define-constant ERR-ALREADY-LIQUIDATED (err u1005))
(define-constant ERR-HEALTHY-POSITION (err u1006))
(define-constant ERR-PRICE-EXPIRED (err u1007))
(define-constant ERR-ZERO-AMOUNT (err u1008))
(define-constant ERR-MAX-AMOUNT-EXCEEDED (err u1009))

;; System Parameters
;; MIN-COLLATERAL-RATIO: Minimum collateralization ratio required to maintain a position (150%)
(define-constant MIN-COLLATERAL-RATIO u150)
;; LIQUIDATION-RATIO: Threshold at which positions become eligible for liquidation (120%)
(define-constant LIQUIDATION-RATIO u120)
;; MIN-DEPOSIT: Minimum amount of satoshis required for a deposit (0.01 BTC)
(define-constant MIN-DEPOSIT u1000000)
;; MAX-DEPOSIT: Maximum deposit limit to prevent excessive concentration (10,000 BTC)
(define-constant MAX-DEPOSIT u1000000000000)
;; PRICE-VALIDITY-PERIOD: Number of blocks before price data is considered stale
(define-constant PRICE-VALIDITY-PERIOD u144)
;; MAX-PRICE: Upper limit for BTC price to prevent manipulation
(define-constant MAX-PRICE u1000000000)

;; State Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var price-oracle principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var btc-price uint u0)
(define-data-var last-price-update uint block-height)

;; Data Maps
;; Stores user positions including collateral amount, debt, and last update block
(define-map user-positions
  principal
  {
    collateral: uint,
    debt: uint,
    last-update: uint
  }
)

;; Records liquidation events for historical tracking and transparency
(define-map liquidation-history
  principal
  {
    timestamp: uint,
    collateral-liquidated: uint,
    debt-repaid: uint
  }
)

;; Read-only functions
(define-read-only (get-position (user principal))
  (map-get? user-positions user)
)

;; Calculates the current collateralization ratio for a user's position
;; Returns the ratio as a percentage (e.g., 150 = 150%)
(define-read-only (get-collateral-ratio (user principal))
  (let (
    (position (unwrap! (get-position user) (err u0)))
    (collateral-value (* (get collateral position) (var-get btc-price)))
    (debt-value (* (get debt position) u100000000))
  )
    (if (is-eq (get debt position) u0)
      (ok u0)
      (ok (/ (* collateral-value u100) debt-value)))
  )
)

(define-read-only (get-current-price)
  (ok (var-get btc-price))
)

;; Private helper functions
;; Ensures price data hasn't expired based on PRICE-VALIDITY-PERIOD
(define-private (check-price-freshness)
  (if (< (- block-height (var-get last-price-update)) PRICE-VALIDITY-PERIOD)
    (ok true)
    ERR-PRICE-EXPIRED
  )
)

;; Validates amount is within acceptable bounds
(define-private (validate-amount (amount uint))
  (begin
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (<= amount MAX-DEPOSIT) ERR-MAX-AMOUNT-EXCEEDED)
    (ok true)
  )
)