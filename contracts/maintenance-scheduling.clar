;; Maintenance Scheduling Contract
;; Predicts and schedules vehicle servicing

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_MAINTENANCE_NOT_FOUND (err u301))
(define-constant ERR_INVALID_INPUT (err u302))
(define-constant ERR_ALREADY_SCHEDULED (err u303))

;; Data Variables
(define-data-var next-maintenance-id uint u1)

;; Data Maps
(define-map maintenance-records
  { maintenance-id: uint }
  {
    vehicle-id: uint,
    maintenance-type: (string-ascii 50),
    scheduled-date: uint,
    completed-date: (optional uint),
    mileage-at-service: uint,
    cost: uint,
    service-provider: (string-ascii 100),
    status: (string-ascii 20),
    notes: (string-ascii 500),
    created-at: uint
  }
)

(define-map vehicle-maintenance
  { vehicle-id: uint }
  { maintenance-ids: (list 100 uint) }
)

(define-map maintenance-schedules
  { vehicle-id: uint }
  {
    last-oil-change: uint,
    last-tire-rotation: uint,
    last-brake-check: uint,
    last-inspection: uint,
    oil-change-interval: uint,
    tire-rotation-interval: uint,
    brake-check-interval: uint,
    inspection-interval: uint
  }
)

(define-map predictive-maintenance
  { vehicle-id: uint }
  {
    predicted-oil-change: uint,
    predicted-tire-replacement: uint,
    predicted-brake-service: uint,
    predicted-battery-replacement: uint,
    risk-score: uint
  }
)

;; Read-only functions
(define-read-only (get-maintenance-record (maintenance-id uint))
  (map-get? maintenance-records { maintenance-id: maintenance-id })
)

(define-read-only (get-vehicle-maintenance (vehicle-id uint))
  (default-to (list) (get maintenance-ids (map-get? vehicle-maintenance { vehicle-id: vehicle-id })))
)

(define-read-only (get-maintenance-schedule (vehicle-id uint))
  (map-get? maintenance-schedules { vehicle-id: vehicle-id })
)

(define-read-only (get-predictive-maintenance (vehicle-id uint))
  (map-get? predictive-maintenance { vehicle-id: vehicle-id })
)

(define-read-only (calculate-next-oil-change (vehicle-id uint) (current-mileage uint))
  (match (get-maintenance-schedule vehicle-id)
    schedule-data
      (let
        (
          (last-change (get last-oil-change schedule-data))
          (interval (get oil-change-interval schedule-data))
        )
        (+ last-change interval)
      )
    (+ current-mileage u5000) ;; Default 5000 miles
  )
)

(define-read-only (is-maintenance-due (vehicle-id uint) (current-mileage uint) (maintenance-type (string-ascii 50)))
  (match (get-maintenance-schedule vehicle-id)
    schedule-data
      (if (is-eq maintenance-type "oil-change")
        (>= current-mileage (+ (get last-oil-change schedule-data) (get oil-change-interval schedule-data)))
        (if (is-eq maintenance-type "tire-rotation")
          (>= current-mileage (+ (get last-tire-rotation schedule-data) (get tire-rotation-interval schedule-data)))
          (if (is-eq maintenance-type "brake-check")
            (>= current-mileage (+ (get last-brake-check schedule-data) (get brake-check-interval schedule-data)))
            false
          )
        )
      )
    false
  )
)

;; Public functions
(define-public (initialize-maintenance-schedule
  (vehicle-id uint)
  (current-mileage uint)
)
  (let
    (
      (default-schedule {
        last-oil-change: current-mileage,
        last-tire-rotation: current-mileage,
        last-brake-check: current-mileage,
        last-inspection: current-mileage,
        oil-change-interval: u5000,
        tire-rotation-interval: u7500,
        brake-check-interval: u15000,
        inspection-interval: u12000
      })
    )
    ;; Check if schedule already exists
    (asserts! (is-none (get-maintenance-schedule vehicle-id)) ERR_ALREADY_SCHEDULED)

    ;; Initialize schedule
    (map-set maintenance-schedules { vehicle-id: vehicle-id } default-schedule)

    (ok true)
  )
)

