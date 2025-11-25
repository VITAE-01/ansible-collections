# Ansible Collections Repository

This repository manages internal Ansible collections used across the organization. It provides a centralized location for developing, versioning, and releasing custom Ansible collections with automated tagging and artifact management.

## Overview

The Ansible Collections Repository is designed to:
- Host multiple custom Ansible collections under a unified namespace (`adams`)
- Manage collection versioning and releases using semantic versioning
- Automatically tag and create releases for GitHub
- Publish collection artifacts to Nexus Artifactory for secure storage and distribution

## Repository Structure

```
ansible-collections/
├── LICENSE              # Repository license
├── README.md           # This file
├── release.sh          # Automated release management script
└── adams/              # Main namespace directory for all collections
    ├── shared/         # Shared collection (roles & utilities)
    └── webservers/     # Webservers collection (server setup & configuration)
```

## Collections

### 1. adams.shared

**Purpose:** Shared roles, plugins, and utilities used across deployments

**Location:** `adams/shared/`

**Features:**
- Standard role structure with handlers, defaults, and variables
- Comprehensive test coverage
- Rollback tasks for safe deployments

### 2. adams.webservers

**Purpose:** Web server deployment, configuration, and bootstrapping

**Location:** `adams/webservers/`

**Features:**
- Complete web server lifecycle management
- Modular role design for flexibility
- Integration with common deployment patterns

## Collection Metadata

Each collection includes a `galaxy.yml` file defining:
- Collection namespace and name
- Semantic versioning
- Authors and licensing (GPL-2.0-or-later)
- Dependencies and runtime requirements
- Repository and documentation URLs

Example structure for each collection:
```
collection-name/
├── galaxy.yml          # Collection metadata
├── README.md          # Collection documentation
├── meta/
│   └── runtime.yml    # Runtime requirements
├── plugins/           # Custom plugins
└── roles/             # Ansible roles
    └── role-name/
        ├── defaults/
        ├── handlers/
        ├── tasks/
        ├── tests/
        └── vars/
```

## Versioning and Releases

### Version Management

Collections follow **semantic versioning** (MAJOR.MINOR.PATCH):
- Update version in each collection's `galaxy.yml` file
- Version changes trigger automated release processes
- All changes are tracked through git tags

### Release Process

The `release.sh` script automates the complete release lifecycle:

**Prerequisites:**
- Git repository with origin remote configured
- GitHub CLI (`gh`) installed and authenticated
- Nexus credentials for Artifactory access

**Usage:**
```bash
./release.sh <NEXUS_REPO_URL> <NEXUS_USER> <NEXUS_PASS>
```

**Example:**
```bash
./release.sh https://nexus.example.com/repository/ansible-collections username password
```

**Release Workflow:**

1. **Version Detection:** Reads version from each collection's `galaxy.yml`
2. **Tag Verification:** Checks if release tag already exists (prevents duplicate releases)
3. **Build:** Creates distributable collection artifacts
4. **GitHub Release:** 
   - Creates annotated git tag: `<collection-name>-v<VERSION>`
   - Pushes tag to origin remote
   - Creates GitHub release with release notes
5. **Nexus Publishing:** Uploads collection artifact to Nexus Artifactory
6. **Cleanup:** Removes temporary build artifacts

**Release Artifacts:**

Each release generates:
- Git tag: `<collection>-v<VERSION>` (e.g., `shared-v1.0.0`)
- GitHub release with source archive
- Nexus artifact: `adams-<collection>-<VERSION>.tar.gz`

### Adding a New Collection

To add a new collection to this repository:

1. Create a new directory under `adams/`:
   ```bash
   mkdir -p adams/new-collection/roles
   ```

2. Initialize collection metadata:
   ```bash
   ansible-galaxy collection init --init-path adams/ adams.new_collection
   ```

3. Update `galaxy.yml` with:
   - Meaningful description
   - Accurate authors and license
   - Tags for discoverability
   - Repository and documentation URLs

4. Develop collection content (roles, plugins, modules)

5. Create initial version tag and run release script

## Installation

### From Nexus Artifactory

```bash

```

### From Source (Development)

```bash
# Install from local path

```

## Development

### Repository Organization

- **ansible-collections/** - This repository (collection source code)
- **ansible-playbooks/** - Playbooks using these collections
- **Infrastructure-IaC/** - Infrastructure configuration and deployment

### Development Workflow

1. Create feature branch for changes
2. Implement changes in target collection(s)
3. Update collection version in `galaxy.yml`
4. Test changes with sample playbooks
5. Create pull request to the Dev branch for review and CI to perform test on collections.
6. Merge to Release branch to trigger CD for release to Nexus artifactory

### Testing Collections

Each role includes test playbooks:
```bash
# Test a specific role
ansible-playbook -i adams/shared/roles/add_user_role/tests/inventory \
                 adams/shared/roles/add_user_role/tests/test.yml
```

## File Descriptions

| File | Purpose |
|------|---------|
| `LICENSE` | Repository license (GPL-2.0-or-later) |
| `release.sh` | Automated release and publishing script |
| `adams/shared/` | Shared utilities and common roles |
| `adams/webservers/` | Web server deployment collection |

## Requirements

To use and manage this repository:

- **Ansible:** 2.9+
- **Git:** For version control
- **GitHub CLI:** For automated release creation
- **curl:** For Nexus Artifactory uploads
- **bash:** For running release script

## Support and Contributions

When contributing to this repository:

1. Follow Ansible role best practices
2. Include comprehensive documentation in role READMEs
3. Add test playbooks for all roles
4. Use semantic versioning when updating collection versions
5. Include meaningful commit messages and release notes

## Future Enhancements

This repository is designed for growth:
- Additional collections can be added to the `adams/` namespace
- Each new collection follows the same versioning and release process
- Releases are independently managed per collection
- All artifacts are centrally stored in Nexus Artifactory

## License

This repository and all collections are licensed under GPL-2.0-or-later. See `LICENSE` file for details.

## Related Repositories

- **ansible-playbooks:** Playbooks that consume these collections
- **Infrastructure-IaC:** Infrastructure as Code definitions