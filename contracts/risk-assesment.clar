;; Risk Assessment Contract
;; Identifies potential disruption factors

(define-data-var admin principal tx-sender)

;; Risk factor types: 1 = supply, 2 = demand, 3 = logistics, 4 = geopolitical, 5 = environmental
(define-map risk-factors uint
  {
    name: (string-utf8 100),
    description: (string-utf8 255),
    risk-type: uint,
    severity: uint,  ;; 1-10 scale
    probability: uint,  ;; 1-10 scale
    last-updated: uint
  }
)

(define-data-var risk-factor-count uint u0)

(define-map entity-risks { entity-id: principal, risk-id: uint } uint) ;; Maps entity to risk score (1-100)

(define-read-only (get-risk-factor (risk-id uint))
  (default-to
    {
      name: u"",
      description: u"",
      risk-type: u0,
      severity: u0,
      probability: u0,
      last-updated: u0
    }
    (map-get? risk-factors risk-id)
  )
)

(define-read-only (get-entity-risk (entity-id principal) (risk-id uint))
  (default-to u0 (map-get? entity-risks { entity-id: entity-id, risk-id: risk-id }))
)

(define-public (add-risk-factor (name (string-utf8 100)) (description (string-utf8 255)) (risk-type uint) (severity uint) (probability uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can add risk factors
    (asserts! (and (>= severity u1) (<= severity u10)) (err u2)) ;; Severity must be 1-10
    (asserts! (and (>= probability u1) (<= probability u10)) (err u3)) ;; Probability must be 1-10
    (asserts! (and (>= risk-type u1) (<= risk-type u5)) (err u4)) ;; Valid risk type

    (let ((new-risk-id (+ (var-get risk-factor-count) u1)))
      (var-set risk-factor-count new-risk-id)
      (ok (map-set risk-factors new-risk-id {
        name: name,
        description: description,
        risk-type: risk-type,
        severity: severity,
        probability: probability,
        last-updated: block-height
      }))
    )
  )
)

(define-public (update-risk-factor (risk-id uint) (severity uint) (probability uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can update risk factors
    (asserts! (is-some (map-get? risk-factors risk-id)) (err u5)) ;; Risk factor must exist
    (asserts! (and (>= severity u1) (<= severity u10)) (err u2)) ;; Severity must be 1-10
    (asserts! (and (>= probability u1) (<= probability u10)) (err u3)) ;; Probability must be 1-10

    (ok (map-set risk-factors risk-id
      (merge (unwrap-panic (map-get? risk-factors risk-id))
        {
          severity: severity,
          probability: probability,
          last-updated: block-height
        }
      )
    ))
  )
)

(define-public (assess-entity-risk (entity-id principal) (risk-id uint) (risk-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can assess risk
    (asserts! (is-some (map-get? risk-factors risk-id)) (err u5)) ;; Risk factor must exist
    (asserts! (and (>= risk-score u1) (<= risk-score u100)) (err u6)) ;; Risk score must be 1-100

    (ok (map-set entity-risks { entity-id: entity-id, risk-id: risk-id } risk-score))
  )
)

(define-read-only (calculate-overall-risk (entity-id principal))
  (let
    (
      (risk-count (var-get risk-factor-count))
      (total-risk u0)
      (count u0)
    )
    (fold calculate-risk-helper
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
      { entity-id: entity-id, total: u0, count: u0 })
  )
)

(define-private (calculate-risk-helper (risk-id uint) (result { entity-id: principal, total: uint, count: uint }))
  (let
    (
      (entity-id (get entity-id result))
      (risk-score (get-entity-risk entity-id risk-id))
    )
    (if (> risk-score u0)
      {
        entity-id: entity-id,
        total: (+ (get total result) risk-score),
        count: (+ (get count result) u1)
      }
      result
    )
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only current admin can transfer
    (ok (var-set admin new-admin))
  )
)
