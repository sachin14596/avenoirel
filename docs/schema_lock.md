# AVENOIREL — Schema Lock Document
**Version:** 1.0  
**Date:** September 2026  
**Status:** LOCKED  

---

> Once this document is committed, schema is frozen.
> No column additions, renames, or type changes without a full downstream review.
> Any change requires updating this document AND all affected dbt models.

---

## Table: properties

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| property_code | VARCHAR | No | PK | Unique property identifier — format BRAND-COUNTRY-001 |
| property_name | VARCHAR | No | | Full property name e.g. Lumiere Hotels Paris |
| brand_code | VARCHAR | No | | Brand identifier — LUX, PRE, MID, ECO |
| brand_name | VARCHAR | No | | Brand display name |
| tier | VARCHAR | No | | Property tier — LUXURY, PREMIUM, MIDSCALE, ECONOMY |
| star_rating | INTEGER | No | | Star rating 2-5 |
| city | VARCHAR | No | | City name |
| country_code | VARCHAR | No | | ISO country code — FR, UK, DE, ES, IT, NL, BE, AE |
| local_currency | VARCHAR | No | | Local currency code — EUR, GBP, AED |
| total_rooms | INTEGER | No | | Total room count across all room types |
| has_restaurant | BOOLEAN | No | | Whether property has F&B outlet |
| has_parking | BOOLEAN | No | | Whether property has parking |
| has_spa | BOOLEAN | No | | Whether property has spa |
| created_at | DATE | No | | Property opening date in system |

---

## Table: room_types

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| room_type_id | VARCHAR | No | PK | Composite ID — PROPERTY_CODE-ROOM_TYPE_CODE |
| property_code | VARCHAR | No | FK → properties | Parent property |
| room_type_code | VARCHAR | No | | Opera room type code — STD, DBL, DLX-KNG etc |
| room_type_name | VARCHAR | No | | Display name — Standard Room, Deluxe King etc |
| is_accessible | BOOLEAN | No | | True for DBCH and TWCH accessible room types |
| total_rooms | INTEGER | No | | Number of rooms of this type in this property |
| max_occupancy | INTEGER | No | | Maximum guests per room |
| created_at | DATE | No | | Date added to system |

---

## Table: guests

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| guest_profile_id | VARCHAR | No | PK | Unique guest profile — format GSTPRF-00000001 |
| title | VARCHAR | Yes | | Salutation — Mr, Mrs, Ms, Dr, Prof |
| first_name | VARCHAR | No | | Guest first name — PII, masked in non-prod |
| last_name | VARCHAR | No | | Guest last name — PII, masked in non-prod |
| email | VARCHAR | Yes | | Guest email — PII, masked in non-prod |
| phone | VARCHAR | Yes | | Guest phone — PII, masked in non-prod |
| address | VARCHAR | Yes | | Guest address — PII, masked in non-prod |
| nationality_code | VARCHAR | Yes | | ISO 3-letter nationality code |
| is_avenir_member | BOOLEAN | No | | Whether guest is enrolled in AVENIR Rewards |
| has_invalid_name | BOOLEAN | No | | Ground truth — M1 fake/joke name flag |
| has_garbled_name | BOOLEAN | No | | Ground truth — M2 transliteration artifact flag |
| has_invalid_email | BOOLEAN | No | | Ground truth — M3 dummy email flag |
| has_missing_phone | BOOLEAN | No | | Ground truth — M4 missing phone flag |
| has_missing_address | BOOLEAN | No | | Ground truth — M5 missing address flag |
| created_at | DATE | No | | Profile creation date |

---

## Table: avenir_members

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| member_number | VARCHAR | No | PK | AVENIR member number — format ALL-0000000001 |
| guest_profile_id | VARCHAR | No | FK → guests | Parent guest profile |
| current_tier | VARCHAR | No | | Current tier — CLASSIC, SILVER, GOLD, PLATINUM, DIAMOND |
| join_date | DATE | No | | Date member enrolled in AVENIR programme |
| lifetime_nights | INTEGER | No | | Total qualifying nights since joining |
| lifetime_status_points | INTEGER | No | | Total status points ever earned |
| current_reward_points | INTEGER | No | | Redeemable reward points balance |
| created_at | DATE | No | | Record creation date |

---

