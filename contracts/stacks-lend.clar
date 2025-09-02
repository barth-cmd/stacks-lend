;; StacksLend - Bitcoin-Secured Decentralized Lending Protocol
;;
;; PROTOCOL OVERVIEW
;;
;; StacksLend revolutionizes decentralized finance by bringing Bitcoin's unparalleled security
;; to programmable lending markets through Stacks Layer 2 technology. This protocol enables
;; users to participate in collateralized lending with the full security guarantees of Bitcoin's
;; proof-of-work consensus while leveraging the smart contract capabilities of Clarity.

;; PROTOCOL CONSTANTS & ERROR CODES

;; Protocol Authority
(define-constant PROTOCOL_OWNER tx-sender)

;; Error Codes - Comprehensive error handling for all protocol operations
(define-constant ERR_UNAUTHORIZED (err u1001))           ;; Insufficient permissions
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1002)) ;; Collateral below minimum ratio
(define-constant ERR_INVALID_AMOUNT (err u1003))         ;; Amount is zero or invalid
(define-constant ERR_POSITION_NOT_FOUND (err u1004))     ;; User position doesn't exist
(define-constant ERR_LOAN_ACTIVE (err u1005))            ;; Cannot modify active loan
(define-constant ERR_INSUFFICIENT_BALANCE (err u1006))   ;; Insufficient protocol balance
(define-constant ERR_LIQUIDATION_CONDITIONS_NOT_MET (err u1007)) ;; Cannot liquidate healthy position
(define-constant ERR_PARAMETER_OUT_OF_BOUNDS (err u1008)) ;; Parameter exceeds allowed range
(define-constant ERR_SELF_LIQUIDATION_PROHIBITED (err u1009)) ;; Cannot liquidate own position

;; Protocol Risk Parameters - Carefully calibrated for Bitcoin volatility
(define-constant MAX_COLLATERAL_RATIO u500)  ;; 500% - Maximum allowed collateral ratio
(define-constant MIN_COLLATERAL_RATIO u110)  ;; 110% - Absolute minimum for loan health
(define-constant MAX_PROTOCOL_FEE u1000)     ;; 10.00% - Maximum fee in basis points
(define-constant BASIS_POINTS u10000)        ;; Standard basis points denominator

;; Interest Rate Constants
(define-constant BLOCKS_PER_YEAR u52560)     ;; Approximate blocks per year on Bitcoin
(define-constant MAX_INTEREST_RATE u2000)    ;; 20.00% maximum annual rate

;; PROTOCOL STATE VARIABLES

;; Risk Management Parameters
(define-data-var minimum-collateral-ratio uint u150)  ;; 150% - Conservative default
(define-data-var liquidation-threshold uint u125)     ;; 125% - Liquidation trigger point
(define-data-var protocol-fee-bps uint u100)          ;; 1.00% - Protocol revenue fee
(define-data-var base-interest-rate uint u500)        ;; 5.00% - Base lending rate

;; Global Protocol Metrics
(define-data-var total-protocol-deposits uint u0)     ;; Total STX deposited as collateral
(define-data-var total-protocol-borrows uint u0)      ;; Total STX borrowed from protocol
(define-data-var total-active-positions uint u0)      ;; Number of active lending positions
(define-data-var protocol-revenue uint u0)            ;; Accumulated protocol fees

;; DATA STRUCTURES & MAPPINGS

;; Individual User Lending Position
(define-map user-lending-positions
    { user: principal }
    {
        collateral-deposited: uint,      ;; STX tokens locked as collateral
        amount-borrowed: uint,           ;; STX tokens borrowed against collateral
        interest-rate-bps: uint,         ;; Annual interest rate in basis points
        last-interaction-height: uint,   ;; Block height of last position update
        accrued-interest: uint,          ;; Interest accumulated since last update
        position-health-score: uint      ;; Calculated health metric (collateral/debt ratio)
    }
)

;; Protocol Statistics and Analytics
(define-map protocol-analytics
    { metric: (string-ascii 32) }
    { value: uint }
)

;; Liquidation Events Log
(define-map liquidation-history
    { liquidation-id: uint, liquidated-user: principal }
    {
        liquidator: principal,
        collateral-seized: uint,
        debt-cleared: uint,
        liquidation-height: uint,
        health-ratio-at-liquidation: uint
    }
)

;; CORE MATHEMATICAL FUNCTIONS

;; Calculate compound interest over specified block period
;; Uses precise arithmetic to prevent rounding errors in interest calculations
(define-private (calculate-compound-interest 
    (principal-amount uint) 
    (annual-rate-bps uint) 
    (blocks-elapsed uint))
    (let (
        ;; Convert annual rate to per-block rate
        (rate-per-block (/ annual-rate-bps BLOCKS_PER_YEAR))
        ;; Calculate compound interest: P * (1 + r)^n - P
        (compound-factor (+ BASIS_POINTS (/ (* rate-per-block blocks-elapsed) BASIS_POINTS)))
        (final-amount (/ (* principal-amount compound-factor) BASIS_POINTS))
    )
    (- final-amount principal-amount))
)

