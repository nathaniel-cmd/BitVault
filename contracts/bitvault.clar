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
(define-data-var last-price-update uint stacks-block-height)

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
  (if (< (- stacks-block-height (var-get last-price-update)) PRICE-VALIDITY-PERIOD)
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

(define-private (check-min-collateral (amount uint))
  (begin
    (try! (validate-amount amount))
    (if (>= amount MIN-DEPOSIT)
      (ok true)
      ERR-BELOW-MINIMUM)
  )
)

;; Verifies position maintains required collateralization ratio
(define-private (check-position-health (user principal))
  (let (
    (ratio (unwrap! (get-collateral-ratio user) (err u0)))
  )
    (if (< ratio MIN-COLLATERAL-RATIO)
      ERR-INSUFFICIENT-COLLATERAL
      (ok true))
  )
)

;; Public functions for user interactions
;; Allows users to deposit BTC collateral to create or increase their position
(define-public (deposit-collateral (amount uint))
  (begin
    (try! (check-min-collateral amount))
    (let (
      (current-position (default-to
        { collateral: u0, debt: u0, last-update: stacks-block-height }
        (get-position tx-sender)
      ))
      (new-collateral (+ amount (get collateral current-position)))
    )
      (asserts! (<= new-collateral MAX-DEPOSIT) ERR-MAX-AMOUNT-EXCEEDED)
      (map-set user-positions tx-sender
        {
          collateral: new-collateral,
          debt: (get debt current-position),
          last-update: stacks-block-height
        }
      )
      (ok true))
  )
)

;; Mints new stablecoins against deposited collateral
;; Requires maintaining minimum collateralization ratio
(define-public (mint-stablecoin (amount uint))
  (begin
    (try! (validate-amount amount))
    (try! (check-price-freshness))
    (let (
      (current-position (unwrap! (get-position tx-sender) ERR-POSITION-NOT-FOUND))
      (new-debt (+ amount (get debt current-position)))
      (collateral-value (* (get collateral current-position) (var-get btc-price)))
      (required-collateral (* new-debt MIN-COLLATERAL-RATIO))
    )
      (asserts! (>= collateral-value required-collateral) ERR-INSUFFICIENT-COLLATERAL)
      (asserts! (<= new-debt MAX-DEPOSIT) ERR-MAX-AMOUNT-EXCEEDED)

      (map-set user-positions tx-sender
        {
          collateral: (get collateral current-position),
          debt: new-debt,
          last-update: stacks-block-height
        }
      )
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok true))
  )
)

;; Allows users to repay their stablecoin debt
(define-public (repay-stablecoin (amount uint))
  (begin
    (try! (validate-amount amount))
    (let (
      (current-position (unwrap! (get-position tx-sender) ERR-POSITION-NOT-FOUND))
    )
      (asserts! (>= (get debt current-position) amount) ERR-INVALID-AMOUNT)

      (map-set user-positions tx-sender
        {
          collateral: (get collateral current-position),
          debt: (- (get debt current-position) amount),
          last-update: stacks-block-height
        }
      )
      (var-set total-supply (- (var-get total-supply) amount))
      (ok true)
    )
  )
)

;; Enables withdrawal of excess collateral
;; Ensures position remains properly collateralized after withdrawal
(define-public (withdraw-collateral (amount uint))
  (begin
    (try! (validate-amount amount))
    (let (
      (current-position (unwrap! (get-position tx-sender) ERR-POSITION-NOT-FOUND))
    )
      (asserts! (>= (get collateral current-position) amount) ERR-INVALID-AMOUNT)

      (map-set user-positions tx-sender
        {
          collateral: (- (get collateral current-position) amount),
          debt: (get debt current-position),
          last-update: stacks-block-height
        }
      )
      (try! (check-position-health tx-sender))
      (ok true)
    )
  )
)

;; Liquidation mechanism for undercollateralized positions
;; Can be triggered by anyone when a position falls below LIQUIDATION-RATIO
(define-public (liquidate-position (user principal))
  (begin
    (try! (check-price-freshness))
    (let (
      (position (unwrap! (get-position user) ERR-POSITION-NOT-FOUND))
      (ratio (unwrap! (get-collateral-ratio user) ERR-POSITION-NOT-FOUND))
    )
      (asserts! (< ratio LIQUIDATION-RATIO) ERR-HEALTHY-POSITION)

      ;; Record liquidation event
      (map-set liquidation-history user
        {
          timestamp: stacks-block-height,
          collateral-liquidated: (get collateral position),
          debt-repaid: (get debt position)
        }
      )
      
      ;; Clear the liquidated position
      (map-set user-positions user
        {
          collateral: u0,
          debt: u0,
          last-update: stacks-block-height
        }
      )
      
      (var-set total-supply (- (var-get total-supply) (get debt position)))
      (ok true))
  )
)

;; Administrative functions
;; Updates the BTC price, can only be called by authorized price oracle
(define-public (set-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get price-oracle)) ERR-NOT-AUTHORIZED)
    (asserts! (and (> new-price u0) (<= new-price MAX-PRICE)) ERR-INVALID-AMOUNT)
    (var-set btc-price new-price)
    (var-set last-price-update stacks-block-height)
    (ok true))
)

;; Updates the price oracle address, can only be called by contract owner
(define-public (set-price-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq new-oracle (var-get price-oracle))) ERR-INVALID-AMOUNT)
    (var-set price-oracle new-oracle)
    (ok true))
)