## Table: reservations

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| confirmation_number | VARCHAR | No | PK | 9-digit numeric Opera confirmation number |
| property_code | VARCHAR | No | FK → properties | Property where reservation is held |
| guest_profile_id | VARCHAR | No | FK → guests | Guest making the reservation |
| room_type_id | VARCHAR | No | FK → room_types | Room type booked |
| room_type_booked | VARCHAR | No | | Room type code at time of booking |
| room_type_to_charge | VARCHAR | No | | Room type code for billing — same unless upgraded |
| was_upgraded | BOOLEAN | No | | True when room_type_booked != room_type_to_charge |
| room_number | VARCHAR | Yes | | Physical room number assigned at check-in |
| rate_code | VARCHAR | No | | Opera rate code — FLRA3, RA1, ARA1 etc |
| rate_channel | VARCHAR | No | | Derived channel — DIRECT, OTA_PRIMARY, OTA_SECONDARY, AVENIR_MEMBER etc |
| rate_flexibility | VARCHAR | No | | Derived flexibility — FLEXIBLE, SEMI_FLEX, SAVER, ADVANCE_SAVER |
| includes_breakfast | BOOLEAN | No | | True for RB* rate codes |
| market_segment | VARCHAR | No | | Derived segment — LEISURE, LOYALTY, CORPORATE, GROUP, MICE |
| booking_date | DATE | No | | Date reservation was made |
| check_in_date | DATE | No | | Arrival date |
| check_out_date | DATE | No | | Departure date |
| nights | INTEGER | No | | Length of stay in nights |
| adults | INTEGER | No | | Number of adults |
| children | INTEGER | No | | Number of children |
| booking_status | VARCHAR | No | | CONFIRMED, CHECKED_IN, CHECKED_OUT, CANCELLED, NO_SHOW |
| nightly_rate | FLOAT | No | | Rate per night in local currency |
| total_cost | FLOAT | No | | Total cost of stay in local currency |
| local_currency | VARCHAR | No | | Currency code — EUR, GBP, AED |
| travel_agent | VARCHAR | Yes | | OTA name — Booking.com, Expedia, blank for direct |
| tars_external_ref | VARCHAR | Yes | | TARS reference — filled for OTA, blank for direct |
| gds_record_locator | VARCHAR | Yes | | 8-char GDS locator for corporate/group bookings |
| is_direct_booking | BOOLEAN | No | | True when travel_agent is blank |
| member_number | VARCHAR | Yes | FK → avenir_members | AVENIR member number if guest is member |
| actual_checkin_at | TIMESTAMP | Yes | | Actual check-in timestamp — filled at check-in |
| is_duplicate_reservation | BOOLEAN | No | | Ground truth — M6 duplicate flag |
| is_test_record | BOOLEAN | No | | Ground truth — M7 test record flag |
| has_invalid_date_sequence | BOOLEAN | No | | Ground truth — M8 date sequence violation flag |

---

## Table: folios

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| folio_id | VARCHAR | No | PK | Unique folio charge ID — format FOL-0000000001 |
| confirmation_number | VARCHAR | No | FK → reservations | Parent reservation |
| window_number | INTEGER | No | | Billing window — 1 Room, 2 F&B, 3 Other |
| charge_type | VARCHAR | No | | ROOM, FB, OTHER |
| charge_description | VARCHAR | No | | Room Charge, Breakfast, Parking, Late Checkout etc |
| amount_local | FLOAT | No | | Charge amount in local currency |
| currency_code | VARCHAR | No | | Currency of charge |
| amount_eur | FLOAT | No | | Charge amount converted to EUR |
| payment_method | VARCHAR | No | | MasterCard, Visa, Amex, Cash, BankTransfer |
| card_last4 | VARCHAR | Yes | | Last 4 digits of card — blank for Cash/BankTransfer |
| payee | VARCHAR | No | | Guest, Bookingcom Agent, Expedia Collect etc |
| charge_date | DATE | No | | Date charge was posted |

---

## Table: cancellations

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| cancellation_id | VARCHAR | No | PK | Unique cancellation ID — format CXL-0000000001 |
| confirmation_number | VARCHAR | No | FK → reservations | Parent reservation |
| cancellation_date | DATE | No | | Date cancellation was processed |
| reason_code | VARCHAR | No | | Opera reason code — SDX, DUP, PLN, WEA etc |
| reason_group | VARCHAR | No | | GUEST_INITIATED, HOTEL_INITIATED, NO_SHOW, DUPLICATE, GROUP, SYSTEM |
| days_before_checkin | INTEGER | No | | Days between cancellation and original check-in |
| cancellation_window | VARCHAR | No | | SAME_DAY, LAST_MINUTE, SHORT, MEDIUM, ADVANCE |
| revenue_at_risk | FLOAT | No | | Total cost of cancelled reservation |
| currency_code | VARCHAR | No | | Currency of revenue_at_risk |

---

## Table: room_availability

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| availability_id | VARCHAR | No | PK | Unique availability record — format AVL-0000000001 |
| property_code | VARCHAR | No | FK → properties | Property |
| room_type_id | VARCHAR | No | FK → room_types | Room type |
| stay_date | DATE | No | | Calendar date |
| total_rooms | INTEGER | No | | Total rooms of this type in this property |
| ooo_rooms | INTEGER | No | | Rooms out of order — not sellable |
| rooms_available | INTEGER | No | | total_rooms - ooo_rooms — RevPAR denominator |

---

## Table: avenir_points_transactions

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| transaction_id | VARCHAR | No | PK | Unique transaction — format TXN-0000000001 |
| member_number | VARCHAR | No | FK → avenir_members | AVENIR member |
| confirmation_number | VARCHAR | No | FK → reservations | Source reservation |
| transaction_type | VARCHAR | No | | STAY, DINING, PARTNER, SHOPPING |
| transaction_date | DATE | No | | Date points were posted |
| status_points | INTEGER | No | | Status points earned — used for tier qualification |
| reward_points | INTEGER | No | | Reward points earned — used for redemption |
| tier_at_earn | VARCHAR | No | | Member tier at time of earning |
| property_code | VARCHAR | No | FK → properties | Property where points were earned |
| has_early_points | BOOLEAN | No | | Ground truth — M9 early points flag |

---

## Table: avenir_tier_history

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| history_id | VARCHAR | No | PK | Unique history record — format TH-0000000001 |
| member_number | VARCHAR | No | FK → avenir_members | AVENIR member |
| previous_tier | VARCHAR | Yes | | Previous tier — blank for NEW_MEMBER |
| new_tier | VARCHAR | No | | New tier after change |
| change_type | VARCHAR | No | | NEW_MEMBER, UPGRADE, DOWNGRADE, RETAINED |
| effective_date | DATE | No | | Date tier change took effect |
| status_points_at_change | INTEGER | No | | Status points balance at time of change |

---

## Change Log

| Date | Change | Reason | Impact |
|---|---|---|---|
| Sep 2026 | Initial schema lock | Phase 0 completion | All downstream models |