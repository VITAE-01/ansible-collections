---
paths:
  - "adams/**"
  - "jenkinsfile.collections"
  - "ci/**"
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
- **Only collection directories may exist directly under `adams/`.** The pipeline
  (`jenkinsfile.collections`) treats every entry there as a collection to build and publish, and
  its "Validate layout" stage fails on any stray file or folder.

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
- `version:` uses semantic versioning (`MAJOR.MINOR.PATCH`). New collections start at `0.0.1`.
  - Write it as a bare `X.Y.Z`, **unquoted on one top-level line** with no prefix, suffix or
    comment, as in `version: 0.0.1`. The pipeline reads it with
    `grep '^version:' | awk '{print $2}'` and fails the build if it isn't a bare `X.Y.Z`.
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
│   ├── main.yml          # entry point: tag-gated includes only (see Tasks)
│   ├── pre_tasks.yml     # OS family detection + vars loading (OS-specific roles)
│   ├── assert.yml        # pre-flight checks on required inputs (when the role has any)
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
- `tasks/main.yml` is the role's entry point and contains no logic. It only includes the
  pre-task, assert, deploy, update and rollback files with `ansible.builtin.include_tasks`.
  **A run without `--tags deploy`, `update` or `rollback` must do nothing.** Each include
  therefore:
  - carries its direction tag(s),
  - passes them to the included tasks with `apply: tags:` (a dynamic include does not do this on its own),
  - runs only when its tag was requested, via `when:` on `ansible_run_tags`, which is `['all']`
    when no tags are passed.

  Do not use the special `never` tag. Reference: `adams/bootstrap/roles/system_role`.
  ```yaml
  ---
  # tasks file for <role_name>_role
  # Nothing runs unless --tags deploy, update or rollback is passed.

  - name: Pre-tasks - detect the OS family and load its variables   # OS-specific roles only
    ansible.builtin.include_tasks:
      file: pre_tasks.yml
      apply:
        tags: [deploy, update, rollback]
    tags: [deploy, update, rollback]
    when: ansible_run_tags | intersect(['deploy', 'update', 'rollback']) | length > 0

  - name: Pre-flight checks                                          # when the role has assert.yml
    ansible.builtin.include_tasks:
      file: assert.yml
      apply:
        tags: [deploy, update, rollback]
    tags: [deploy, update, rollback]
    when: ansible_run_tags | intersect(['deploy', 'update', 'rollback']) | length > 0

  - name: Deploy
    ansible.builtin.include_tasks:
      file: deploy.yml
      apply:
        tags: [deploy]
    tags: [deploy]
    when: "'deploy' in ansible_run_tags"

  - name: Update
    ansible.builtin.include_tasks:
      file: update.yml
      apply:
        tags: [update]
    tags: [update]
    when: "'update' in ansible_run_tags"

  - name: Rollback
    ansible.builtin.include_tasks:
      file: rollback.yml
      apply:
        tags: [rollback]
    tags: [rollback]
    when: "'rollback' in ansible_run_tags"
  ```
- **Every task has the tag `deploy`, `update` or `rollback`**, as well as the include that
  pulls it in. Callers choose the direction with `--tags deploy`, `--tags update` or
  `--tags rollback`, and can combine them (`--tags deploy,update`).
- Assertions that must stop the whole play (missing required input, unsupported OS) use
  `any_errors_fatal: true`.
- **Every role ships a rollback** that undoes its deploy tasks where possible, such as stopping
  services or removing packages, files and users. Rollback task names start with
  `Rollback - `, as in `Rollback - Delete Users`.
- Use FQCN module names such as `ansible.builtin.user` or `ansible.builtin.service`, never the
  short names.
- Give every task a descriptive `name:` and keep tasks idempotent.
- Use `block`/`rescue` where a failure should be handled gracefully, as `add_user.yml` does.

