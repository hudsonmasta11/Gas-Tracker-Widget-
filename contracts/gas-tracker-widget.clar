(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_NO_RECOMMENDATIONS (err u105))
(define-constant ERR_BUDGET_EXCEEDED (err u106))
(define-constant ERR_INVALID_PERIOD (err u107))
(define-constant ERR_INSUFFICIENT_CREDITS (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))
(define-constant ERR_INVALID_RATE (err u110))

(define-data-var total-transactions uint u0)
(define-data-var total-gas-consumed uint u0)
(define-data-var contract-enabled bool true)
(define-data-var credit-exchange-rate uint u100)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-redeemed uint u0)

(define-map user-stats principal {
    transactions: uint,
    gas-consumed: uint,
    avg-gas-per-tx: uint,
    last-interaction: uint,
    efficiency-score: uint
})

(define-map transaction-history uint {
    sender: principal,
    function-name: (string-ascii 50),
    gas-estimate: uint,
    actual-cost: uint,
    timestamp: uint,
    block-height: uint
})

(define-map gas-price-history uint {
    base-fee: uint,
    priority-fee: uint,
    timestamp: uint,
    network-congestion: uint
})

(define-map daily-stats uint {
    date: uint,
    total-txs: uint,
    total-gas: uint,
    avg-gas-price: uint,
    peak-congestion: uint
})

(define-map function-gas-costs (string-ascii 50) {
    min-cost: uint,
    max-cost: uint,
    avg-cost: uint,
    call-count: uint,
    total-cost: uint
})

(define-map optimization-recommendations principal {
    best-hour: uint,
    potential-savings: uint,
    confidence: uint,
    last-updated: uint,
    recommendation-count: uint
})

(define-map hourly-gas-patterns uint {
    hour: uint,
    avg-cost: uint,
    tx-count: uint,
    congestion-level: uint,
    day-of-week: uint
})

(define-map user-budgets principal {
    daily-limit: uint,
    monthly-limit: uint,
    alert-threshold: uint,
    auto-restrict: bool,
    created-at: uint
})

(define-map budget-tracking {user: principal, period: uint} {
    period-start: uint,
    period-end: uint,
    total-spent: uint,
    transaction-count: uint,
    budget-exceeded: bool,
    last-alert-sent: uint
})

(define-map budget-performance principal {
    periods-tracked: uint,
    periods-under-budget: uint,
    total-saved: uint,
    avg-utilization: uint,
    best-period: uint
})

(define-map gas-credits principal {
    balance: uint,
    total-purchased: uint,
    total-redeemed: uint,
    last-purchase: uint,
    last-redemption: uint
})

(define-map credit-transactions uint {
    user: principal,
    transaction-type: (string-ascii 20),
    amount: uint,
    rate: uint,
    timestamp: uint,
    block-height: uint
})

(define-map credit-transfers uint {
    from: principal,
    to: principal,
    amount: uint,
    timestamp: uint,
    status: (string-ascii 20)
})

