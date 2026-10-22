#!/usr/bin/env python3
"""Download and safely restore a Trilium backup into an empty isolated directory."""

import argparse
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
from contextlib import closing
from pathlib import Path
from urllib.parse import quote


LIVE_DATA = Path('/var/lib/homelab/apps/trilium')
OBJECT_PATTERN = re.compile(
    r'gs://[a-z0-9][a-z0-9._-]+/trilium/\d{4}/\d{2}/\d{2}/'
    r'\d{8}T\d{12}Z-[a-f0-9]{32}\.tar\.gz\Z'
)


def empty_destination(destination: Path) -> None:
    if destination.is_symlink() or (destination.exists() and
                                    (not destination.is_dir() or any(destination.iterdir()))):
        raise ValueError('destination must be an empty directory, not a symlink')
    resolved = destination.resolve()
    live = LIVE_DATA.resolve()
    if resolved == live or resolved.is_relative_to(live) or live.is_relative_to(resolved):
        raise ValueError('destination must be isolated from live Trilium data')


def archive_members(archive: tarfile.TarFile) -> list[tarfile.TarInfo]:
    members = archive.getmembers()
    seen = set()
    files = set()
    for member in members:
        name = member.name.rstrip('/')
        parts = name.split('/')
        if (not name or member.name.startswith('/') or
                any(part in ('', '.', '..') for part in parts) or
                not (member.isdir() or member.isfile()) or name in seen):
            raise ValueError('archive contains an unsafe or duplicate member')
        seen.add(name)
        if member.isfile():
            files.add(name)
    if 'document.db' not in files or 'config.ini' not in files:
        raise ValueError('archive is missing the database or config.ini')
    for name in seen:
        parts = name.split('/')
        if any('/'.join(parts[:i]) in files for i in range(1, len(parts))):
            raise ValueError('archive contains a file used as a directory')
    return members


def unpack(archive: tarfile.TarFile, members: list[tarfile.TarInfo], destination: Path) -> None:
    directories = []
    for member in members:
        target = destination.joinpath(*member.name.rstrip('/').split('/'))
        if member.isdir():
            target.mkdir(parents=True, exist_ok=True)
            directories.append((target, member.mode))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            source = archive.extractfile(member)
            if source is None:
                raise ValueError('archive contains an unreadable file')
            with source, target.open('xb') as output:
                shutil.copyfileobj(source, output)
            target.chmod(member.mode & 0o777)
    for directory, mode in sorted(directories, key=lambda item: len(item[0].parts), reverse=True):
        directory.chmod(mode & 0o777)


def check_database(path: Path) -> None:
    with closing(sqlite3.connect(f'file:{quote(str(path))}?mode=ro', uri=True)) as database:
        if database.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
            raise ValueError('restored document.db failed SQLite integrity check')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--object', required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--credentials', type=Path, required=True)
    parser.add_argument('--gcloud-bin', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    stage = 'destination check'
    try:
        if not OBJECT_PATTERN.fullmatch(args.object):
            raise ValueError('object must be an exact Trilium backup URI')
        destination = args.destination.absolute()
        empty_destination(destination)
        environment = os.environ.copy()
        environment['CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE'] = str(args.credentials.resolve())
        environment['CLOUDSDK_CORE_DISABLE_PROMPTS'] = '1'
        with tempfile.TemporaryDirectory(prefix='.trilium-restore-', dir=destination.parent) as directory:
            workspace = Path(directory)
            download = workspace / 'trilium.tar.gz'
            stage = 'download'
            subprocess.run(
                [args.gcloud_bin, 'storage', 'cp', args.object, str(download)],
                env=environment, capture_output=True, check=True,
            )
            stage = 'archive validation and extraction'
            restored = workspace / 'restored'
            restored.mkdir()
            with tarfile.open(download, 'r:gz') as archive:
                members = archive_members(archive)
                unpack(archive, members, restored)
            stage = 'database integrity check'
            check_database(restored / 'document.db')
            stage = 'install into empty destination'
            empty_destination(destination)
            os.replace(restored, destination)
        print(f'Restored Trilium backup into {destination}')
    except (OSError, sqlite3.Error, tarfile.TarError, subprocess.CalledProcessError,
            ValueError) as error:
        print(f'Trilium restore failed during {stage}: {type(error).__name__}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
