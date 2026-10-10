# AVENOIREL — Raw Tables Reference Guide

> This document explains every raw table, what it represents in the real world,
> what each column means, and how it connects to real hospitality operations.
> Use this when building intermediate and mart models to understand where data comes from.

---

## Table: properties

### What is this table?

In a real hotel group, every hotel is a distinct legal and operational entity.
The central corporate system maintains a master list of all properties —
their location, brand, capacity, and facilities.

In Opera Cloud, this is called the "Property Configuration" — set up once
when a hotel joins the group and updated when facilities change.

**Real world equivalent:** Accor's property master data in Opera Cloud.
Every Sofitel, Novotel, Ibis in the network has one record here.

**One row = one hotel property.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `property_code` | VARCHAR | `LUX-FR-001` | Unique identifier — format is BRAND-COUNTRY-NUMBER. Primary key. Never changes once assigned. |
| `property_name` | VARCHAR | `Lumiere Hotels Paris` | Full display name of the hotel. Used in reports and dashboards. |
| `brand_code` | VARCHAR | `LUX` | Which brand this property belongs to — LUX, PRE, MID, ECO. Links to brands seed table. |
| `brand_name` | VARCHAR | `Lumiere Hotels` | Display name of the brand. Redundant with brand_code but useful for direct reporting. |
| `tier` | VARCHAR | `LUXURY` | Tier classification — LUXURY, PREMIUM, MIDSCALE, ECONOMY. Drives pricing strategy. |
| `star_rating` | INTEGER | `5` | Official star rating 2-5. Set by national tourism authority. |
| `city` | VARCHAR | `Paris` | City where the hotel is located. Used for geographic analysis. |
| `country_code` | VARCHAR | `FR` | ISO 2-letter country code. Used for regional reporting and GDPR compliance. |
| `local_currency` | VARCHAR | `EUR` | Currency used at this property. GBP for UK, AED for UAE, EUR for all others. |
| `total_rooms` | INTEGER | `156` | Total room count across all room types. Used as capacity baseline. |
| `has_restaurant` | BOOLEAN | `true` | Whether property has F&B outlet. Affects TRevPAR calculation. |
| `has_parking` | BOOLEAN | `true` | Whether property has parking. Affects ancillary revenue potential. |
| `has_spa` | BOOLEAN | `true` | Whether property has spa. LUXURY and PREMIUM only. |
| `created_at` | DATE | `2021-01-01` | Date property was added to the system. |

### Example Row

property_code: LUX-FR-001
property_name: Lumiere Hotels Paris
brand_code: LUX
brand_name: Lumiere Hotels
tier: LUXURY
star_rating: 5
city: Paris
country_code: FR
local_currency: EUR
total_rooms: 156
has_restaurant: true
has_parking: true
has_spa: true
created_at: 2021-01-01


### Real World Connection

In a real hotel group, the Revenue Management team queries this table constantly —
"show me all 5-star properties in France" or "which properties have a spa?"
The property master data is the foundation of every report. Without it,
you cannot segment analysis by brand, tier, or geography.

---

## Table: room_types

### What is this table?

Every hotel has multiple room categories — a Standard room is priced differently
from a Suite. Each category has a fixed number of physical rooms and different
capacity constraints.

In Opera Cloud, room types are configured per property in "Room Type Configuration."
A Novotel in Paris might have STD, SUP, DLX, FAM, STE-JNR. The same brand in
London might have slightly different room types based on the building.

**Real world equivalent:** Opera Cloud Room Type setup per property.

**One row = one room type in one property.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `room_type_id` | VARCHAR | `LUX-FR-001-DLX-KNG` | Composite unique ID — property_code + room_type_code. Primary key. |
| `property_code` | VARCHAR | `LUX-FR-001` | Which property this room type belongs to. Foreign key to properties. |
| `room_type_code` | VARCHAR | `DLX-KNG` | Opera room type code. Standard codes used across the industry. |
| `room_type_name` | VARCHAR | `Deluxe King` | Display name. Used in guest-facing systems and reports. |
| `is_accessible` | BOOLEAN | `false` | True for DBCH and TWCH — accessible rooms for guests with disabilities. |
| `total_rooms` | INTEGER | `24` | How many physical rooms of this type exist in this property. RevPAR denominator component. |
| `max_occupancy` | INTEGER | `2` | Maximum guests allowed. Twins and doubles = 2, family rooms = 3. |
| `created_at` | DATE | `2021-01-01` | Date room type was configured. |

### Example Row

