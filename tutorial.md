- [Infrastructure as code (IaC)](#infrastructure-as-code-iac)
  - [Managed node](#managed-node)
    - [Raspberry Pi vorbereiten](#raspberry-pi-vorbereiten)
  - [Control node](#control-node)
    - [Ansible installieren](#ansible-installieren)
    - [Docker-Rolle installieren](#docker-rolle-installieren)
  - [Projekt anpassen](#projekt-anpassen)
    - [Inventory konfigurieren](#inventory-konfigurieren)
    - [Inventory testen](#inventory-testen)
    - [Docker-Rolle konfigurieren](#docker-rolle-konfigurieren)
    - [Templates anpassen](#templates-anpassen)
  - [Playbooks](#playbooks)
    - [Initiale Installation](#initiale-installation)
    - [Docker-Dienste installieren](#docker-dienste-installieren)
  - [Services direkt auf dem Host starten und stoppen](#services-direkt-auf-dem-host-starten-und-stoppen)
  - [Services im Browser testen](#services-im-browser-testen)
  - [Generierte Artefakte](#generierte-artefakte)
    - [.../traefik/docker-compose.yml](#traefikdocker-composeyml)
    - [.../portainer/docker-compose.yml](#portainerdocker-composeyml)
    - [.../autoheal/docker-compose.yml](#autohealdocker-composeyml)
    - [.../watchtower/docker-compose.yml](#watchtowerdocker-composeyml)
  - [Verweise](#verweise)
    - [Dokumentation](#dokumentation)
    - [Docker-Tutorials](#docker-tutorials)
    - [Ansible-Tutorials](#ansible-tutorials)
    - [Traefik-Beispiele](#traefik-beispiele)

# Infrastructure as code (IaC)

Diese Dokumentation behandelt die Automatisierung von Verwaltungstätigkeiten - Installieren, Kopieren, Patchen - mit **Ansible**. Anweisungen werden auf einem der Verwaltung dienenden Server (ansible control node) reproduzierbar für eine beliebige Anzahl von Servern (managed nodes) ausgeführt. Bei dem **ansible control node** kann es sich um den Arbeitsplatzrechner als auch um einen aus der Ferne zu administrierenden Server handeln.

IaC bietet die folgenden Vorteile:

- Kostenreduzierung
- Beschleunigung der Software-Verteilung
- Fehlervermeidung
- Verbesserung der Infrastruktur-Konsistenz
- Vermeidung von Konfigurationsabweichungen

Das vorhandene Wissen bezüglich Installation und Konfiguration fließt in Anweisungen, die gleichzeitig die vollständige Dokumentation bilden und über Ansible ausgeführt werden. Anweisungen, **Tasks** werden in Rollen, **Roles** organisiert und über **Playbooks** ausgeführt.

Ausgangspunkt ist eine Artikelserie in der Zeitschrift c't, in der ein Projekt zum Server-Setup in einer Docker-Umgebung beschrieben wird. Es wurde eine Kopie erstellt, die für eine vorhandene Docker-Installation auf einem Raspberry Pi im Heimbereich angepasst wird.

Bevor mit der Automatisierung über Ansible begonnen wird, sollte das Ziel klar sein. Aus diesem Grund wurde die im c't-Projekt verwendete Docker-Installation zunächst manuell nachgebaut und in der Zielumgebung getestet. Erst im Anschluß wurde das c't-Projekt so angepasst, dass es die manuelle Konfiguration auch automatisch erstellt werden kann.

Wenn die Infrastruktur am Ende automatisch erzeugt und bereitgestellt werden kann, ist es an der Zeit, die Ansible-Konfiguration um weitere Playbooks für die konkret benötigten Container-Dienste zu erweitern.

## Managed node

### Raspberry Pi vorbereiten

Der bereits vorhandene Raspberry Pi soll der **managed node** sein, auf dem eine Docker-Infrastruktur installiert werden soll. Der Raspi muss per ssh vom **control node** erreichbar sein.

## Control node

### Ansible installieren

- [Pipfile](Pipfile)

**Pipenv** ist ein Paketmanager, der alle erforderliche Ressourcen bereitstellt, um eine virtuelle Ablaufumgebung für ein Python-Projekt zu erzeugen. Zu installierende Pakete werden über **Pipfile** verwaltet.

Unter Umständen muss die Python-Version an die im Betriebsystem installierte Version angepasst werden.

```shell
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]
passlib = "*"
ansible = "*"

[dev-packages]

[requires]
python_version = "3.10"
```

Zunächst werden die Pakete **passlib** und **ansible** in **Pipfile**  installiert:

```shell
andy@mars:~/git/ansible-workbench$ pipenv install
```

### Docker-Rolle installieren

**Ansible Galaxy** ist ein Repository zur Verwaltung und Bereitstellung von Rollen, die in den eigenen Autoamtisierungsprojekten verwendet werden können. Hier wird die Rolle zur Docker-Installation installiert:

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-galaxy role install geerlingguy.docker
Starting galaxy role install process
- downloading role 'docker', owned by geerlingguy
- downloading role from https://github.com/geerlingguy/ansible-role-docker/archive/7.1.0.tar.gz
- extracting geerlingguy.docker to /home/andy/.ansible/roles/geerlingguy.docker
- geerlingguy.docker (7.1.0) was installed successfully
```

Um auf die Konfigurationsdateien über die IDE zugreifen zu können, kann ein symbolischer Link angelegt werden. Der Link sollte anschließend der Datei **.gitignore** hinzugefügt werden, um ihn von der Synchronisation mit dem Repository auszuschließen:

```shell
andy@mars:~/git/ansible-workbench$ ln -s ~/.ansible/ .ansible
```

## Projekt anpassen

### Inventory konfigurieren

- [hosts](hosts)

Hier werden die Namen oder statischen IP-Adressen der **control nodes** hinterlegt:

```shell
[server]
raspberrypi

[server:vars]
ansible_become_method=sudo
```

Passend dazu wird im Verzeichnis **host_vars** eine Konfigurationsdatei mit dem Namen bzw. der statischen IP-Adresse pro **control node** angelegt:

- [host_vars/raspberrypi.yml](host_vars/raspberrypi.yml)

```yaml
ansible_user: andy
admin:
  name: andy
  key: "{{ lookup('file', '~/.ssh/home_rsa.pub') }}"
  email: "andreas.keye@gmail.com"
locale: de_DE.UTF-8
timezone: Europe/Berlin
docker_dir: "/docker"
```

In der ersten Zeile steht der Benutzername des Ansible-Anwenders. Es folgt der Name des Anwenders auf dem Server. Der kryptographische Schlüssel wird über die Lookup-Funktion in der lokalen SSH-Konfiguration gefunden und in die SSH-Konfiguration des Servers kopiert. Anschließend ist auf dem Server eine passwortlose Anmeldung möglich.

In der letzten Zeile wird das Installationsverzeichnis auf dem Server festgelegt, in das die zu installierenden Dienste kopiert werden sollen.

### Inventory testen

Die für eine automatisierte Installation hinterlegten Server können wie folgt getestet werden:

```shell
andy@mars:~/git/ansible-workbench$ ansible-inventory -i hosts --list
andy@mars:~/git/ansible-workbench$ ansible server -m ping -i hosts
```
### Docker-Rolle konfigurieren

- [~/.ansible/roles/geerlingguy.docker/defaults/main.yml](.ansible/roles/geerlingguy.docker/defaults/main.yml)

In der Konfiguration der Docker-Rolle müssen die User angegeben werden, die während der Installation der Gruppe **docker** hinzugefügt werden sollen.

```yaml
...
# A list of users who will be added to the docker group.
docker_users: [andy]
...
```

### Templates anpassen

Die ursprüngliche Adressierung der Dienste erfolgte über eine **subdomain**. Wo dies möglich ist, soll aber über einen **subfolder** adressiert werden. Auf die gleiche Weise soll das Traefik-Dashboard erreichbar sein. Dafür müssen das Master-Template sowie die Templates für Traefik und Portainer umgestellt werden:

- [compose_master_template.yml.j2](roles/compose_hull/templates/compose_master_template.yml.j2)
- [docker-compose.yml.j2](roles/traefik/templates/docker-compose.yml.j2)
- [docker-compose.yml.j2](roles/portainer/docker-compose.yml.j2)

## Playbooks

### Initiale Installation

Über dieses Playbook werden auf dem **control node** weitere Software-Pakete installiert, Dateien und Schlüssel kopiert und die Docker-Ablaufumgebung vorbereitet.

- [Playbook: initial-setup.yml](initial-setup.yml)

Bei der erstmaligen initialen Installation ist die passwortlose Anmeldung per SSH nicht möglich, da der öffentliche SSH-Schlüssel noch nicht hinterlegt wurde. Deshalb werden einmalig Benutzername und -kennwort abgefragt. Bei wiederholten Aufrufen ist dies nicht mehr erforderlich.

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook initial-setup.yml -i hosts --ask-pass --ask-become-pass
```

Die folgenden Aufgaben werden durchgeführt:

- [Rolle: system](roles/system)

  - Kryptographische Schlüssel für die passwortlose Anmeldung mit SSH übertragen
  - Benutzer der sudo-Gruppe hinzufügen
  - Installation der [Basis-Pakete](roles/system/vars/main.yml) mit **apt**
  - [Docker-Verzeichnis](host_vars/raspberrypi.yml) anlegen

- [Rolle: docker](.ansible)

  - Paketquelle für Docker inklusive der GPG-Schlüssel einrichten.
  - Docker und das Compose-Plugin installieren

Nach erfolgter Installation und Neuanmeldung des Users kann die Docker-Konfiguration auf dem Server getestet werden:

```shell
# Passwortloses login
andy@mars:~ $ ssh raspberrypi
Linux raspberrypi 6.1.0-rpi7-rpi-v8 #1 SMP PREEMPT Debian 1:6.1.63-1+rpt1 (2023-11-24) aarch64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri Feb  2 11:14:38 2024 from 192.168.178.55
# Gruppenzuordnung verifizieren
andy@raspberrypi:~ $ groups
andy adm dialout cdrom sudo audio video plugdev games users input render netdev lpadmin gpio i2c spi docker
# Docker-Installation verifizieren
andy@raspberrypi:~ $ docker -v
Docker version 25.0.1, build 29cf629
$ docker compose version
Docker Compose version v2.24.2
andy@raspberrypi:~ $ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

### Docker-Dienste installieren

Die Playbooks aller Services können gemeinsam über ein System-Playbook ausgeführt werden.
Dies ist aus noch ungeklärten Gründen nicht möglich.

- [Playbook: system-setup](system-setup.yml)

Aufruf:

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook system-setup.yml -i hosts
```

Werden die Playbooks einzeln ausgeführt, kommt es zu keinen Fehlermeldungen.

- [Playbook: traefik.yml](traefik.yml)
- [Playbook: watchtower.yml](watchtower.yml)
- [Playbook: autoheal.yml](autoheal.yml)
- [Playbook: portainer.yml](portainer.yml)

Die Playbooks können alternativ über ein Skript gestartet werden:

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook traefik.yml -i hosts
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook watchtower.yml -i hosts
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook autoheal.yml -i hosts
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook portainer.yml -i hosts
```

## Services direkt auf dem Host starten und stoppen

Alternativ dazu können die Services auch direkt auf dem Host gestartet werden. Da für jeden Service eine eigene Docker-Compose-Datei generiert wurde, muss auch jeder Service für sich gestartet werden.

```shell
# Services starten
docker compose \
	-f traefik/docker-compose.yml \
	-f watchtower/docker-compose.yml \
	-f autoheal/docker-compose.yml \
	-f portainer/docker-compose.yml \
	up -d
# Services stoppen
docker compose \
	-f portainer/docker-compose.yml \
	-f autoheal/docker-compose.yml \
	-f watchtower/docker-compose.yml \
	-f traefik/docker-compose.yml \
	down
```

## Services im Browser testen

- [Dashboard](https://tohus.dnshome.de/dashboard)
- [API, Rohdaten](https://tohus.dnshome.de/api/rawdata)
- [API, Version](https://tohus.dnshome.de/api/version)
- [Portainer](https://tohus.dnshome.de/portainer)

## Generierte Artefakte

Die folgenden Docker-Compose-Dateien werden auf den **managed nodes** generiert:

### .../traefik/docker-compose.yml

```yaml
#
# Ansible managed
#

# Labels for Traefik, Watchtower, and Autoheal
#   (docker compose ignores fields that start with `x-`. So we can use them to
#    define reusable fragments with `&anchors`. See:
#    https://docs.docker.com/compose/compose-file/11-extension/ )
x-labels: &base_labels
      traefik.enable: "true"
      traefik.docker.network: "proxy_net"
      traefik.http.services.traefik.loadbalancer.server.port: "8080"
      traefik.http.routers.traefik_web.EntryPoints: "web-secure"
      traefik.http.routers.traefik_web.tls: "true"
      traefik.http.routers.traefik_web.tls.certresolver: "default"
      com.centurylinklabs.watchtower.enable: "true"
      autoheal: "true"

# Reusable default networks configuration to ensure container is part of both
# the traefik network and the default network of this compose file
x-networks: &base_networks
# default:
  traefik_net:
    aliases:
      - traefik

# The main Docker Compose file
version: "3.8"

services:
  traefik:
    image: "traefik"
    container_name: "traefik"
    restart: always
    healthcheck:
      test: "traefik healthcheck"
    ports:
      - "80:80"
      - "443:443"
    environment:
      PUID: "1000"
      PGID: "1001"
      TZ: "Europe/Berlin"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:rw"
      - "/docker/traefik/traefik.yml:/etc/traefik/traefik.yml:ro"
      - "/docker/traefik/dynamic:/etc/traefik/dynamic"
      - "/docker/traefik/acme.json:/etc/traefik/acme/acme.json:rw"

    labels:
      << : *base_labels
#     Middleware
      traefik.http.middlewares.traefik_web-auth.basicauth.users: "admin:$$apr1$$X/y3j80i$$WCQ6u03uAmH3AGVYsblxg1"
      traefik.http.middlewares.dashboard-strip.stripprefix.prefixes: "/dashboard"
      traefik.http.routers.traefik_web.middlewares: "dashboard-strip,traefik_web-auth"
#     Routing
      traefik.http.routers.traefik_web.rule: "Host(`tohus.dnshome.de`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
      traefik.http.routers.traefik_web.service: api@internal

    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks: *base_networks

# Access the traefik-network
networks:
  traefik_net:
    name: proxy_net
    external: False
```

### .../portainer/docker-compose.yml

```yaml
#
# Ansible managed
#

# Labels for Traefik, Watchtower, and Autoheal
#   (docker compose ignores fields that start with `x-`. So we can use them to
#    define reusable fragments with `&anchors`. See:
#    https://docs.docker.com/compose/compose-file/11-extension/ )
x-labels: &base_labels
      traefik.enable: "true"
      traefik.docker.network: "proxy_net"
      traefik.http.services.portainer.loadbalancer.server.port: "9000"
      traefik.http.routers.portainer_web.EntryPoints: "web-secure"
      traefik.http.routers.portainer_web.tls: "true"
      traefik.http.routers.portainer_web.tls.certresolver: "default"
      com.centurylinklabs.watchtower.enable: "true"
      autoheal: "true"

# Reusable default networks configuration to ensure container is part of both
# the traefik network and the default network of this compose file
x-networks: &base_networks
# default:
  traefik_net:
    aliases:
      - portainer

# The main Docker Compose file
version: "3.8"

services:
  portainer:
    container_name: "portainer"
    image: "portainer/portainer-ce"
    restart: unless-stopped
    environment:
      TZ: "Europe/Berlin"
    volumes:
      - "/docker/portainer:/data:rw"
      - "/var/run/docker.sock:/var/run/docker.sock"

    labels:
      << : *base_labels
#     Middleware
      traefik.http.middlewares.portainer_web-strip.stripprefix.prefixes: "/portainer"
      traefik.http.routers.portainer_web.middlewares: "portainer_web-strip"
#     Routing
      traefik.http.routers.portainer_web.rule: "Host(`tohus.dnshome.de`) && PathPrefix(`/portainer`)"
      traefik.http.routers.portainer_web.service: "portainer"

    networks: *base_networks

# Access the traefik-network
networks:
  traefik_net:
    name: proxy_net
    external: True
```

### .../autoheal/docker-compose.yml

```yaml
#
# Ansible managed
#

# Labels for Traefik, Watchtower, and Autoheal
#   (docker compose ignores fields that start with `x-`. So we can use them to
#    define reusable fragments with `&anchors`. See:
#    https://docs.docker.com/compose/compose-file/11-extension/ )
x-labels: &base_labels
      com.centurylinklabs.watchtower.enable: "true"

# Reusable default networks configuration to ensure container is part of both
# the traefik network and the default network of this compose file
x-networks: &base_networks
# default:
  traefik_net:
    aliases:
      - autoheal

# The main Docker Compose file
version: "3.8"

services:
  autoheal:
    container_name: "autoheal"
    image: "willfarrell/autoheal:latest"
    restart: unless-stopped
    environment:
      AUTOHEAL_CONTAINER_LABEL: "autoheal"
      AUTOHEAL_INTERVAL: 60   # check every 60 seconds
    volumes:
      - "/etc/localtime:/etc/localtime:ro"
      - "/var/run/docker.sock:/var/run/docker.sock"
    labels: *base_labels
    networks: *base_networks

# Access the traefik-network
networks:
  traefik_net:
    name: proxy_net
    external: True
```

### .../watchtower/docker-compose.yml

```yaml
#
# Ansible managed
#

# Labels for Traefik, Watchtower, and Autoheal
#   (docker compose ignores fields that start with `x-`. So we can use them to
#    define reusable fragments with `&anchors`. See:
#    https://docs.docker.com/compose/compose-file/11-extension/ )
x-labels: &base_labels
      com.centurylinklabs.watchtower.enable: "true"
      autoheal: "true"

# Reusable default networks configuration to ensure container is part of both
# the traefik network and the default network of this compose file
x-networks: &base_networks
# default:
  traefik_net:
    aliases:
      - watchtower

# The main Docker Compose file
version: "3.8"

services:
  watchtower:
    container_name: "watchtower"
    image: "containrrr/watchtower:latest"
    restart: unless-stopped
    environment:
      TZ: "Europe/Berlin"             # https://containrrr.dev/watchtower/arguments/#time_zone
      WATCHTOWER_CLEANUP: "true"       # https://containrrr.dev/watchtower/arguments/#cleanup
      WATCHTOWER_LABEL_ENABLE: "true"  # https://containrrr.dev/watchtower/arguments/#filter_by_enable_label
      WATCHTOWER_INCLUDE_RESTARTING: "true"
      WATCHTOWER_INCLUDE_STOPPED: "true"
      WATCHTOWER_REVIVE_STOPPED: "true"
      WATCHTOWER_POLL_INTERVAL: "86400"  # https://containrrr.dev/watchtower/arguments/#poll_interval
      WATCHTOWER_HTTP_API_UPDATE: "true"
      WATCHTOWER_HTTP_API_TOKEN: "jP4nalPjSva67SXHV4kJCdS67"
      WATCHTOWER_HTTP_API_PERIODIC_POLLS: "true"
    volumes:
      - "/docker/watchtower:/config"
      - "/var/run/docker.sock:/var/run/docker.sock"
    labels: *base_labels
    networks: *base_networks

# Access the traefik-network
networks:
  traefik_net:
    name: proxy_net
    external: True
```

## Verweise

### Dokumentation

  - [Dokumentation](https://docs.ansible.com/ansible/latest/index.html)
  - [Templating (Jinja2)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html)
  - [Template Designer Documentation](https://jinja.palletsprojects.com/en/3.1.x/templates/)
  - []()

### Docker-Tutorials

  - [Initial Server Setup with Ubuntu](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-20-04)
  - [How To Install and Use Docker on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)
  - []()

### Ansible-Tutorials

  - [How to Use Ansible to Automate Initial Server Setup on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-use-ansible-to-automate-initial-server-setup-on-ubuntu-20-04)
  - [How to Use Ansible to Install and Set Up Docker on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-use-ansible-to-install-and-set-up-docker-on-ubuntu-20-04)
  - []()

### Traefik-Beispiele

  - [Routing with SubDirectory (Host + Path)](https://community.traefik.io/t/routing-with-subdirectory-host-path/6805)
  - [Route Traefik to subfolder](https://serverfault.com/questions/988488/route-traefik-to-subfolder)
  - [Reverse proxy in Traefik with subdirectories](https://iceburn.medium.com/reverse-proxy-in-traefik-with-subdirectories-eef4261939e)
  - [Docker compose file for Traefik](https://gist.github.com/stefanfluit/0056bf42c2a2f729640ea755e03b1d5b)
  - [Advanced configuration with Docker Compose](https://mmorejon.io/en/blog/traefik-2-advanced-configuration-docker-compose/)
  - []()
