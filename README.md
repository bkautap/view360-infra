# leadership3-infra

Ansible-deployment van de leadership3-omgeving op een Leaseweb VPS: Traefik (proxy + TLS), CrowdSec (optioneel), Keycloak (SSO), Odoo 20, Nextcloud, OpenProject en Flowable. Elke applicatie draait als eigen Docker Compose-stack met eigen Postgres (Odoo, Nextcloud, OpenProject, Keycloak, Flowable).

## Hostnames

| Dienst       | Hostname                 |
|--------------|--------------------------|
| Odoo 20      | leadership3eco.com, www.leadership3eco.com |
| Nextcloud    | dms.leadership3eco.com       |
| OpenProject  | project.leadership3eco.com   |
| Flowable     | flow.leadership3eco.com      |
| Keycloak     | auth.leadership3eco.com      |
| Traefik      | traefik.leadership3eco.com   |

## Structuur

```
inventory/        hosts + group_vars (vars.yml open, vault.yml versleuteld)
playbooks/        site.yml
roles/
  common/         basispakketten, ufw, SSH-hardening, gedeelde deploy-taak
  docker/         Docker Engine + Compose plugin, proxy-netwerk
  traefik/        reverse proxy, socket-proxy, middlewares
  crowdsec/       IDS/bouncer als ForwardAuth (optioneel)
  keycloak/       SSO met realm 'leadership3' en clients
  odoo/           Odoo 20 + Postgres + longpolling
  nextcloud/      Nextcloud + Postgres + Redis + cron
  openproject/    OpenProject + Postgres
  flowable/       Flowable UI (IDM, modeler, task, admin) + Postgres
  backup/         dagelijkse dumps + volumes, versleuteld, retentie, systemd-timer
```

## Eerste keer opzetten

1. **DNS**: maak A-records aan voor `leadership3eco.com`, `www`, `dms`, `project`, `flow`, `auth` en `traefik` naar het IP van de VPS.
2. **Vault**: kopieer `inventory/group_vars/all/vault.yml.example` naar `vault.yml`, vul alle waarden in (`openssl rand -base64 32` voor geheimen) en versleutel: `ansible-vault encrypt inventory/group_vars/all/vault.yml`.
3. **Inventory**: zet het IP van de VPS in `inventory/hosts.yml`. Op de VPS moet een gebruiker `ansible` met sudo en je SSH-key bestaan.
4. **Dependencies**: `make deps`
5. **Dry-run**: `make check`
6. **Uitrollen**: `make deploy`
7. **CrowdSec-bouncer-sleutel** (eenmalig): `docker exec crowdsec cscli bouncers add traefik`. Zet de sleutel in `vault_crowdsec_bouncer_key` en draai daarna `make deploy TAGS=crowdsec,traefik`.

## Na de eerste start

- **Keycloak**: de realm `leadership3` wordt bij de eerste start geïmporteerd. Wijzig het admin-wachtwoord, maak gebruikers aan en koppel rollen (`leadership3-admin`, `leadership3-user`).
- **Odoo**: installeer de OCA-module `auth_oidc` en voeg de Keycloak-provider toe (redirect `/auth_oauth/signin`). Zet het database-manager-scherm uit (`list_db = False` staat al in de config).
- **Nextcloud**: `docker exec -u www-data nextcloud php occ app:install user_oidc` en configureer de provider.
- **OpenProject**: controleer de OIDC-variabelen in `roles/openproject/templates/docker-compose.yml.j2` tegen de actuele docs (zie open punten).
- **Flowable**: wijzig de standaardwachtwoorden van de IDM-gebruikers `admin` en `test`. Maak de servicegebruiker `svc-flowable` aan met de juiste rechten en gebruik die in `FLOWABLE_COMMON_APP_IDM-ADMIN_*`. Het admin-account niet gebruiken voor interne calls.

## Beheer

- Wijzigingen doorvoeren: pas vars of templates aan en draai `make deploy`. Docker Compose herstart alleen de containers waarvan de configuratie is veranderd.
- Versies verhogen: wijzig `versions` in `vars.yml`, lees de release notes en draai eerst een backup.
- Backups: `/var/backups/leadership3` op de VPS (versleuteld met `vault_backup_passphrase`). Test een restore regelmatig.
- Offsite-kopie: zet `backup_remote` in `vars.yml`. De backup-timer draait dagelijks om 02:30.

## Bekende beperkingen

- Docker omzeilt UFW voor gepubliceerde poorten. Alleen Traefik publiceert 80/443. Databases publiceren nergens poorten.
- Flowable heeft geen kant-en-klare OIDC-koppeling met Keycloak. De client bestaat, maar de koppeling vraagt aparte uitwerking.
- De host wordt als amd64 ingericht. Pas `roles/docker/tasks/main.yml` aan voor andere architectuur.