(define-public (track-transaction (function-name (string-ascii 50)) (gas-estimate uint) (actual-cost uint))
    (let ((tx-id (var-get total-transactions))
          (current-block stacks-block-height)
          (current-time burn-block-height))
        (begin
            (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
            (asserts! (> actual-cost u0) ERR_INVALID_AMOUNT)
            
            (map-set transaction-history tx-id {
                sender: tx-sender,
                function-name: function-name,
                gas-estimate: gas-estimate,
                actual-cost: actual-cost,
                timestamp: current-time,
                block-height: current-block
            })
            
            (update-user-stats tx-sender actual-cost)
            (update-function-stats function-name actual-cost)
            (update-daily-stats current-time actual-cost)
            (update-hourly-patterns current-time actual-cost)
            (try! (update-budget-tracking tx-sender actual-cost current-time))
            
            (var-set total-transactions (+ tx-id u1))
            (var-set total-gas-consumed (+ (var-get total-gas-consumed) actual-cost))
            
            (ok tx-id)
        )
    )
)

(define-public (update-gas-price (base-fee uint) (priority-fee uint) (congestion uint))
    (let ((price-id (var-get total-transactions)))
        (begin
            (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
            (asserts! (> base-fee u0) ERR_INVALID_AMOUNT)
            
            (map-set gas-price-history price-id {
                base-fee: base-fee,
                priority-fee: priority-fee,
                timestamp: burn-block-height,
                network-congestion: congestion
            })
            
            (ok price-id)
        )
    )
)

(define-public (set-efficiency-goal (target-gas uint))
    (let ((user-data (default-to 
                       {transactions: u0, gas-consumed: u0, avg-gas-per-tx: u0, 
                        last-interaction: u0, efficiency-score: u0} 
                       (map-get? user-stats tx-sender))))
        (begin
            (asserts! (> target-gas u0) ERR_INVALID_AMOUNT)
            
            (map-set user-stats tx-sender 
                (merge user-data {efficiency-score: target-gas}))
            
            (ok true)
        )
    )
)

(define-public (toggle-contract (enabled bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-enabled enabled)
        (ok enabled)
    )
)

(define-private (update-user-stats (user principal) (gas-cost uint))
    (let ((current-stats (default-to 
                           {transactions: u0, gas-consumed: u0, avg-gas-per-tx: u0, 
                            last-interaction: u0, efficiency-score: u0} 
                           (map-get? user-stats user))))
        (let ((new-tx-count (+ (get transactions current-stats) u1))
              (new-gas-total (+ (get gas-consumed current-stats) gas-cost)))
            (map-set user-stats user {
                transactions: new-tx-count,
                gas-consumed: new-gas-total,
                avg-gas-per-tx: (/ new-gas-total new-tx-count),
                last-interaction: burn-block-height,
                efficiency-score: (get efficiency-score current-stats)
            })
        )
    )
)

(define-private (update-function-stats (func-name (string-ascii 50)) (cost uint))
    (let ((current-stats (default-to 
                           {min-cost: cost, max-cost: cost, avg-cost: cost, 
                            call-count: u0, total-cost: u0} 
                           (map-get? function-gas-costs func-name))))
        (let ((new-call-count (+ (get call-count current-stats) u1))
              (new-total-cost (+ (get total-cost current-stats) cost)))
            (map-set function-gas-costs func-name {
                min-cost: (if (< cost (get min-cost current-stats)) cost (get min-cost current-stats)),
                max-cost: (if (> cost (get max-cost current-stats)) cost (get max-cost current-stats)),
                avg-cost: (/ new-total-cost new-call-count),
                call-count: new-call-count,
                total-cost: new-total-cost
            })
        )
    )
)

(define-private (update-daily-stats (timestamp uint) (gas-cost uint))
    (let ((day-key (/ timestamp u144)))
        (let ((current-daily (default-to 
                               {date: day-key, total-txs: u0, total-gas: u0, 
                                avg-gas-price: u0, peak-congestion: u0} 
                               (map-get? daily-stats day-key))))
            (let ((new-tx-count (+ (get total-txs current-daily) u1))
                  (new-gas-total (+ (get total-gas current-daily) gas-cost)))
                (map-set daily-stats day-key {
                    date: day-key,
                    total-txs: new-tx-count,
                    total-gas: new-gas-total,
                    avg-gas-price: (/ new-gas-total new-tx-count),
                    peak-congestion: (get peak-congestion current-daily)
                })
            )
        )
    )
)

(define-read-only (get-user-stats (user principal))
    (map-get? user-stats user)
)

(define-read-only (get-transaction (tx-id uint))
    (map-get? transaction-history tx-id)
)

(define-read-only (get-gas-price (price-id uint))
    (map-get? gas-price-history price-id)
)

(define-read-only (get-daily-stats (day uint))
    (map-get? daily-stats day)
)

(define-read-only (get-function-stats (func-name (string-ascii 50)))
    (map-get? function-gas-costs func-name)
)

(define-read-only (get-contract-stats)
    {
        total-transactions: (var-get total-transactions),
        total-gas-consumed: (var-get total-gas-consumed),
        avg-gas-per-tx: (if (> (var-get total-transactions) u0) 
                          (/ (var-get total-gas-consumed) (var-get total-transactions)) 
                          u0),
        contract-enabled: (var-get contract-enabled)
    }
)

(define-read-only (calculate-efficiency-score (user principal))
    (match (map-get? user-stats user)
        user-data 
            (let ((avg-gas (get avg-gas-per-tx user-data))
                  (target-gas (get efficiency-score user-data)))
                (if (and (> target-gas u0) (> avg-gas u0))
                    (some (/ (* u100 target-gas) avg-gas))
                    none))
        none
    )
)

(define-read-only (get-gas-trend (days uint))
    (let ((current-day (/ burn-block-height u144)))
        (map get-daily-gas-average 
             (list (- current-day days) (- current-day (- days u1)) 
                   (- current-day (- days u2)) (- current-day (- days u3))))
    )
)

(define-private (get-daily-gas-average (day uint))
    (match (map-get? daily-stats day)
        stats (get avg-gas-price stats)
        u0
    )
)

(define-read-only (predict-gas-cost (function-name (string-ascii 50)))
    (match (map-get? function-gas-costs function-name)
        stats 
            {
                predicted-cost: (get avg-cost stats),
                confidence: (if (> (get call-count stats) u10) u95 
                           (if (> (get call-count stats) u5) u80 u60)),
                min-expected: (get min-cost stats),
                max-expected: (get max-cost stats)
            }
        {predicted-cost: u0, confidence: u0, min-expected: u0, max-expected: u0}
    )
)

(define-read-only (get-network-congestion-level)
    (let ((recent-price-id (- (var-get total-transactions) u1)))
        (match (map-get? gas-price-history recent-price-id)
            price-data (get network-congestion price-data)
            u0
        )
    )
)

(define-read-only (compare-user-efficiency (user principal))
    (let ((global-avg (if (> (var-get total-transactions) u0) 
                        (/ (var-get total-gas-consumed) (var-get total-transactions)) 
                        u0)))
        (match (map-get? user-stats user)
            user-data 
                {
                    user-avg: (get avg-gas-per-tx user-data),
                    global-avg: global-avg,
                    percentile: (if (> global-avg u0) 
                                  (/ (* u100 global-avg) (get avg-gas-per-tx user-data)) 
                                  u50)
                }
            {user-avg: u0, global-avg: global-avg, percentile: u0}
        )
    )
)

(define-private (update-hourly-patterns (timestamp uint) (gas-cost uint))
    (let ((hour-key (mod (/ timestamp u6) u24))
          (day-key (mod (/ timestamp u144) u7)))
        (let ((current-hourly (default-to 
                                {hour: hour-key, avg-cost: gas-cost, tx-count: u0, 
                                 congestion-level: u0, day-of-week: day-key} 
                                (map-get? hourly-gas-patterns hour-key))))
            (let ((new-tx-count (+ (get tx-count current-hourly) u1))
                  (total-cost (+ (* (get avg-cost current-hourly) (get tx-count current-hourly)) gas-cost)))
                (map-set hourly-gas-patterns hour-key {
                    hour: hour-key,
                    avg-cost: (/ total-cost new-tx-count),
                    tx-count: new-tx-count,
                    congestion-level: (calculate-congestion-for-hour hour-key),
                    day-of-week: day-key
                })
            )
        )
    )
)

(define-private (calculate-congestion-for-hour (hour uint))
    (let ((recent-price-id (var-get total-transactions)))
        (if (> recent-price-id u0)
            (match (map-get? gas-price-history (- recent-price-id u1))
                price-data (get network-congestion price-data)
                u50)
            u50)
    )
)

(define-public (generate-optimization-recommendation (user principal))
    (let ((user-data (map-get? user-stats user)))
        (match user-data
            stats
                (let ((best-hour (find-optimal-hour))
                      (current-avg (get avg-gas-per-tx stats))
                      (optimal-cost (get-hour-avg-cost best-hour)))
                    (let ((savings (if (> current-avg optimal-cost) 
                                     (- current-avg optimal-cost) 
                                     u0))
                          (confidence (calculate-recommendation-confidence best-hour)))
                        (begin
                            (map-set optimization-recommendations user {
                                best-hour: best-hour,
                                potential-savings: savings,
                                confidence: confidence,
                                last-updated: burn-block-height,
                                recommendation-count: (+ (get-user-recommendation-count user) u1)
                            })
                            (ok {
                                best-hour: best-hour,
                                potential-savings: savings,
                                confidence: confidence
                            })
                        )
                    )
                )
            ERR_NOT_FOUND
        )
    )
)

(define-private (find-optimal-hour)
    (let ((hours (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23)))
        (fold find-cheapest-hour hours u0)
    )
)

(define-private (find-cheapest-hour (hour uint) (current-best uint))
    (let ((hour-cost (get-hour-avg-cost hour))
          (best-cost (get-hour-avg-cost current-best)))
        (if (< hour-cost best-cost) hour current-best)
    )
)

(define-private (get-hour-avg-cost (hour uint))
    (match (map-get? hourly-gas-patterns hour)
        pattern (get avg-cost pattern)
        u999999
    )
)

(define-private (calculate-recommendation-confidence (hour uint))
    (match (map-get? hourly-gas-patterns hour)
        pattern 
            (let ((tx-count (get tx-count pattern)))
                (if (> tx-count u20) u95
                (if (> tx-count u10) u80
                (if (> tx-count u5) u65 u40))))
        u0
    )
)

(define-private (get-user-recommendation-count (user principal))
    (match (map-get? optimization-recommendations user)
        rec (get recommendation-count rec)
        u0
    )
)

(define-read-only (get-optimization-recommendation (user principal))
    (map-get? optimization-recommendations user)
)

(define-read-only (get-hourly-pattern (hour uint))
    (map-get? hourly-gas-patterns hour)
)

(define-read-only (get-best-hours-ranking)
    (let ((all-hours (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23)))
        (map get-hour-ranking all-hours)
    )
)

(define-private (get-hour-ranking (hour uint))
    {
        hour: hour,
        avg-cost: (get-hour-avg-cost hour),
        tx-count: (get-hour-tx-count hour),
        congestion: (get-hour-congestion hour)
    }
)

(define-private (get-hour-tx-count (hour uint))
    (match (map-get? hourly-gas-patterns hour)
        pattern (get tx-count pattern)
        u0
    )
)

(define-private (get-hour-congestion (hour uint))
    (match (map-get? hourly-gas-patterns hour)
        pattern (get congestion-level pattern)
        u0
    )
)

(define-read-only (calculate-potential-monthly-savings (user principal))
    (match (map-get? user-stats user)
        stats
            (match (map-get? optimization-recommendations user)
                rec
                    (let ((monthly-txs (* (get transactions stats) u30))
                          (savings-per-tx (get potential-savings rec)))
                        (* monthly-txs savings-per-tx))
                u0)
        u0
    )
)

(define-public (set-gas-budget (daily-limit uint) (monthly-limit uint) (alert-threshold uint) (auto-restrict bool))
    (begin
        (asserts! (> daily-limit u0) ERR_INVALID_AMOUNT)
        (asserts! (> monthly-limit u0) ERR_INVALID_AMOUNT)
        (asserts! (<= alert-threshold u100) ERR_INVALID_AMOUNT)
        
        (map-set user-budgets tx-sender {
            daily-limit: daily-limit,
            monthly-limit: monthly-limit,
            alert-threshold: alert-threshold,
            auto-restrict: auto-restrict,
            created-at: burn-block-height
        })
        
        (ok true)
    )
)

(define-private (update-budget-tracking (user principal) (cost uint) (timestamp uint))
    (let ((daily-period (/ timestamp u144))
          (monthly-period (/ timestamp u4320)))
        (begin
            (try! (update-period-budget user cost daily-period u1))
            (try! (update-period-budget user cost monthly-period u30))
            (ok true)
        )
    )
)

(define-private (update-period-budget (user principal) (cost uint) (period uint) (period-type uint))
    (let ((budget-key {user: user, period: period})
          (user-budget (map-get? user-budgets user)))
        (match user-budget
            budget-info
                (let ((limit (if (is-eq period-type u1) 
                               (get daily-limit budget-info) 
                               (get monthly-limit budget-info)))
                      (current-tracking (default-to 
                                          {period-start: period, period-end: (+ period period-type),
                                           total-spent: u0, transaction-count: u0, 
                                           budget-exceeded: false, last-alert-sent: u0}
                                          (map-get? budget-tracking budget-key))))
                    (let ((new-total (+ (get total-spent current-tracking) cost))
                          (new-tx-count (+ (get transaction-count current-tracking) u1))
                          (exceeds-budget (> new-total limit))
                          (threshold-reached (> (* new-total u100) (* limit (get alert-threshold budget-info)))))
                        (begin
                            (map-set budget-tracking budget-key {
                                period-start: (get period-start current-tracking),
                                period-end: (get period-end current-tracking),
                                total-spent: new-total,
                                transaction-count: new-tx-count,
                                budget-exceeded: exceeds-budget,
                                last-alert-sent: (if threshold-reached burn-block-height (get last-alert-sent current-tracking))
                            })
                            
                            (if (and (get auto-restrict budget-info) exceeds-budget)
                                ERR_BUDGET_EXCEEDED
                                (ok true))
                        )
                    )
                )
            (ok true)
        )
    )
)

(define-public (check-budget-status (user principal))
    (let ((daily-period (/ burn-block-height u144))
          (monthly-period (/ burn-block-height u4320)))
        (match (map-get? user-budgets user)
            budget
                (let ((daily-tracking (map-get? budget-tracking {user: user, period: daily-period}))
                      (monthly-tracking (map-get? budget-tracking {user: user, period: monthly-period})))
                    (ok {
                        daily-budget: (get daily-limit budget),
                        monthly-budget: (get monthly-limit budget),
                        daily-spent: (match daily-tracking t (get total-spent t) u0),
                        monthly-spent: (match monthly-tracking t (get total-spent t) u0),
                        daily-remaining: (- (get daily-limit budget) 
                                           (match daily-tracking t (get total-spent t) u0)),
                        monthly-remaining: (- (get monthly-limit budget) 
                                             (match monthly-tracking t (get total-spent t) u0)),
                        alert-threshold: (get alert-threshold budget)
                    }))
            ERR_NOT_FOUND
        )
    )
)

(define-public (update-budget-performance (user principal))
    (let ((daily-period (/ burn-block-height u144))
          (budget-key {user: user, period: daily-period}))
        (match (map-get? budget-tracking budget-key)
            tracking
                (match (map-get? user-budgets user)
                    budget
                        (let ((current-perf (default-to 
                                              {periods-tracked: u0, periods-under-budget: u0,
                                               total-saved: u0, avg-utilization: u0, best-period: u0}
                                              (map-get? budget-performance user)))
                              (utilization (/ (* (get total-spent tracking) u100) (get daily-limit budget)))
                              (under-budget (< (get total-spent tracking) (get daily-limit budget)))
                              (saved-amount (if under-budget 
                                              (- (get daily-limit budget) (get total-spent tracking)) 
                                              u0)))
                            (map-set budget-performance user {
                                periods-tracked: (+ (get periods-tracked current-perf) u1),
                                periods-under-budget: (+ (get periods-under-budget current-perf) 
                                                        (if under-budget u1 u0)),
                                total-saved: (+ (get total-saved current-perf) saved-amount),
                                avg-utilization: (/ (+ (* (get avg-utilization current-perf) 
                                                        (get periods-tracked current-perf)) 
                                                      utilization) 
                                                   (+ (get periods-tracked current-perf) u1)),
                                best-period: (if (< utilization (get avg-utilization current-perf)) 
                                               daily-period 
                                               (get best-period current-perf))
                            })
                            (ok true))
                    ERR_NOT_FOUND)
            ERR_NOT_FOUND
        )
    )
)

(define-read-only (get-budget-alerts (user principal))
    (let ((daily-period (/ burn-block-height u144))
          (monthly-period (/ burn-block-height u4320)))
        (match (map-get? user-budgets user)
            budget
                (let ((daily-key {user: user, period: daily-period})
                      (monthly-key {user: user, period: monthly-period}))
                    (let ((daily-tracking (map-get? budget-tracking daily-key))
                          (monthly-tracking (map-get? budget-tracking monthly-key)))
                        {
                            daily-alert: (match daily-tracking 
                                           t (> (* (get total-spent t) u100) 
                                              (* (get daily-limit budget) (get alert-threshold budget)))
                                           false),
                            monthly-alert: (match monthly-tracking 
                                            t (> (* (get total-spent t) u100) 
                                               (* (get monthly-limit budget) (get alert-threshold budget)))
                                            false),
                            daily-exceeded: (match daily-tracking 
                                             t (get budget-exceeded t) 
                                             false),
                            monthly-exceeded: (match monthly-tracking 
                                               t (get budget-exceeded t) 
                                               false)
                        }))
            {daily-alert: false, monthly-alert: false, daily-exceeded: false, monthly-exceeded: false}
        )
    )
)

(define-read-only (get-budget-performance (user principal))
    (map-get? budget-performance user)
)

(define-read-only (calculate-budget-efficiency (user principal))
    (match (map-get? budget-performance user)
        perf
            (let ((success-rate (/ (* (get periods-under-budget perf) u100) (get periods-tracked perf)))
                  (avg-util (get avg-utilization perf)))
                {
                    success-rate: success-rate,
                    efficiency-score: (/ (+ success-rate (- u100 avg-util)) u2),
                    total-periods: (get periods-tracked perf),
                    savings-achieved: (get total-saved perf)
                })
        {success-rate: u0, efficiency-score: u0, total-periods: u0, savings-achieved: u0}
    )
)

(define-read-only (predict-budget-usage (user principal) (upcoming-transactions uint))
    (match (map-get? user-stats user)
        stats
            (let ((avg-cost (get avg-gas-per-tx stats))
                  (predicted-cost (* upcoming-transactions avg-cost)))
                (match (check-budget-status user)
                    ok-value
                        {
                            predicted-cost: predicted-cost,
                            daily-affordable: (/ (get daily-remaining ok-value) avg-cost),
                            monthly-affordable: (/ (get monthly-remaining ok-value) avg-cost),
                            will-exceed-daily: (> predicted-cost (get daily-remaining ok-value)),
                            will-exceed-monthly: (> predicted-cost (get monthly-remaining ok-value))
                        }
                    err-value
                        {predicted-cost: predicted-cost, daily-affordable: u0, monthly-affordable: u0,
                         will-exceed-daily: true, will-exceed-monthly: true}))
        {predicted-cost: u0, daily-affordable: u0, monthly-affordable: u0,
         will-exceed-daily: false, will-exceed-monthly: false}
    )
)

(define-public (purchase-gas-credits (amount uint))
    (let ((current-rate (var-get credit-exchange-rate))
          (tx-id (var-get total-transactions)))
        (begin
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
            
            (let ((current-credits (default-to 
                                     {balance: u0, total-purchased: u0, total-redeemed: u0,
                                      last-purchase: u0, last-redemption: u0}
                                     (map-get? gas-credits tx-sender))))
                (begin
                    (map-set gas-credits tx-sender {
                        balance: (+ (get balance current-credits) amount),
                        total-purchased: (+ (get total-purchased current-credits) amount),
                        total-redeemed: (get total-redeemed current-credits),
                        last-purchase: burn-block-height,
                        last-redemption: (get last-redemption current-credits)
                    })
                    
                    (map-set credit-transactions tx-id {
                        user: tx-sender,
                        transaction-type: "purchase",
                        amount: amount,
                        rate: current-rate,
                        timestamp: burn-block-height,
                        block-height: stacks-block-height
                    })
                    
                    (var-set total-credits-issued (+ (var-get total-credits-issued) amount))
                    (ok amount)
                )
            )
        )
    )
)

(define-public (redeem-gas-credits (amount uint))
    (let ((user-credits (map-get? gas-credits tx-sender))
          (current-rate (var-get credit-exchange-rate))
          (tx-id (var-get total-transactions)))
        (match user-credits
            credits
                (begin
                    (asserts! (>= (get balance credits) amount) ERR_INSUFFICIENT_CREDITS)
                    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
                    
                    (map-set gas-credits tx-sender {
                        balance: (- (get balance credits) amount),
                        total-purchased: (get total-purchased credits),
                        total-redeemed: (+ (get total-redeemed credits) amount),
                        last-purchase: (get last-purchase credits),
                        last-redemption: burn-block-height
                    })
                    
                    (map-set credit-transactions tx-id {
                        user: tx-sender,
                        transaction-type: "redemption",
                        amount: amount,
                        rate: current-rate,
                        timestamp: burn-block-height,
                        block-height: stacks-block-height
                    })
                    
                    (var-set total-credits-redeemed (+ (var-get total-credits-redeemed) amount))
                    (ok amount)
                )
            ERR_INSUFFICIENT_CREDITS
        )
    )
)

(define-public (transfer-gas-credits (recipient principal) (amount uint))
    (let ((sender-credits (map-get? gas-credits tx-sender))
          (transfer-id (var-get total-credits-issued)))
        (match sender-credits
            credits
                (begin
                    (asserts! (>= (get balance credits) amount) ERR_INSUFFICIENT_CREDITS)
                    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
                    (asserts! (not (is-eq tx-sender recipient)) ERR_INVALID_AMOUNT)
                    
                    (map-set gas-credits tx-sender {
                        balance: (- (get balance credits) amount),
                        total-purchased: (get total-purchased credits),
                        total-redeemed: (get total-redeemed credits),
                        last-purchase: (get last-purchase credits),
                        last-redemption: (get last-redemption credits)
                    })
                    
                    (let ((recipient-credits (default-to 
                                               {balance: u0, total-purchased: u0, total-redeemed: u0,
                                                last-purchase: u0, last-redemption: u0}
                                               (map-get? gas-credits recipient))))
                        (map-set gas-credits recipient {
                            balance: (+ (get balance recipient-credits) amount),
                            total-purchased: (get total-purchased recipient-credits),
                            total-redeemed: (get total-redeemed recipient-credits),
                            last-purchase: (get last-purchase recipient-credits),
                            last-redemption: (get last-redemption recipient-credits)
                        })
                    )
                    
                    (map-set credit-transfers transfer-id {
                        from: tx-sender,
                        to: recipient,
                        amount: amount,
                        timestamp: burn-block-height,
                        status: "completed"
                    })
                    
                    (ok amount)
                )
            ERR_INSUFFICIENT_CREDITS
        )
    )
)

(define-public (update-credit-exchange-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-rate u0) ERR_INVALID_RATE)
        (var-set credit-exchange-rate new-rate)
        (ok new-rate)
    )
)

