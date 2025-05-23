;; Inventory Buffer Contract
;; Tracks strategic reserves

(define-data-var admin principal tx-sender)

;; Inventory levels by entity and product
(define-map inventory-levels
  { entity-id: principal, product-id: uint }
  {
    current-level: uint,
    buffer-threshold: uint,
    last-updated: uint
  }
)

;; Alert status: 0 = normal, 1 = warning, 2 = critical
(define-map buffer-alerts
  { entity-id: principal, product-id: uint }
  {
    status: uint,
    timestamp: uint
  }
)

(define-read-only (get-inventory-level (entity-id principal) (product-id uint))
  (default-to
    { current-level: u0, buffer-threshold: u0, last-updated: u0 }
    (map-get? inventory-levels { entity-id: entity-id, product-id: product-id })
  )
)

(define-read-only (get-buffer-alert (entity-id principal) (product-id uint))
  (default-to
    { status: u0, timestamp: u0 }
    (map-get? buffer-alerts { entity-id: entity-id, product-id: product-id })
  )
)

(define-public (update-inventory (entity-id principal) (product-id uint) (level uint))
  (begin
    (asserts! (or (is-eq tx-sender entity-id) (is-eq tx-sender (var-get admin))) (err u1)) ;; Only entity or admin can update

    (let
      (
        (current-data (get-inventory-level entity-id product-id))
        (threshold (get buffer-threshold current-data))
        (alert-status (if (< level threshold) u1 u0))
        (critical-status (if (< level (/ threshold u2)) u2 alert-status))
      )

      ;; Update inventory level
      (map-set inventory-levels
        { entity-id: entity-id, product-id: product-id }
        {
          current-level: level,
          buffer-threshold: (if (> threshold u0) threshold u100), ;; Default threshold if not set
          last-updated: block-height
        }
      )

      ;; Update alert status if needed
      (if (> critical-status u0)
        (map-set buffer-alerts
          { entity-id: entity-id, product-id: product-id }
          {
            status: critical-status,
            timestamp: block-height
          }
        )
        true
      )

      (ok true)
    )
  )
)

(define-public (set-buffer-threshold (entity-id principal) (product-id uint) (threshold uint))
  (begin
    (asserts! (or (is-eq tx-sender entity-id) (is-eq tx-sender (var-get admin))) (err u1)) ;; Only entity or admin can set threshold

    (let ((current-data (get-inventory-level entity-id product-id)))
      (ok (map-set inventory-levels
        { entity-id: entity-id, product-id: product-id }
        {
          current-level: (get current-level current-data),
          buffer-threshold: threshold,
          last-updated: block-height
        }
      ))
    )
  )
)

(define-public (clear-alert (entity-id principal) (product-id uint))
  (begin
    (asserts! (or (is-eq tx-sender entity-id) (is-eq tx-sender (var-get admin))) (err u1)) ;; Only entity or admin can clear alert

    (ok (map-set buffer-alerts
      { entity-id: entity-id, product-id: product-id }
      {
        status: u0,
        timestamp: block-height
      }
    ))
  )
)

(define-read-only (check-buffer-status (entity-id principal) (product-id uint))
  (let
    (
      (inventory-data (get-inventory-level entity-id product-id))
      (current-level (get current-level inventory-data))
      (threshold (get buffer-threshold inventory-data))
    )
    (if (> threshold u0)
      (if (< current-level threshold)
        (if (< current-level (/ threshold u2))
          u2  ;; Critical
          u1  ;; Warning
        )
        u0  ;; Normal
      )
      u0  ;; No threshold set
    )
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only current admin can transfer
    (ok (var-set admin new-admin))
  )
)