room_type_id: LUX-FR-001-DLX-KNG
property_code: LUX-FR-001
room_type_code: DLX-KNG
room_type_name: Deluxe King
is_accessible: false
total_rooms: 24
max_occupancy: 2
created_at: 2021-01-01


### Real World Connection

Room type data is critical for Revenue Management. A Revenue Manager tracks
occupancy and ADR separately per room type — Suites command a premium price
and should never be discounted. Standard rooms drive volume. Knowing how many
rooms exist per type is the denominator in every occupancy calculation.

---

## Table: guests

### What is this table?

Every guest who makes a booking gets a profile in Opera — even OTA bookings
where the guest data comes from Booking.com or Expedia. Guest profiles accumulate
over time — a loyal guest who visits 20 times still has one profile.

In Opera Cloud, this is the "Guest Profile" module — the central CRM of the PMS.

**Real world equivalent:** Opera Cloud Guest Profile / CRM.

**One row = one unique guest profile.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `guest_profile_id` | VARCHAR | `GSTPRF-00000001` | Unique Opera profile ID. System generated. Never changes. |
| `title` | VARCHAR | `Mr` | Salutation. Manually entered at check-in or from OTA. |
| `first_name` | VARCHAR | `James` | Guest first name. PII — masked in non-prod. |
| `last_name` | VARCHAR | `Wilson` | Guest last name. PII — masked in non-prod. |
| `email` | VARCHAR | `j.wilson@email.com` | Guest email. PII. Often missing for OTA bookings — OTA keeps it. |
| `phone` | VARCHAR | `+44 7700 900123` | Guest phone. PII. Often missing for OTA bookings. |
| `address` | VARCHAR | `14 Baker Street, London` | Guest address. PII. Often incomplete. |
| `nationality_code` | VARCHAR | `GBR` | ISO 3-letter nationality. Used for tourism reporting. |
| `is_avenir_member` | BOOLEAN | `true` | Whether guest is in the loyalty programme. |
| `has_invalid_name` | BOOLEAN | `false` | Ground truth flag — M1 fake name injected deliberately. |
| `has_garbled_name` | BOOLEAN | `false` | Ground truth flag — M2 transliteration artifact. |
| `has_invalid_email` | BOOLEAN | `false` | Ground truth flag — M3 dummy email. |
| `has_missing_phone` | BOOLEAN | `true` | Ground truth flag — M4 missing phone. |
| `has_missing_address` | BOOLEAN | `true` | Ground truth flag — M5 missing address. |
| `created_at` | DATE | `2020-03-15` | Date profile was first created in Opera. |

### Real World Connection

Guest profiles are gold in hospitality. A returning guest's profile tells
the hotel their preferences, previous complaints, room upgrades given, spend history.
The loyalty programme builds on top of guest profiles — every AVENIR member
has a guest profile. OTA bookings create "thin" profiles with minimal data
because OTAs protect guest data — a key reason hotels push for direct bookings.

---

## Table: avenir_members

### What is this table?

The loyalty programme membership table. Not all guests are members — roughly
65% in our dataset. Members earn points on stays, which count toward tier status.

In real hotel groups, this data lives in a separate loyalty platform —
not Opera itself. Opera and the loyalty system sync via API after checkout.

**Real world equivalent:** Accor ALL (Accor Live Limitless) programme database.
In our simulation this is called AVENIR Rewards.

**One row = one loyalty programme membership.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `member_number` | VARCHAR | `ALL-0000000001` | Unique membership number. Format mirrors Accor ALL numbers. |
| `guest_profile_id` | VARCHAR | `GSTPRF-00000001` | Links to the guest profile. One member = one guest. |
| `current_tier` | VARCHAR | `GOLD` | Current tier — CLASSIC, SILVER, GOLD, PLATINUM, DIAMOND. |
| `join_date` | DATE | `2020-05-01` | When guest enrolled in the programme. |
| `lifetime_nights` | INTEGER | `47` | Total qualifying nights since joining. Determines tier eligibility. |
| `lifetime_status_points` | INTEGER | `3820` | Total status points ever earned. Used for tier qualification. |
| `current_reward_points` | INTEGER | `1240` | Redeemable reward points balance. Can be spent on free nights, upgrades. |
| `created_at` | DATE | `2020-05-01` | Date membership record was created. |

### Real World Connection

Two separate point currencies is non-negotiable in real loyalty programmes.
Status Points determine your tier — you need 30 nights or equivalent to reach GOLD.
Reward Points are currency — you spend them on free nights or upgrades.
Earning rates differ by tier — a DIAMOND member earns 3x more reward points
than a CLASSIC member for the same stay. This is the core mechanic that drives
loyalty behaviour.

