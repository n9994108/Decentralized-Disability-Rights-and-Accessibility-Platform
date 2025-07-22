;; Advocacy Coordination Contract
;; Organizes disability rights advocacy and policy change efforts

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-NOT-FOUND (err u402))
(define-constant ERR-ALREADY-VOTED (err u403))
(define-constant ERR-CAMPAIGN-ENDED (err u404))

;; Data Variables
(define-data-var next-campaign-id uint u1)
(define-data-var next-petition-id uint u1)
(define-data-var next-proposal-id uint u1)

;; Data Maps
(define-map advocacy-campaigns
  { campaign-id: uint }
  {
    organizer: principal,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    category: (string-ascii 50),
    target-audience: (string-ascii 100),
    goal: (string-ascii 500),
    status: (string-ascii 20),
    supporters: uint,
    funding-goal: uint,
    funding-raised: uint,
    created-at: uint,
    deadline: uint
  }
)

(define-map petitions
  { petition-id: uint }
  {
    campaign-id: uint,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    target-official: (string-ascii 100),
    signatures: uint,
    goal-signatures: uint,
    status: (string-ascii 20),
    created-at: uint,
    deadline: uint
  }
)

(define-map policy-proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    category: (string-ascii 50),
    impact-area: (string-ascii 100),
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 20),
    created-at: uint,
    voting-deadline: uint
  }
)

(define-map campaign-supporters
  { campaign-id: uint, supporter: principal }
  {
    support-type: (string-ascii 20),
    contribution-amount: uint,
    joined-at: uint,
    active: bool
  }
)