### OS-specific behaviour
- Detect the OS family and load its vars in `tasks/pre_tasks.yml`, never in `main.yml`:
  1. gather facts with `ansible.builtin.setup` (`gather_subset: [distribution]`) when
     `ansible_os_family is not defined`,
  2. `set_fact` the family into an internal variable, e.g. `_<role>_os_family`,
  3. `assert` (with `any_errors_fatal: true`) that it is in `_<role>_supported_os_families`,
     defined in `vars/main.yml`,
  4. `include_vars` `"{{ _<role>_os_family }}.yml"`.

  Supporting a new OS family means adding it to `_<role>_supported_os_families`, adding
  `vars/<family>.yml`, and adding its `<os>_*.yml` task files.
- Put the values in `vars/Debian.yml` and `vars/RedHat.yml`, and prefix the variable names by
  OS family: `deb_packages`, `deb_services`, `redhat_packages`, `redhat_services`.
- Name OS-specific task files `<os>_<action>.yml` and `<os>_rollback.yml` (for example
  `deb_package.yml` or `redhat_rollback.yml`), and guard them with
  `when: _<role>_os_family == 'Debian'` or `'RedHat'`.

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

- Releases are handled by the Jenkins pipeline in `jenkinsfile.collections` (`release.sh` has
  been removed). Every build lints, syntax-checks and builds the selected collection(s). A
  manually triggered build with the `AUTOMATION_BRANCH` parameter set to `main` also publishes them to the Nexus Galaxy
  repository with `ansible-galaxy collection publish` and pushes a git tag. The `COLLECTION`
  build parameter picks one collection or `all`.
- **When you add a collection, add its name to the `COLLECTION` choices in
  `jenkinsfile.collections`.**
- The pipeline steps live in `ci/` (`check-tools.sh`, `validate-collections.sh`,
  `syntax-check.sh`, `build.sh`, `release.sh` and `nexus-version-exists.py`), and
  `jenkinsfile.collections` only wires them into stages. Change the steps there, not inline in
  the Jenkinsfile. `ci/` sits at the repository root, never under `adams/`.
- A release happens only when `version` in `galaxy.yml` changes. If the version is unchanged,
  its tag already exists on GitHub and the collection is skipped. **Bump the version in every PR
  that changes a collection:**
  - PATCH for fixes
  - MINOR for new roles or backwards-compatible variables
  - MAJOR for breaking changes, such as renamed or removed roles or variables
- Released artifacts use the names below. Do not rename a collection after it has been
  released.
  - Git tag: `<collection_name>-<VERSION>` (e.g. `bootstrap-0.0.1`), with no prefix or suffix
  - Built tarball: `adams-<collection_name>-<VERSION>.tar.gz`
  - Nexus Galaxy: `adams.<collection_name>` version `<VERSION>`

## 9. Checklist for a new collection

- [ ] `adams/<collection_name>/` exists, has a valid name, and matches `name` in `galaxy.yml`
- [ ] `galaxy.yml` has `namespace: adams`, an unquoted `version: 0.0.1`, GPL-2.0-or-later and no placeholders
- [ ] The collection name is added to the `COLLECTION` choices in `jenkinsfile.collections`
- [ ] `meta/runtime.yml`, `plugins/README.md` and `README.md` are present
- [ ] Every role name ends in `_role`, and each role has `deploy.yml`, `update.yml` and `rollback.yml`, with every task tagged `deploy` or `update` or `rollback`
- [ ] `tasks/main.yml` only has tag-gated `include_tasks` (with `apply: tags:` and a `when:` on `ansible_run_tags`), so a run without `--tags` does nothing
- [ ] An OS-specific role detects the OS family and loads `vars/<family>.yml` in `tasks/pre_tasks.yml`
- [ ] Modules use FQCN, and OS vars are in `vars/Debian.yml` and `vars/RedHat.yml`
- [ ] `ansible-galaxy collection build` succeeds