(define-public (schedule-maintenance
  (vehicle-id uint)
  (maintenance-type (string-ascii 50))
  (scheduled-date uint)
  (estimated-mileage uint)
  (service-provider (string-ascii 100))
  (estimated-cost uint)
)
  (let
    (
      (maintenance-id (var-get next-maintenance-id))
    )
    ;; Validate inputs
    (asserts! (> (len maintenance-type) u0) ERR_INVALID_INPUT)
    (asserts! (> scheduled-date block-height) ERR_INVALID_INPUT)
    (asserts! (> (len service-provider) u0) ERR_INVALID_INPUT)

    ;; Create maintenance record
    (map-set maintenance-records
      { maintenance-id: maintenance-id }
      {
        vehicle-id: vehicle-id,
        maintenance-type: maintenance-type,
        scheduled-date: scheduled-date,
        completed-date: none,
        mileage-at-service: estimated-mileage,
        cost: estimated-cost,
        service-provider: service-provider,
        status: "scheduled",
        notes: "",
        created-at: block-height
      }
    )

    ;; Add to vehicle maintenance list
    (let
      (
        (current-maintenance (get-vehicle-maintenance vehicle-id))
        (updated-maintenance (unwrap! (as-max-len? (append current-maintenance maintenance-id) u100) ERR_INVALID_INPUT))
      )
      (map-set vehicle-maintenance { vehicle-id: vehicle-id } { maintenance-ids: updated-maintenance })
    )

    ;; Increment next maintenance ID
    (var-set next-maintenance-id (+ maintenance-id u1))

    (ok maintenance-id)
  )
)

(define-public (complete-maintenance
  (maintenance-id uint)
  (actual-mileage uint)
  (actual-cost uint)
  (notes (string-ascii 500))
)
  (let
    (
      (maintenance-data (unwrap! (get-maintenance-record maintenance-id) ERR_MAINTENANCE_NOT_FOUND))
      (vehicle-id (get vehicle-id maintenance-data))
      (maintenance-type (get maintenance-type maintenance-data))
    )
    ;; Check if maintenance is scheduled
    (asserts! (is-eq (get status maintenance-data) "scheduled") ERR_INVALID_INPUT)

    ;; Update maintenance record
    (map-set maintenance-records
      { maintenance-id: maintenance-id }
      (merge maintenance-data {
        completed-date: (some block-height),
        mileage-at-service: actual-mileage,
        cost: actual-cost,
        status: "completed",
        notes: notes
      })
    )

    ;; Update maintenance schedule
    (match (get-maintenance-schedule vehicle-id)
      schedule-data
        (let
          (
            (updated-schedule
              (if (is-eq maintenance-type "oil-change")
                (merge schedule-data { last-oil-change: actual-mileage })
                (if (is-eq maintenance-type "tire-rotation")
                  (merge schedule-data { last-tire-rotation: actual-mileage })
                  (if (is-eq maintenance-type "brake-check")
                    (merge schedule-data { last-brake-check: actual-mileage })
                    (if (is-eq maintenance-type "inspection")
                      (merge schedule-data { last-inspection: actual-mileage })
                      schedule-data
                    )
                  )
                )
              )
            )
          )
          (map-set maintenance-schedules { vehicle-id: vehicle-id } updated-schedule)
        )
      true ;; No existing schedule
    )

    (ok true)
  )
)

(define-public (update-predictive-maintenance
  (vehicle-id uint)
  (current-mileage uint)
  (engine-hours uint)
  (brake-wear-percentage uint)
)
  (let
    (
      (oil-prediction (+ current-mileage u5000))
      (tire-prediction (+ current-mileage u25000))
      (brake-prediction (+ current-mileage (if (> brake-wear-percentage u70) u5000 u15000)))
      (battery-prediction (+ current-mileage u50000))
      (risk-score (calculate-risk-score current-mileage engine-hours brake-wear-percentage))
    )
    ;; Update predictive maintenance
    (map-set predictive-maintenance
      { vehicle-id: vehicle-id }
      {
        predicted-oil-change: oil-prediction,
        predicted-tire-replacement: tire-prediction,
        predicted-brake-service: brake-prediction,
        predicted-battery-replacement: battery-prediction,
        risk-score: risk-score
      }
    )

    (ok true)
  )
)

(define-public (cancel-maintenance (maintenance-id uint))
  (let
    (
      (maintenance-data (unwrap! (get-maintenance-record maintenance-id) ERR_MAINTENANCE_NOT_FOUND))
    )
    ;; Check if maintenance can be cancelled
    (asserts! (is-eq (get status maintenance-data) "scheduled") ERR_INVALID_INPUT)

    ;; Update status
    (map-set maintenance-records
      { maintenance-id: maintenance-id }
      (merge maintenance-data { status: "cancelled" })
    )

    (ok true)
  )
)

;; Private functions
(define-private (calculate-risk-score (mileage uint) (engine-hours uint) (brake-wear uint))
  ;; Calculate risk score based on various factors (0-100)
  (let
    (
      (mileage-factor (if (> mileage u100000) u30 (/ (* mileage u30) u100000)))
      (engine-factor (if (> engine-hours u5000) u25 (/ (* engine-hours u25) u5000)))
      (brake-factor (if (> brake-wear u80) u25 (/ (* brake-wear u25) u100)))
      (base-score u20)
    )
    (+ base-score mileage-factor engine-factor brake-factor)
  )
)
