;; Payment Distribution Contract
;; Automates royalty payments to creators and rights holders

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INSUFFICIENT-FUNDS (err u501))
(define-constant ERR-PAYMENT-NOT-FOUND (err u502))
(define-constant ERR-ALREADY-CLAIMED (err u503))
(define-constant ERR-INVALID-INPUT (err u504))
(define-constant ERR-PAYMENT-EXPIRED (err u505))

;; Data Variables
(define-data-var next-payment-id uint u1)
(define-data-var payment-expiry-blocks uint u52560) ;; ~1 year in blocks
(define-data-var total-distributed uint u0)

;; Data Maps
(define-map payment-records
  { payment-id: uint }
  {
    song-id: uint,
    recipient: principal,
    amount: uint,
    percentage: uint,
    creation-date: uint,
    claim-deadline: uint,
    status: (string-ascii 20),
    claimed-date: (optional uint)
  }
)

(define-map recipient-balances
  { recipient: principal }
  { available-balance: uint, total-earned: uint, last-claim: uint }
)

(define-map song-payment-history
  { song-id: uint }
  { total-distributed: uint, payment-count: uint, last-distribution: uint }
)

(define-map payment-schedules
  { song-id: uint }
  { next-payment-date: uint, frequency-blocks: uint, auto-distribute: bool }
)

;; Public Functions

;; Create payment for rights holder
(define-public (create-payment (song-id uint) (recipient principal) (amount uint) (percentage uint))
  (let
    (
      (payment-id (var-get next-payment-id))
      (expiry-blocks (var-get payment-expiry-blocks))
      (claim-deadline (+ block-height expiry-blocks))
      (current-balance (default-to u0 (get available-balance (map-get? recipient-balances { recipient: recipient }))))
      (current-earned (default-to u0 (get total-earned (map-get? recipient-balances { recipient: recipient }))))
    )
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (and (> percentage u0) (<= percentage u100)) ERR-INVALID-INPUT)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR-INSUFFICIENT-FUNDS)

    ;; Create payment record
    (map-set payment-records
      { payment-id: payment-id }
      {
        song-id: song-id,
        recipient: recipient,
        amount: amount,
        percentage: percentage,
        creation-date: block-height,
        claim-deadline: claim-deadline,
        status: "pending",
        claimed-date: none
      }
    )

    ;; Update recipient balance
    (map-set recipient-balances
      { recipient: recipient }
      {
        available-balance: (+ current-balance amount),
        total-earned: (+ current-earned amount),
        last-claim: block-height
      }
    )

    ;; Update song payment history
    (let
      (
        (history (default-to { total-distributed: u0, payment-count: u0, last-distribution: u0 }
                            (map-get? song-payment-history { song-id: song-id })))
      )
      (map-set song-payment-history
        { song-id: song-id }
        {
          total-distributed: (+ (get total-distributed history) amount),
          payment-count: (+ (get payment-count history) u1),
          last-distribution: block-height
        }
      )
    )

    ;; Increment payment ID
    (var-set next-payment-id (+ payment-id u1))

    (ok payment-id)
  )
)

;; Claim payment
(define-public (claim-payment (payment-id uint))
  (let
    (
      (payment (unwrap! (map-get? payment-records { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
      (recipient (get recipient payment))
      (amount (get amount payment))
      (claim-deadline (get claim-deadline payment))
    )
    (asserts! (is-eq tx-sender recipient) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) "pending") ERR-ALREADY-CLAIMED)
    (asserts! (<= block-height claim-deadline) ERR-PAYMENT-EXPIRED)

    ;; Transfer payment to recipient
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))

    ;; Update payment record
    (map-set payment-records
      { payment-id: payment-id }
      (merge payment { status: "claimed", claimed-date: (some block-height) })
    )

    ;; Update recipient balance
    (let
      (
        (balance-info (unwrap! (map-get? recipient-balances { recipient: recipient }) ERR-PAYMENT-NOT-FOUND))
      )
      (map-set recipient-balances
        { recipient: recipient }
        (merge balance-info {
          available-balance: (- (get available-balance balance-info) amount),
          last-claim: block-height
        })
      )
    )

    ;; Update total distributed
    (var-set total-distributed (+ (var-get total-distributed) amount))

    (ok true)
  )
)