(define-map petition-signatures
  { petition-id: uint, signer: principal }
  {
    signed-at: uint,
    verified: bool,
    comment: (string-ascii 500)
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  {
    vote: bool,
    voted-at: uint,
    reasoning: (string-ascii 500)
  }
)

(define-map advocacy-stats
  { advocate: principal }
  {
    campaigns-organized: uint,
    campaigns-supported: uint,
    petitions-signed: uint,
    proposals-submitted: uint,
    total-contributions: uint,
    reputation-score: uint
  }
)

;; Public Functions

;; Create advocacy campaign
(define-public (create-campaign (title (string-ascii 200)) (description (string-ascii 1000)) (category (string-ascii 50))
                               (target-audience (string-ascii 100)) (goal (string-ascii 500)) (funding-goal uint) (deadline uint))
  (let ((campaign-id (var-get next-campaign-id)))
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> deadline block-height) ERR-INVALID-INPUT)

    (map-set advocacy-campaigns
      { campaign-id: campaign-id }
      {
        organizer: tx-sender,
        title: title,
        description: description,
        category: category,
        target-audience: target-audience,
        goal: goal,
        status: "active",
        supporters: u0,
        funding-goal: funding-goal,
        funding-raised: u0,
        created-at: block-height,
        deadline: deadline
      }
    )

    ;; Update organizer stats
    (let ((advocate-stats (default-to { campaigns-organized: u0, campaigns-supported: u0, petitions-signed: u0, proposals-submitted: u0, total-contributions: u0, reputation-score: u50 }
                                      (map-get? advocacy-stats { advocate: tx-sender }))))
      (map-set advocacy-stats
        { advocate: tx-sender }
        (merge advocate-stats {
          campaigns-organized: (+ (get campaigns-organized advocate-stats) u1),
          reputation-score: (+ (get reputation-score advocate-stats) u5)
        })
      )
    )

    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Support a campaign
(define-public (support-campaign (campaign-id uint) (support-type (string-ascii 20)) (contribution-amount uint))
  (let ((campaign (unwrap! (map-get? advocacy-campaigns { campaign-id: campaign-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get status campaign) "active") ERR-CAMPAIGN-ENDED)
    (asserts! (> (get deadline campaign) block-height) ERR-CAMPAIGN-ENDED)
    (asserts! (is-none (map-get? campaign-supporters { campaign-id: campaign-id, supporter: tx-sender })) ERR-ALREADY-VOTED)

    ;; Record support
    (map-set campaign-supporters
      { campaign-id: campaign-id, supporter: tx-sender }
      {
        support-type: support-type,
        contribution-amount: contribution-amount,
        joined-at: block-height,
        active: true
      }
    )

    ;; Update campaign stats
    (map-set advocacy-campaigns
      { campaign-id: campaign-id }
      (merge campaign {
        supporters: (+ (get supporters campaign) u1),
        funding-raised: (+ (get funding-raised campaign) contribution-amount)
      })
    )

    ;; Update supporter stats
    (let ((advocate-stats (default-to { campaigns-organized: u0, campaigns-supported: u0, petitions-signed: u0, proposals-submitted: u0, total-contributions: u0, reputation-score: u50 }
                                      (map-get? advocacy-stats { advocate: tx-sender }))))
      (map-set advocacy-stats
        { advocate: tx-sender }
        (merge advocate-stats {
          campaigns-supported: (+ (get campaigns-supported advocate-stats) u1),
          total-contributions: (+ (get total-contributions advocate-stats) contribution-amount),
          reputation-score: (+ (get reputation-score advocate-stats) u2)
        })
      )
    )

    (ok true)
  )
)

;; Create petition
(define-public (create-petition (campaign-id uint) (title (string-ascii 200)) (description (string-ascii 1000))
                               (target-official (string-ascii 100)) (goal-signatures uint) (deadline uint))
  (let ((petition-id (var-get next-petition-id))
        (campaign (unwrap! (map-get? advocacy-campaigns { campaign-id: campaign-id }) ERR-NOT-FOUND)))

    (asserts! (is-eq (get organizer campaign) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> goal-signatures u0) ERR-INVALID-INPUT)
    (asserts! (> deadline block-height) ERR-INVALID-INPUT)

    (map-set petitions
      { petition-id: petition-id }
      {
        campaign-id: campaign-id,
        title: title,
        description: description,
        target-official: target-official,
        signatures: u0,
        goal-signatures: goal-signatures,
        status: "active",
        created-at: block-height,
        deadline: deadline
      }
    )

    (var-set next-petition-id (+ petition-id u1))
    (ok petition-id)
  )
)

;; Sign petition
(define-public (sign-petition (petition-id uint) (comment (string-ascii 500)))
  (let ((petition (unwrap! (map-get? petitions { petition-id: petition-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get status petition) "active") ERR-CAMPAIGN-ENDED)
    (asserts! (> (get deadline petition) block-height) ERR-CAMPAIGN-ENDED)
    (asserts! (is-none (map-get? petition-signatures { petition-id: petition-id, signer: tx-sender })) ERR-ALREADY-VOTED)

    ;; Record signature
    (map-set petition-signatures
      { petition-id: petition-id, signer: tx-sender }
      {
        signed-at: block-height,
        verified: true,
        comment: comment
      }
    )

    ;; Update petition stats
    (map-set petitions
      { petition-id: petition-id }
      (merge petition { signatures: (+ (get signatures petition) u1) })
    )

    ;; Update signer stats
    (let ((advocate-stats (default-to { campaigns-organized: u0, campaigns-supported: u0, petitions-signed: u0, proposals-submitted: u0, total-contributions: u0, reputation-score: u50 }
                                      (map-get? advocacy-stats { advocate: tx-sender }))))
      (map-set advocacy-stats
        { advocate: tx-sender }
        (merge advocate-stats {
          petitions-signed: (+ (get petitions-signed advocate-stats) u1),
          reputation-score: (+ (get reputation-score advocate-stats) u1)
        })
      )
    )

    (ok true)
  )
)

;; Submit policy proposal
(define-public (submit-proposal (title (string-ascii 200)) (description (string-ascii 1000)) (category (string-ascii 50))
                               (impact-area (string-ascii 100)) (voting-deadline uint))
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> voting-deadline block-height) ERR-INVALID-INPUT)

    (map-set policy-proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        category: category,
        impact-area: impact-area,
        votes-for: u0,
        votes-against: u0,
        status: "voting",
        created-at: block-height,
        voting-deadline: voting-deadline
      }
    )

    ;; Update proposer stats
    (let ((advocate-stats (default-to { campaigns-organized: u0, campaigns-supported: u0, petitions-signed: u0, proposals-submitted: u0, total-contributions: u0, reputation-score: u50 }
                                      (map-get? advocacy-stats { advocate: tx-sender }))))
      (map-set advocacy-stats
        { advocate: tx-sender }
        (merge advocate-stats {
          proposals-submitted: (+ (get proposals-submitted advocate-stats) u1),
          reputation-score: (+ (get reputation-score advocate-stats) u3)
        })
      )
    )

    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

;; Vote on policy proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool) (reasoning (string-ascii 500)))
  (let ((proposal (unwrap! (map-get? policy-proposals { proposal-id: proposal-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get status proposal) "voting") ERR-CAMPAIGN-ENDED)
    (asserts! (> (get voting-deadline proposal) block-height) ERR-CAMPAIGN-ENDED)
    (asserts! (is-none (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)

    ;; Record vote
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: tx-sender }
      {
        vote: vote,
        voted-at: block-height,
        reasoning: reasoning
      }
    )

    ;; Update proposal vote counts
    (if vote
      (map-set policy-proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) u1) })
      )
      (map-set policy-proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) u1) })
      )
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get campaign details
(define-read-only (get-campaign (campaign-id uint))
  (map-get? advocacy-campaigns { campaign-id: campaign-id })
)

;; Get petition details
(define-read-only (get-petition (petition-id uint))
  (map-get? petitions { petition-id: petition-id })
)

;; Get policy proposal
(define-read-only (get-proposal (proposal-id uint))
  (map-get? policy-proposals { proposal-id: proposal-id })
)

;; Get campaign support
(define-read-only (get-campaign-support (campaign-id uint) (supporter principal))
  (map-get? campaign-supporters { campaign-id: campaign-id, supporter: supporter })
)

;; Get petition signature
(define-read-only (get-petition-signature (petition-id uint) (signer principal))
  (map-get? petition-signatures { petition-id: petition-id, signer: signer })
)

;; Get proposal vote
(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

;; Get advocacy stats
(define-read-only (get-advocacy-stats (advocate principal))
  (map-get? advocacy-stats { advocate: advocate })
)

;; Get next IDs
(define-read-only (get-next-campaign-id)
  (var-get next-campaign-id)
)

(define-read-only (get-next-petition-id)
  (var-get next-petition-id)
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)
