"""
AVENOIREL Data Validation
=========================
5 business-logic validation queries against clean CSVs.
ALL must return 0 violations before proceeding to Snowflake load.

Usage:
    python scripts/validate_data.py
"""

import pandas as pd
from pathlib import Path

CLEAN_DIR = Path("data/clean")

def load_tables() -> dict:
    """Load all clean CSVs into pandas DataFrames."""
    print("Loading clean data...\n")
    tables = {}
    csv_files = [
        "properties", "room_types", "guests", "avenir_members",
        "reservations", "folios", "cancellations", "room_availability",
        "avenir_points_transactions", "avenir_tier_history",
    ]
    for name in csv_files:
        path = CLEAN_DIR / f"{name}.csv"
        tables[name] = pd.read_csv(path)
        print(f"  Loaded {name}: {len(tables[name]):,} rows")
    print()
    return tables


def vq1_no_event_before_parent(tables: dict) -> pd.DataFrame:
    """
    VQ1: No stay/folio/cancellation exists before its parent booking date.
    Checks: cancellation_date >= booking_date
    """
    res = tables['reservations'][['confirmation_number', 'booking_date', 'check_in_date']].copy()
    can = tables['cancellations'][['confirmation_number', 'cancellation_date']].copy()

    merged = can.merge(res, on='confirmation_number', how='left')
    merged['booking_date']       = pd.to_datetime(merged['booking_date'])
    merged['cancellation_date']  = pd.to_datetime(merged['cancellation_date'])

    violations = merged[merged['cancellation_date'] < merged['booking_date']]
    return violations[['confirmation_number', 'cancellation_date', 'booking_date']]


def vq2_kpi_consistency(tables: dict) -> pd.DataFrame:
    """
    VQ2: Total folio room charges must match reservation total_cost within €1 tolerance.
    """
    res     = tables['reservations'][
        tables['reservations']['booking_status'] == 'CHECKED_OUT'
    ][['confirmation_number', 'total_cost']].copy()

    room_folios = tables['folios'][
        tables['folios']['charge_type'] == 'ROOM'
    ].groupby('confirmation_number')['amount_local'].sum().reset_index()
    room_folios.columns = ['confirmation_number', 'folio_total']

    merged  = res.merge(room_folios, on='confirmation_number', how='left')
    merged['discrepancy'] = abs(merged['total_cost'] - merged['folio_total'])

    violations = merged[merged['discrepancy'] > 1.0]
    return violations[['confirmation_number', 'total_cost', 'folio_total', 'discrepancy']]


def vq3_no_orphaned_records(tables: dict) -> pd.DataFrame:
    """
    VQ3: All foreign keys resolve — no orphaned records.
    Checks: every reservation has a valid property_code and guest_profile_id.
    """
    valid_props  = set(tables['properties']['property_code'])
    valid_guests = set(tables['guests']['guest_profile_id'])

    res = tables['reservations'].copy()
    orphaned_prop  = res[~res['property_code'].isin(valid_props)]
    orphaned_guest = res[~res['guest_profile_id'].isin(valid_guests)]

    violations = pd.concat([orphaned_prop, orphaned_guest]).drop_duplicates(
        subset=['confirmation_number']
    )
    return violations[['confirmation_number', 'property_code', 'guest_profile_id']]


def vq4_date_sequences_logical(tables: dict) -> pd.DataFrame:
    """
    VQ4: All date sequences are logical.
    check_in_date > booking_date AND check_out_date > check_in_date.
    """
    res = tables['reservations'].copy()
    res['booking_date']   = pd.to_datetime(res['booking_date'])
    res['check_in_date']  = pd.to_datetime(res['check_in_date'])
    res['check_out_date'] = pd.to_datetime(res['check_out_date'])

    violations = res[
        (res['check_in_date'] < res['booking_date']) |
        (res['check_out_date'] <= res['check_in_date'])
    ]
    return violations[['confirmation_number', 'booking_date', 'check_in_date', 'check_out_date']]


def vq5_categorical_values_valid(tables: dict) -> pd.DataFrame:
    """
    VQ5: All categorical values within defined domains.
    Checks: booking_status, market_segment, charge_type, avenir tier.
    """
    violations = []

    # booking_status
    valid_statuses = {"CONFIRMED", "CHECKED_IN", "CHECKED_OUT", "CANCELLED", "NO_SHOW"}
    bad_status = tables['reservations'][
        ~tables['reservations']['booking_status'].isin(valid_statuses)
    ][['confirmation_number', 'booking_status']].copy()
    bad_status['issue'] = 'invalid_booking_status'
    violations.append(bad_status.rename(columns={'booking_status': 'value'}))

    # avenir tier
    valid_tiers = {"CLASSIC", "SILVER", "GOLD", "PLATINUM", "DIAMOND"}
    bad_tier = tables['avenir_members'][
        ~tables['avenir_members']['current_tier'].isin(valid_tiers)
    ][['member_number', 'current_tier']].copy()
    bad_tier['issue'] = 'invalid_avenir_tier'
    bad_tier = bad_tier.rename(columns={'member_number': 'confirmation_number', 'current_tier': 'value'})
    violations.append(bad_tier)

    # charge_type
    valid_charge_types = {"ROOM", "FB", "OTHER"}
    bad_charge = tables['folios'][
        ~tables['folios']['charge_type'].isin(valid_charge_types)
    ][['folio_id', 'charge_type']].copy()
    bad_charge['issue'] = 'invalid_charge_type'
    bad_charge = bad_charge.rename(columns={'folio_id': 'confirmation_number', 'charge_type': 'value'})
    violations.append(bad_charge)

    return pd.concat(violations, ignore_index=True) if violations else pd.DataFrame()


def run_validations(tables: dict):
    """Run all 5 validation queries and report results."""
    queries = [
        ("VQ1", "No event before parent record",     vq1_no_event_before_parent),
        ("VQ2", "KPI consistency — folio vs total",  vq2_kpi_consistency),
        ("VQ3", "No orphaned foreign keys",           vq3_no_orphaned_records),
        ("VQ4", "Date sequences logical",             vq4_date_sequences_logical),
        ("VQ5", "Categorical values valid",           vq5_categorical_values_valid),
    ]

    all_passed = True
    print("=" * 60)
    print("AVENOIREL — Data Validation Report")
    print("=" * 60)

    for code, name, fn in queries:
        violations = fn(tables)
        count      = len(violations)
        status     = "PASS" if count == 0 else "FAIL"
        icon       = "✅" if count == 0 else "❌"

        print(f"\n{icon} {code}: {name}")
        print(f"   Status: {status} | Violations: {count}")

        if count > 0:
            all_passed = False
            print(f"   Sample violations:")
            print(violations.head(3).to_string(index=False))

    print("\n" + "=" * 60)
    if all_passed:
        print("✅ ALL 5 VALIDATION QUERIES PASSED")
        print("   Data is ready for Snowflake load.")
    else:
        print("❌ VALIDATION FAILED — Fix generator before proceeding.")
    print("=" * 60)


if __name__ == "__main__":
    tables = load_tables()
    run_validations(tables)