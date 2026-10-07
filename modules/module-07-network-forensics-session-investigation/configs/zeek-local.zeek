# Cyber Forge mirrored/virtual traffic may contain checksum-offload artifacts.
redef ignore_checksums = T;

# Structured Zeek telemetry for SIEM ingestion and automation.
redef LogAscii::use_json = T;