---

## Table: reservations

### What is this table?

The most important table in the entire system. Every booking — whether made
directly, through Booking.com, a corporate account, or a group contract —
creates one reservation record in Opera.

This is the heartbeat of hotel operations. Front desk staff work in this table
all day — checking guests in, modifying bookings, processing cancellations.

**Real world equivalent:** Opera Cloud Reservation module.

**One row = one booking.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `confirmation_number` | VARCHAR | `483920175` | 9-digit unique Opera confirmation number. Given to guest at booking. |
| `property_code` | VARCHAR | `LUX-FR-001` | Which hotel this booking is for. |
| `guest_profile_id` | VARCHAR | `GSTPRF-00000001` | Which guest made this booking. |
| `room_type_id` | VARCHAR | `LUX-FR-001-DLX-KNG` | Which room type was booked. |
| `room_type_booked` | VARCHAR | `DLX-KNG` | Room type code at time of booking. |
| `room_type_to_charge` | VARCHAR | `STE-JNR` | Room type for billing — different if guest was upgraded. |
| `was_upgraded` | BOOLEAN | `true` | True when room_type_booked != room_type_to_charge. |
| `room_number` | VARCHAR | `412` | Physical room assigned at check-in. Null before arrival. |
| `rate_code` | VARCHAR | `FLRA3` | Opera rate code. Encodes channel, flexibility, breakfast. |
| `rate_channel` | VARCHAR | `OTA_PRIMARY` | Derived — which channel this booking came through. |
| `rate_flexibility` | VARCHAR | `SAVER` | Derived — cancellation flexibility tier. |
| `includes_breakfast` | BOOLEAN | `false` | True for RB rate codes. |
| `market_segment` | VARCHAR | `LEISURE` | Derived — LEISURE, LOYALTY, CORPORATE, GROUP, MICE. |
| `booking_date` | DATE | `2024-01-02` | When the reservation was made. |
| `check_in_date` | DATE | `2024-03-15` | Arrival date. |
| `check_out_date` | DATE | `2024-03-18` | Departure date. |
| `nights` | INTEGER | `3` | Length of stay. check_out - check_in. |
| `adults` | INTEGER | `2` | Number of adults. |
| `children` | INTEGER | `0` | Number of children. |
| `booking_status` | VARCHAR | `CHECKED_OUT` | Current status — CONFIRMED, CHECKED_IN, CHECKED_OUT, CANCELLED, NO_SHOW. |
| `nightly_rate` | FLOAT | `185.00` | Rate per night in local currency. |
| `total_cost` | FLOAT | `555.00` | nightly_rate × nights. |
| `local_currency` | VARCHAR | `EUR` | Currency of this booking. |
| `travel_agent` | VARCHAR | `Booking.com` | OTA name. Blank for direct bookings. |
| `tars_external_ref` | VARCHAR | `4839201750@001` | TARS reference — Accor's central reservation system ref for OTA bookings. |
| `gds_record_locator` | VARCHAR | `ABCD1234` | GDS locator for corporate/group bookings. |
| `is_direct_booking` | BOOLEAN | `false` | True when travel_agent is blank. Key metric for distribution strategy. |
| `member_number` | VARCHAR | `ALL-0000000001` | AVENIR member number if guest is a member. |
| `actual_checkin_at` | TIMESTAMP | `2024-03-15 14:30:00` | Actual check-in time. Null before arrival. |
| `is_duplicate_reservation` | BOOLEAN | `false` | Ground truth — M6 duplicate injected deliberately. |
| `is_test_record` | BOOLEAN | `false` | Ground truth — M7 test record injected deliberately. |
| `has_invalid_date_sequence` | BOOLEAN | `false` | Ground truth — M8 check_out before check_in. |

### Real World Connection

Rate codes are the language of hotel distribution. `FLRA3` means:
FL = via OTA (Flat Rate), R = room only, A = primary OTA channel, 3 = saver/non-refundable.
Revenue Managers obsess over the mix of rate codes — too many FLRA3 means
too much OTA dependency and high commission costs. The goal is to shift guests
from OTA to direct (`RA3`) — same price for the guest, but the hotel saves
15-25% commission. `is_direct_booking` is one of the most watched metrics.

TARS reference is blank for direct bookings — this is how you definitively
identify a direct booking in Opera even if the rate code is ambiguous.

---

## Table: folios

### What is this table?

