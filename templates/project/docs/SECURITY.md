# Security boundaries

First login requires network access. Demo API tokens expire after seven days and have read/write draft abilities. This is not an offline identity provider or a production RBAC system. Offline UI expiry uses the device clock; the server independently enforces token expiry and authorization.

Logging out attempts server revocation. If unreachable, the client deletes its cached token and warns that server revocation is pending; the token otherwise expires. Local data is kept per account so pending work is not lost. Establish retention and device deprovisioning policies before deployment.

SQLite is NOT encrypted by this starter. OS secure storage protects tokens, not draft contents. Use managed device encryption/access controls or implement an audited database-encryption integration before storing sensitive HRIS/health/biometric data. Do not ship test credentials or production data.

Require HTTPS for production; Android cleartext is allowed only in debug. The installer adds INTERNET permission to the Android main manifest. Disable APP_DEBUG in production. Review backup/restore and conflict/authorization requirements for each business module.

Only explicitly flagged is_admin users enter Filament. The example panel shows only that user's drafts. Group/company/location scopes and granular role policies must be implemented before using shared enterprise data. Do not infer those features from the starter.