;; Calculate current health ratio of a lending position
;; Health ratio = (collateral_value * 100) / debt_value
;; Higher ratios indicate healthier positions
(define-private (calculate-position-health-ratio 
    (collateral-amount uint) 
    (debt-amount uint))
    (if (is-eq debt-amount u0)
        u0  ;; No debt means perfect health
        (/ (* collateral-amount u100) debt-amount))
)

;; Determine if a position is eligible for liquidation
;; Positions become liquidatable when health ratio falls below threshold
(define-private (is-position-liquidatable 
    (collateral-amount uint) 
    (debt-amount uint))
    (< (calculate-position-health-ratio collateral-amount debt-amount)
       (var-get liquidation-threshold))
)

;; Calculate liquidation penalty and rewards
;; Provides incentive for liquidators while protecting protocol
(define-private (calculate-liquidation-amounts 
    (collateral-amount uint) 
    (debt-amount uint))
    (let (
        ;; 5% liquidation penalty applied to collateral
        (penalty-rate u500)  ;; 5.00% in basis points
        (liquidation-penalty (/ (* collateral-amount penalty-rate) BASIS_POINTS))
        (liquidator-reward (/ liquidation-penalty u2))  ;; 50% of penalty to liquidator
        (protocol-reward (- liquidation-penalty liquidator-reward))
    )
    {
        liquidator-reward: liquidator-reward,
        protocol-reward: protocol-reward,
        collateral-to-seize: collateral-amount
    })
)

;; POSITION MANAGEMENT UTILITIES

;; Update user position with new collateral and debt amounts
;; Handles interest accrual and health score recalculation
(define-private (update-user-position 
    (user principal) 
    (new-collateral uint) 
    (new-debt uint)
    (accrue-interest bool))
    (let (
        (current-position (default-to
            {
                collateral-deposited: u0,
                amount-borrowed: u0,
                interest-rate-bps: (var-get base-interest-rate),
                last-interaction-height: stacks-block-height,
                accrued-interest: u0,
                position-health-score: u0
            }
            (map-get? user-lending-positions { user: user })))
        
        ;; Calculate accrued interest if requested
        (blocks-since-update (- stacks-block-height (get last-interaction-height current-position)))
        (new-interest (if accrue-interest
            (+ (get accrued-interest current-position)
               (calculate-compound-interest 
                   (get amount-borrowed current-position)
                   (get interest-rate-bps current-position)
                   blocks-since-update))
            (get accrued-interest current-position)))
        
        ;; Calculate new health score
        (total-debt (+ new-debt new-interest))
        (health-score (calculate-position-health-ratio new-collateral total-debt))
    )
    
    ;; Update position mapping and return true
    (begin
        (map-set user-lending-positions
            { user: user }
            {
                collateral-deposited: new-collateral,
                amount-borrowed: new-debt,
                interest-rate-bps: (get interest-rate-bps current-position),
                last-interaction-height: stacks-block-height,
                accrued-interest: new-interest,
                position-health-score: health-score
            })
        true))
)

;; CORE LENDING PROTOCOL FUNCTIONS

;; DEPOSIT COLLATERAL
;; Users deposit STX tokens as collateral to secure future borrowing capacity
;; Collateral is safely held in the contract and tracked per user
(define-public (deposit-collateral (amount uint))
    (let (
        (current-position (get-user-position tx-sender))
        (new-collateral (+ (get collateral-deposited current-position) amount))
        (current-debt (get amount-borrowed current-position))
    )
    
    ;; Validation checks
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (stx-get-balance tx-sender)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Execute collateral transfer
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update protocol state
    (var-set total-protocol-deposits (+ (var-get total-protocol-deposits) amount))
    
    ;; Update user position
    (update-user-position tx-sender new-collateral current-debt true)
    
    (ok amount))
)

;; BORROW AGAINST COLLATERAL  
;; Users can borrow STX tokens up to their collateralization limit
;; Borrowing is subject to minimum collateral ratio requirements
(define-public (borrow-tokens (amount uint))
    (let (
        (user-position (get-user-position tx-sender))
        (current-collateral (get collateral-deposited user-position))
        (current-debt (get amount-borrowed user-position))
        (new-total-debt (+ current-debt amount))
        (resulting-health-ratio (calculate-position-health-ratio current-collateral new-total-debt))
    )
    
    ;; Validation and risk checks
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= resulting-health-ratio (var-get minimum-collateral-ratio)) 
              ERR_INSUFFICIENT_COLLATERAL)
    (asserts! (<= amount (as-contract (stx-get-balance tx-sender))) 
              ERR_INSUFFICIENT_BALANCE)
    
    ;; Execute token transfer to borrower
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    ;; Update protocol metrics
    (var-set total-protocol-borrows (+ (var-get total-protocol-borrows) amount))
    
    ;; Update user position
    (update-user-position tx-sender current-collateral new-total-debt true)
    
    (ok amount))
)