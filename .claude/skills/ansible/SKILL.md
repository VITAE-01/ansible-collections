---
name: ansible
description: Workflows for building and changing Ansible content in the ansible-collections repo under the `adams` namespace. Use when adding a new collection, adding or changing a role, writing deploy/update/rollback tasks, bumping a collection version, linting or building a collection, changelog, or preparing a change for the Jenkins release. Triggers on "new collection", "new role", "add a role to adams.*", "rollback tasks", "bump version", "ansible-lint", "build the collection".
---

# Ansible collections: `adams` namespace

This skill gives the step-by-step workflows. The conventions themselves are in
`.claude/rules/collections.md`. **Read that file first, every time.** It is the source of
truth and it takes precedence if anything here disagrees with it.

Reference implementations to copy from:
- `adams/shared`: simple roles (`add_user_role`, `add_group_role`) with no OS split.
- `adams/webservers`: OS-specific roles (`bootstrap_setup_role`, `webservers_role`) and a
  shared-handler helper (`common_role`). These use the older layout.
- `adams/bootstrap/roles/system_role`: **the reference for new roles**. It has the tag-gated
  `main.yml`, `pre_tasks.yml` for OS detection, and `assert.yml`.

## 0. Before you start

1. Read `.claude/rules/collections.md`.
2. Read the nearest reference role end to end before writing a new one.
3. Check the tooling with `command -v ansible-galaxy ansible-playbook ansible-lint`.
   If a tool is missing, tell the user to install it.
4. Run every command from the repository root unless a step says otherwise.

## 1. Workflow: add a new collection

1. Choose `<collection_name>` and check it against rules §1: lowercase letters, digits and
   underscores only, and no clash with an existing directory in `adams/`.
2. Scaffold it:
   ```bash
   ansible-galaxy collection init adams.<collection_name>
   ```
3. Remove any scaffold content that the reference collections don't have, such as `docs/`.
   Keep `meta/runtime.yml` and `plugins/README.md`.
4. Edit `galaxy.yml` as rules §4 requires:
   - `namespace: adams`, `name: <collection_name>`, unquoted `version: 0.0.1`
   - `license: [GPL-2.0-or-later]`, `license_file: ''`
   - Ask the user for the real `authors`, `description`, `tags` and URLs. Don't invent them
     and don't leave the placeholders in.
5. Add the roles using workflow 2.
6. Write the collection `README.md` (rules §7). Use `adams/shared/README.md` as the template
   and change the title, roles, usage and variables.
7. Validate it (workflow 4).
8. Make sure nothing but collection directories sits directly under `adams/`, because the
   pipeline treats every entry there as a collection and fails on anything else.
9. Add the collection name to the `COLLECTION` choices in `jenkinsfile.collections`.

## 2. Workflow: add a role to a collection

1. Scaffold it:
   ```bash
   cd adams/<collection_name>/roles
   ansible-galaxy role init <role_name>_role
   ```
2. Lay out `tasks/` with a deploy, an update and a rollback file:

   `tasks/main.yml` holds wiring only. Copy it from rules §5 (Tasks) or from
   `bootstrap/roles/system_role/tasks/main.yml`. Each file is pulled in with `include_tasks`,
   tagged with its direction, passed on with `apply: tags:`, and guarded by `when:` on
   `ansible_run_tags`, so **a run without `--tags` does nothing**. Don't use the `never` tag.
   ```yaml
   - name: Deploy
     ansible.builtin.include_tasks:
       file: deploy.yml
       apply:
         tags: [deploy]
     tags: [deploy]
     when: "'deploy' in ansible_run_tags"
   ```
   Add the same block for `update` and `rollback`, and put `pre_tasks.yml` (OS-specific roles)
   and `assert.yml` (required inputs) first, tagged `[deploy, update, rollback]` with
   `when: ansible_run_tags | intersect(['deploy', 'update', 'rollback']) | length > 0`.

   `tasks/deploy.yml`: first-time install or create. Tag every task with `deploy`.
   ```yaml
   ---
   - name: Install <thing>
     tags: deploy
     ansible.builtin.<module>:
       ...
   ```

   `tasks/update.yml`: change something that is already deployed, such as config, versions or
   content. Tag every task with `update`. It notifies handlers when something changes.

   `tasks/rollback.yml`: undoes everything in `deploy.yml`, in reverse order. Tag every task
   with `rollback` and start every name with `Rollback - `.
   ```yaml
   ---
   - name: Rollback - Remove <thing>
     tags: rollback
     ansible.builtin.<module>:
       ...
       state: absent
   ```
3. **Tag every task, without exception.** Each task gets `deploy`, `update` or `rollback`, in
   addition to the tag the include passes down, so the direction is still clear when someone
   reads the file on its own. Use FQCN module names only.
