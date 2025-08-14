(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_NO_RECOMMENDATIONS (err u105))

(define-data-var total-transactions uint u0)
(define-data-var total-gas-consumed uint u0)
(define-data-var contract-enabled bool true)

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
