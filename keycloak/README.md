# Keycloak Local Notes

- Realm name (default): `mspr`
- Internal issuer from Docker network: `http://keycloak:8080/realms/mspr`
- External access through gateway: `http://localhost:8080/auth/`

## Issuer Consistency Warning

Services should validate tokens against one issuer value consistently in development.
If services use the internal issuer, keep `KEYCLOAK_ISSUER_INTERNAL` aligned with the realm.
If tokens are issued from external URLs, standardize that flow in all services and clients.

## Realm Placeholder

A placeholder export exists at `keycloak/realm/mspr-realm.json`.
Replace it with a real realm export when available.

## Secrets

Do not commit secrets. Keep credentials in `.env` only.
