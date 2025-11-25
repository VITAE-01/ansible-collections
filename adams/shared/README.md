# Ansible Collection - adams.shared

Documentation for the collection.

Overview
--------
This collection contains shared roles for user and group management used across environments. It provides small, focused roles to add system groups and users in a consistent, testable way.

Roles
-----
- `add_group_role`: Create and manage system groups. Contains idempotent tasks and a rollback task.
- `add_user_role`: Create users and manage group membership. Includes optional home skeleton and rollback tasks.

Usage
-----
Basic playbook examples:

```yaml
- hosts: all

  roles:
    - name: adams.shared.add_group_role

- hosts: all
  roles:
    - name: adams.shared.add_user_role
```

Key variables
-------------
- `deploy_groups` (list) : information of the group to create.
- `deploy_users` (list) : information of the user to create.
- deploy_groups:
  - name: developers
  - gid: 2000
  - system: false
- deploy_users:
  - user: "john_doe"
  - create_home: true
  - uid: 1050
  - groups: 
    - "developers"
    - "testers"
  - password: "{{ 'XXXXXX' | password_hash('sha512') }}"
  - shell: "/bin/bash"
- See each role's `defaults/main.yml` for full variable lists and defaults.

Testing
-------
Run the role test playbooks (relative to the collection roles directory):

```powershell
cd ansible-collections/adams/shared/roles

ansible-playbook -i add_user_role/tests/inventory add_user_role/tests/test.yml

ansible-playbook -i add_group_role/tests/inventory add_group_role/tests/test.yml
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
For example: `adams-shared-v1.2.0`.

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

1. Create a new directory under `adams/shared/roles`:
   ```bash
   mkdir -p adams/shared/roles/new-role-name
   ```

2. Initialize collection metadata:
   ```bash
   cd adams/shared/roles/
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
ansible-playbook playbooks/init_user.yml --tags rollback
```

Notes
-----
Keep role responsibilities small and idempotent. Use the `release.sh` script to publish and tag releases consistently.