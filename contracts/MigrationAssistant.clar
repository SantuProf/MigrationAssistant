;; Migration Assistant Contract
;; A tool for migrating data between contract versions safely and efficiently

;; Define error constants
(define-constant err-owner-only (err u100))
(define-constant err-invalid-contract (err u101))
(define-constant err-migration-failed (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-data (err u104))

;; Contract constants
(define-constant contract-owner tx-sender)

;; Data variables
(define-data-var migration-active bool false)
(define-data-var current-version uint u1)

;; Migration tracking maps
(define-map migration-records 
  { old-contract: principal, new-contract: principal }
  { status: (string-ascii 20), timestamp: uint, data-count: uint })

(define-map migrated-data
  { contract: principal, data-key: (string-ascii 50) }
  { data: (string-ascii 500), migrated: bool })

;; Function 1: Migrate Contract Data
;; Transfers data from old contract version to new contract version
(define-public (migrate-contract-data 
  (old-contract principal) 
  (new-contract principal) 
  (data-keys (list 10 (string-ascii 50)))
  (data-values (list 10 (string-ascii 500))))
  (begin
    ;; Only contract owner can initiate migration
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Validate contracts are different
    (asserts! (not (is-eq old-contract new-contract)) err-invalid-contract)
    
    ;; Validate data integrity
    (asserts! (is-eq (len data-keys) (len data-values)) err-invalid-data)
    
    ;; Set migration as active
    (var-set migration-active true)
    
    ;; Process migration using fold with indices
    (let ((indices (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))
          (migration-result (fold process-migration-item 
                                 indices
                                 { contract: old-contract, 
                                   keys: data-keys,
                                   values: data-values,
                                   success: true, 
                                   count: u0 })))
      
      ;; Record migration attempt
      (map-set migration-records
        { old-contract: old-contract, new-contract: new-contract }
        { status: (if (get success migration-result) "completed" "failed"),
          timestamp: stacks-block-height,
          data-count: (get count migration-result) })
      
      ;; Set migration as inactive
      (var-set migration-active false)
      
      ;; Return result
      (if (get success migration-result)
          (ok { message: "Migration completed successfully", 
                migrated-items: (get count migration-result) })
          err-migration-failed))))

;; Helper function for processing individual migration items
(define-private (process-migration-item 
  (index uint)
  (acc { contract: principal, 
         keys: (list 10 (string-ascii 50)),
         values: (list 10 (string-ascii 500)),
         success: bool, 
         count: uint }))
  (if (and (get success acc) (< index (len (get keys acc))))
      (let ((key-opt (element-at (get keys acc) index))
            (value-opt (element-at (get values acc) index)))
        
        (match key-opt
          key (match value-opt
                value (begin
                        ;; Store migrated data
                        (map-set migrated-data
                          { contract: (get contract acc), data-key: key }
                          { data: value, migrated: true })
                        
                        ;; Update accumulator
                        { contract: (get contract acc),
                          keys: (get keys acc),
                          values: (get values acc),
                          success: true,
                          count: (+ (get count acc) u1) })
                
                ;; No matching value
                { contract: (get contract acc),
                  keys: (get keys acc),
                  values: (get values acc),
                  success: false,
                  count: (get count acc) })
          
          ;; No key at this index, but that's ok (end of list)
          acc))
      
      ;; Either failed or index out of bounds
      acc))

;; Function 2: Verify Migration Integrity
;; Verifies that data migration was successful and complete
(define-public (verify-migration-integrity 
  (old-contract principal)
  (new-contract principal)
  (verification-keys (list 10 (string-ascii 50))))
  (begin
    ;; Check if migration record exists
    (let ((migration-record (map-get? migration-records 
                                    { old-contract: old-contract, 
                                      new-contract: new-contract })))
      
      (match migration-record
        record-data
        (let ((verification-result (fold verify-data-item 
                                        verification-keys
                                        { contract: old-contract, 
                                          verified: u0, 
                                          total: (len verification-keys),
                                          all-valid: true })))
          
          (ok { migration-status: (get status record-data),
                timestamp: (get timestamp record-data),
                total-migrated: (get data-count record-data),
                verified-items: (get verified verification-result),
                verification-complete: (get all-valid verification-result),
                integrity-score: (if (> (get total verification-result) u0)
                                   (/ (* (get verified verification-result) u100) 
                                      (get total verification-result))
                                   u0) }))
        
        ;; No migration record found
        (err err-invalid-contract)))))

;; Helper function for verifying individual data items
(define-private (verify-data-item 
  (key (string-ascii 50))
  (acc { contract: principal, verified: uint, total: uint, all-valid: bool }))
  (let ((migrated-item (map-get? migrated-data 
                                { contract: (get contract acc), 
                                  data-key: key })))
    
    (match migrated-item
      item-data
      (if (get migrated item-data)
          ;; Item was successfully migrated
          { contract: (get contract acc),
            verified: (+ (get verified acc) u1),
            total: (get total acc),
            all-valid: (get all-valid acc) }
          
          ;; Item migration failed
          { contract: (get contract acc),
            verified: (get verified acc),
            total: (get total acc),
            all-valid: false })
      
      ;; Item not found
      { contract: (get contract acc),
        verified: (get verified acc),
        total: (get total acc),
        all-valid: false })))

;; Read-only functions for monitoring migration status

;; Get migration status
(define-read-only (get-migration-status (old-contract principal) (new-contract principal))
  (map-get? migration-records { old-contract: old-contract, new-contract: new-contract }))

;; Get migrated data
(define-read-only (get-migrated-data (contract principal) (data-key (string-ascii 50)))
  (map-get? migrated-data { contract: contract, data-key: data-key }))

;; Check if migration is currently active
(define-read-only (is-migration-active)
  (var-get migration-active))

;; Get current version
(define-read-only (get-current-version)
  (var-get current-version)) 