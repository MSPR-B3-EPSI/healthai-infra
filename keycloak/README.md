# Keycloak Configuration (MSPR Realm)

- **Realm:** `healthia`
- **Identity Provider:** `http://localhost:8080/auth/realms/healthai`
- **Simplified Access:** All tokens include the `api-all-access` audience by default.

## Integration Logic

- **User Mapping:** Use the `sub` claim from the JWT as the unique identifier in the `users` table of the Business API.
- **Plans:** Check for realm roles `plan-freemium`, `plan-premium`, or `plan-premium+` within the token to gate features.

## Setup

1. The realm is automatically imported from `keycloak/realm/mspr-realm.json` on startup.
2. Ensure `.env` contains the `KEYCLOAK_CLIENT_SECRET` for the `mspr-dev-cli`.

## Development Tip

If the API fails to validate tokens due to 'Issuer Mismatch', ensure the API is configured to trust `http://localhost:8080/realms/mspr` even if it communicates over the internal Docker network.
