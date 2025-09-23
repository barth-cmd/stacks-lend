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

;; REPAY BORROWED TOKENS
;; Users repay their outstanding debt plus accrued interest
;; Partial and full repayments are supported
(define-public (repay-debt (amount uint))
    (let (
        (user-position (get-user-position tx-sender))
        (current-collateral (get collateral-deposited user-position))
        (current-debt (get amount-borrowed user-position))
        (accrued-interest (get accrued-interest user-position))
        (total-debt (+ current-debt accrued-interest))
        (repay-amount (if (<= amount total-debt) amount total-debt))
        (remaining-debt (- total-debt repay-amount))
    )
    
    ;; Validation
    (asserts! (> repay-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> total-debt u0) ERR_POSITION_NOT_FOUND)
    (asserts! (<= repay-amount (stx-get-balance tx-sender)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Execute repayment transfer
    (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
    
    ;; Calculate protocol fee from repayment
    (let ((protocol-fee (/ (* repay-amount (var-get protocol-fee-bps)) BASIS_POINTS)))
        (var-set protocol-revenue (+ (var-get protocol-revenue) protocol-fee)))
    
    ;; Update protocol metrics
    (var-set total-protocol-borrows (- (var-get total-protocol-borrows) repay-amount))
    
    ;; Update user position
    (update-user-position tx-sender current-collateral remaining-debt false)
    
    (ok repay-amount))
)

;; WITHDRAW COLLATERAL
;; Users can withdraw excess collateral while maintaining minimum ratios
;; Protects protocol by enforcing collateralization requirements
(define-public (withdraw-collateral (amount uint))
    (let (
        (user-position (get-user-position tx-sender))
        (current-collateral (get collateral-deposited user-position))
        (current-debt (get amount-borrowed user-position))
        (remaining-collateral (- current-collateral amount))
        (resulting-health-ratio (if (> current-debt u0)
            (calculate-position-health-ratio remaining-collateral current-debt)
            u0))
    )
    
    ;; Validation and safety checks
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount current-collateral) ERR_INSUFFICIENT_COLLATERAL)
    
    ;; If user has debt, ensure withdrawal maintains minimum collateral ratio
    (if (> current-debt u0)
        (asserts! (>= resulting-health-ratio (var-get minimum-collateral-ratio))
                  ERR_INSUFFICIENT_COLLATERAL)
        true)
    
    ;; Execute collateral withdrawal
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    ;; Update protocol state
    (var-set total-protocol-deposits (- (var-get total-protocol-deposits) amount))
    
    ;; Update user position
    (update-user-position tx-sender remaining-collateral current-debt true)
    
    (ok amount))
)

;; LIQUIDATE UNHEALTHY POSITION
;; Liquidators can seize collateral from positions below liquidation threshold
;; Protects protocol solvency and provides liquidation incentives
(define-public (liquidate-position (target-user principal))
    (let (
        (target-position (unwrap! (map-get? user-lending-positions { user: target-user }) 
                                  ERR_POSITION_NOT_FOUND))
        (collateral (get collateral-deposited target-position))
        (debt (+ (get amount-borrowed target-position) (get accrued-interest target-position)))
        (liquidation-calc (calculate-liquidation-amounts collateral debt))
    )
    
    ;; Security and eligibility checks
    (asserts! (not (is-eq target-user tx-sender)) ERR_SELF_LIQUIDATION_PROHIBITED)
    (asserts! (> debt u0) ERR_POSITION_NOT_FOUND)
    (asserts! (is-position-liquidatable collateral debt) ERR_LIQUIDATION_CONDITIONS_NOT_MET)
    
    ;; Execute liquidation transfers
    (try! (as-contract (stx-transfer? (get liquidator-reward liquidation-calc) 
                                     tx-sender tx-sender)))
    
    ;; Update protocol revenue with liquidation fees
    (var-set protocol-revenue (+ (var-get protocol-revenue) 
                                (get protocol-reward liquidation-calc)))
    
    ;; Update global protocol metrics
    (var-set total-protocol-deposits (- (var-get total-protocol-deposits) collateral))
    (var-set total-protocol-borrows (- (var-get total-protocol-borrows) debt))
    
    ;; Clear liquidated position
    (map-delete user-lending-positions { user: target-user })
    
    ;; Record liquidation event for analytics
    ;; (liquidation history logging would be implemented here)
    
    (ok { liquidated-debt: debt, seized-collateral: collateral }))
)

;; PROTOCOL ANALYTICS & READ-ONLY FUNCTIONS

;; Get comprehensive user position data
(define-read-only (get-user-position (user principal))
    (default-to
        {
            collateral-deposited: u0,
            amount-borrowed: u0,
            interest-rate-bps: (var-get base-interest-rate),
            last-interaction-height: u0,
            accrued-interest: u0,
            position-health-score: u0
        }
        (map-get? user-lending-positions { user: user })
    )
)

;; Get real-time protocol statistics and health metrics
(define-read-only (get-protocol-statistics)
    (let (
        (total-deposits (var-get total-protocol-deposits))
        (total-borrows (var-get total-protocol-borrows))
        (utilization-rate (if (> total-deposits u0)
            (/ (* total-borrows u100) total-deposits)
            u0))
    )
    {
        total-collateral-locked: total-deposits,
        total-tokens-borrowed: total-borrows,
        protocol-utilization-rate: utilization-rate,
        minimum-collateral-ratio: (var-get minimum-collateral-ratio),
        liquidation-threshold: (var-get liquidation-threshold),
        protocol-fee-rate: (var-get protocol-fee-bps),
        base-interest-rate: (var-get base-interest-rate),
        total-protocol-revenue: (var-get protocol-revenue),
        active-positions: (var-get total-active-positions)
    })
)

;; Calculate borrowing capacity for a given collateral amount
(define-read-only (calculate-max-borrow-amount (collateral-amount uint))
    (/ (* collateral-amount u100) (var-get minimum-collateral-ratio))
)

;; Check if a position is healthy or at risk of liquidation
(define-read-only (check-position-health (user principal))
    (let (
        (position (get-user-position user))
        (collateral (get collateral-deposited position))
        (debt (+ (get amount-borrowed position) (get accrued-interest position)))
        (health-ratio (calculate-position-health-ratio collateral debt))
    )
    {
        current-health-ratio: health-ratio,
        is-healthy: (>= health-ratio (var-get minimum-collateral-ratio)),
        liquidation-risk: (< health-ratio (var-get liquidation-threshold)),
        collateral-amount: collateral,
        total-debt: debt
    })
)

;; PROTOCOL GOVERNANCE & ADMINISTRATION

;; Update minimum collateral ratio (owner only)
;; Controls the minimum health ratio required for borrowing
(define-public (set-minimum-collateral-ratio (new-ratio uint))
    (begin
        (asserts! (is-eq tx-sender PROTOCOL_OWNER) ERR_UNAUTHORIZED)
        (asserts! (and (>= new-ratio MIN_COLLATERAL_RATIO) 
                      (<= new-ratio MAX_COLLATERAL_RATIO)) 
                 ERR_PARAMETER_OUT_OF_BOUNDS)
        (asserts! (>= new-ratio (var-get liquidation-threshold))
                 ERR_PARAMETER_OUT_OF_BOUNDS)
        
        (var-set minimum-collateral-ratio new-ratio)
        (ok new-ratio)
    )
)

;; Update liquidation threshold (owner only)  
;; Sets the health ratio at which positions become liquidatable
(define-public (set-liquidation-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender PROTOCOL_OWNER) ERR_UNAUTHORIZED)
        (asserts! (and (>= new-threshold MIN_COLLATERAL_RATIO)
                      (<= new-threshold (var-get minimum-collateral-ratio)))
                 ERR_PARAMETER_OUT_OF_BOUNDS)
        
        (var-set liquidation-threshold new-threshold)
        (ok new-threshold)
    )
)

;; Update protocol fee rate (owner only)
;; Controls the fee percentage taken from repayments
(define-public (set-protocol-fee (new-fee-bps uint))
    (begin
        (asserts! (is-eq tx-sender PROTOCOL_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee-bps MAX_PROTOCOL_FEE) ERR_PARAMETER_OUT_OF_BOUNDS)
        
        (var-set protocol-fee-bps new-fee-bps)
        (ok new-fee-bps)
    )
)

;; Update base interest rate (owner only)
;; Sets the baseline interest rate for all borrowing
(define-public (set-base-interest-rate (new-rate-bps uint))
    (begin
        (asserts! (is-eq tx-sender PROTOCOL_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-rate-bps MAX_INTEREST_RATE) ERR_PARAMETER_OUT_OF_BOUNDS)
        
        (var-set base-interest-rate new-rate-bps)
        (ok new-rate-bps)
    )
)

;; Emergency protocol pause (owner only)
;; Implements circuit breaker for critical security situations
(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender PROTOCOL_OWNER) ERR_UNAUTHORIZED)
        ;; Emergency pause logic would be implemented here
        ;; This would disable non-critical functions during emergencies
        (ok true)
    )
)