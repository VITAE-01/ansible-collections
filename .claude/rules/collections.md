---
paths:
  - "adams/**"
  - "release.sh"
---

# Collection rules: `adams` namespace

All collections in this repository live under the single namespace `adams`. A new
collection must copy the layout and conventions of the reference collections,
`adams/shared` and `adams/webservers`. When something is unclear, follow what they do.

## 1. Location and naming

- Each collection is a directory directly under `adams/`: `adams/<collection_name>/`.
- `<collection_name>` uses only lowercase letters, digits and underscores. It must not start
  with a digit or underscore, and it must not contain `__` or hyphens (for example `databases`
  or `load_balancers`).
- The directory name must equal `name:` in the collection's `galaxy.yml`.
- **Only collection directories may exist directly under `adams/`.** `release.sh` runs
  `ls adams/` and treats every entry as a collection to build and release, so a stray file or
  folder there breaks the pipeline.

## 2. Creating a collection

Run this from the repository root so the scaffold lands in `adams/<collection_name>`:

```bash
ansible-galaxy collection init adams.<collection_name>
```

Then delete any scaffold content the reference collections do not have (for example `docs/`),
so the result matches section 3.

## 3. Required collection layout

```
adams/<collection_name>/
├── galaxy.yml            # collection metadata (section 4)
├── README.md             # collection docs (section 7)
├── meta/
│   └── runtime.yml       # Ansible runtime metadata
├── plugins/
│   └── README.md         # keep this even when there are no plugins yet
└── roles/
    └── <role_name>_role/ # one or more roles (section 5)
```

## 4. `galaxy.yml`

- `namespace: adams` is always this value.
- `name: <collection_name>` must match the directory name.
- `version:` uses semantic versioning (`MAJOR.MINOR.PATCH`). New collections start at `1.0.0`.
  - Write it **unquoted on one top-level line**, as in `version: 1.0.0`. `release.sh` reads it
    with `grep '^version:' | awk '{print $2}'`, so quotes or an inline comment would end up in
    the tag and tarball names.
- `readme: README.md`
- `license: [GPL-2.0-or-later]` with `license_file: ''`, the same as the existing collections.
- Give `authors`, `description`, `tags`, `repository`, `documentation`, `homepage` and `issues`
  real values. Do not copy the `your name <example@domain.com>` or `example.com` placeholders.
- List dependencies on other `adams` collections under `dependencies:` with a version range,
  for example `adams.shared: ">=1.0.0"`.

## 5. Roles

### Naming
- Role directories are snake_case and **end in `_role`**, for example `add_user_role` or
  `bootstrap_setup_role`.
- Playbooks call a role by its FQCN: `adams.<collection_name>.<role_name>_role`.

### Layout
Create each role inside `roles/` with `ansible-galaxy role init <role_name>_role`. Every new
role must have the layout below. Some existing roles still use the older `<action>.yml` +
`rollback.yml` layout; leave those as they are unless the user asks to migrate them.

```
<role_name>_role/
├── README.md
├── defaults/main.yml
├── handlers/main.yml
├── meta/main.yml
├── tasks/
│   ├── main.yml
│   ├── deploy.yml
│   ├── update.yml
│   └── rollback.yml
├── tests/
│   ├── inventory
│   └── test.yml
└── vars/
    ├── main.yml
    ├── Debian.yml        # only when the role is OS-specific
    └── RedHat.yml        # only when the role is OS-specific
```

Add `files/` or `templates/` only when the role needs them. A helper role that exists only to
share handlers or vars with sibling roles, like `webservers/roles/common_role`, can leave out
`tasks/`, `tests/` and `meta/`.

### Tasks
- `tasks/main.yml` is the role's entry point and contains no logic. It only imports the deploy,
  update and rollback files. Use `import_tasks` (static) so the tags on the imported tasks
  apply; an OS-specific role loads its vars first (see below).
  ```yaml
  ---
  # tasks file for <role_name>_role

  - ansible.builtin.import_tasks: deploy.yml
  - ansible.builtin.import_tasks: update.yml
  - ansible.builtin.import_tasks: rollback.yml
  ```
