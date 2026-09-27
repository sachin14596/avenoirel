"""
AVENOIREL Data Generator
========================
Generates synthetic hospitality data mimicking Opera Cloud PMS output.
Produces clean CSVs first, then injects deliberate messiness.

Output:
    data/clean/  - Clean data (ground truth)
    data/raw/    - Messy data (what dbt will process)

Usage:
    python scripts/generate_data.py --rows 100   # validation run
    python scripts/generate_data.py --rows full  # full dataset
"""

import argparse
import csv
import os
import random
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

import pandas as pd
import yaml
from faker import Faker

# ── Configuration ──────────────────────────────────────────────────────────────

def load_config(config_path: str = "scripts/generator_config.yaml") -> dict:
    """Load generator configuration from YAML file."""
    with open(config_path, "r") as f:
        return yaml.safe_load(f)

# ── Paths ──────────────────────────────────────────────────────────────────────

CLEAN_DIR = Path("data/clean")
RAW_DIR   = Path("data/raw")

def setup_directories():
    """Create output directories if they don't exist."""
    CLEAN_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)

# ── Utilities ──────────────────────────────────────────────────────────────────

def random_date(start: date, end: date) -> date:
    """Return a random date between start and end inclusive."""
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def save_csv(records: list[dict], filename: str, directory: Path):
    """Save a list of dicts to CSV."""
    if not records:
        print(f"  WARNING: No records to save for {filename}")
        return
    filepath = directory / filename
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)
    print(f"  Saved {len(records):,} rows → {filepath}")

# ── Generator: Properties ──────────────────────────────────────────────────────

def generate_properties(config: dict) -> list[dict]:
    """
    Generate hotel properties across 4 brands and 8 countries.
    Property code format: BRAND-COUNTRY-001
    """
    print("Generating properties...")
    properties = []
    
    cities = {
        "FR": ["Paris", "Lyon", "Marseille", "Nice", "Bordeaux", "Toulouse", "Strasbourg", "Lille"],
        "UK": ["London", "Manchester", "Edinburgh", "Birmingham", "Bristol", "Liverpool"],
        "DE": ["Berlin", "Munich", "Hamburg", "Frankfurt", "Cologne"],
        "ES": ["Madrid", "Barcelona", "Seville", "Valencia"],
        "IT": ["Rome", "Milan", "Florence", "Venice"],
        "NL": ["Amsterdam", "Rotterdam"],
        "BE": ["Brussels", "Antwerp"],
        "AE": ["Dubai"],
    }

    country_currencies = {c['code']: c['currency'] for c in config['countries']}

    for brand in config['brands']:
        brand_code     = brand['code']
        brand_name     = brand['name']
        tier           = brand['tier']
        star_rating    = brand['star_rating']
        property_count = brand['property_count']
        avg_rooms      = brand['avg_rooms']

        # Distribute properties across countries
        country_codes = [c['code'] for c in config['countries']]
        assigned_countries = []
        for i in range(property_count):
            assigned_countries.append(country_codes[i % len(country_codes)])

        country_counter = {}
        for country_code in assigned_countries:
            country_counter[country_code] = country_counter.get(country_code, 0) + 1
            prop_num      = country_counter[country_code]
            property_code = f"{brand_code}-{country_code}-{prop_num:03d}"
            city_list     = cities.get(country_code, ["Unknown"])
            city          = city_list[(prop_num - 1) % len(city_list)]
            total_rooms   = int(random.gauss(avg_rooms, avg_rooms * 0.15))
            total_rooms   = max(50, min(300, total_rooms))

            properties.append({
                "property_code":   property_code,
                "property_name":   f"{brand_name} {city}",
                "brand_code":      brand_code,
                "brand_name":      brand_name,
                "tier":            tier,
                "star_rating":     star_rating,
                "city":            city,
                "country_code":    country_code,
                "local_currency":  country_currencies[country_code],
                "total_rooms":     total_rooms,
                "has_restaurant":  tier in ("LUXURY", "PREMIUM", "MIDSCALE"),
                "has_parking":     True,
                "has_spa":         tier in ("LUXURY", "PREMIUM"),
                "created_at":      "2021-01-01",
            })

    return properties

# ── Generator: Room Types ──────────────────────────────────────────────────────

