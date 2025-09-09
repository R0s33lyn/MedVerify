;; MedVerify - Medical research data validation and peer review platform
;; Researchers earn tokens based on study verification and peer ratings

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_STUDY_ID (err u109))
(define-constant ERR_EMPTY_HASH (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant CITATION_REWARD u10)
(define-constant EXCELLENCE_REWARD u20)
(define-constant PUBLICATION_REWARD u50)

;; Data maps
(define-map research-entities
  { entity-id: principal }
  { name: (string-ascii 50), entity-type: (string-ascii 20), reputation: uint, tokens: uint, published: bool }
)

(define-map research-studies
  { study-id: uint }
  { 
    researcher: principal, 
    description: (string-ascii 500), 
    study-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    peer-review-count: uint,
    citation-count: uint,
    methodology-rating: uint,
    rating-count: uint
  }
)

(define-map study-peer-reviews
  { study-id: uint, reviewer: principal }
  { reviewed: bool }
)

(define-map study-citations
  { study-id: uint, citing-researcher: principal }
  { citation-weight: uint, citation-date: uint }
)

(define-map methodology-ratings
  { study-id: uint, evaluator: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-study-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-study-id (study-id uint))
  (< study-id (var-get next-study-id))
)

;; Entity functions
(define-public (register-entity (name (string-ascii 50)) (entity-type (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq entity-type "researcher") (is-eq entity-type "reviewer") (is-eq entity-type "institution")) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? research-entities {entity-id: caller})) ERR_ALREADY_EXISTS)
    (ok (map-set research-entities 
      {entity-id: caller} 
      {name: name, entity-type: entity-type, reputation: u0, tokens: u100, published: false}))
  )
)

(define-public (update-entity (name (string-ascii 50)) (entity-type (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq entity-type "researcher") (is-eq entity-type "reviewer") (is-eq entity-type "institution")) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? research-entities {entity-id: caller})) ERR_NOT_FOUND)
    (ok (map-set research-entities 
      {entity-id: caller} 
      (merge (unwrap! (map-get? research-entities {entity-id: caller}) ERR_NOT_FOUND)
             {name: name, entity-type: entity-type})))
  )
)

;; Study functions
(define-public (submit-study (description (string-ascii 500)) (study-hash (buff 32)))
  (let ((caller tx-sender)
        (study-id (var-get next-study-id)))
    (asserts! (> (len description) u0) ERR_EMPTY_STRING)
    (asserts! (> (len study-hash) u0) ERR_EMPTY_HASH)
    (asserts! (is-some (map-get? research-entities {entity-id: caller})) ERR_NOT_FOUND)
    (var-set action-counter (+ (var-get action-counter) u1))
    
    (map-set research-studies 
      {study-id: study-id} 
      { 
        researcher: caller, 
        description: description, 
        study-hash: study-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        peer-review-count: u0,
        citation-count: u0,
        methodology-rating: u0,
        rating-count: u0
      })
    (var-set next-study-id (+ study-id u1))
    (ok study-id)
  )
)

