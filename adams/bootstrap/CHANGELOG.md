# Changelog - adams.bootstrap

## 0.0.1

- New collection `adams.bootstrap` for configuring new RedHat-family hosts.
- New role `system_role`:
  - Pre-tasks detect the OS family, check it is supported (RedHat for now) and load the
    matching `vars/<family>.yml`.
  - Pre-flight asserts: the play stops if `repo_host` is not defined.
  - Tag-driven entry point: nothing runs unless `--tags deploy`, `update` or `rollback` is passed.
  - Sets the hostname (default `inventory_hostname`).
  - Adds `/etc/yum.repos.d/adamslab.repo` (RHEL 9.6 BaseOS, AppStream and RHEL 9 Custom repos).
  - Refreshes the dnf metadata cache.
  - Update and rollback tasks.