def generate_room_types(properties: list[dict], config: dict) -> list[dict]:
    """
    Generate room types for each property.
    Each brand has its own set of room type codes.
    Room counts per type are distributed from property's total_rooms.
    """
    print("Generating room types...")
    room_types = []

    brand_room_types = {b['code']: b['room_types'] for b in config['brands']}

    room_type_names = {
        "STD":     "Standard Room",
        "DBL":     "Double Room",
        "TWI":     "Twin Room",
        "DBCH":    "Double Accessible",
        "TWCH":    "Twin Accessible",
        "SUP":     "Superior Room",
        "FAM":     "Family Room",
        "DLX":     "Deluxe Room",
        "DLX-KNG": "Deluxe King",
        "DLX-TWN": "Deluxe Twin",
        "EXE":     "Executive Room",
        "STE-JNR": "Junior Suite",
        "STE-EXE": "Executive Suite",
        "STE-GRD": "Grand Suite",
        "PNT":     "Penthouse",
    }

    accessible_codes = {"DBCH", "TWCH"}

    for prop in properties:
        brand_code   = prop['brand_code']
        rt_codes     = brand_room_types[brand_code]
        total_rooms  = prop['total_rooms']
        n_types      = len(rt_codes)

        # Distribute total rooms across room types
        base_rooms   = total_rooms // n_types
        remainder    = total_rooms % n_types

        for i, rt_code in enumerate(rt_codes):
            rooms_for_type = base_rooms + (1 if i < remainder else 0)
            # Accessible rooms are always a small number
            if rt_code in accessible_codes:
                rooms_for_type = max(2, rooms_for_type // 5)

            room_types.append({
                "room_type_id":   f"{prop['property_code']}-{rt_code}",
                "property_code":  prop['property_code'],
                "room_type_code": rt_code,
                "room_type_name": room_type_names.get(rt_code, rt_code),
                "is_accessible":  rt_code in accessible_codes,
                "total_rooms":    rooms_for_type,
                "max_occupancy":  2 if "TWI" in rt_code or "DBL" in rt_code or rt_code == "STD" else 3,
                "created_at":     "2021-01-01",
            })

    return room_types

# ── Generator: Guests ──────────────────────────────────────────────────────────

def generate_guests(config: dict, fake: Faker) -> list[dict]:
    """
    Generate guest profiles — every booking has a guest profile in Opera.
    ~65% of guests are AVENIR members.
    Includes deliberate messiness in names, emails, phones.
    """
    print("Generating guests...")
    guests = []

    guest_count     = config['scale']['guests']
    member_pct      = 0.65
    nationalities   = ["GBR", "FRA", "DEU", "ESP", "ITA", "NLD", "BEL", "USA",
                       "CHN", "JPN", "KOR", "IND", "AUS", "CAN", "BRA", "ARE"]
    nationality_weights = [20, 15, 12, 8, 8, 5, 5, 8, 4, 3, 2, 2, 2, 2, 2, 2]
    titles          = ["Mr", "Mrs", "Ms", "Dr", "Prof"]
    title_weights   = [40, 25, 25, 7, 3]

    fake_names      = ["Hello World", "I Am Ironman", "Test Guest", "World Is Bad",
                       "John Doe123", "World Is Ending", "Asdf Qwerty"]

    garbled_names   = ["Xio Mng Wng", "Km Jwn", "Zng Wei Ln", "Pk Shn",
                       "Chn Yn", "Lm Jng Wn", "Bk Jn Ho"]

    for i in range(guest_count):
        guest_id      = f"GSTPRF-{i+1:08d}"
        nationality   = random.choices(nationalities, weights=nationality_weights)[0]
        title         = random.choices(titles, weights=title_weights)[0]
        is_member     = random.random() < member_pct

        # Clean name generation
        first_name    = fake.first_name()
        last_name     = fake.last_name()

        # M1: Fake/joke names — 1%
        has_invalid_name = False
        if random.random() < config['messiness']['fake_names_pct']:
            parts         = random.choice(fake_names).split()
            first_name    = parts[0]
            last_name     = parts[1] if len(parts) > 1 else parts[0]
            has_invalid_name = True

        # M2: Garbled transliteration — 2%
        has_garbled_name = False
        if not has_invalid_name and random.random() < config['messiness']['garbled_names_pct']:
            parts         = random.choice(garbled_names).split()
            first_name    = parts[0]
            last_name     = parts[1] if len(parts) > 1 else parts[0]
            has_garbled_name = True

        # M3: Dummy/missing email — 8%
        has_invalid_email = False
        if random.random() < config['messiness']['dummy_email_pct']:
            email         = random.choice(["test@test.com", "noemail@noemail.com",
                                           "unknown@unknown.com", ""])
            has_invalid_email = True
        else:
            email         = fake.email()

        # M4: Missing phone — 15%
        has_missing_phone = False
        if random.random() < config['messiness']['missing_phone_pct']:
            phone         = ""
            has_missing_phone = True
        else:
            phone         = fake.phone_number()

        # M5: Missing address — 20%
        has_missing_address = False
        if random.random() < config['messiness']['missing_address_pct']:
            address       = ""
            has_missing_address = True
        else:
            address       = fake.street_address()

        guests.append({
            "guest_profile_id":    guest_id,
            "title":               title,
            "first_name":          first_name,
            "last_name":           last_name,
            "email":               email,
            "phone":               phone,
            "address":             address,
            "nationality_code":    nationality,
            "is_avenir_member":    is_member,
            # Ground truth flags
            "has_invalid_name":    has_invalid_name,
            "has_garbled_name":    has_garbled_name,
            "has_invalid_email":   has_invalid_email,
            "has_missing_phone":   has_missing_phone,
            "has_missing_address": has_missing_address,
            "created_at":          fake.date_between(
                                       start_date=date(2019, 1, 1),
                                       end_date=date(2022, 1, 1)
                                   ).isoformat(),
        })

    return guests

# ── Generator: Avenir Members ─────────────────────────────────────────────────

def generate_avenir_members(guests: list[dict], config: dict) -> list[dict]:
    """
    Generate AVENIR Rewards membership records.
    Only guests with is_avenir_member = True get a record here.
    Two separate point types: status_points and reward_points.
    Tier is derived from lifetime_status_points.
    """
    print("Generating AVENIR members...")
    members = []

    tiers = config['avenir_tiers']

    def get_tier(nights: int) -> str:
        for tier in tiers:
            if tier['min_nights'] <= nights <= tier['max_nights']:
                return tier['name']
        return "CLASSIC"

    member_num = 1
    for guest in guests:
        if not guest['is_avenir_member']:
            continue

        # Lifetime nights determines tier
        lifetime_nights        = random.choices(
            [random.randint(0, 9),     # CLASSIC
             random.randint(10, 29),   # SILVER
             random.randint(30, 59),   # GOLD
             random.randint(60, 99),   # PLATINUM
             random.randint(100, 300)],# DIAMOND
            weights=[40, 25, 20, 10, 5]
        )[0]

        current_tier           = get_tier(lifetime_nights)
        lifetime_status_points = lifetime_nights * random.randint(8, 15)
        current_reward_points  = random.randint(0, lifetime_status_points // 3)

        join_date = date.fromisoformat(guest['created_at']) + timedelta(
            days=random.randint(0, 180)
        )

        members.append({
            "member_number":          f"ALL-{member_num:010d}",
            "guest_profile_id":       guest['guest_profile_id'],
            "current_tier":           current_tier,
            "join_date":              join_date.isoformat(),
            "lifetime_nights":        lifetime_nights,
            "lifetime_status_points": lifetime_status_points,
            "current_reward_points":  current_reward_points,
            "created_at":             join_date.isoformat(),
        })
        member_num += 1

    return members

# ── Generator: Reservations ───────────────────────────────────────────────────

def generate_reservations(
    properties: list[dict],
    room_types: list[dict],
    guests: list[dict],
    avenir_members: list[dict],
    config: dict,
    reservation_count: int,
) -> list[dict]:
    """
    Generate reservation records mimicking Opera Cloud PMS output.
    Core business entity — every other table links back to this.
    """
    print("Generating reservations...")
    reservations = []

    data_start  = date.fromisoformat(config['scale']['data_start_date'])
    data_end    = date.fromisoformat(config['scale']['data_end_date'])

    # Build lookup indexes for performance
    prop_list   = properties
    member_ids  = {m['guest_profile_id']: m for m in avenir_members}

    # Room types per property
    rt_by_prop  = {}
    for rt in room_types:
        rt_by_prop.setdefault(rt['property_code'], []).append(rt)

    # Rate code channel mapping
    rate_channel_map = {}
    rate_flex_map    = {}
    rate_bb_map      = {}

    for channel, subcats in config['rate_codes'].items():
        if isinstance(subcats, dict):
            for flex, codes in subcats.items():
                for code in codes:
                    rate_channel_map[code] = channel.upper()
                    rate_flex_map[code]    = flex.upper()
                    rate_bb_map[code]      = code.endswith('B') or 'BB' in code or code.startswith('RB') or code.startswith('ARB') or code.startswith('FLRB') or code.startswith('FLMRB')
        elif isinstance(subcats, list):
            for code in subcats:
                rate_channel_map[code] = channel.upper()
                rate_flex_map[code]    = "STANDARD"
                rate_bb_map[code]      = 'BB' in code

    # Travel agent names per channel
    travel_agents = {
        "OTA_PRIMARY":   ["Booking.com", "Booking.com", "Booking.com", "Agoda"],
        "OTA_SECONDARY": ["Expedia", "Expedia", "Hotels.com"],
        "GROUP":         ["Group Direct", "Event Coordinator"],
        "CORPORATE":     ["", "Corporate Account"],
    }

    # Booking status distribution
    statuses        = ["CHECKED_OUT", "CANCELLED", "NO_SHOW", "CONFIRMED", "CHECKED_IN"]
    status_weights  = [65, 20, 3, 8, 4]

    # Seasonality weights per month (UK/Europe pattern)
    monthly_weights = [3, 3, 5, 7, 9, 12, 13, 13, 11, 9, 7, 8]

    confirmation_nums = set()

    for i in range(reservation_count):
        # Pick property weighted by brand reservation volume
        prop            = random.choice(prop_list)
        prop_code       = prop['property_code']
        brand_code      = prop['brand_code']

        # Pick room type for this property
        prop_rts        = rt_by_prop.get(prop_code, [])
        if not prop_rts:
            continue
        room_type       = random.choice(prop_rts)
        room_type_code  = room_type['room_type_code']

        # Pick guest
        guest           = random.choice(guests)
        guest_id        = guest['guest_profile_id']
        is_member       = guest_id in member_ids
        member          = member_ids.get(guest_id)

        # Booking date — weighted by seasonality
        month           = random.choices(range(1, 13), weights=monthly_weights)[0]
        year            = random.choice([2022, 2023, 2024])
        try:
            booking_date = date(year, month, random.randint(1, 28))
        except ValueError:
            booking_date = date(year, month, 1)

        if booking_date > data_end:
            booking_date = data_end - timedelta(days=1)

        # Lead time: days between booking and check-in
        lead_days       = random.choices(
            [random.randint(0, 1),   # same/next day
             random.randint(2, 7),   # 1 week
             random.randint(8, 30),  # 1 month
             random.randint(31, 90), # 3 months
             random.randint(91, 180)],# 6 months
            weights=[10, 25, 35, 20, 10]
        )[0]

        check_in_date   = booking_date + timedelta(days=lead_days)
        if check_in_date > data_end:
            check_in_date = data_end

        # Length of stay by brand
        alos_by_brand   = {"LUX": (2, 5), "PRE": (1, 4), "MID": (1, 3), "ECO": (1, 2)}
        min_n, max_n    = alos_by_brand.get(brand_code, (1, 3))
        nights          = random.randint(min_n, max_n)
        check_out_date  = check_in_date + timedelta(days=nights)

        # Booking status
        status          = random.choices(statuses, weights=status_weights)[0]

        # Rate code selection
        if is_member and random.random() < 0.4:
            channel_key = "avenir_member"
        elif random.random() < 0.35:
            channel_key = "ota_primary"
        elif random.random() < 0.15:
            channel_key = "ota_secondary"
        elif random.random() < 0.08:
            channel_key = "corporate"
        elif random.random() < 0.03:
            channel_key = "group"
        else:
            channel_key = "direct"

        rate_pool       = config['rate_codes'].get(channel_key, {})
        if isinstance(rate_pool, dict):
            flex_key    = random.choice(list(rate_pool.keys()))
            rate_code   = random.choice(rate_pool[flex_key])
        else:
            rate_code   = random.choice(rate_pool) if rate_pool else "RA1"

        rate_channel    = rate_channel_map.get(rate_code, "DIRECT")
        rate_flex       = rate_flex_map.get(rate_code, "FLEXIBLE")
        includes_bb     = rate_bb_map.get(rate_code, False)

        # Market segment from channel
        segment_map     = {
            "DIRECT": "LEISURE", "AVENIR_MEMBER": "LOYALTY",
            "OTA_PRIMARY": "LEISURE", "OTA_SECONDARY": "LEISURE",
            "CORPORATE": "CORPORATE", "GROUP": "GROUP",
            "EVENT": "MICE", "MOBILE_APP": "LEISURE",
        }
        market_segment  = segment_map.get(rate_channel, "LEISURE")

        # Travel agent
        ta_list         = travel_agents.get(rate_channel, [""])
        travel_agent    = random.choice(ta_list)

        # TARS reference — only for OTA bookings
        tars_ref        = ""
        if travel_agent:
            tars_ref    = f"{random.randint(1000000000, 9999999999)}@{prop_code[-3:]}"

        # GDS locator — only for corporate/group
        gds_locator     = ""
        if market_segment in ("CORPORATE", "GROUP") and random.random() < 0.6:
            gds_locator = ''.join(random.choices('ABCDEFGHJKLMNPQRSTUVWXYZ0123456789', k=8))

        # Room number
        room_number     = f"{random.randint(1, 8)}{random.randint(0, 9)}{random.randint(1, 9)}"

        # Upgrade detection
        was_upgraded    = False
        room_to_charge  = room_type_code
        if random.random() < 0.08:
            was_upgraded   = True
            room_to_charge = room_type_code

        # Nightly rate by brand and tier
        base_rates      = {"LUX": (180, 450), "PRE": (100, 220), "MID": (60, 130), "ECO": (35, 80)}
        min_r, max_r    = base_rates.get(brand_code, (50, 150))
        nightly_rate    = round(random.uniform(min_r, max_r), 2)
        total_cost      = round(nightly_rate * nights, 2)

        # Currency
        currency        = prop['local_currency']

        # Confirmation number — 9 digit unique
        while True:
            conf_num    = str(random.randint(100000000, 999999999))
            if conf_num not in confirmation_nums:
                confirmation_nums.add(conf_num)
                break

        # Actual check-in timestamp (only for CHECKED_IN and CHECKED_OUT)
        actual_checkin  = ""
        if status in ("CHECKED_IN", "CHECKED_OUT"):
            checkin_hour    = random.randint(12, 23)
            checkin_min     = random.choice([0, 15, 30, 45])
            actual_checkin  = f"{check_in_date}T{checkin_hour:02d}:{checkin_min:02d}:00"

        # Ground truth flags — clean at this stage
        reservations.append({
            "confirmation_number":   conf_num,
            "property_code":         prop_code,
            "guest_profile_id":      guest_id,
            "room_type_id":          room_type['room_type_id'],
            "room_type_booked":      room_type_code,
            "room_type_to_charge":   room_to_charge,
            "was_upgraded":          was_upgraded,
            "room_number":           room_number,
            "rate_code":             rate_code,
            "rate_channel":          rate_channel,
            "rate_flexibility":      rate_flex,
            "includes_breakfast":    includes_bb,
            "market_segment":        market_segment,
            "booking_date":          booking_date.isoformat(),
            "check_in_date":         check_in_date.isoformat(),
            "check_out_date":        check_out_date.isoformat(),
            "nights":                nights,
            "adults":                random.randint(1, 2),
            "children":              random.choices([0, 1, 2], weights=[70, 20, 10])[0],
            "booking_status":        status,
            "nightly_rate":          nightly_rate,
            "total_cost":            total_cost,
            "local_currency":        currency,
            "travel_agent":          travel_agent,
            "tars_external_ref":     tars_ref,
            "gds_record_locator":    gds_locator,
            "is_direct_booking":     travel_agent == "",
            "member_number":         member['member_number'] if member else "",
            "actual_checkin_at":     actual_checkin,
            # Ground truth flags
            "is_duplicate_reservation": False,
            "is_test_record":           False,
            "has_invalid_date_sequence": False,
        })

    return reservations

# ── Generator: Folios ─────────────────────────────────────────────────────────

def generate_folios(reservations: list[dict], config: dict) -> list[dict]:
    """
    Generate folio charges per reservation.
    Multiple windows possible — Room, F&B, Parking, Pet, Late Checkout etc.
    Only CHECKED_OUT and CHECKED_IN reservations have folios.
    """
    print("Generating folios...")
    folios = []

    payment_methods = ["MasterCard", "Visa", "Amex", "Cash", "BankTransfer"]
    method_weights  = [35, 35, 15, 10, 5]

    payee_by_agent  = {
        "Booking.com": "Bookingcom Agent",
        "Expedia":     "Expedia Collect",
        "Agoda":       "Agoda Collect",
        "Hotels.com":  "Hotels.com Collect",
        "":            "Guest",
    }

    # EUR exchange rates (approximate)
    fx_rates = {"EUR": 1.0, "GBP": 1.17, "AED": 0.25}

    folio_num = 1
    for res in reservations:
        if res['booking_status'] not in ("CHECKED_OUT", "CHECKED_IN"):
            continue

        conf_num     = res['confirmation_number']
        currency     = res['local_currency']
        fx           = fx_rates.get(currency, 1.0)
        travel_agent = res['travel_agent']
        payee        = payee_by_agent.get(travel_agent, "Guest")
        method       = random.choices(payment_methods, weights=method_weights)[0]
        card_last4   = f"{random.randint(1000, 9999)}" if method in ("MasterCard", "Visa", "Amex") else ""

        # Window 1 — Room charge (always present)
        room_amount  = res['total_cost']
        folios.append({
            "folio_id":             f"FOL-{folio_num:010d}",
            "confirmation_number":  conf_num,
            "window_number":        1,
            "charge_type":          "ROOM",
            "charge_description":   "Room Charge",
            "amount_local":         room_amount,
            "currency_code":        currency,
            "amount_eur":           round(room_amount * fx, 2),
            "payment_method":       method,
            "card_last4":           card_last4,
            "payee":                payee,
            "charge_date":          res['check_out_date'],
        })
        folio_num += 1

        # Window 2 — F&B charge (60% chance)
        if random.random() < 0.60:
            fb_amount = round(random.uniform(10, 80) * res['nights'], 2)
            folios.append({
                "folio_id":             f"FOL-{folio_num:010d}",
                "confirmation_number":  conf_num,
                "window_number":        2,
                "charge_type":          "FB",
                "charge_description":   random.choice(["Breakfast", "Restaurant", "Room Service", "Minibar"]),
                "amount_local":         fb_amount,
                "currency_code":        currency,
                "amount_eur":           round(fb_amount * fx, 2),
                "payment_method":       method,
                "card_last4":           card_last4,
                "payee":                "Guest",
                "charge_date":          res['check_out_date'],
            })
            folio_num += 1

        # Window 3 — Other charges (30% chance)
        if random.random() < 0.30:
            other_desc   = random.choice(["Parking", "Late Checkout", "Early Checkin",
                                          "Pet Fee", "Laundry", "Spa"])
            other_amount = round(random.uniform(10, 60), 2)
            folios.append({
                "folio_id":             f"FOL-{folio_num:010d}",
                "confirmation_number":  conf_num,
                "window_number":        3,
                "charge_type":          "OTHER",
                "charge_description":   other_desc,
                "amount_local":         other_amount,
                "currency_code":        currency,
                "amount_eur":           round(other_amount * fx, 2),
                "payment_method":       method,
                "card_last4":           card_last4,
                "payee":                "Guest",
                "charge_date":          res['check_out_date'],
            })
            folio_num += 1

    return folios

# ── Generator: Cancellations ──────────────────────────────────────────────────

def generate_cancellations(reservations: list[dict], config: dict) -> list[dict]:
    """
    Generate cancellation records for CANCELLED and NO_SHOW reservations.
    Uses real Opera cancellation reason codes.
    """
    print("Generating cancellations...")
    cancellations = []

    reasons         = config['cancellation_reasons']

    reason_group_map = {
        "guest_initiated":  "GUEST_INITIATED",
        "hotel_initiated":  "HOTEL_INITIATED",
        "no_show":          "NO_SHOW",
        "duplicate":        "DUPLICATE",
        "group":            "GROUP",
        "system":           "SYSTEM",
    }

    # Weights for reason groups
    group_weights = {
        "CANCELLED": {
            "guest_initiated": 50,
            "hotel_initiated": 15,
            "duplicate":       20,
            "group":           10,
            "system":           5,
        },
        "NO_SHOW": {
            "no_show": 100,
        },
    }

    cancel_num = 1
    for res in reservations:
        if res['booking_status'] not in ("CANCELLED", "NO_SHOW"):
            continue

        status          = res['booking_status']
        booking_date    = date.fromisoformat(res['booking_date'])
        check_in_date   = date.fromisoformat(res['check_in_date'])

        # Cancellation date — between booking and check-in
        if status == "NO_SHOW":
            cancel_date = check_in_date
        else:
            max_days    = max((check_in_date - booking_date).days, 1)
            cancel_date = booking_date + timedelta(days=random.randint(0, max_days))

        days_before     = (check_in_date - cancel_date).days

        # Cancellation window
        if days_before == 0:
            cancel_window = "SAME_DAY"
        elif days_before <= 3:
            cancel_window = "LAST_MINUTE"
        elif days_before <= 14:
            cancel_window = "SHORT"
        elif days_before <= 30:
            cancel_window = "MEDIUM"
        else:
            cancel_window = "ADVANCE"

        # Pick reason group and code
        weights_dict    = group_weights.get(status, group_weights["CANCELLED"])
        groups          = list(weights_dict.keys())
        weights         = list(weights_dict.values())
        chosen_group    = random.choices(groups, weights=weights)[0]
        reason_codes    = reasons[chosen_group]
        reason_code     = random.choice(reason_codes)
        reason_group    = reason_group_map[chosen_group]

        cancellations.append({
            "cancellation_id":      f"CXL-{cancel_num:010d}",
            "confirmation_number":  res['confirmation_number'],
            "cancellation_date":    cancel_date.isoformat(),
            "reason_code":          str(reason_code),
            "reason_group":         reason_group,
            "days_before_checkin":  days_before,
            "cancellation_window":  cancel_window,
            "revenue_at_risk":      res['total_cost'],
            "currency_code":        res['local_currency'],
        })
        cancel_num += 1

    return cancellations

# ── Generator: Room Availability ──────────────────────────────────────────────

def generate_room_availability(
    properties: list[dict],
    room_types: list[dict],
    config: dict,
) -> list[dict]:
    """
    Generate daily room availability per property per room type.
    rooms_available = total_rooms - ooo_rooms
    OOS rooms are still sellable — only OOO rooms reduce availability.
    This is the denominator for RevPAR calculations.
    """
    print("Generating room availability (this may take a moment)...")
    availability    = []

    data_start      = date.fromisoformat(config['scale']['data_start_date'])
    data_end        = date.fromisoformat(config['scale']['data_end_date'])
    total_days      = (data_end - data_start).days + 1

    # Room types per property
    rt_by_prop      = {}
    for rt in room_types:
        rt_by_prop.setdefault(rt['property_code'], []).append(rt)

    avail_id = 1
    for prop in properties:
        prop_code   = prop['property_code']
        prop_rts    = rt_by_prop.get(prop_code, [])

        for rt in prop_rts:
            total_rooms = rt['total_rooms']

            current_date = data_start
            while current_date <= data_end:
                # OOO rooms — random maintenance days (0-2% of rooms)
                ooo_rooms   = 0
                if random.random() < 0.05:  # 5% chance of any OOO on a given day
                    ooo_rooms = random.randint(1, max(1, total_rooms // 20))

                rooms_avail = max(0, total_rooms - ooo_rooms)

                availability.append({
                    "availability_id":  f"AVL-{avail_id:010d}",
                    "property_code":    prop_code,
                    "room_type_id":     rt['room_type_id'],
                    "stay_date":        current_date.isoformat(),
                    "total_rooms":      total_rooms,
                    "ooo_rooms":        ooo_rooms,
                    "rooms_available":  rooms_avail,
                })
                avail_id    += 1
                current_date += timedelta(days=1)

    return availability

# ── Generator: Avenir Points Transactions ─────────────────────────────────────

def generate_points_transactions(
    reservations: list[dict],
    avenir_members: list[dict],
    config: dict,
) -> list[dict]:
    """
    Generate loyalty points transactions for AVENIR members.
    Points are earned AFTER checkout — not visible in Opera.
    Two separate point types: status_points and reward_points.
    """
    print("Generating AVENIR points transactions...")
    transactions    = []

    member_map      = {m['guest_profile_id']: m for m in avenir_members}

    # Points earning rates per tier
    status_rate     = {"CLASSIC": 5, "SILVER": 8, "GOLD": 10, "PLATINUM": 12, "DIAMOND": 15}
    reward_rate     = {"CLASSIC": 3, "SILVER": 5, "GOLD":  7, "PLATINUM":  9, "DIAMOND": 12}

    txn_num = 1
    for res in reservations:
        guest_id    = res['guest_profile_id']
        member      = member_map.get(guest_id)

        if not member:
            continue

        if res['booking_status'] not in ("CHECKED_OUT",):
            continue

        tier            = member['current_tier']
        nights          = res['nights']
        total_cost      = res['total_cost']
        checkout_date   = date.fromisoformat(res['check_out_date'])

        # Points earned date — after checkout (R4 rule)
        # M9: Early points — 1.5% violation
        has_early_points = False
        if random.random() < config['messiness']['early_points_pct']:
            points_date  = checkout_date - timedelta(days=random.randint(1, 3))
            has_early_points = True
        else:
            points_date  = checkout_date + timedelta(days=random.randint(1, 7))

        # Status points — based on nights
        sp              = nights * status_rate.get(tier, 5)
        sp              += int(total_cost * 0.02)  # bonus for spend

        # Reward points — based on spend
        rp              = int(total_cost * reward_rate.get(tier, 3) / 10)

        transactions.append({
            "transaction_id":       f"TXN-{txn_num:010d}",
            "member_number":        member['member_number'],
            "confirmation_number":  res['confirmation_number'],
            "transaction_type":     "STAY",
            "transaction_date":     points_date.isoformat(),
            "status_points":        sp,
            "reward_points":        rp,
            "tier_at_earn":         tier,
            "property_code":        res['property_code'],
            # Ground truth flag
            "has_early_points":     has_early_points,
        })
        txn_num += 1

        # Additional dining/partner transactions — 20% chance
        if random.random() < 0.20:
            dining_date = checkout_date + timedelta(days=random.randint(1, 30))
            txn_type    = random.choice(["DINING", "PARTNER", "SHOPPING"])
            transactions.append({
                "transaction_id":       f"TXN-{txn_num:010d}",
                "member_number":        member['member_number'],
                "confirmation_number":  res['confirmation_number'],
                "transaction_type":     txn_type,
                "transaction_date":     dining_date.isoformat(),
                "status_points":        random.randint(10, 100),
                "reward_points":        random.randint(5, 50),
                "tier_at_earn":         tier,
                "property_code":        res['property_code'],
                "has_early_points":     False,
            })
            txn_num += 1

    return transactions

# ── Generator: Avenir Tier History ────────────────────────────────────────────

def generate_tier_history(
    avenir_members: list[dict],
    config: dict,
) -> list[dict]:
    """
    Generate tier change history for AVENIR members.
    Simulates tier movements over 3 years.
    Members start at a lower tier and progress upward.
    """
    print("Generating AVENIR tier history...")
    history         = []

    tier_order      = ["CLASSIC", "SILVER", "GOLD", "PLATINUM", "DIAMOND"]
    tier_index      = {t: i for i, t in enumerate(tier_order)}

    data_start      = date.fromisoformat(config['scale']['data_start_date'])
    data_end        = date.fromisoformat(config['scale']['data_end_date'])

    history_id = 1
    for member in avenir_members:
        current_tier    = member['current_tier']
        current_idx     = tier_index[current_tier]
        join_date       = date.fromisoformat(member['join_date'])

        # Starting tier — one below current (or CLASSIC)
        start_idx       = max(0, current_idx - random.randint(0, 2))
        start_tier      = tier_order[start_idx]

        # NEW_MEMBER entry
        history.append({
            "history_id":           f"TH-{history_id:010d}",
            "member_number":        member['member_number'],
            "previous_tier":        "",
            "new_tier":             start_tier,
            "change_type":          "NEW_MEMBER",
            "effective_date":       join_date.isoformat(),
            "status_points_at_change": 0,
        })
        history_id += 1

        # Simulate tier progressions
        current_sim_tier    = start_tier
        current_sim_idx     = start_idx
        current_sim_date    = join_date + timedelta(days=random.randint(90, 180))

        while current_sim_tier != current_tier and current_sim_date <= data_end:
            next_idx        = current_sim_idx + 1
            if next_idx >= len(tier_order):
                break

            next_tier       = tier_order[next_idx]
            sp_at_change    = member['lifetime_status_points'] // (current_idx + 1)

            history.append({
                "history_id":           f"TH-{history_id:010d}",
                "member_number":        member['member_number'],
                "previous_tier":        current_sim_tier,
                "new_tier":             next_tier,
                "change_type":          "UPGRADE",
                "effective_date":       current_sim_date.isoformat(),
                "status_points_at_change": sp_at_change,
            })
            history_id          += 1
            current_sim_tier     = next_tier
            current_sim_idx      = next_idx
            current_sim_date    += timedelta(days=random.randint(180, 365))

        # 5% chance of a downgrade event
        if random.random() < 0.05 and current_idx > 0:
            downgrade_date  = data_start + timedelta(
                days=random.randint(0, (data_end - data_start).days)
            )
            history.append({
                "history_id":           f"TH-{history_id:010d}",
                "member_number":        member['member_number'],
                "previous_tier":        current_tier,
                "new_tier":             tier_order[current_idx - 1],
                "change_type":          "DOWNGRADE",
                "effective_date":       downgrade_date.isoformat(),
                "status_points_at_change": random.randint(100, 500),
            })
            history_id += 1

    return history

# ── Entry Point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AVENOIREL Data Generator")
    parser.add_argument(
        "--rows",
        default="100",
        help="Number of reservations to generate. Use 'full' for full dataset."
    )
    args = parser.parse_args()

    config = load_config()
    setup_directories()

    fake = Faker(['en_GB', 'fr_FR', 'de_DE', 'es_ES'])
    random.seed(42)
    fake.seed_instance(42)

    if args.rows == "full":
        reservation_count = config['scale']['reservations']
    else:
        reservation_count = int(args.rows)

    print(f"\nAVENOIREL Generator starting...")
    print(f"Reservations to generate: {reservation_count:,}")
    print(f"Data period: {config['scale']['data_start_date']} to {config['scale']['data_end_date']}\n")

        # Step 1: Properties
    properties = generate_properties(config)
    save_csv(properties, "properties.csv", CLEAN_DIR)

        # Step 2: Room Types
    room_types = generate_room_types(properties, config)
    save_csv(room_types, "room_types.csv", CLEAN_DIR)

        # Step 3: Guests
    guests = generate_guests(config, fake)
    save_csv(guests, "guests.csv", CLEAN_DIR)

        # Step 4: Avenir Members
    avenir_members = generate_avenir_members(guests, config)
    save_csv(avenir_members, "avenir_members.csv", CLEAN_DIR)

        # Step 5: Reservations
    reservations = generate_reservations(
        properties, room_types, guests, avenir_members, config, reservation_count
    )
    save_csv(reservations, "reservations.csv", CLEAN_DIR)

        # Step 6: Folios
    folios = generate_folios(reservations, config)
    save_csv(folios, "folios.csv", CLEAN_DIR)

        # Step 7: Cancellations
    cancellations = generate_cancellations(reservations, config)
    save_csv(cancellations, "cancellations.csv", CLEAN_DIR)

        # Step 8: Room Availability
    room_availability = generate_room_availability(properties, room_types, config)
    save_csv(room_availability, "room_availability.csv", CLEAN_DIR)

        # Step 9: Avenir Points Transactions
    points_txns = generate_points_transactions(reservations, avenir_members, config)
    save_csv(points_txns, "avenir_points_transactions.csv", CLEAN_DIR)

        # Step 10: Avenir Tier History
    tier_history = generate_tier_history(avenir_members, config)
    save_csv(tier_history, "avenir_tier_history.csv", CLEAN_DIR)

    print(f"\nClean data generation complete!")
    print(f"All files saved to: {CLEAN_DIR}\n")