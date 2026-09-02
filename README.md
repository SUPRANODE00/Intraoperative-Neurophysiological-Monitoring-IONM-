# Intraoperative Neurophysiological Monitoring (IONM) Telemetry & CPT Compliance Engine

An enterprise-grade telemetry processing and CPT billing audit engine designed for continuous intraoperative neurophysiological monitoring (IONM).

## System Capabilities
- **CPT Audit Verification:** Validates time-based intraoperative attendance (CPT 95940 / CPT 95941).
- **DSP Zero Ground Balance:** Real-time signal stability verification for evoked potential streams.
- **Automated CI/CD Pipeline:** Pytest compliance suite executed via GitHub Actions on every push.

## Setup & Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Execute test suite
pytest -v test_main.py
