;; Accident Liability Contract
;; Determines fault and manages compensation

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_ACCIDENT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_INPUT (err u402))
(define-constant ERR_ALREADY_PROCESSED (err u403))

;; Data Variables
(define-data-var next-accident-id uint u1)

;; Data Maps
(define-map accidents
  { accident-id: uint }
  {
    vehicle-id: uint,
    other-party-id: (optional uint),
    location-lat: int,
    location-lng: int,
    timestamp: uint,
    severity: (string-ascii 20),
    weather-conditions: (string-ascii 50),
    road-conditions: (string-ascii 50),
    speed-at-impact: uint,
    damage-estimate: uint,
    injury-reported: bool,
    police-report-number: (string-ascii 50),
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map liability-assessments
  { accident-id: uint }
  {
    primary-fault-percentage: uint,
    secondary-fault-percentage: uint,
    contributing-factors: (string-ascii 500),
    assessment-date: uint,
    assessor: principal,
    final-determination: bool
  }
)

(define-map compensation-claims
  { accident-id: uint }
  {
    property-damage: uint,
    medical-expenses: uint,
    lost-income: uint,
    pain-suffering: uint,
    total-claim: uint,
    approved-amount: uint,
    payment-status: (string-ascii 20),
    claim-date: uint,
    settlement-date: (optional uint)
  }
)

(define-map vehicle-accident-history
  { vehicle-id: uint }
  { accident-ids: (list 50 uint) }
)

;; Read-only functions
(define-read-only (get-accident (accident-id uint))
  (map-get? accidents { accident-id: accident-id })
)

(define-read-only (get-liability-assessment (accident-id uint))
  (map-get? liability-assessments { accident-id: accident-id })
)

(define-read-only (get-compensation-claim (accident-id uint))
  (map-get? compensation-claims { accident-id: accident-id })
)

(define-read-only (get-vehicle-accidents (vehicle-id uint))
  (default-to (list) (get accident-ids (map-get? vehicle-accident-history { vehicle-id: vehicle-id })))
)

(define-read-only (calculate-base-liability (speed uint) (weather (string-ascii 50)) (road (string-ascii 50)))
  ;; Calculate base liability percentage based on conditions
  (let
    (
      (speed-factor (if (> speed u80) u30 (if (> speed u60) u20 u10)))
      (weather-factor (if (is-eq weather "rain") u15 (if (is-eq weather "snow") u25 u0)))
      (road-factor (if (is-eq road "wet") u10 (if (is-eq road "icy") u20 u0)))
    )
    (+ speed-factor weather-factor road-factor)
  )
)

(define-read-only (estimate-damages (severity (string-ascii 20)) (vehicle-value uint))
  ;; Estimate damages based on severity and vehicle value
  (if (is-eq severity "minor")
    (/ (* vehicle-value u10) u100)
    (if (is-eq severity "moderate")
      (/ (* vehicle-value u30) u100)
      (if (is-eq severity "severe")
        (/ (* vehicle-value u60) u100)
        vehicle-value ;; total loss
      )
    )
  )
)

;; Public functions
(define-public (report-accident
  (vehicle-id uint)
  (other-party-id (optional uint))
  (location-lat int)
  (location-lng int)
  (severity (string-ascii 20))
  (weather-conditions (string-ascii 50))
  (road-conditions (string-ascii 50))
  (speed-at-impact uint)
  (injury-reported bool)
  (police-report-number (string-ascii 50))
)
  (let
    (
      (accident-id (var-get next-accident-id))
      (damage-estimate (estimate-damages severity u50000)) ;; Default vehicle value
    )
    ;; Validate inputs
    (asserts! (and (>= location-lat -90000000) (<= location-lat 90000000)) ERR_INVALID_INPUT)
    (asserts! (and (>= location-lng -180000000) (<= location-lng 180000000)) ERR_INVALID_INPUT)
    (asserts! (> (len severity) u0) ERR_INVALID_INPUT)
    (asserts! (<= speed-at-impact u200) ERR_INVALID_INPUT)

    ;; Create accident record
    (map-set accidents
      { accident-id: accident-id }
      {
        vehicle-id: vehicle-id,
        other-party-id: other-party-id,
        location-lat: location-lat,
        location-lng: location-lng,
        timestamp: block-height,
        severity: severity,
        weather-conditions: weather-conditions,
        road-conditions: road-conditions,
        speed-at-impact: speed-at-impact,
        damage-estimate: damage-estimate,
        injury-reported: injury-reported,
        police-report-number: police-report-number,
        status: "reported",
        created-at: block-height
      }
    )

    ;; Add to vehicle accident history
    (let
      (
        (current-accidents (get-vehicle-accidents vehicle-id))
        (updated-accidents (unwrap! (as-max-len? (append current-accidents accident-id) u50) ERR_INVALID_INPUT))
      )
      (map-set vehicle-accident-history { vehicle-id: vehicle-id } { accident-ids: updated-accidents })
    )

    ;; Increment next accident ID
    (var-set next-accident-id (+ accident-id u1))

    (ok accident-id)
  )
)

(define-public (assess-liability
  (accident-id uint)
  (primary-fault-percentage uint)
  (secondary-fault-percentage uint)
  (contributing-factors (string-ascii 500))
)
  (let
    (
      (accident-data (unwrap! (get-accident accident-id) ERR_ACCIDENT_NOT_FOUND))
    )
    ;; Validate fault percentages
    (asserts! (<= primary-fault-percentage u100) ERR_INVALID_INPUT)
    (asserts! (<= secondary-fault-percentage u100) ERR_INVALID_INPUT)
    (asserts! (<= (+ primary-fault-percentage secondary-fault-percentage) u100) ERR_INVALID_INPUT)

    ;; Create liability assessment
    (map-set liability-assessments
      { accident-id: accident-id }
      {
        primary-fault-percentage: primary-fault-percentage,
        secondary-fault-percentage: secondary-fault-percentage,
        contributing-factors: contributing-factors,
        assessment-date: block-height,
        assessor: tx-sender,
        final-determination: true
      }
    )

    ;; Update accident status
    (map-set accidents
      { accident-id: accident-id }
      (merge accident-data { status: "assessed" })
    )

    (ok true)
  )
)

(define-public (file-compensation-claim
  (accident-id uint)
  (property-damage uint)
  (medical-expenses uint)
  (lost-income uint)
  (pain-suffering uint)
)
  (let
    (
      (accident-data (unwrap! (get-accident accident-id) ERR_ACCIDENT_NOT_FOUND))
      (total-claim (+ property-damage medical-expenses lost-income pain-suffering))
    )
    ;; Check if accident is assessed
    (asserts! (is-eq (get status accident-data) "assessed") ERR_INVALID_INPUT)

    ;; Check if claim already exists
    (asserts! (is-none (get-compensation-claim accident-id)) ERR_ALREADY_PROCESSED)

    ;; Create compensation claim
    (map-set compensation-claims
      { accident-id: accident-id }
      {
        property-damage: property-damage,
        medical-expenses: medical-expenses,
        lost-income: lost-income,
        pain-suffering: pain-suffering,
        total-claim: total-claim,
        approved-amount: u0,
        payment-status: "pending",
        claim-date: block-height,
        settlement-date: none
      }
    )

    (ok total-claim)
  )
)

(define-public (approve-compensation
  (accident-id uint)
  (approved-amount uint)
)
  (let
    (
      (claim-data (unwrap! (get-compensation-claim accident-id) ERR_ACCIDENT_NOT_FOUND))
      (liability-data (unwrap! (get-liability-assessment accident-id) ERR_ACCIDENT_NOT_FOUND))
    )
    ;; Check if claim is pending
    (asserts! (is-eq (get payment-status claim-data) "pending") ERR_INVALID_INPUT)

    ;; Validate approved amount
    (asserts! (<= approved-amount (get total-claim claim-data)) ERR_INVALID_INPUT)

    ;; Update compensation claim
    (map-set compensation-claims
      { accident-id: accident-id }
      (merge claim-data {
        approved-amount: approved-amount,
        payment-status: "approved",
        settlement-date: (some block-height)
      })
    )

    (ok true)
  )
)

(define-public (process-payment (accident-id uint))
  (let
    (
      (claim-data (unwrap! (get-compensation-claim accident-id) ERR_ACCIDENT_NOT_FOUND))
    )
    ;; Check if claim is approved
    (asserts! (is-eq (get payment-status claim-data) "approved") ERR_INVALID_INPUT)

    ;; Update payment status
    (map-set compensation-claims
      { accident-id: accident-id }
      (merge claim-data { payment-status: "paid" })
    )

    (ok (get approved-amount claim-data))
  )
)

(define-public (update-accident-status (accident-id uint) (new-status (string-ascii 20)))
  (let
    (
      (accident-data (unwrap! (get-accident accident-id) ERR_ACCIDENT_NOT_FOUND))
    )
    ;; Validate status
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)

    ;; Update accident
    (map-set accidents
      { accident-id: accident-id }
      (merge accident-data { status: new-status })
    )

    (ok true)
  )
)
