;; Disruption Response Contract
;; Coordinates supply chain adjustments

(define-data-var admin principal tx-sender)

;; Disruption types: 1 = supply, 2 = demand, 3 = logistics, 4 = geopolitical, 5 = environmental
;; Disruption status: 0 = reported, 1 = in progress, 2 = resolved
(define-map disruptions uint
  {
    reporter: principal,
    disruption-type: uint,
    description: (string-utf8 255),
    severity: uint,  ;; 1-10 scale
    status: uint,
    affected-entities: (list 10 principal),
    affected-products: (list 10 uint),
    reported-at: uint,
    resolved-at: uint
  }
)

(define-data-var disruption-count uint u0)

;; Response plans
(define-map response-plans uint
  {
    disruption-id: uint,
    description: (string-utf8 255),
    actions: (list 5 (string-utf8 100)),
    is-active: bool,
    created-at: uint
  }
)

(define-data-var response-plan-count uint u0)

(define-read-only (get-disruption (disruption-id uint))
  (default-to
    {
      reporter: tx-sender,
      disruption-type: u0,
      description: u"",
      severity: u0,
      status: u0,
      affected-entities: (list),
      affected-products: (list),
      reported-at: u0,
      resolved-at: u0
    }
    (map-get? disruptions disruption-id)
  )
)

(define-read-only (get-response-plan (plan-id uint))
  (default-to
    {
      disruption-id: u0,
      description: u"",
      actions: (list),
      is-active: false,
      created-at: u0
    }
    (map-get? response-plans plan-id)
  )
)

(define-public (report-disruption (disruption-type uint) (description (string-utf8 255)) (severity uint) (affected-entities (list 10 principal)) (affected-products (list 10 uint)))
  (begin
    (asserts! (and (>= disruption-type u1) (<= disruption-type u5)) (err u1)) ;; Valid disruption type
    (asserts! (and (>= severity u1) (<= severity u10)) (err u2)) ;; Severity must be 1-10

    (let ((new-disruption-id (+ (var-get disruption-count) u1)))
      (var-set disruption-count new-disruption-id)
      (ok (map-set disruptions new-disruption-id {
        reporter: tx-sender,
        disruption-type: disruption-type,
        description: description,
        severity: severity,
        status: u0, ;; Reported
        affected-entities: affected-entities,
        affected-products: affected-products,
        reported-at: block-height,
        resolved-at: u0
      }))
    )
  )
)

(define-public (update-disruption-status (disruption-id uint) (status uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only admin can update status
    (asserts! (is-some (map-get? disruptions disruption-id)) (err u4)) ;; Disruption must exist
    (asserts! (and (>= status u0) (<= status u2)) (err u5)) ;; Valid status

    (let
      (
        (disruption (unwrap-panic (map-get? disruptions disruption-id)))
        (resolved-at (if (is-eq status u2) block-height (get resolved-at disruption)))
      )
      (ok (map-set disruptions disruption-id
        (merge disruption
          {
            status: status,
            resolved-at: resolved-at
          }
        )
      ))
    )
  )
)

(define-public (create-response-plan (disruption-id uint) (description (string-utf8 255)) (actions (list 5 (string-utf8 100))))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only admin can create response plans
    (asserts! (is-some (map-get? disruptions disruption-id)) (err u4)) ;; Disruption must exist

    (let ((new-plan-id (+ (var-get response-plan-count) u1)))
      (var-set response-plan-count new-plan-id)
      (ok (map-set response-plans new-plan-id {
        disruption-id: disruption-id,
        description: description,
        actions: actions,
        is-active: false,
        created-at: block-height
      }))
    )
  )
)

(define-public (activate-response-plan (plan-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only admin can activate plans
    (asserts! (is-some (map-get? response-plans plan-id)) (err u6)) ;; Plan must exist

    (ok (map-set response-plans plan-id
      (merge (unwrap-panic (map-get? response-plans plan-id))
        { is-active: true }
      )
    ))
  )
)

(define-public (deactivate-response-plan (plan-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only admin can deactivate plans
    (asserts! (is-some (map-get? response-plans plan-id)) (err u6)) ;; Plan must exist

    (ok (map-set response-plans plan-id
      (merge (unwrap-panic (map-get? response-plans plan-id))
        { is-active: false }
      )
    ))
  )
)

(define-read-only (get-active-plans-for-disruption (disruption-id uint))
  (filter-active-plans (var-get response-plan-count) disruption-id)
)

(define-private (filter-active-plans (max-id uint) (disruption-id uint))
  (let
    (
      (result (list))
    )
    (fold check-plan-for-disruption
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
      { disruption-id: disruption-id, plans: (list) })
  )
)

(define-private (check-plan-for-disruption (plan-id uint) (result { disruption-id: uint, plans: (list 10 uint) }))
  (let
    (
      (plan (get-response-plan plan-id))
      (is-match (and
                  (is-eq (get disruption-id plan) (get disruption-id result))
                  (get is-active plan)
                ))
    )
    (if is-match
      {
        disruption-id: (get disruption-id result),
        plans: (unwrap-panic (as-max-len? (append (get plans result) plan-id) u10))
      }
      result
    )
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only current admin can transfer
    (ok (var-set admin new-admin))
  )
)
