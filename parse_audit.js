const fs = require('fs');

const rawData = fs.readFileSync('master_batch_audit.json', 'utf8');
const auditLogs = JSON.parse(rawData);

console.log("=== BATCH AUDIT AGGREGATION ===");
auditLogs.forEach((log) => {
  console.log(`Session: ${log.session_id} | CPT: ${log.assigned_cpt} | Units: ${log.billable_units_hours} | Status: ${log.compliance_flags[0]}`);
});
