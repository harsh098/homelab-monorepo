#!/usr/bin/env python3
"""Snapshot Trilium's live SQLite database and upload a restorable data archive."""

import argparse
import base64
import datetime
import hashlib
import json
import os
import sqlite3
import stat
import subprocess
import sys
import tarfile
import tempfile
import uuid
from contextlib import closing
from pathlib import Path
from urllib.parse import quote


SKIP_TOP_LEVEL = {'tmp', 'log', 'backup', 'backups'}
SKIP_FILES = {'document.db', 'document.db-wal', 'document.db-shm', 'document.db-journal'}


def check_database(path: Path) -> None:
    with closing(sqlite3.connect(f'file:{quote(str(path))}?mode=ro', uri=True)) as database:
        if database.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
            raise ValueError('snapshot failed SQLite integrity check')


def snapshot_database(source: Path, destination: Path) -> None:
    if not source.is_file() or source.is_symlink():
        raise ValueError('Trilium document.db is missing or is not a regular file')
    with closing(sqlite3.connect(f'file:{quote(str(source))}?mode=ro', uri=True, timeout=60)) as live:
        with closing(sqlite3.connect(destination)) as snapshot:
            live.backup(snapshot)
    check_database(destination)


def add_file(archive: tarfile.TarFile, path: Path, name: str) -> None:
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError('Trilium data contains an unsupported file type')
    member = tarfile.TarInfo(name)
    member.size = info.st_size
    member.mode = stat.S_IMODE(info.st_mode) & 0o777
    member.mtime = info.st_mtime
    with path.open('rb') as source:
        archive.addfile(member, source)


def raise_walk_error(error: OSError) -> None:
    raise error


def make_archive(data_dir: Path, snapshot: Path, destination: Path) -> None:
    if not data_dir.is_dir() or data_dir.is_symlink():
        raise ValueError('Trilium data directory is missing or is a symlink')
    for required in ('config.ini', 'session_secret.txt'):
        if not (data_dir / required).is_file():
            raise ValueError(f'Trilium data is missing {required}')

    with tarfile.open(destination, 'w:gz') as archive:
        add_file(archive, snapshot, 'document.db')
        for root, dirs, files in os.walk(data_dir, followlinks=False, onerror=raise_walk_error):
            relative = Path(root).relative_to(data_dir)
            if relative == Path('.'):
                dirs[:] = [name for name in dirs if name not in SKIP_TOP_LEVEL]
                files = [name for name in files
                         if name not in SKIP_FILES | SKIP_TOP_LEVEL
                         and not (name.startswith('backup-') and name.endswith('.db'))]
            for name in sorted(dirs):
                path = Path(root) / name
                info = path.lstat()
                if not stat.S_ISDIR(info.st_mode):
                    raise ValueError('Trilium data contains a symlink or unsupported directory')
                member = tarfile.TarInfo((relative / name).as_posix() + '/')
                member.type = tarfile.DIRTYPE
                member.mode = stat.S_IMODE(info.st_mode) & 0o777
                member.mtime = info.st_mtime
                archive.addfile(member)
            for name in sorted(files):
                path = Path(root) / name
                add_file(archive, path, (relative / name).as_posix())


def checksum(path: Path) -> tuple[int, str]:
    digest = hashlib.md5()
    size = 0
    with path.open('rb') as source:
        while chunk := source.read(1024 * 1024):
            size += len(chunk)
            digest.update(chunk)
    return size, base64.b64encode(digest.digest()).decode('ascii')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('--bucket', required=True)
    parser.add_argument('--credentials', type=Path, required=True)
    parser.add_argument('--gcloud-bin', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    stage = 'snapshot'
    try:
        environment = os.environ.copy()
        environment['CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE'] = str(args.credentials.resolve())
        environment['CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_ENABLED'] = 'false'
        environment['CLOUDSDK_CORE_DISABLE_PROMPTS'] = '1'
        with tempfile.TemporaryDirectory(prefix='trilium-backup-') as directory:
            workspace = Path(directory)
            snapshot = workspace / 'document.db'
            archive = workspace / 'trilium.tar.gz'
            snapshot_database(args.data_dir / 'document.db', snapshot)
            stage = 'archive'
            make_archive(args.data_dir, snapshot, archive)
            size, md5 = checksum(archive)
            now = datetime.datetime.now(datetime.timezone.utc)
            object_uri = (
                f'gs://{args.bucket}/trilium/{now:%Y/%m/%d}/'
                f'{now:%Y%m%dT%H%M%S%fZ}-{uuid.uuid4().hex}.tar.gz'
            )
            stage = 'upload'
            subprocess.run(
                [args.gcloud_bin, 'storage', 'cp', '--if-generation-match=0',
                 f'--content-md5={md5}', str(archive), object_uri],
                env=environment, capture_output=True, check=True,
            )
            stage = 'remote metadata verification'
            result = subprocess.run(
                [args.gcloud_bin, 'storage', 'objects', 'describe', object_uri,
                 '--raw', '--format=json'],
                env=environment, capture_output=True, check=True,
            )
            metadata = json.loads(result.stdout)
            if str(metadata.get('size')) != str(size) or metadata.get('md5Hash') != md5:
                raise ValueError('remote archive size or MD5 is missing or mismatched')
            print(object_uri)
    except (OSError, sqlite3.Error, tarfile.TarError, subprocess.CalledProcessError,
            json.JSONDecodeError, ValueError) as error:
        print(f'Trilium backup failed during {stage}: {type(error).__name__}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