When a guest checks out, every charge during their stay is itemised in their
folio — like a detailed bill. Room charges, restaurant meals, parking, spa visits,
minibar — each gets its own line item.

In Opera, folios are organised into "windows" — Window 1 is typically room charges
(often paid by the OTA or corporate account), Window 2 is F&B and extras
(always paid by the guest directly).

**Real world equivalent:** Opera Cloud Folio / Cashiering module.

**One row = one charge line item on a reservation.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `folio_id` | VARCHAR | `FOL-0000000001` | Unique folio line ID. |
| `confirmation_number` | VARCHAR | `483920175` | Which reservation this charge belongs to. |
| `window_number` | INTEGER | `1` | Billing window — 1 Room, 2 F&B, 3 Other. |
| `charge_type` | VARCHAR | `ROOM` | Category — ROOM, FB, OTHER. |
| `charge_description` | VARCHAR | `Room Charge` | Specific description — Room Charge, Breakfast, Parking, Late Checkout etc. |
| `amount_local` | FLOAT | `185.00` | Charge amount in local currency. |
| `currency_code` | VARCHAR | `EUR` | Currency of this charge. |
| `amount_eur` | FLOAT | `185.00` | Charge converted to EUR for group-level reporting. |
| `payment_method` | VARCHAR | `Visa` | How this charge was paid. |
| `card_last4` | VARCHAR | `4729` | Last 4 digits of card. Null for cash. |
| `payee` | VARCHAR | `Bookingcom Agent` | Who paid — Guest, OTA agent, corporate account. |
| `charge_date` | DATE | `2024-03-18` | Date charge was posted — typically checkout date. |

### Real World Connection

Folios are the source of TRevPAR — Total Revenue Per Available Room.
RevPAR only counts room revenue. TRevPAR adds F&B, spa, parking, and all
ancillary revenue. A luxury hotel's TRevPAR can be 40-60% higher than its
RevPAR — guests spend significantly on restaurants and spa.

The payee field reveals distribution cost — when payee is "Bookingcom Agent",
Booking.com collects from the guest and remits to the hotel minus commission.
When payee is "Guest", the hotel collects directly.

---

## Table: cancellations

### What is this table?

When a reservation is cancelled, Opera creates a cancellation record with
the reason code. These reason codes are standardised across Opera installations —
the same codes appear in hotels worldwide.

**Real world equivalent:** Opera Cloud Cancellation module.

**One row = one cancellation.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `cancellation_id` | VARCHAR | `CXL-0000000001` | Unique cancellation ID. |
| `confirmation_number` | VARCHAR | `483920175` | Which reservation was cancelled. |
| `cancellation_date` | DATE | `2024-03-10` | When cancellation was processed. |
| `reason_code` | VARCHAR | `SDX` | Opera reason code. SDX = Same Day cancellation. |
| `reason_group` | VARCHAR | `GUEST_INITIATED` | Grouped category — GUEST_INITIATED, HOTEL_INITIATED, NO_SHOW, DUPLICATE, GROUP, SYSTEM. |
| `days_before_checkin` | INTEGER | `5` | Days between cancellation and original check-in. |
| `cancellation_window` | VARCHAR | `SHORT` | Timing bucket — SAME_DAY, LAST_MINUTE, SHORT, MEDIUM, ADVANCE. |
| `revenue_at_risk` | FLOAT | `555.00` | Total cost of the cancelled booking — revenue that was lost. |
| `currency_code` | VARCHAR | `EUR` | Currency of revenue at risk. |

### Real World Connection

Cancellation analysis is critical for Revenue Management. A hotel with 30%
cancellation rate needs to overbook strategically — if you have 100 rooms
and expect 30% cancellation, you sell 130 rooms. Getting this wrong in either
direction costs money — too many cancellations means empty rooms, too few
means walking guests (paying them to go to a competitor).

SDX (same-day) cancellations are the most damaging — there is no time to
resell the room. Hotels track SDX rate obsessively and design rate policies
(non-refundable rates) to minimise them.

---

## Table: room_availability

### What is this table?

Every day, for every room type in every property, the system records how many
rooms are available to sell. This is NOT the same as total rooms — some rooms
may be Out of Order (OOO) due to maintenance, renovation, or damage.

This table is the denominator in every RevPAR calculation.
Without accurate availability data, RevPAR is meaningless.

**Real world equivalent:** Opera Cloud Room Management / Inventory module.

