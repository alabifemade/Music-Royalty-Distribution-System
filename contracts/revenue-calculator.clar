;; Revenue Calculator Contract
;; Determines royalty payments based on streaming usage and rates

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-SONG-NOT-FOUND (err u301))
(define-constant ERR-INVALID-INPUT (err u302))
(define-constant ERR-CALCULATION-ERROR (err u303))
(define-constant ERR-OVERFLOW (err u304))

;; Data Variables
(define-data-var base-rate-per-stream uint u100) ;; Base rate in microSTX
(define-data-var platform-multiplier uint u100) ;; Percentage multiplier
(define-data-var minimum-payout uint u1000000) ;; 1 STX minimum

;; Data Maps
(define-map revenue-calculations
  { song-id: uint, calculation-id: uint }
  {
    total-streams: uint,
    total-revenue: uint,
    calculation-date: uint,
    period-start: uint,
    period-end: uint
  }
)

(define-map platform-rates
  { platform: (string-ascii 50) }
  { rate-per-stream: uint, multiplier: uint }
)

(define-map song-revenue-totals
  { song-id: uint }
  { lifetime-revenue: uint, last-calculation: uint }
)

;; Public Functions

;; Set platform-specific rates (admin only)
(define-public (set-platform-rate (platform (string-ascii 50)) (rate uint) (multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> rate u0) ERR-INVALID-INPUT)
    (asserts! (and (> multiplier u0) (<= multiplier u200)) ERR-INVALID-INPUT) ;; 0-200% multiplier

    (map-set platform-rates
      { platform: platform }
      { rate-per-stream: rate, multiplier: multiplier }
    )

    (ok true)
  )
)

;; Calculate revenue for song based on streams
(define-public (calculate-song-revenue (song-id uint) (total-streams uint) (period-start uint) (period-end uint))
  (let
    (
      (base-rate (var-get base-rate-per-stream))
      (calculation-id block-height)
      (total-revenue (calculate-revenue-amount total-streams base-rate))
      (current-total (default-to u0 (get lifetime-revenue (map-get? song-revenue-totals { song-id: song-id }))))
    )
    (asserts! (> total-streams u0) ERR-INVALID-INPUT)
    (asserts! (< period-start period-end) ERR-INVALID-INPUT)
    (asserts! (<= period-end block-height) ERR-INVALID-INPUT)

    ;; Check for overflow
    (asserts! (< total-revenue u340282366920938463463374607431768211455) ERR-OVERFLOW)

    ;; Record calculation
    (map-set revenue-calculations
      { song-id: song-id, calculation-id: calculation-id }
      {
        total-streams: total-streams,
        total-revenue: total-revenue,
        calculation-date: block-height,
        period-start: period-start,
        period-end: period-end
      }
    )

    ;; Update song revenue totals
    (map-set song-revenue-totals
      { song-id: song-id }
      {
        lifetime-revenue: (+ current-total total-revenue),
        last-calculation: block-height
      }
    )

    (ok total-revenue)
  )
)

;; Calculate platform-specific revenue
(define-public (calculate-platform-revenue (song-id uint) (platform (string-ascii 50)) (streams uint))
  (let
    (
      (platform-info (unwrap! (map-get? platform-rates { platform: platform }) ERR-INVALID-INPUT))
      (rate (get rate-per-stream platform-info))
      (multiplier (get multiplier platform-info))
      (base-revenue (calculate-revenue-amount streams rate))
      (adjusted-revenue (/ (* base-revenue multiplier) u100))
    )
    (asserts! (> streams u0) ERR-INVALID-INPUT)
    (asserts! (< adjusted-revenue u340282366920938463463374607431768211455) ERR-OVERFLOW)

    (ok adjusted-revenue)
  )
)

;; Update base rate (admin only)
(define-public (update-base-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-rate u0) ERR-INVALID-INPUT)
    (var-set base-rate-per-stream new-rate)
    (ok true)
  )
)

;; Update minimum payout (admin only)
(define-public (update-minimum-payout (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-minimum u0) ERR-INVALID-INPUT)
    (var-set minimum-payout new-minimum)
    (ok true)
  )
)

;; Private Functions

;; Calculate revenue amount from streams and rate
(define-private (calculate-revenue-amount (streams uint) (rate uint))
  (let
    (
      (revenue (* streams rate))
    )
    (if (< revenue u340282366920938463463374607431768211455)
      revenue
      u0 ;; Return 0 on overflow
    )
  )
)

;; Read-only Functions

;; Get revenue calculation
(define-read-only (get-revenue-calculation (song-id uint) (calculation-id uint))
  (map-get? revenue-calculations { song-id: song-id, calculation-id: calculation-id })
)

;; Get platform rate information
(define-read-only (get-platform-rate (platform (string-ascii 50)))
  (map-get? platform-rates { platform: platform })
)

;; Get song revenue totals
(define-read-only (get-song-revenue-totals (song-id uint))
  (map-get? song-revenue-totals { song-id: song-id })
)

;; Get current base rate
(define-read-only (get-base-rate)
  (var-get base-rate-per-stream)
)

;; Get minimum payout amount
(define-read-only (get-minimum-payout)
  (var-get minimum-payout)
)

;; Calculate estimated revenue for given streams
(define-read-only (estimate-revenue (streams uint))
  (let
    (
      (base-rate (var-get base-rate-per-stream))
    )
    (if (> streams u0)
      (* streams base-rate)
      u0
    )
  )
)

;; Check if revenue meets minimum payout
(define-read-only (meets-minimum-payout (revenue uint))
  (>= revenue (var-get minimum-payout))
)
