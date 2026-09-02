const auditData = require('./master_batch_audit.json');
console.log("Master Audit Array:", auditData);

const sessionIds = auditData.map(s => s.session_id);
console.log("Extracted Session IDs:", sessionIds);
