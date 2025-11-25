# Ansible Collection - adams.webservers

Documentation for the collection.

Overview
--------
This collection contains webserver roles for installing webserver packages and deploying webservers used across environments. It provides small, focused roles to deploy webservers in a consistent, testable way.

Roles
-----
- `bootstrap_setup_role`: Install webserver packages. Contains idempotent tasks and a rollback task.
- `webservers_role`: Deploy webservers and trigger webserver services restart for update and a rollback tasks.

Usage
-----
Basic playbook examples:

```yaml
- hosts: all

  roles:
    - name: adams.webservers.bootstrap_setup_role

- hosts: all
  roles:
    - name: adams.webservers.webservers_role
```

Key variables
-------------
- `deb_packages` (list) : packages related to Debian distributions.
- `deb_services` (list) : services related to Debian distributions.
- `redhat_packages` (list) : packages related to Redhat distribution.
- `redhat_services` (list) : services related to Redhat distribution.
- See each role's `defaults/main.yml` for full variable lists and defaults.

Testing
-------
Run the role test playbooks (relative to the collection roles directory):

```powershell
cd ansible-collections/adams/webservers/roles

ansible-playbook -i bootstrap_setup_role/tests/inventory bootstrap_setup_role/tests/test.yml

ansible-playbook -i webservers_role/tests/inventory webservers_role/tests/test.yml
```

Versioning & Releases
----------------------
- Update version in the collection's `galaxy.yml` file
- Version changes trigger automated release processes
- All changes are tracked through git tags

Release using the repository `release.sh` script. Tags follow the convention:

```
<collection>-v<VERSION>
```
For example: `adams-webservers-v1.2.0`.

Installation
------------
- From Nexus (example):

```bash

```

- From source (build then install):

```bash

```

Contributing / Adding New Roles
-------------------------------
To add a new role to this collection:

1. Create a new directory under `adams/webservers/roles`:
   ```bash
   mkdir -p adams/webservers/roles/new-role-name
   ```

2. Initialize collection metadata:
   ```bash
   cd adams/webservers/roles/
   ansible-galaxy role init new-role-name --force
   ```

3. Update `galaxy.yml` with:
   - Meaningful description
   - Accurate authors and license
   - Tags for discoverability
   - Repository and documentation URLs

4. Update galaxy.yml version tag and run release script

Requirements
------------
- Test inventory shells use local VMs/containers — ensure your test target is available.

Rollbacks & Tags
-----------------
Each role provides a `tasks/rollback.yml` for reversing changes where feasible. Use playbook tags to run rollbacks selectively, for example:

```bash
ansible-playbook playbooks/init_webserver.yml --tags rollback
```

Notes
-----
Keep role responsibilities small and idempotent. Use the `release.sh` script to publish and tag releases consistently.