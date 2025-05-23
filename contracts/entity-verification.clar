;; Entity Verification Contract
;; Validates supply chain participants

(define-data-var admin principal tx-sender)

;; Entity status: 0 = unverified, 1 = verified, 2 = suspended
(define-map entities principal
  {
    name: (string-utf8 100),
    entity-type: (string-utf8 50),
    status: uint,
    verification-date: uint
  }
)

(define-read-only (get-entity (entity-id principal))
  (default-to
    {
      name: u"",
      entity-type: u"",
      status: u0,
      verification-date: u0
    }
    (map-get? entities entity-id)
  )
)

(define-public (register-entity (name (string-utf8 100)) (entity-type (string-utf8 50)))
  (begin
    (asserts! (not (is-some (map-get? entities tx-sender))) (err u1)) ;; Already registered
    (ok (map-set entities tx-sender {
      name: name,
      entity-type: entity-type,
      status: u0, ;; Unverified by default
      verification-date: u0
    }))
  )
)

(define-public (verify-entity (entity-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Only admin can verify
    (asserts! (is-some (map-get? entities entity-id)) (err u3)) ;; Entity must exist
    (ok (map-set entities entity-id
      (merge (unwrap-panic (map-get? entities entity-id))
        {
          status: u1,
          verification-date: block-height
        }
      )
    ))
  )
)

(define-public (suspend-entity (entity-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Only admin can suspend
    (asserts! (is-some (map-get? entities entity-id)) (err u3)) ;; Entity must exist
    (ok (map-set entities entity-id
      (merge (unwrap-panic (map-get? entities entity-id))
        {
          status: u2
        }
      )
    ))
  )
)

(define-public (update-entity-info (name (string-utf8 100)) (entity-type (string-utf8 50)))
  (begin
    (asserts! (is-some (map-get? entities tx-sender)) (err u3)) ;; Entity must exist
    (ok (map-set entities tx-sender
      (merge (unwrap-panic (map-get? entities tx-sender))
        {
          name: name,
          entity-type: entity-type
        }
      )
    ))
  )
)

(define-read-only (is-verified (entity-id principal))
  (let ((entity (get-entity entity-id)))
    (is-eq (get status entity) u1)
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2)) ;; Only current admin can transfer
    (ok (var-set admin new-admin))
  )
)