(define-public (peer-review-study (study-id uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-study-id study-id) ERR_INVALID_STUDY_ID)
    (asserts! (is-some (map-get? research-entities {entity-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? research-studies {study-id: study-id})) ERR_NOT_FOUND)
    
    (let ((study (unwrap! (map-get? research-studies {study-id: study-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get researcher study))) ERR_SELF_RATING)
      (asserts! (is-none (map-get? study-peer-reviews {study-id: study-id, reviewer: caller})) ERR_ALREADY_VERIFIED)
      
      (map-set study-peer-reviews 
        {study-id: study-id, reviewer: caller} 
        {reviewed: true})
      
      (let ((new-peer-review-count (+ (get peer-review-count study) u1))
            (study-researcher (unwrap! (map-get? research-entities {entity-id: (get researcher study)}) ERR_NOT_FOUND))
            (reviewer-entity (unwrap! (map-get? research-entities {entity-id: caller}) ERR_NOT_FOUND)))
        
        (map-set research-studies 
          {study-id: study-id} 
          (merge study {
            peer-review-count: new-peer-review-count,
            verified: (>= new-peer-review-count u3)
          }))
        
        (map-set research-entities 
          {entity-id: caller} 
          (merge reviewer-entity {
            tokens: (+ (get tokens reviewer-entity) u5),
            reputation: (+ (get reputation reviewer-entity) u1)
          }))
        
        (if (and (>= new-peer-review-count u3) (not (get verified study)))
          (map-set research-entities 
            {entity-id: (get researcher study)} 
            (merge study-researcher {
              tokens: (+ (get tokens study-researcher) PUBLICATION_REWARD),
              reputation: (+ (get reputation study-researcher) u10),
              published: true
            }))
          true)
        
        (ok new-peer-review-count)
      )
    )
  )
)

(define-public (cite-study (study-id uint) (citation-weight uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-study-id study-id) ERR_INVALID_STUDY_ID)
    (asserts! (> citation-weight u0) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? research-entities {entity-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? research-studies {study-id: study-id})) ERR_NOT_FOUND)
    
    (let ((study (unwrap! (map-get? research-studies {study-id: study-id}) ERR_NOT_FOUND)))
      (asserts! (get verified study) ERR_UNAUTHORIZED)
      
      (map-set study-citations 
        {study-id: study-id, citing-researcher: caller} 
        {citation-weight: citation-weight, citation-date: (var-get action-counter)})
      
      (let ((new-citation-count (+ (get citation-count study) citation-weight))
            (study-researcher (unwrap! (map-get? research-entities {entity-id: (get researcher study)}) ERR_NOT_FOUND)))
        
        (map-set research-studies 
          {study-id: study-id} 
          (merge study {citation-count: new-citation-count}))
        
        (map-set research-entities 
          {entity-id: (get researcher study)} 
          (merge study-researcher {
            tokens: (+ (get tokens study-researcher) (* CITATION_REWARD citation-weight))
          }))
        
        (ok new-citation-count)
      )
    )
  )
)

(define-public (rate-study-methodology (study-id uint) (rating uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-study-id study-id) ERR_INVALID_STUDY_ID)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    (asserts! (is-some (map-get? research-entities {entity-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? research-studies {study-id: study-id})) ERR_NOT_FOUND)
    
    (let ((study (unwrap! (map-get? research-studies {study-id: study-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get researcher study))) ERR_SELF_RATING)
      (asserts! (is-none (map-get? methodology-ratings {study-id: study-id, evaluator: caller})) ERR_ALREADY_RATED)
      
      (map-set methodology-ratings 
        {study-id: study-id, evaluator: caller} 
        {rating: rating})
      
      (let ((current-total-rating (* (get methodology-rating study) (get rating-count study)))
            (new-rating-count (+ (get rating-count study) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (study-researcher (unwrap! (map-get? research-entities {entity-id: (get researcher study)}) ERR_NOT_FOUND))
            (evaluator-entity (unwrap! (map-get? research-entities {entity-id: caller}) ERR_NOT_FOUND)))
        
        (map-set research-studies 
          {study-id: study-id} 
          (merge study {
            methodology-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        (map-set research-entities 
          {entity-id: caller} 
          (merge evaluator-entity {
            tokens: (+ (get tokens evaluator-entity) u2),
            reputation: (+ (get reputation evaluator-entity) u1)
          }))
        
        (if (>= rating u4)
          (map-set research-entities 
            {entity-id: (get researcher study)} 
            (merge study-researcher {
              tokens: (+ (get tokens study-researcher) EXCELLENCE_REWARD),
              reputation: (+ (get reputation study-researcher) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-entity-info (entity-id principal))
  (map-get? research-entities {entity-id: entity-id})
)

(define-read-only (get-study (study-id uint))
  (map-get? research-studies {study-id: study-id})
)

(define-read-only (get-study-peer-review (study-id uint) (reviewer principal))
  (map-get? study-peer-reviews {study-id: study-id, reviewer: reviewer})
)

(define-read-only (get-study-citation (study-id uint) (citing-researcher principal))
  (map-get? study-citations {study-id: study-id, citing-researcher: citing-researcher})
)

(define-read-only (get-methodology-rating (study-id uint) (evaluator principal))
  (map-get? methodology-ratings {study-id: study-id, evaluator: evaluator})
)

(define-read-only (get-total-studies)
  (- (var-get next-study-id) u1)
)
