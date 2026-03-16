# Simplified Auction on Miden

## Contracts
- [x] Create `auction-account` component (9 Value storage slots, place_bid, settle_auction, receive_asset)
- [x] Create `fund-note` script (adds prize assets to auction vault via receive_asset)
- [x] Create `bid-note` script (adds bid assets + calls place_bid)
- [x] Create `settle-note` script (calls settle_auction)
- [x] Build all 4 contracts successfully

## Integration Tests
- [x] Test 1: Fund auction with PRIZE tokens
- [x] Test 2: Bidder A places bid, verify highest_bid/highest_bidder updates
- [x] Test 3: Bidder B outbids, verify refund output note for A
- [x] Test 4: Settle auction after end block, verify 2 output notes + is_settled
- [x] Test 5: Bid after auction ended is rejected

## Phase 2: CLI Binary (Local Node Validation)
- [x] Add `setup_local_client()` helper (localhost:57291, separate store/keystore)
- [x] Add `create_faucet_account()` helper (BasicFungibleFaucet with Falcon512 auth)
- [x] Create `run_auction.rs` CLI binary (18-step auction flow)
- [x] Binary compiles successfully
- [x] All existing tests still pass

## Results
All tests passing:
```
test test_bid_after_auction_ended ... ok
test test_auction_full_flow ... ok
test result: ok. 2 passed; 0 failed
```

Binary compiles:
```
cargo build --bin run_auction --release — OK
```
