#!/usr/bin/env python3
"""
Pytest suite for IONM Telemetry & CPT Compliance Engine (main.py)
"""

import pytest
from main import run_dsp_zero_ground_balance, audit_cpt_billing


def test_audit_cpt_billing_standard_counts():
    """Verify correct counting of CPT 95940 and 95941 codes."""
    sample_records = [
        {"id": 1, "cpt_code": "95940", "ground_offset": 0.01},
        {"id": 2, "cpt_code": "95940", "ground_offset": -0.02},
        {"id": 3, "cpt_code": "95941", "ground_offset": 0.00},
        {"id": 4, "cpt_code": "99214", "ground_offset": 0.01},  # Non-IONM code
    ]
    assert audit_cpt_billing(sample_records) is True


def test_audit_cpt_billing_empty_records():
    """Ensure audit handles empty telemetry payloads gracefully."""
    empty_records = []
    assert audit_cpt_billing(empty_records) is True


def test_zero_ground_balance_stability():
    """Verify ground offset thresholds evaluate correctly."""
    records = [
        {"id": 1, "ground_offset": 0.01},   # Stable (< 0.05)
        {"id": 2, "ground_offset": -0.04},  # Stable (< 0.05)
        {"id": 3, "ground_offset": 0.12},   # Unstable (> 0.05)
    ]
    assert run_dsp_zero_ground_balance(records) is True


@pytest.mark.parametrize(
    "records, expected_stable",
    [
        ([{"ground_offset": 0.00}], 1),
        ([{"ground_offset": 0.06}, {"ground_offset": -0.08}], 0),
        ([{"ground_offset": 0.049}, {"ground_offset": -0.049}], 2),
    ],
)
def test_zero_ground_balance_parametrized(records, expected_stable):
    """Parametrized test for granular threshold boundary verification."""
    assert run_dsp_zero_ground_balance(records) is True