- **Every task has the tag `deploy`, `update` or `rollback`.**. Callers choose the direction with `--tags deploy`
  or `--tags update` or `--tags rollback`.
- **Every role ships a rollback** that undoes its deploy tasks where possible, such as stopping
  services or removing packages, files and users. Rollback task names start with
  `Rollback - `, as in `Rollback - Delete Users`.
- Use FQCN module names such as `ansible.builtin.user` or `ansible.builtin.service`, never the
  short names.
- Give every task a descriptive `name:` and keep tasks idempotent.
- Use `block`/`rescue` where a failure should be handled gracefully, as `add_user.yml` does.

### OS-specific behaviour
- Load the OS vars with:
  ```yaml
  - name: Include OS-specific variables
    tags: deploy, update, rollback
    ansible.builtin.include_vars:
      file: "{{ ansible_os_family }}.yml"
  ```
- Put the values in `vars/Debian.yml` and `vars/RedHat.yml`, and prefix the variable names by
  OS family: `deb_packages`, `deb_services`, `redhat_packages`, `redhat_services`.
- Name OS-specific task files `<os>_<action>.yml` and `<os>_rollback.yml` (for example
  `deb_package.yml` or `redhat_rollback.yml`), and guard them with
  `when: ansible_os_family == 'Debian'` or `'RedHat'`.

### Variables and handlers
- User inputs go in `defaults/main.yml` as lists of dicts named `deploy_<thing>`, for example
  `deploy_users` or `deploy_groups`. Internal flags start with an underscore, for example
  `_adams`.
- Never put real secrets in defaults. Run example passwords through `password_hash`, and keep
  real values in the consuming playbook or in a vault.
- Handlers that restart services listen on the topics `deb service restart` and
  `redhat service restart`. When several roles in one collection share handlers, put them in a
  `common_role` and load it with `ansible.builtin.include_role`.

## 6. Testing

- TBD - molecule or ansible-test.
- ansible lint run on the collection and all roles, and fix any warnings or errors.
- The collection must build cleanly:
  `ansible-galaxy collection build --force adams/<collection_name> --output-path dist/`.
  Delete `dist/` afterwards and never commit it.

## 7. Documentation

- The collection `README.md` follows the existing collections. Its title is
  `# Ansible Collection - adams.<collection_name>`, followed by these sections: **Overview,
  Roles, Usage, Key variables, Testing, Versioning & Releases, Notes**.
- Each role's `README.md` replaces the `ansible-galaxy` template text with a real description,
  the role's variables and dependencies, and an example playbook that uses the FQCN.

## 8. Versioning and release

- Each collection is released separately. A release is triggered manually in Jenkins, which
  runs `release.sh` based on the job's parameters. (The CI details are still being refined.)
- A release happens only when `version` in `galaxy.yml` changes. If the version is unchanged,
  its tag already exists and the collection is skipped. **Bump the version in every PR that
  changes a collection:**
  - PATCH for fixes
  - MINOR for new roles or backwards-compatible variables
  - MAJOR for breaking changes, such as renamed or removed roles or variables
- Released artifacts use the names below. Do not rename a collection after it has been
  released.
  - Git tag and GitHub release: `<collection_name>-v<VERSION>-<ENV>`
  - Built tarball: `adams-<collection_name>-<VERSION>.tar.gz`
  - Nexus path: `<NEXUS_REPO_URL>/adams-<collection_name>-<VERSION>-<ENV>.tar.gz`

## 9. Checklist for a new collection

- [ ] `adams/<collection_name>/` exists, has a valid name, and matches `name` in `galaxy.yml`
- [ ] `galaxy.yml` has `namespace: adams`, an unquoted `version: 1.0.0`, GPL-2.0-or-later and no placeholders
- [ ] `meta/runtime.yml`, `plugins/README.md` and `README.md` are present
- [ ] Every role name ends in `_role`, and each role has `deploy.yml`, `update.yml` and `rollback.yml`, with every task tagged `deploy` or `update` or `rollback`
- [ ] Modules use FQCN, and OS vars are in `vars/Debian.yml` and `vars/RedHat.yml`
- [ ] `ansible-galaxy collection build` succeeds