4. For an OS-specific role:
   - Write `tasks/pre_tasks.yml` as rules §5 (OS-specific behaviour) describes: gather facts if
     missing, `set_fact` `_<role>_os_family`, assert it is in `_<role>_supported_os_families`
     (in `vars/main.yml`), then `include_vars` `<family>.yml`. Copy
     `bootstrap/roles/system_role/tasks/pre_tasks.yml`.
   - Put values in `vars/Debian.yml` and `vars/RedHat.yml`, using `deb_*` and `redhat_*` names.
   - Split the work into `deb_<action>.yml`, `redhat_<action>.yml`, `deb_rollback.yml` and
     `redhat_rollback.yml`, guarded by `when: _<role>_os_family == '...'`.
5. Put user inputs in `defaults/main.yml` as `deploy_<thing>` lists of dicts. Never put real
   secrets there; use `password_hash` placeholders and say in the README that real values
   belong in vault.
6. For services, notify the `deb service restart` and `redhat service restart` topics. If the
   collection already has a `common_role`, include it with `ansible.builtin.include_role`
   instead of copying its handlers.
7. Write `tests/inventory` (containing `localhost`) and `tests/test.yml`
   (`hosts: localhost`, `remote_user: root`, `roles: [<role_name>_role]`).
8. Replace the template text in the role `README.md`: description, variables, dependencies,
   and an example playbook using `adams.<collection_name>.<role_name>_role`.
9. Add the role to the **Roles**, **Usage** and **Key variables** sections of the collection
    README.
10. Bump the collection version as a MINOR change (workflow 3) and validate it (workflow 4).
11. Update the changelog with a short description and version.

## 3. Workflow: change an existing role or collection

1. Make the change and keep the deploy, update and rollback files consistent:
   - If you add something in `deploy.yml`, add a matching undo step in `rollback.yml`.
   - If something already deployed can change, handle it in `update.yml`.
2. Some existing roles still use the older layout, with `<action>.yml` and `rollback.yml` and
   no `update.yml`. **Don't silently restructure them.** Tell the user and ask whether to
   migrate the role in this change.
3. **Bump `version:` in that collection's `galaxy.yml`.** Without a bump, the pipeline sees an
   existing tag and skips the release.
   - PATCH: bug fix, no interface change.
   - MINOR: new role, new optional variable, new `update` behaviour.
   - MAJOR: renamed or removed role or variable, or changed defaults that alter behaviour.
   Keep the version unquoted on one line.
4. Bump only the collections you actually changed. Each one is released on its own.
5. Validate it (workflow 4).

## 4. Workflow: validate

Run these for every collection you touched, and report the real output. If something fails or
a tool is missing, say so instead of claiming it passed.

```bash
# Lint the collection and its roles; fix every warning and error
ansible-lint adams/<collection_name>

# Syntax-check each role's test playbook
cd adams/<collection_name>/roles
ansible-playbook -i <role>/tests/inventory <role>/tests/test.yml --syntax-check
cd -

# Build the artifact exactly the way the pipeline does, then clean up
ansible-galaxy collection build --force adams/<collection_name> --output-path dist/
rm -rf dist/
```

Then check these by hand:
- `grep '^version:' adams/<collection_name>/galaxy.yml | awk '{print $2}'` prints a bare
  `X.Y.Z` with no quotes and no comment.
- `grep -rL 'tags:' adams/<collection_name>/roles/*/tasks/*.yml` finds no task file without
  tags.
- No placeholders remain: `grep -rn 'example.com\|your name\|your role description' adams/<collection_name>`.

Running test playbooks against real hosts changes those hosts, because they install packages
and create users. Only do it when the user asks, and only against a test target.
`rules §6` says the plan for proper testing (Molecule or ansible-test) is still TBD. Don't
create that scaffolding unless the user asks.

## 5. Release (for information only)

Releases run in Jenkins from `jenkinsfile.collections`. The pipeline lints, syntax-checks and builds, then on a manual build with `AUTOMATION_BRANCH` publishes to the Nexus Galaxy repository and pushes git tags. 
You never publish or push tags yourself. What you are responsible for is getting the change ready for that release: the version is bumped, validation passes, and the docs are updated. 
The artifact names are listed in rules §8.

## 6. Pitfalls in this repo

- The pipeline iterates `ls adams/`, so any non-collection file there fails the build.
- The version must be a bare `X.Y.Z`, unquoted, on one line, with no prefix, suffix or comment.
  Anything else fails the pipeline's "Validate layout" stage.
- A new collection that isn't in the `COLLECTION` choices of `jenkinsfile.collections` is still
  released by an `all` build, but it can't be picked on its own.
- `include_tasks` (dynamic) doesn't pass its tags to the tasks inside it unless you add
  `apply: tags:`. Without `apply`, `--tags deploy` runs the include but skips everything in it.
- Tags alone can't stop a run that has no `--tags`, because Ansible then runs every task. The
  `when:` on `ansible_run_tags` is what makes such a run do nothing. Keep it on every include
  in `main.yml`.
- To test a tag-gated role, run its test playbook with `--tags deploy` (or another direction).
  Without tags it does nothing, so the output tells you nothing.
- `common_role` is resolved by its short name inside the same collection. To use it from
  another collection, refer to it by its FQCN and declare the dependency in `galaxy.yml`.
