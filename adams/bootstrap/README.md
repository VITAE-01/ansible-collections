# Ansible Collection - adams.bootstrap

Documentation for the collection.

Overview
--------
This collection configures a new host. It sets the hostname, configure local repositories and refreshes the repository cache.

Roles
-----
- `system_role`: Pre-flight checks (`repo_host` must be defined),
  sets the hostname, adds repo template file and runs the equivalent of
  `dnf makecache`. Includes update and rollback tasks.

Usage
-----
Basic playbook example:

```yaml
- hosts: new_hosts
  become: true
  vars:
    repo_host: repo.adamslab.local
  roles:
    - name: adams.bootstrap.system_role
```

```bash
ansible-playbook -i inventory bootstrap.yml --tags deploy
ansible-playbook -i inventory bootstrap.yml --tags update
ansible-playbook -i inventory bootstrap.yml --tags rollback
```

Key variables
-------------
- `repo_host` (string, **required**): There is no default; the play
  stops if it is not set.
- `deploy_hostname` (string): hostname to set. Default `{{ inventory_hostname }}`.
- `deploy_repos` (list)
- deploy_repos:
  - id: adams-repo-x86_64-9.6-baseos
  - name: Adams local repo for x86_64 - RHEL 9.6 BaseOS
  - baseurl: "http://{{ repo_host }}/adams-repos/rhel9/x86_64/9.6/baseos/rhel-9-for-x86_64-baseos-eus-rpms/"
  - enabled: 1
  - gpgcheck: 0
- See `roles/system_role/defaults/main.yml` for the full list and defaults.

Testing
-------
Syntax-check the role test playbook (relative to the collection roles directory):

```bash
cd ansible-collections/adams/bootstrap/roles

ansible-playbook -i system_role/tests/inventory system_role/tests/test.yml --syntax-check
```

Running the test playbook for real changes the target's hostname and repo configuration. Only
run it against a test VM, and pass `-e repo_host=<host> --tags deploy`.

Versioning & Releases
----------------------
- Update `version` in the collection's `galaxy.yml` file
- A release is triggered manually in Jenkins (`jenkinsfile.collections`, `COLLECTION=bootstrap`),
  which publishes to the Nexus Galaxy repository. Collections whose version is unchanged are
  skipped.
- Releases are published from the `main` branch (`AUTOMATION_BRANCH=main`). Tags follow
  `<collection>-<VERSION>`, for example `bootstrap-0.0.1`.
- See `CHANGELOG.md` for changes per version.

Notes
-----
- RedHat-family only. The role supports RedHAt family only. Other Distributions will be supported later.
- `/etc/hosts` is not modified.
- Keep role responsibilities small and idempotent.