**One row = one property + one room type + one date.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `availability_id` | VARCHAR | `AVL-0000000001` | Unique availability record ID. |
| `property_code` | VARCHAR | `LUX-FR-001` | Which property. |
| `room_type_id` | VARCHAR | `LUX-FR-001-STD` | Which room type. |
| `stay_date` | DATE | `2024-01-15` | The calendar date this record covers. |
| `total_rooms` | INTEGER | `24` | Total physical rooms of this type. Never changes. |
| `ooo_rooms` | INTEGER | `2` | Rooms Out of Order — maintenance, renovation, damage. Not sellable. |
| `rooms_available` | INTEGER | `22` | total_rooms - ooo_rooms. This is the RevPAR denominator. |

### Real World Connection

OOO vs OOS distinction matters in real operations:
- OOO (Out of Order) — room cannot be sold. Reduces available inventory.
- OOS (Out of Service) — room has minor issue but can still be sold if needed.

Only OOO rooms reduce the RevPAR denominator. OOS rooms still count as available.
This is why our table only tracks OOO — consistent with industry practice.

In real Opera, the Revenue Manager updates OOO rooms daily — a burst pipe on
Floor 3 means 8 rooms go OOO immediately, which changes tonight's RevPAR target.

---

## Table: avenir_points_transactions

### What is this table?

After a guest checks out, the loyalty system posts their points. This happens
outside Opera — a nightly batch job reads Opera checkout data and posts
points to the loyalty platform. This is why points appear 24-48 hours after
checkout in real programmes.

Status Points and Reward Points are completely separate currencies with different
earning rates, accumulation rules, and redemption mechanisms.

**Real world equivalent:** Accor ALL programme points ledger.

**One row = one points posting transaction.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `transaction_id` | VARCHAR | `TXN-0000000001` | Unique transaction ID. |
| `member_number` | VARCHAR | `ALL-0000000001` | Which member earned these points. |
| `confirmation_number` | VARCHAR | `483920175` | Which stay triggered this posting. |
| `transaction_type` | VARCHAR | `STAY` | What activity earned points — STAY, DINING, PARTNER, SHOPPING. |
| `transaction_date` | DATE | `2024-03-19` | When points were posted — typically 1-7 days after checkout. |
| `status_points` | INTEGER | `120` | Status points earned — count toward tier qualification. |
| `reward_points` | INTEGER | `74` | Reward points earned — redeemable for free nights, upgrades. |
| `tier_at_earn` | VARCHAR | `GOLD` | Member's tier when points were earned — affects earning multiplier. |
| `property_code` | VARCHAR | `LUX-FR-001` | Where points were earned. |
| `has_early_points` | BOOLEAN | `false` | Ground truth — M9 points posted before checkout date. |

### Real World Connection

The 24-48 hour delay in points posting is intentional — the hotel needs to
finalise the folio (all charges settled) before posting points. If points posted
at check-in, a guest could check out early or dispute charges after points were
already awarded.

DINING and PARTNER transactions come from Accor's broader ecosystem —
restaurants, Europcar rentals, airport transfers. These earn Reward Points
but typically not Status Points. This is how Accor differentiates the
two currencies in practice.

---

## Table: avenir_tier_history

### What is this table?

Every time a member's tier changes — upgrade, downgrade, new member enrollment —
a record is created. This allows tracking of loyalty programme health over time:
are members progressing upward or churning?

**Real world equivalent:** Accor ALL tier change audit log.

**One row = one tier change event.**

### Columns

| Column | Data Type | Example | What it means |
|---|---|---|---|
| `history_id` | VARCHAR | `TH-0000000001` | Unique history record ID. |
| `member_number` | VARCHAR | `ALL-0000000001` | Which member had a tier change. |
| `previous_tier` | VARCHAR | `SILVER` | Tier before the change. Null for NEW_MEMBER. |
| `new_tier` | VARCHAR | `GOLD` | Tier after the change. |
| `change_type` | VARCHAR | `UPGRADE` | Type — NEW_MEMBER, UPGRADE, DOWNGRADE, RETAINED. |
| `effective_date` | DATE | `2024-06-01` | When new tier took effect. |
| `status_points_at_change` | INTEGER | `2400` | Status points balance at time of change. |

### Real World Connection

Tier downgrades are one of the most sensitive moments in loyalty management.
When a PLATINUM member drops to GOLD because they did not travel enough,
they often write angry emails. Hotels track downgrade rates carefully and
sometimes offer "tier matches" or "tier extensions" to retain high-value members.

RETAINED change type means a member qualified for their current tier again —
they stayed enough nights to keep their status. This is tracked separately
from upgrades because retention is as valuable as acquisition.

---

*AVENOIREL Raw Tables Reference — built on real Opera Cloud data structures*