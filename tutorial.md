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
$ pipenv install
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

## Konfigurationen anpassen

## [hosts](hosts)

In der zweiten Zeile wird der Name oder die statische IP-Adresse des Servers hinterlegt.

```shell
[server]
raspberrypi

[server:vars]
ansible_become_method=sudo
```

Passend dazu wird im Verzeichnis **host_vars** eine Konfigurationsdatei mit dem Namen bzw. der statischen IP-Adresse angelegt.

## [host_vars/raspberrypi.yml](host_vars/raspberrypi.yml)

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

## [~/.ansible/roles/geerlingguy.docker/defaults/main.yml](.ansible/roles/geerlingguy.docker/defaults/main.yml):

In der Konfiguration der Docker-Rolle müssen die User angegeben werden, die während der Installation der Gruppe **docker** hinzugefügt werden sollen.

```yaml
...
# A list of users who will be added to the docker group.
docker_users: [andy]
...
```

## Playbook: [initial-setup.yml](initial-setup.yml)

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
pipenv run ansible-playbook initial-setup.yml -i hosts --ask-pass --ask-become-pass
```

### [Rolle: system](roles/system)

- Kryptographische Schlüssel für die passwortlose Anmeldung mit SSH übertragen
- Benutzer der sudo-Gruppe hinzufügen
- Installation der [Basis-Pakete](roles/system/vars/main.yml) mit **apt**
- [Docker-Verzeichnis]([host_vars/raspberrypi.yml](host_vars/raspberrypi.yml)) anlegen

### [Rolle: docker](.ansible)

- Paketquelle für Docker inklusive der GPG-Schlüssel einrichten.
- Docker und das Compose-Plugin installieren

Nach erfolgter Installation und Neuanmeldung des Users kann die Docker-Konfiguration getestet werden:

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

## Playbook: [system-setup](system-setup.yml)

### Aufruf

```shell
$ pipenv run ansible-playbook system-setup.yml -i hosts
```

### Rolle [traefik.yml](traefik.yml)

```shell
- hosts: server
  become: true
  roles:
    - role: traefik
      vars:
        service_cfg: "{{ traefik }}"
```

## Services über Ansible starten

```shell
$ pipenv run ansible-playbook traefik.yml -i hosts
$ pipenv run ansible-playbook watchtower.yml -i hosts
$ pipenv run ansible-playbook autoheal.yml -i hosts
$ pipenv run ansible-playbook portainer.yml -i hosts
```

## Services auf dem Host starten

Falls der Start der Services über Ansible noch nicht funktioniert, aber die Docker-Konfiguration auf dem Raspberry Pi bereits angelegt ist, können die Services auf dem Host auch manuell gestartet werden:

```shell
$ andy@raspberrypi:/docker $ docker compose -f traefik/docker-compose.yml up
$ andy@raspberrypi:/docker $ docker compose -f watchtower/docker-compose.yml up
$ andy@raspberrypi:/docker $ docker compose -f autoheal/docker-compose.yml up
$ andy@raspberrypi:/docker $ docker compose -f portainer/docker-compose.yml up
```
