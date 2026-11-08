system_role
===========

Base system configuration for a new RedHat-family host. The role:

1. Detects the OS family, checks that it is supported and loads `vars/<family>.yml`
   (`tasks/pre_tasks.yml`), then checks that `repo_host` is defined (`tasks/assert.yml`).
   If either check fails, the play stops for every host.
2. Sets the hostname (by default to the host's `inventory_hostname`).
3. Writes template file to local repositories.
4. Refreshes the dnf metadata cache (the equivalent of `dnf makecache`).

Task files:

`tasks/main.yml` only includes the files below. Each include runs only when its tag is passed
with `--tags`, so **a run without `--tags deploy`, `update` or `rollback` does nothing**.

| File | Tag | What it does |
|------|-----|--------------|
| `tasks/pre_tasks.yml` | `deploy`, `update`, `rollback` | Detects the OS family (gathering facts if needed), checks it is in `_system_supported_os_families`, loads `vars/<family>.yml` |
| `tasks/assert.yml` | `deploy`, `update`, `rollback` | Pre-flight checks (`repo_host` is defined) |
| `tasks/deploy.yml` | `deploy` | Sets the hostname, adds the repo file, refreshes the dnf cache |
| `tasks/update.yml` | `update` | Re-applies the hostname and repo file; refreshes the dnf cache only when the repo file changed |
| `tasks/rollback.yml` | `rollback` | Removes the repo file |

Requirements
------------

- RedHat-family host with dnf (RHEL / Rocky / Alma 8 or 9).
- Run with sudo priviledges (`become: true`).
- OS facts are gathered by the role if the play did not gather them.

Role Variables
--------------

| Variable | Where | Default | Description |
|----------|-------|---------|-------------|
| `repo_host` | **required**, caller | none | Host (and optional `:port`) of the adams repository server. The play fails if it is not set. |
| `deploy_hostname` | `defaults/main.yml` | `{{ inventory_hostname }}` | Hostname to set on the host. |
| `deploy_repos` | `defaults/main.yml` | BaseOS, AppStream and Custom repos for RHEL 9.6 x86_64 | List of repo sections. Each has `id`, `name`, `baseurl`, `enabled`, `gpgcheck` and an optional `gpgkey`. |
| `redhat_repo_dir` | `vars/RedHat.yml` | `/etc/yum.repos.d` | Where the repo file is written. |
| `redhat_repo_file` | `vars/RedHat.yml` | `adamslab.repo` | Repo file name (the template is `templates/<name>.j2`). |
| `_system_supported_os_families` | `vars/main.yml` | `[RedHat]` | Internal. OS families the role supports; each needs a `vars/<family>.yml`. |

Dependencies
------------

None.

Example Playbook
----------------

```yaml
- hosts: new_hosts
  become: true
  vars:
    repo_host: repo.adamslab.local
  roles:
    - adams.bootstrap.system_role
```

```bash
ansible-playbook -i inventory bootstrap.yml --tags deploy
ansible-playbook -i inventory bootstrap.yml --tags update
ansible-playbook -i inventory bootstrap.yml --tags rollback
```

Without `--tags`, nothing runs. `--tags deploy,update` runs both directions.

License
-------

GPL-2.0-or-later

Author Information
------------------

Adams <adeyemoadams005@gmail.com>