(define-read-only (get-gas-credits (user principal))
    (map-get? gas-credits user)
)

(define-read-only (get-credit-transaction (tx-id uint))
    (map-get? credit-transactions tx-id)
)

(define-read-only (get-credit-transfer (transfer-id uint))
    (map-get? credit-transfers transfer-id)
)

(define-read-only (get-credit-system-stats)
    {
        total-issued: (var-get total-credits-issued),
        total-redeemed: (var-get total-credits-redeemed),
        credits-in-circulation: (- (var-get total-credits-issued) (var-get total-credits-redeemed)),
        current-exchange-rate: (var-get credit-exchange-rate)
    }
)

(define-read-only (calculate-credit-value (credits uint))
    (let ((current-rate (var-get credit-exchange-rate)))
        {
            credit-amount: credits,
            gas-equivalent: (/ (* credits u100) current-rate),
            current-rate: current-rate
        }
    )
)

(define-read-only (get-user-credit-stats (user principal))
    (match (map-get? gas-credits user)
        credits
            {
                current-balance: (get balance credits),
                lifetime-purchased: (get total-purchased credits),
                lifetime-redeemed: (get total-redeemed credits),
                net-savings: (let ((purchased-value (* (get total-purchased credits) (var-get credit-exchange-rate)))
                                   (redeemed-value (* (get total-redeemed credits) u100)))
                               (if (> redeemed-value purchased-value)
                                 (- redeemed-value purchased-value)
                                 u0)),
                last-activity: (if (> (get last-purchase credits) (get last-redemption credits))
                                 (get last-purchase credits)
                                 (get last-redemption credits))
            }
        {current-balance: u0, lifetime-purchased: u0, lifetime-redeemed: u0, 
         net-savings: u0, last-activity: u0}
    )
)

(define-read-only (estimate-credit-purchase-savings (amount uint))
    (let ((current-rate (var-get credit-exchange-rate))
          (network-congestion (get-network-congestion-level)))
        (let ((market-gas-cost (* amount u120))
              (credit-gas-cost (* amount current-rate)))
            {
                credits-to-purchase: amount,
                market-cost: market-gas-cost,
                credit-cost: credit-gas-cost,
                potential-savings: (if (> market-gas-cost credit-gas-cost)
                                     (- market-gas-cost credit-gas-cost)
                                     u0),
                savings-percentage: (if (> market-gas-cost u0)
                                      (/ (* (- market-gas-cost credit-gas-cost) u100) market-gas-cost)
                                      u0),
                recommended: (> network-congestion u70)
            }
        )
    )
)
