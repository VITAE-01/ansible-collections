#!/usr/bin/env python3
"""Ask the Nexus Galaxy server whether a collection version exists.

Usage: nexus-version-exists.py <namespace> <name> <version> [server]

Resolves the server exactly like `ansible-galaxy collection publish --server <server>`
(default server: nexus): the [galaxy_server.<server>] section of ansible.cfg, overridden by
ANSIBLE_GALAXY_SERVER_<SERVER>_{URL,TOKEN,USERNAME,PASSWORD,VALIDATE_CERTS,TIMEOUT} environment
variables. Token and username/password auth are both supported.

Exit codes: 0 = version exists, 2 = version not found, 1 = lookup failed.
Run it with the Python interpreter that ansible-galaxy uses.
"""

import sys

EXISTS, NOT_FOUND, ERROR = 0, 2, 1


def server_options(server):
    """Resolve [galaxy_server.<server>] the same way ansible-galaxy does (ansible.cfg + env)."""
    from ansible import constants as C
    from ansible.cli.galaxy import SERVER_DEF, SERVER_ADDITIONAL

    defs = {}
    for key, required, option_type in SERVER_DEF:
        definition = {
            'description': 'The %s of the %s Galaxy server' % (key, server),
            'ini': [{'section': 'galaxy_server.%s' % server, 'key': key}],
            'env': [{'name': 'ANSIBLE_GALAXY_SERVER_%s_%s' % (server.upper(), key.upper())}],
            'required': required,
            'type': option_type,
        }
        # 'cli' entries only apply to ansible-galaxy's own command line
        definition.update({k: v for k, v in SERVER_ADDITIONAL.get(key, {}).items() if k != 'cli'})
        defs[key] = definition

    C.config.initialize_plugin_configuration_definitions('galaxy_server', server, defs)
    return C.config.get_plugin_options('galaxy_server', server), C.config._config_file


def main():
    if len(sys.argv) not in (4, 5):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return ERROR
    namespace, name, version = sys.argv[1:4]
    server = sys.argv[4] if len(sys.argv) == 5 else 'nexus'

    try:
        from ansible.errors import AnsibleError
        from ansible.galaxy.api import GalaxyAPI, GalaxyError
        from ansible.galaxy.token import BasicAuthToken, GalaxyToken
    except ImportError as err:
        print("ERROR: cannot import ansible (%s); run with ansible-galaxy's Python" % err, file=sys.stderr)
        return ERROR

    try:
        opts, config_file = server_options(server)
    except AnsibleError as err:
        print("ERROR: Galaxy server '%s' is not configured: %s" % (server, err), file=sys.stderr)
        return ERROR
    if not opts.get('url'):
        print("ERROR: no url for Galaxy server '%s' (config file: %s; env: ANSIBLE_GALAXY_SERVER_%s_URL)"
              % (server, config_file or 'none found', server.upper()), file=sys.stderr)
        return ERROR

    if opts.get('username'):
        token = BasicAuthToken(opts['username'], opts.get('password'))
    elif opts.get('token'):
        token = GalaxyToken(token=opts['token'])
    else:
        token = None
    validate_certs = True if opts.get('validate_certs') is None else opts['validate_certs']

    api = GalaxyAPI(None, server, opts['url'], token=token, validate_certs=validate_certs,
                    timeout=opts.get('timeout') or 60)
    target = "%s.%s %s on %s (%s)" % (namespace, name, version, server, opts['url'])
    try:
        api.get_collection_version_metadata(namespace, name, version)
    except GalaxyError as err:
        if err.http_code == 404:
            return NOT_FOUND
        print("ERROR: lookup of %s failed: %s" % (target, err), file=sys.stderr)
        return ERROR
    except Exception as err:  # network errors, TLS failures, unexpected response format, ...
        print("ERROR: lookup of %s failed: %s: %s" % (target, type(err).__name__, err), file=sys.stderr)
        return ERROR
    return EXISTS


if __name__ == "__main__":
    sys.exit(main())
