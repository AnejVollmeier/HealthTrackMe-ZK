"""CI-only orchestration; existing Flutter test code and expectations are unchanged."""

import json
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import uuid

ROOT = Path(__file__).resolve().parents[2]
MOBILE = ROOT / 'apps/mobile_flutter'
API = 'http://localhost:18080/api/v1'
CASES = ('fs_01_tp01', 'fs_01_tp02', 'fs_02_tp01', 'fs_02_tp02',
         'fs_03_tp01', 'fs_03_tp02')


def directories():
    base = Path(os.environ['RUNNER_TEMP']) / 'functional-e2e'
    for name in ('raw', 'artifacts'):
        (base / name).mkdir(parents=True, exist_ok=True)
    return base


def redact(text, values):
    for value in sorted(set(values), key=len, reverse=True):
        if value:
            text = text.replace(value, '[REDACTED]')
    return re.sub(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
                  '[REDACTED_JWT]', text)


def collect():
    base = directories()
    secret_file = base / 'secrets.json'
    values = json.loads(secret_file.read_text()) if secret_file.exists() else []
    # Existing tests have a public synthetic fixture password. Mask it in logs too.
    support = MOBILE / 'integration_test/support/e2e.dart'
    if support.exists():
        values += re.findall(r"const testPassword = '([^']+)';", support.read_text())
    for source in (base / 'raw').iterdir():
        if source.is_file() and source.suffix in ('.log', '.json', '.md'):
            target = base / 'artifacts' / source.name
            target.write_text(redact(source.read_text(errors='replace'), values),
                              encoding='utf-8')
    summary = base / 'artifacts/summary.md'
    if not summary.exists():
        summary.write_text('Functional E2E did not reach the test loop. '
                           'Check the setup/build steps and available logs.\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as out:
            out.write(summary.read_text())


def logged(command, path, *, cwd=ROOT, env=None, timeout=30):
    """Kill the whole process group on timeout, including Flutter's children."""
    with path.open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        finally:
            stop(process)


def stop(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    # The parent may already have exited while a child still owns the group.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def http(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = Request(API + path, data=data, method=method,
                      headers={'Content-Type': 'application/json'})
    try:
        with urlopen(request, timeout=5) as response:
            return response.status, json.load(response)
    except HTTPError as error:
        return error.code, None


def wait_api(process):
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError('API exited before readiness; see api.log.')
        try:
            status, _ = http('GET', '/users')
            if status == 401:
                return  # Ready AND authentication is enforced.
            if status == 200:
                raise RuntimeError('API permits anonymous access; authentication is off.')
        except (URLError, TimeoutError, ConnectionError):
            pass
        time.sleep(1)
    raise RuntimeError('API readiness exceeded 120 seconds.')


def save_results(raw, results):
    (raw / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    lines = ['# Functional E2E', '', '| Test | Result | Exit code |',
             '| --- | --- | --- |']
    for result in results:
        lines.append(f"| {result['test']} | {result['status']} | {result['exit_code']} |")
    passed = sum(item['status'] == 'PASS' for item in results)
    lines += ['', f'{passed}/{len(CASES)} PASS; {len(results)} cases completed.', '']
    (raw / 'summary.md').write_text('\n'.join(lines))


def run():
    # Never point this orchestration at a developer DB or run it on the workstation.
    if sys.platform != 'linux' or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Run only on the Linux GitHub Actions runner.')
    os.umask(0o077)
    base = directories()
    raw = base / 'raw'
    password, wrong_password, db_password, jwt_secret = [
        secrets.token_urlsafe(32) for _ in range(4)]
    values = [password, wrong_password, db_password, jwt_secret]
    (base / 'secrets.json').write_text(json.dumps(values))
    for value in values:
        print(f'::add-mask::{value}', flush=True)
    chrome = os.environ['E2E_CHROME_BINARY']
    driver = os.environ['E2E_CHROMEDRIVER_BINARY']
    versions = []
    for command in (['flutter', '--version'], ['java', '-version'],
                    [chrome, '--version'], [driver, '--version']):
        versions.append(subprocess.check_output(command, stderr=subprocess.STDOUT,
                                                timeout=30, text=True).strip())
    (raw / 'versions.log').write_text('\n\n'.join(versions) + '\n')
    browser_version = re.search(r'\d+\.\d+\.\d+\.\d+', versions[2])
    driver_version = re.search(r'\d+\.\d+\.\d+\.\d+', versions[3])
    if not browser_version or not driver_version or browser_version[0] != driver_version[0]:
        raise RuntimeError('Chrome and ChromeDriver versions must match exactly.')
    if not versions[0].startswith('Flutter 3.41.9 ') or not re.search(r'version "25[.\"]', versions[1]):
        raise RuntimeError('Expected Flutter 3.41.9 and Java 25, matching this project.')
    print('Building the API with the project Maven wrapper.', flush=True)
    if logged(['bash', './mvnw', '-B', '-Dmaven.test.skip=true', 'package'],
              raw / 'api-build.log', cwd=ROOT / 'apps/api', timeout=600) != 0:
        raise RuntimeError('API build failed; see api-build.log.')

    processes, handles, results = [], [], []
    container_id = None
    try:
        name = 'healthtrackme-e2e-' + uuid.uuid4().hex[:12]
        env = dict(os.environ, POSTGRES_PASSWORD=db_password)
        container_id = subprocess.check_output([
            'docker', 'run', '--detach', '--rm', '--name', name,
            '--publish', '127.0.0.1:55432:5432',
            '--env', 'POSTGRES_DB=healthtrackme_e2e',
            '--env', 'POSTGRES_USER=healthtrackme_e2e',
            '--env', 'POSTGRES_PASSWORD', 'postgres:16'],
            env=env, timeout=120, text=True).strip()
        query = [
            'docker', 'exec', '--env', 'PGPASSWORD', container_id, 'psql',
            '-h', '127.0.0.1', '-U', 'healthtrackme_e2e',
            '-d', 'healthtrackme_e2e', '-Atc',
            "SELECT current_database(), current_setting('server_version_num');"]
        deadline = time.monotonic() + 60
        while True:
            # Query the final TCP server, not initdb's temporary Unix-socket server.
            ready = subprocess.run(query,
                                   capture_output=True, timeout=5, text=True,
                                   env=dict(env, PGPASSWORD=db_password))
            if ready.returncode == 0:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('PostgreSQL readiness exceeded 60 seconds.')
            time.sleep(1)
        database = ready.stdout.strip().split('|')
        if database[0] != 'healthtrackme_e2e' or int(database[1]) // 10000 != 16:
            raise RuntimeError('Expected isolated healthtrackme_e2e on PostgreSQL 16.')
        (raw / 'database.log').write_text('|'.join(database) + '\n')
        api_env = dict(os.environ, PORT='18080',
                       DATABASE_URL='jdbc:postgresql://localhost:55432/healthtrackme_e2e',
                       DATABASE_USERNAME='healthtrackme_e2e', DATABASE_PASSWORD=db_password,
                       JWT_SECRET=jwt_secret, AUTH_ENABLED='true',
                       SPRING_PROFILES_ACTIVE='e2e', APP_MAIL_ENABLED='false',
                       GROQ_API_KEY='', GOOGLE_OAUTH_ALLOWED_CLIENT_IDS='')
        jars = list((ROOT / 'apps/api/target').glob('*.jar'))
        if len(jars) != 1:
            raise RuntimeError('Expected exactly one executable API jar.')
        for command, environment, filename in (
            (['java', '-jar', str(jars[0])], api_env, 'api.log'),
            ([driver, '--port=4444', '--allowed-ips=127.0.0.1,::1'],
             os.environ.copy(), 'chromedriver.log'),
        ):
            handle = (raw / filename).open('w')
            handles.append(handle)
            processes.append(subprocess.Popen(command, env=environment, stdout=handle,
                                               stderr=subprocess.STDOUT,
                                               start_new_session=True))
        wait_api(processes[0])
        deadline = time.monotonic() + 30
        while True:
            if processes[1].poll() is not None:
                raise RuntimeError('ChromeDriver exited; see chromedriver.log.')
            try:
                with urlopen('http://127.0.0.1:4444/status', timeout=3) as response:
                    if json.load(response)['value']['ready']:
                        break
            except (URLError, TimeoutError, ConnectionError):
                pass
            if time.monotonic() >= deadline:
                raise RuntimeError('ChromeDriver readiness exceeded 30 seconds.')
            time.sleep(1)
        email = f'zk-e2e-ci-{uuid.uuid4().hex}@example.com'
        status, payload = http('POST', '/users', {
            'email': email, 'password': password, 'firstName': 'CI',
            'lastName': 'WrongPassword', 'dateOfBirth': '2000-05-15', 'userType': 'PATIENT'})
        if status != 201 or not payload or payload.get('success') is not True:
            raise RuntimeError('Could not create the FS-01-TP02 prerequisite account.')
        config = base / 'config.json'
        config.write_text(json.dumps({
            'API_BASE_URL': API, 'E2E_ISOLATED_DATABASE': 'true',
            'E2E_EMAIL': email, 'E2E_PASSWORD': password,
            'E2E_WRONG_PASSWORD': wrong_password}))
        for case in CASES:
            print(f'Running {case}', flush=True)
            test_driver = ('reload_integration_test.dart' if case == 'fs_02_tp01'
                           else 'integration_test.dart')
            log = raw / f'{case}.log'
            try:
                code = logged([
                    'flutter', 'drive', '--no-pub', f'--driver=test_driver/{test_driver}',
                    f'--target=integration_test/{case}_test.dart', '-d', 'web-server',
                    '--web-port=52145', '--browser-name=chrome', '--driver-port=4444',
                    '--headless', f'--chrome-binary={chrome}',
                    f'--dart-define-from-file={config}'], log, cwd=MOBILE, timeout=420)
            except subprocess.TimeoutExpired:
                code = 124
                with log.open('a') as out:
                    out.write('\nFAIL: CI case timeout exceeded 420 seconds.\n')
            passed = code == 0 and 'All tests passed.' in log.read_text(errors='replace')
            results.append({'test': case, 'status': 'PASS' if passed else 'FAIL',
                            'exit_code': code})
            save_results(raw, results)
            print(f"{results[-1]['status']} {case} (exit {code})", flush=True)
        return 0 if len(results) == 6 and all(r['status'] == 'PASS' for r in results) else 1
    finally:
        for process in reversed(processes):
            stop(process)
        for handle in handles:
            handle.close()
        if container_id:
            try:
                logged(['docker', 'logs', container_id], raw / 'postgres.log', timeout=15)
            finally:
                subprocess.run(['docker', 'rm', '--force', container_id],
                               capture_output=True, timeout=20, check=False)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['collect']:
            collect()
        elif sys.argv[1:] == ['run']:
            sys.exit(run())
        else:
            raise ValueError('Usage: functional_e2e.py run|collect')
    except Exception as error:
        # Do not emit HTTP request payloads, credentials, or full subprocess args.
        secret_file = (Path(os.environ['RUNNER_TEMP']) / 'functional-e2e/secrets.json'
                       if os.environ.get('RUNNER_TEMP') else None)
        values = json.loads(secret_file.read_text()) if secret_file and secret_file.exists() else []
        print(f'Functional E2E failed: {type(error).__name__}: '
              f'{redact(str(error), values)}',
              file=sys.stderr)
        sys.exit(1)
