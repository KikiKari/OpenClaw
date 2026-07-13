# Root-SSH vom Gateway zu Node 2

Stand: 2026-07-12

## Zweck und Trennung

- Tailscale läuft systemweit und stellt die private Netzwerkverbindung bereit.
- Das OpenClaw-Pairing verwendet dieses Netz; die OpenClaw-Dienste laufen als
  Benutzer `openclaw`.
- Klassisches SSH als `root` dient ausschließlich Administration, Updates und
  Dienstneustarts. Es ist unabhängig vom OpenClaw-Pairing und von Tailscale SSH.

Aktuelle Adressen:

- Gateway: `100.64.80.9`
- Node 2 (`openclaw-node2`, Systemhostname `v2202603104722445775`):
  `100.109.255.27`

## 1. Auf der Root-Konsole des Gateways

Der Schlüssel wurde zunächst unter dem Dienstkonto erzeugt. Installiere ihn
für `root`, ohne die Quelldateien zu verändern:

```bash
install -d -m 700 /root/.ssh
install -m 600 -o root -g root /home/openclaw/.ssh/id_ed25519_openclaw_admin /root/.ssh/id_ed25519_openclaw_admin
install -m 644 -o root -g root /home/openclaw/.ssh/id_ed25519_openclaw_admin.pub /root/.ssh/id_ed25519_openclaw_admin.pub
ssh-keygen -lf /root/.ssh/id_ed25519_openclaw_admin.pub
```

Erwarteter Fingerprint:

```text
SHA256:qYTQGaJxbk7r6iZ2GttcXTHFp5u9jaOGC3lh8Xlvd2U
```

## 2. Auf der Root-Konsole von Node 2

Autorisiere ausschließlich den öffentlichen Schlüssel:

```bash
install -d -m 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
grep -qxF 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNP9yWywctKeQS71oOOnilm72k27YLIuIYP8u5T+Iw+ root@v2202604104722446711-openclaw-admin' /root/.ssh/authorized_keys || printf '%s\n' 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNP9yWywctKeQS71oOOnilm72k27YLIuIYP8u5T+Iw+ root@v2202604104722446711-openclaw-admin' >> /root/.ssh/authorized_keys
chown -R root:root /root/.ssh
```

## 3. Verbindung vom Gateway prüfen

```bash
ssh -i /root/.ssh/id_ed25519_openclaw_admin -o IdentitiesOnly=yes root@100.109.255.27 'hostname; id -un'
```

Erwartete Ausgabe:

```text
v2202603104722445775
root
```