;; Batch create payments for multiple recipients
(define-public (batch-create-payments (song-id uint) (recipients (list 10 { recipient: principal, amount: uint, percentage: uint })))
  (let
    (
      (total-amount (fold + (map get-amount recipients) u0))
    )
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) total-amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> (len recipients) u0) ERR-INVALID-INPUT)

    ;; Create payments for each recipient
    (fold create-single-payment recipients (ok (list)))
  )
)

;; Set payment schedule for song
(define-public (set-payment-schedule (song-id uint) (frequency-blocks uint) (auto-distribute bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> frequency-blocks u0) ERR-INVALID-INPUT)

    (map-set payment-schedules
      { song-id: song-id }
      {
        next-payment-date: (+ block-height frequency-blocks),
        frequency-blocks: frequency-blocks,
        auto-distribute: auto-distribute
      }
    )

    (ok true)
  )
)

;; Update payment expiry (admin only)
(define-public (update-payment-expiry (new-expiry-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-expiry-blocks u0) ERR-INVALID-INPUT)
    (var-set payment-expiry-blocks new-expiry-blocks)
    (ok true)
  )
)

;; Reclaim expired payment (admin only)
(define-public (reclaim-expired-payment (payment-id uint))
  (let
    (
      (payment (unwrap! (map-get? payment-records { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
      (amount (get amount payment))
      (claim-deadline (get claim-deadline payment))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) "pending") ERR-ALREADY-CLAIMED)
    (asserts! (> block-height claim-deadline) ERR-INVALID-INPUT)

    ;; Update payment status
    (map-set payment-records
      { payment-id: payment-id }
      (merge payment { status: "expired" })
    )

    ;; Update recipient balance
    (let
      (
        (recipient (get recipient payment))
        (balance-info (unwrap! (map-get? recipient-balances { recipient: recipient }) ERR-PAYMENT-NOT-FOUND))
      )
      (map-set recipient-balances
        { recipient: recipient }
        (merge balance-info {
          available-balance: (- (get available-balance balance-info) amount)
        })
      )
    )

    (ok true)
  )
)

;; Private Functions

;; Helper function for batch payments
(define-private (create-single-payment (recipient-info { recipient: principal, amount: uint, percentage: uint }) (acc (response (list 10 uint) uint)))
  (match acc
    success-list (match (create-payment u0 (get recipient recipient-info) (get amount recipient-info) (get percentage recipient-info))
                   success-id (ok (unwrap-panic (as-max-len? (append success-list success-id) u10)))
                   error-val (err error-val))
    error-val (err error-val)
  )
)

;; Helper function to get amount from recipient info
(define-private (get-amount (recipient-info { recipient: principal, amount: uint, percentage: uint }))
  (get amount recipient-info)
)

;; Read-only Functions

;; Get payment record
(define-read-only (get-payment-record (payment-id uint))
  (map-get? payment-records { payment-id: payment-id })
)

;; Get recipient balance
(define-read-only (get-recipient-balance (recipient principal))
  (map-get? recipient-balances { recipient: recipient })
)

;; Get song payment history
(define-read-only (get-song-payment-history (song-id uint))
  (map-get? song-payment-history { song-id: song-id })
)

;; Get payment schedule
(define-read-only (get-payment-schedule (song-id uint))
  (map-get? payment-schedules { song-id: song-id })
)

;; Get total distributed amount
(define-read-only (get-total-distributed)
  (var-get total-distributed)
)

;; Get payment expiry blocks
(define-read-only (get-payment-expiry-blocks)
  (var-get payment-expiry-blocks)
)

;; Get next payment ID
(define-read-only (get-next-payment-id)
  (var-get next-payment-id)
)

;; Check if payment is claimable
(define-read-only (is-payment-claimable (payment-id uint))
  (match (map-get? payment-records { payment-id: payment-id })
    payment (and
              (is-eq (get status payment) "pending")
              (<= block-height (get claim-deadline payment)))
    false
  )
)

;; Get available balance for recipient
(define-read-only (get-available-balance (recipient principal))
  (default-to u0 (get available-balance (map-get? recipient-balances { recipient: recipient })))
)
