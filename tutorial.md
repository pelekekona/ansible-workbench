- [Ansible-Tutorial](#ansible-tutorial)
  - [Installationen](#installationen)
    - [Pipfile](#pipfile)
    - [Docker](#docker)
  - [Inventory anpassen](#inventory-anpassen)
    - [hosts](#hosts)
    - [host\_vars/raspberrypi.yml](#host_varsraspberrypiyml)
  - [Inventory testen](#inventory-testen)
  - [Konfiguration der Docker-Rolle anpassen](#konfiguration-der-docker-rolle-anpassen)
    - [~/.ansible/roles/geerlingguy.docker/defaults/main.yml:](#ansiblerolesgeerlingguydockerdefaultsmainyml)
  - [initial-setup.yml](#initial-setupyml)
    - [Aufruf](#aufruf)
    - [Rolle: system](#rolle-system)
    - [Rolle: docker](#rolle-docker)
    - [Rolle: compose\_hull](#rolle-compose_hull)
  - [system-setup](#system-setup)
    - [Aufruf](#aufruf-1)
  - [traefik.yml](#traefikyml)
  - [watchtower.yml](#watchtoweryml)
  - [autoheal.yml](#autohealyml)
  - [portainer.yml](#portaineryml)
  - [Services einzeln über Ansible starten](#services-einzeln-über-ansible-starten)
  - [Services auf dem Host starten](#services-auf-dem-host-starten)
  - [Auf Services zugreifen](#auf-services-zugreifen)
    - [Entfernter Zugriff über Subdomain](#entfernter-zugriff-über-subdomain)
    - [Subdirectory statt Subdomain](#subdirectory-statt-subdomain)
    - [Lokaler Zugriff](#lokaler-zugriff)
  - [Generierte Docker-Compose-Dateien](#generierte-docker-compose-dateien)
    - [traefik.yml](#traefikyml-1)
    - [portainer.yml](#portaineryml-1)
    - [autoheal.yml](#autohealyml-1)
    - [watchtower.yml](#watchtoweryml-1)
  - [Verweise](#verweise)
    - [Dokumentation](#dokumentation)
    - [Docker-Tutorials](#docker-tutorials)
    - [Ansible-Tutorials](#ansible-tutorials)
    - [Traefik-Beispiele](#traefik-beispiele)

# Ansible-Tutorial

## Installationen

In den folgenden Ausführungen bezeichnet ***Server*** den durch Ansible zu verwaltenden Server.

### [Pipfile](Pipfile)

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

Die packages **passlib** und **ansible** in **Pipfile** werden explizit installiert:

```shell
andy@mars:~/git/ansible-workbench$ pipenv install
```

### Docker

Die Rolle zur Docker-Installation wird über **ansible-galaxy** installiert:

```shell
$ pipenv run ansible-galaxy role install geerlingguy.docker
Starting galaxy role install process
- downloading role 'docker', owned by geerlingguy
- downloading role from https://github.com/geerlingguy/ansible-role-docker/archive/7.1.0.tar.gz
- extracting geerlingguy.docker to /home/andy/.ansible/roles/geerlingguy.docker
- geerlingguy.docker (7.1.0) was installed successfully
```

Symbolischen Link anlegen, um die Konfigurationsdateien in der IDE im Zugriff zu haben. Der Link sollte anschließend der Datei **.gitignore** hinzugefügt werden, um ihn von der Synchronisation mit dem Repository auszuschließen.

```shell
andy@mars:~/git/ansible-workbench$ ln -s ~/.ansible/ .ansible
```

## Inventory anpassen

### [hosts](hosts)

In der zweiten Zeile wird der Name oder die statische IP-Adresse des Servers hinterlegt.

```shell
[server]
raspberrypi

[server:vars]
ansible_become_method=sudo
```

Passend dazu wird im Verzeichnis **host_vars** eine Konfigurationsdatei mit dem Namen bzw. der statischen IP-Adresse angelegt.

### [host_vars/raspberrypi.yml](host_vars/raspberrypi.yml)

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

## Inventory testen

```shell
#
andy@mars:~/git/ansible-workbench$ ansible-inventory -i hosts --list
#
andy@mars:~/git/ansible-workbench$ ansible server -m ping -i hosts
```
## Konfiguration der Docker-Rolle anpassen

### [~/.ansible/roles/geerlingguy.docker/defaults/main.yml](.ansible/roles/geerlingguy.docker/defaults/main.yml):

In der Konfiguration der Docker-Rolle müssen die User angegeben werden, die während der Installation der Gruppe **docker** hinzugefügt werden sollen.

```yaml
...
# A list of users who will be added to the docker group.
docker_users: [andy]
...
```

## [initial-setup.yml](initial-setup.yml)

```yaml
- hosts: server
  become: true
  vars:
    pip_package: python3-pip
  roles:
    - system
    - geerlingguy.docker
```

### Aufruf

Bei der erstmaligen initialen Installation ist die passwortlose Anmeldung per SSH nicht möglich, da der öffentliche SSH-Schlüssel noch nicht hinterlegt wurde.

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook initial-setup.yml -i hosts --ask-pass --ask-become-pass
```

### [Rolle: system](roles/system)

- Kryptographische Schlüssel für die passwortlose Anmeldung mit SSH übertragen
- Benutzer der sudo-Gruppe hinzufügen
- Installation der [Basis-Pakete](roles/system/vars/main.yml) mit **apt**
- [Docker-Verzeichnis]([host_vars/raspberrypi.yml](host_vars/raspberrypi.yml)) anlegen

### [Rolle: docker](.ansible)

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

### Rolle: [compose_hull](roles/compose_hull)

```Baustelle...```

## [system-setup](system-setup.yml)

Hier werden die Servicerollen nacheinander aufgerufen, was leider zur Zeit nicht funktioniert:

```yaml
- hosts: server
  become: true
  roles:
    - system
    - geerlingguy.docker
    - role: traefik
      vars:
        service_cfg: "{{ traefik }}"
    - role: watchtower
      vars:
        service_cfg: "{{ watchtower }}"
    - role: autoheal
      vars:
        service_cfg: "{{ autoheal }}"
    - role: portainer
      vars:
        service_cfg: "{{ portainer }}"
```

### Aufruf

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook system-setup.yml -i hosts
```

Werden die Rollen einzeln gestartet, kommt es zu keinen Fehlermeldungen:

## [traefik.yml](traefik.yml)

```yaml
- hosts: server
  become: true
  roles:
    - role: traefik
      vars:
        service_cfg: "{{ traefik }}"
```

## [watchtower.yml](watchtower.yml)

```yaml
- hosts: server
  become: true
  roles:
    - role: watchtower
      vars:
        service_cfg: "{{ watchtower }}"
```

## [autoheal.yml](autoheal.yml)

```yaml
- hosts: server
  become: true
  roles:
    - role: autoheal
      vars:
        service_cfg: "{{ autoheal }}"
```

## [portainer.yml](portainer.yml)

```yaml
- hosts: server
  become: true
  roles:
    - role: portainer
      vars:
        service_cfg: "{{ portainer }}"
```

## Services einzeln über Ansible starten

```shell
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook traefik.yml -i hosts
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook watchtower.yml -i hosts
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook autoheal.yml -i hosts
andy@mars:~/git/ansible-workbench$ pipenv run ansible-playbook portainer.yml -i hosts
```

## Services auf dem Host starten

Alternativ dazu können die Services auch direkt auf dem Host gestartet werden. Da für jeden Service eine eigene Docker-Compose-Datei generiert wurde, muss auch jeder Service für sich gestartet werden.

```shell
andy@raspberrypi:/docker $ docker compose -f traefik/docker-compose.yml up
andy@raspberrypi:/docker $ docker compose -f watchtower/docker-compose.yml up
andy@raspberrypi:/docker $ docker compose -f autoheal/docker-compose.yml up
andy@raspberrypi:/docker $ docker compose -f portainer/docker-compose.yml up
```

## Auf Services zugreifen

### Entfernter Zugriff über Subdomain

- [Dashboard](https://tohus.dnshome.de/dashboard#/)
- [Portainer] noch unbekannt

### Subdirectory statt Subdomain

Beispiel für die Traefik-Konfiguration in **docker-compose.yml**:

```yaml
- "traefik.http.routers.typo3-${NAMEOFSERVICE}.rule=(Host(`${HOSTNAME}`) && Path(`${DIRECTORY}`))"
```

### Lokaler Zugriff

Muss noch herausgefunden werden...

## Generierte Docker-Compose-Dateien

### traefik.yml

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
      traefik.docker.network: "traefik_default"
      traefik.http.services.traefik.loadbalancer.server.port: "8080"
      traefik.http.routers.traefik_web.EntryPoints: "web-secure"
#     traefik.http.routers.traefik_web.rule: "Host(`tohus.dnshome.de`)"
      traefik.http.routers.traefik_web.rule: "Host(`tohus.dnshome.de`) && PathPrefix(`/traefik`)"
      traefik.http.middlewares.traefikpathstrip.stripprefix.prefixes: "/traefik"
      traefik.http.routers.traefik.middlewares: "traefikpathstrip@docker"
      traefik.http.routers.traefik_web.service: "traefik"
      traefik.http.routers.traefik_web.tls: "true"
      traefik.http.routers.traefik_web.tls.certresolver: "default"
      com.centurylinklabs.watchtower.enable: "true"
      autoheal: "true"

# Reusable default networks configuration to ensure container is part of both
# the traefik network and the default network of this compose file
x-networks: &base_networks
  default:
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
      traefik.http.middlewares.traefik_web-auth.basicauth.users: "admin:$$apr1$$X/y3j80i$$WCQ6u03uAmH3AGVYsblxg1"
      traefik.http.routers.traefik_web.middlewares: "traefik_web-auth"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks: *base_networks

# Access the traefik-network
networks:
  traefik_net:
    name: traefik_default
    external: true
```

### portainer.yml

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
      traefik.docker.network: "traefik_default"
      traefik.http.services.portainer.loadbalancer.server.port: "9000"
      traefik.http.routers.portainer_web.EntryPoints: "web-secure"
#     traefik.http.routers.portainer_web.rule: "Host(`tohus.dnshome.de`)"
      traefik.http.routers.portainer_web.rule: "Host(`tohus.dnshome.de`) && PathPrefix(`/portainer`)"
      traefik.http.middlewares.portainerpathstrip.stripprefix.prefixes: "/portainer"
      traefik.http.routers.portainer.middlewares: "portainerpathstrip@docker"
      traefik.http.routers.portainer_web.service: "portainer"
      traefik.http.routers.portainer_web.tls: "true"
      traefik.http.routers.portainer_web.tls.certresolver: "default"
      com.centurylinklabs.watchtower.enable: "true"
      autoheal: "true"

# Reusable default networks configuration to ensure container is part of both
# the traefik network and the default network of this compose file
x-networks: &base_networks
  default:
  traefik_net:
    aliases:
      - portainer

# The main Docker Compose file
version: "3.8"

services:
  portainer:
    container_name: "portainer"
    image: "portainer/portainer-ce:alpine"
    restart: unless-stopped
    environment:
      TZ: "Europe/Berlin"
    volumes:
      - "/docker/portainer:/data:rw"
      - "/var/run/docker.sock:/var/run/docker.sock"
    labels: *base_labels
    networks: *base_networks

# Access the traefik-network
networks:
  traefik_net:
    name: traefik_default
    external: true
```

### autoheal.yml

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
  default:
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
    name: traefik_default
    external: true
```

### watchtower.yml

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
  default:
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
    name: traefik_default
    external: true
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
