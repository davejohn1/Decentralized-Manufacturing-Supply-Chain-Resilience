;; Alternative Sourcing Contract
;; Manages backup suppliers

(define-data-var admin principal tx-sender)

;; Map of primary suppliers to their alternatives
(define-map alternative-suppliers
  { primary-supplier: principal, product-id: uint }
  {
    alternatives: (list 10 principal),
    is-active: bool
  }
)

;; Supplier performance ratings (1-10)
(define-map supplier-ratings principal uint)

;; Product information
(define-map products uint
  {
    name: (string-utf8 100),
    category: (string-utf8 50)
  }
)

(define-data-var product-count uint u0)

(define-read-only (get-alternatives (primary-supplier principal) (product-id uint))
  (default-to
    { alternatives: (list), is-active: false }
    (map-get? alternative-suppliers { primary-supplier: primary-supplier, product-id: product-id })
  )
)

(define-read-only (get-supplier-rating (supplier principal))
  (default-to u0 (map-get? supplier-ratings supplier))
)

(define-read-only (get-product (product-id uint))
  (default-to
    { name: u"", category: u"" }
    (map-get? products product-id)
  )
)

(define-public (add-product (name (string-utf8 100)) (category (string-utf8 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can add products

    (let ((new-product-id (+ (var-get product-count) u1)))
      (var-set product-count new-product-id)
      (ok (map-set products new-product-id {
        name: name,
        category: category
      }))
    )
  )
)

(define-public (register-alternatives (primary-supplier principal) (product-id uint) (alternatives (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can register alternatives
    (asserts! (is-some (map-get? products product-id)) (err u2)) ;; Product must exist

    (ok (map-set alternative-suppliers
      { primary-supplier: primary-supplier, product-id: product-id }
      { alternatives: alternatives, is-active: false }
    ))
  )
)

(define-public (activate-alternatives (primary-supplier principal) (product-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can activate alternatives
    (asserts! (is-some (map-get? alternative-suppliers { primary-supplier: primary-supplier, product-id: product-id })) (err u3)) ;; Alternatives must exist

    (ok (map-set alternative-suppliers
      { primary-supplier: primary-supplier, product-id: product-id }
      (merge (unwrap-panic (map-get? alternative-suppliers { primary-supplier: primary-supplier, product-id: product-id }))
        { is-active: true }
      )
    ))
  )
)

(define-public (deactivate-alternatives (primary-supplier principal) (product-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can deactivate alternatives
    (asserts! (is-some (map-get? alternative-suppliers { primary-supplier: primary-supplier, product-id: product-id })) (err u3)) ;; Alternatives must exist

    (ok (map-set alternative-suppliers
      { primary-supplier: primary-supplier, product-id: product-id }
      (merge (unwrap-panic (map-get? alternative-suppliers { primary-supplier: primary-supplier, product-id: product-id }))
        { is-active: false }
      )
    ))
  )
)

(define-public (rate-supplier (supplier principal) (rating uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can rate suppliers
    (asserts! (and (>= rating u1) (<= rating u10)) (err u4)) ;; Rating must be 1-10

    (ok (map-set supplier-ratings supplier rating))
  )
)

(define-read-only (get-best-alternative (primary-supplier principal) (product-id uint))
  (let
    (
      (alternatives-data (get-alternatives primary-supplier product-id))
      (alternatives-list (get alternatives alternatives-data))
    )
    (fold find-best-rated-supplier alternatives-list { best-supplier: none, best-rating: u0 })
  )
)

(define-private (find-best-rated-supplier (supplier principal) (result { best-supplier: (optional principal), best-rating: uint }))
  (let
    (
      (rating (get-supplier-rating supplier))
    )
    (if (> rating (get best-rating result))
      { best-supplier: (some supplier), best-rating: rating }
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
